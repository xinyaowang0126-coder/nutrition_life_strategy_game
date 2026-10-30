[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$Suite = "",
    [switch]$ExportWeb,
    [string]$ExportOutput = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectDir = Join-Path $repoRoot "life-strategy"
$presetPath = Join-Path $projectDir "export_presets.cfg"
$exportPluginPath = Join-Path $projectDir "addons\release_guard\export_guard.gd"
$verificationLogDir = Join-Path $projectDir ".godot\logs"


function Resolve-GodotExecutable {
    param([string]$RequestedPath)

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $candidates += $RequestedPath
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        $candidates += $env:GODOT_BIN
    }
    foreach ($commandName in @("godot", "godot4")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) {
            $candidates += $command.Source
        }
    }
    $runningGodot = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -like "Godot*" -and -not [string]::IsNullOrWhiteSpace($_.Path) } |
        Select-Object -First 1
    if ($null -ne $runningGodot) {
        $candidates += $runningGodot.Path
    }

    $expanded = @()
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        $fullCandidate = [Environment]::ExpandEnvironmentVariables($candidate)
        if ([IO.Path]::GetExtension($fullCandidate) -eq ".exe") {
            $directory = Split-Path -Parent $fullCandidate
            $baseName = [IO.Path]::GetFileNameWithoutExtension($fullCandidate)
            if (-not $baseName.EndsWith("_console", [StringComparison]::OrdinalIgnoreCase)) {
                $expanded += Join-Path $directory ($baseName + "_console.exe")
            }
        }
        $expanded += $fullCandidate
    }

    foreach ($candidate in ($expanded | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Godot executable not found. Pass -GodotPath or set GODOT_BIN."
}


function Invoke-GodotStep {
    param(
        [string]$Label,
        [string[]]$Arguments
    )

    Write-Host "`n==> $Label" -ForegroundColor Cyan
    $captured = New-Object System.Collections.Generic.List[string]
    New-Item -ItemType Directory -Path $verificationLogDir -Force | Out-Null
    $godotLog = Join-Path $verificationLogDir ("verify-" + [Guid]::NewGuid().ToString("N") + ".log")
    $effectiveArguments = @("--log-file", $godotLog) + $Arguments
    $previousErrorAction = $ErrorActionPreference
    try {
        # Windows PowerShell wraps native stderr as non-terminating error
        # records. Keep collecting it so Godot's own exit code remains the
        # source of truth for the step.
        $ErrorActionPreference = "Continue"
        & $script:godotExecutable @effectiveArguments 2>&1 | ForEach-Object {
            $line = [string]$_
            $captured.Add($line)
            Write-Host $line
        }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
        if (Test-Path -LiteralPath $godotLog) {
            Remove-Item -LiteralPath $godotLog -Force
        }
    }
    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode."
    }
    return ,$captured.ToArray()
}


function Assert-NoScriptFailures {
    param(
        [string]$Label,
        [string[]]$Output
    )

    $fatalPatterns = @(
        "SCRIPT ERROR:",
        "Parse Error:",
        "Failed to load script",
        "Failed to instantiate an autoload"
    )
    foreach ($line in $Output) {
        foreach ($pattern in $fatalPatterns) {
            if ($line.IndexOf($pattern, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                throw "$Label reported a script failure: $line"
            }
        }
    }
}


function Assert-HeadlessTestResult {
    param([string[]]$Output)

    # Suite setup/teardown and autoload errors can occur outside the test
    # framework's per-test capture window, even with failed=0 and exit=0.
    Assert-NoScriptFailures -Label "Headless tests" -Output $Output
    $resultLine = $Output | Where-Object { $_.StartsWith("MCP_TEST_RESULT=") } | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($resultLine)) {
        throw "Headless tests did not emit MCP_TEST_RESULT."
    }
    $result = $resultLine.Substring("MCP_TEST_RESULT=".Length) | ConvertFrom-Json
    if ([int]$result.total -le 0 -or [int]$result.suite_count -le 0 -or [int]$result.passed -le 0) {
        throw "Headless test run executed no passing tests."
    }
    if ([int]$result.failed -gt 0) {
        throw "Headless test run reported $($result.failed) failure(s)."
    }
    if ([int]$result.failed -lt 0 -or [int]$result.skipped -lt 0 -or
        ([int]$result.passed + [int]$result.failed + [int]$result.skipped) -ne [int]$result.total) {
        throw "Headless test run reported inconsistent result counts."
    }
    return $result
}


function Assert-ReleaseConfiguration {
    $preset = Get-Content -LiteralPath $presetPath -Raw -Encoding UTF8
    foreach ($requiredText in @(
        'export_filter="scenes"',
        'res://scenes/boot/Boot.tscn',
        'res://scenes/main_menu/MainMenu.tscn',
        'res://scenes/game_v2/GameRootV2.tscn',
        'scenes/game_v2/components/*.tscn',
        'scenes/game_v2/stages/*.tscn',
        'assets/generated/ui_v2/day_popup/states/*.png',
        'assets/generated/ui_v2/day_popup/events/*.png',
        'scripts/CardDataStore.gd',
        'scripts/GameData.gd',
        'scripts/systems/*.gd',
        'scripts/health/*.gd',
        'scripts/ui_v2/*.gd',
        'scripts/ui_v2/stages/*.gd',
        'scripts/stories/*.gdshader',
        'assets/generated/stories/props/regions.json',
        'data/characters/*.xml',
        'data/health/*.xml',
        'addons/godot_ai/**',
        'addons/release_guard/**',
        'tests/**',
        'scenes/game/**'
    )) {
        if ($preset.IndexOf($requiredText, [StringComparison]::Ordinal) -lt 0) {
            throw "Release preset is missing required configuration: $requiredText"
        }
    }
    if ($preset.IndexOf('export_filter="all_resources"', [StringComparison]::Ordinal) -ge 0) {
        throw "Release preset still exports all project resources."
    }

    $exportPlugin = Get-Content -LiteralPath $exportPluginPath -Raw -Encoding UTF8
    $projectSettings = Get-Content -LiteralPath (Join-Path $projectDir "project.godot") -Raw -Encoding UTF8
    if ($projectSettings -notmatch '(?m)^enabled=PackedStringArray\([^\r\n]*"res://addons/release_guard/plugin\.cfg"') {
        throw "Project release guard is not enabled."
    }
    foreach ($requiredText in @(
        'editor_plugins/enabled',
        'ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, null)'
    )) {
        if ($exportPlugin.IndexOf($requiredText, [StringComparison]::Ordinal) -lt 0) {
            throw "Export plugin does not strip a development-only setting: $requiredText"
        }
    }
    $mcpExportPlugin = Get-Content -LiteralPath (Join-Path $projectDir "addons\godot_ai\export\mcp_export_plugin.gd") -Raw -Encoding UTF8
    foreach ($requiredText in @('autoload/_mcp_game_helper', 'ProjectSettings.set_setting(AUTOLOAD_KEY, null)')) {
        if ($mcpExportPlugin.IndexOf($requiredText, [StringComparison]::Ordinal) -lt 0) {
            throw "MCP export plugin no longer strips its helper: $requiredText"
        }
    }
}


function Assert-CleanWebPack {
    param([string]$PackPath)

    if (-not (Test-Path -LiteralPath $PackPath -PathType Leaf)) {
        throw "Web export did not produce a PCK: $PackPath"
    }
    # Pages serves the checked-in export, so the pack must fit regular Git.
    if ((Get-Item -LiteralPath $PackPath).Length -gt 100MB) {
        throw "Web PCK exceeds GitHub's 100 MiB file limit. Reduce texture import size before publishing."
    }
    $packBytes = [IO.File]::ReadAllBytes($PackPath)
    $packText = [Text.Encoding]::ASCII.GetString($packBytes)
    $packPaths = Get-WebPackPaths -PackBytes $packBytes
    $directoryText = $packPaths -join "`n"

    $forbidden = [ordered]@{
        "MCP autoload" = "autoload/_mcp_game_helper"
        "Godot AI development plugin" = "addons/godot_ai/"
        "project release guard" = "addons/release_guard/"
        "test suites" = "tests/test_"
        "legacy game scene" = "scenes/game/GameRoot"
        "legacy game controller" = "scripts/GameRoot.gd"
        "legacy UI" = "scripts/ui/ChoiceCard"
    }
    $leaks = @()
    foreach ($entry in $forbidden.GetEnumerator()) {
        if ($packText.IndexOf([string]$entry.Value, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $leaks += [string]$entry.Key
        }
    }
    if ($leaks.Count -gt 0) {
        throw "Web PCK contains development or legacy content: $($leaks -join ', ')."
    }

    foreach ($requiredPath in @(
        "project.binary",
        "scenes/main_menu/MainMenu",
        "scenes/game_v2/GameRootV2",
        "scenes/game_v2/components/CompactChoiceCard",
        "scenes/game_v2/components/NewDayPopup",
        "scenes/game_v2/components/EndingScreen",
        "scenes/game_v2/stages/MealSourceStage",
        "scripts/GameData.gd",
        "scripts/systems/MealResolver",
        "scripts/systems/NutritionLedger",
        "scripts/systems/WeeklyEventService",
        "scripts/systems/DayCarryoverService",
        "scripts/systems/RecoveryStateService",
        "scripts/systems/RecoveryRules",
        "scripts/systems/RecoveryGameplayService",
        "scripts/systems/GameplayBalanceRules",
        "scripts/systems/EndingFeedbackBuilder",
        "scripts/systems/ActionFeedbackTrace",
        "scripts/ui_v2/EndingFeedbackCopy",
        "scripts/ui_v2/EndingScreen",
        "scripts/health/HealthGuidanceFeatureFlags",
        "scripts/health/HealthDataStore",
        "scripts/health/HealthDataValidator",
        "scripts/health/HealthEvidenceRegistry",
        "scripts/health/HealthXmlStructure",
        "scripts/health/MealHealthSnapshot",
        "scripts/health/MealHealthArchive",
        "scripts/ui_v2/NewDayPopup",
        "scripts/ui_v2/stages/MealStageBase",
        "data/cards/foods.xml",
        "data/health/food_health_profiles.xml",
        "data/health/evidence_registry.xml",
        "assets/generated/cards/",
        "assets/generated/ui_v2/day_popup/states/clear_focus",
        "assets/generated/ui_v2/day_popup/events/mock_exam_notice",
        "assets/generated/ui_v2/day_popup/events/rainy_day"
        "scripts/stories/CookingPlanStage"
        "scripts/stories/HouseholdWorktop"
        "scripts/stories/KitchenStockStage"
        "scripts/stories/HouseholdMarketStage"
        "scripts/stories/HouseholdLocations"
        "scripts/stories/PropTint"
        "scenes/stories/HouseholdMealStage"
        "assets/generated/stories/ingredients/ingredient_atlas"
        "assets/generated/stories/ingredients/ingredient_regions.json"
        "assets/generated/stories/props/regions.json"
        "assets/generated/stories/actions/zhou_rehearse-v1"
        "assets/generated/stories/actions/zhou_group_rehearsal-v1"
        "assets/generated/stories/actions/zhou_perform-v1"
        "assets/generated/stories/actions/zhou_call_friend-v1"
        "assets/generated/endings/feedback/student_shortfall-v1"
        "assets/generated/endings/feedback/zhou_unready-v1"
        "assets/generated/endings/feedback/zhou_other_choice-v1"
        "assets/generated/stories/night/zhou_home_night-v1"
        "assets/generated/stories/locations/zhou-kitchen-v1"
        "assets/generated/stories/locations/zhou-kitchen-portrait-v1"
        "assets/generated/stories/locations/zhou-open-fridge-v1"
        "assets/generated/stories/locations/zhou-market-wide-v1"
        "assets/generated/stories/locations/zhou-market-portrait-v1"
        "assets/generated/stories/locations/zhou-breakfast-shop-v1"
        "assets/generated/stories/locations/zhou-homestyle-diner-v1"
        "assets/generated/stories/locations/zhou-fruit-stall-v1"
        "assets/generated/stories/locations/steamed-bun-v1"
        "assets/fonts/HouseholdBody"
        "assets/fonts/HouseholdSansSC-Medium"
        "assets/fonts/HouseholdSans-OFL.txt"
    )) {
        if ($directoryText.IndexOf($requiredPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "Web PCK is missing required production content: $requiredPath"
        }
    }

    $sizeMb = [Math]::Round($packBytes.Length / 1MB, 2)
    Write-Host "Web PCK audit passed ($sizeMb MB)." -ForegroundColor Green
}


function Get-WebPackPaths {
    param([byte[]]$PackBytes)

    # Read the standalone, unencrypted PCK directory. Searching payload text
    # alone accepts a missing XML file when a script contains its path constant.
    # Format reference: Godot core/io/file_access_pack.cpp, try_open_pack().
    $stream = New-Object IO.MemoryStream(,$PackBytes)
    $reader = New-Object IO.BinaryReader($stream)
    try {
        if ($reader.ReadUInt32() -ne 0x43504447) {
            throw "Web PCK has an invalid header."
        }
        $version = $reader.ReadUInt32()
        if ($version -notin @(2, 3, 4)) {
            throw "Unsupported Web PCK format: $version."
        }
        $null = $reader.ReadBytes(12) # Engine version.
        $flags = $reader.ReadUInt32()
        if (($flags -band (-bnot 2)) -ne 0) {
            throw "Web PCK must be a standalone, unencrypted full pack."
        }
        $fileBase = $reader.ReadUInt64()
        if ($version -ge 3) {
            $directoryOffset = $reader.ReadUInt64()
            if ($directoryOffset -gt ($stream.Length - 4)) {
                throw "Web PCK directory is outside the file."
            }
            $stream.Position = $directoryOffset
        }
        else {
            $null = $reader.ReadBytes(64) # Reserved v2 header fields.
        }
        $fileCount = $reader.ReadUInt32()
        if ($fileCount -le 0 -or $fileCount -gt (($stream.Length - $stream.Position) / 40)) {
            throw "Web PCK has an invalid file count."
        }
        $paths = New-Object System.Collections.Generic.List[string]
        for ($index = 0; $index -lt $fileCount; $index++) {
            $pathLength = $reader.ReadUInt32()
            if ($pathLength -le 0 -or $pathLength -gt 1MB -or
                $pathLength + 36 -gt ($stream.Length - $stream.Position)) {
                throw "Web PCK has a truncated or invalid directory entry."
            }
            $path = [Text.Encoding]::UTF8.GetString($reader.ReadBytes($pathLength)).TrimEnd([char]0)
            $offset = $reader.ReadUInt64()
            $size = $reader.ReadUInt64()
            if ($path -match '(^|/)project\.binary$' -and $size -eq 0) {
                throw "Web PCK contains empty project settings: $path"
            }
            $null = $reader.ReadBytes(16) # MD5; content hashes are not verified here.
            $entryFlags = $reader.ReadUInt32()
            if ($entryFlags -ne 0 -or ([decimal]$fileBase + $offset + $size) -gt $stream.Length) {
                throw "Web PCK contains an unsupported or out-of-bounds file entry: $path"
            }
            if ($path -match '(^|/)project\.binary$') {
                if ($size -lt 4) { throw "Web PCK contains truncated project settings: $path" }
                $directoryPosition = $stream.Position
                $stream.Position = [long]([decimal]$fileBase + $offset)
                $settingsMagic = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
                $stream.Position = $directoryPosition
                if ($settingsMagic -ne "ECFG") { throw "Web PCK contains invalid project settings header: $path" }
            }
            $paths.Add($path)
        }
        return ,$paths.ToArray()
    }
    finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}


$godotExecutable = Resolve-GodotExecutable -RequestedPath $GodotPath
Write-Host "Godot: $godotExecutable"
Write-Host "Project: $projectDir"

Assert-ReleaseConfiguration
Write-Host "Release configuration check passed." -ForegroundColor Green

$importOutput = Invoke-GodotStep -Label "Import resources and global script classes" -Arguments @(
    "--headless",
    "--path", $projectDir,
    "--editor",
    "--import"
)
Assert-NoScriptFailures -Label "Resource import" -Output $importOutput

$testArguments = @(
    "--headless",
    "--path", $projectDir,
    "--script", "res://tests/headless_runner.gd"
)
if (-not [string]::IsNullOrWhiteSpace($Suite)) {
    $testArguments += "--"
    $testArguments += "--suite=$Suite"
}
$testOutput = Invoke-GodotStep -Label "Headless tests" -Arguments $testArguments
$testResult = Assert-HeadlessTestResult -Output $testOutput
Write-Host "Headless tests passed: $($testResult.passed)/$($testResult.total)." -ForegroundColor Green

$smokeOutput = Invoke-GodotStep -Label "Main scene smoke test" -Arguments @(
    "--headless",
    "--path", $projectDir,
    "--quit-after", "30"
)
Assert-NoScriptFailures -Label "Main scene smoke test" -Output $smokeOutput
Write-Host "Main scene smoke test passed." -ForegroundColor Green

if ($ExportWeb) {
    $ownsExportDirectory = [string]::IsNullOrWhiteSpace($ExportOutput)
    if ($ownsExportDirectory) {
        $exportDirectory = Join-Path ([IO.Path]::GetTempPath()) ("nutrition-life-web-" + [Guid]::NewGuid().ToString("N"))
    }
    else {
        if ([IO.Path]::IsPathRooted($ExportOutput)) {
            $exportDirectory = [IO.Path]::GetFullPath($ExportOutput)
        }
        else {
            $exportDirectory = [IO.Path]::GetFullPath((Join-Path (Get-Location) $ExportOutput))
        }
    }
    New-Item -ItemType Directory -Path $exportDirectory -Force | Out-Null
    try {
        $webIndex = Join-Path $exportDirectory "index.html"
        $exportOutputLines = Invoke-GodotStep -Label "Temporary Web export" -Arguments @(
            "--headless",
            "--path", $projectDir,
            "--export-release", "Web", $webIndex
        )
        Assert-NoScriptFailures -Label "Temporary Web export" -Output $exportOutputLines
        $titleAssetOutput = Invoke-GodotStep -Label "Prepare title loading backgrounds" -Arguments @(
            "--headless", "--path", $projectDir,
            "--script", (Join-Path $repoRoot "tools\prepare_title_web_assets.gd"),
            "--", "--output=$exportDirectory"
        )
        Assert-NoScriptFailures -Label "Title loading backgrounds" -Output $titleAssetOutput
        Assert-CleanWebPack -PackPath (Join-Path $exportDirectory "index.pck")
        if (-not $ownsExportDirectory) {
            Write-Host "Verified Web export retained at: $exportDirectory"
        }
    }
    finally {
        if ($ownsExportDirectory -and (Test-Path -LiteralPath $exportDirectory)) {
            Remove-Item -LiteralPath $exportDirectory -Recurse -Force
        }
    }
}

Write-Host "`nProject verification passed." -ForegroundColor Green
