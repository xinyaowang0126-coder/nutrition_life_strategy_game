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
$exportPluginPath = Join-Path $projectDir "addons\godot_ai\export\mcp_export_plugin.gd"
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


function Assert-ReleaseConfiguration {
    $preset = Get-Content -LiteralPath $presetPath -Raw -Encoding UTF8
    foreach ($requiredText in @(
        'export_filter="scenes"',
        'res://scenes/boot/Boot.tscn',
        'res://scenes/main_menu/MainMenu.tscn',
        'res://scenes/game_v2/GameRootV2.tscn',
        'scenes/game_v2/components/*.tscn',
        'scenes/game_v2/stages/*.tscn',
        'scripts/CardDataStore.gd',
        'scripts/GameData.gd',
        'scripts/systems/*.gd',
        'scripts/ui_v2/*.gd',
        'scripts/ui_v2/stages/*.gd',
        'addons/godot_ai/**',
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
    foreach ($requiredText in @(
        'autoload/_mcp_game_helper',
        'editor_plugins/enabled',
        'ProjectSettings.set_setting(AUTOLOAD_KEY, null)',
        'ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, null)'
    )) {
        if ($exportPlugin.IndexOf($requiredText, [StringComparison]::Ordinal) -lt 0) {
            throw "Export plugin does not strip a development-only setting: $requiredText"
        }
    }
}


function Assert-CleanWebPack {
    param([string]$PackPath)

    if (-not (Test-Path -LiteralPath $PackPath -PathType Leaf)) {
        throw "Web export did not produce a PCK: $PackPath"
    }
    $packBytes = [IO.File]::ReadAllBytes($PackPath)
    $packText = [Text.Encoding]::ASCII.GetString($packBytes)

    $forbidden = [ordered]@{
        "MCP autoload" = "autoload/_mcp_game_helper"
        "Godot AI development plugin" = "addons/godot_ai/"
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
        "scenes/main_menu/MainMenu",
        "scenes/game_v2/GameRootV2",
        "scenes/game_v2/components/CompactChoiceCard",
        "scenes/game_v2/stages/MealSourceStage",
        "scripts/GameData.gd",
        "scripts/systems/MealResolver",
        "scripts/systems/NutritionLedger",
        "scripts/systems/WeeklyEventService",
        "scripts/systems/DayCarryoverService",
        "scripts/ui_v2/stages/MealStageBase",
        "data/cards/foods.xml",
        "assets/generated/cards/"
    )) {
        if ($packText.IndexOf($requiredPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "Web PCK is missing required production content: $requiredPath"
        }
    }

    $sizeMb = [Math]::Round($packBytes.Length / 1MB, 2)
    Write-Host "Web PCK audit passed ($sizeMb MB)." -ForegroundColor Green
}


$godotExecutable = Resolve-GodotExecutable -RequestedPath $GodotPath
Write-Host "Godot: $godotExecutable"
Write-Host "Project: $projectDir"

Assert-ReleaseConfiguration
Write-Host "Release configuration check passed." -ForegroundColor Green

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
$resultLine = $testOutput | Where-Object { $_.StartsWith("MCP_TEST_RESULT=") } | Select-Object -Last 1
if ([string]::IsNullOrWhiteSpace($resultLine)) {
    throw "Headless tests did not emit MCP_TEST_RESULT."
}
$testResult = $resultLine.Substring("MCP_TEST_RESULT=".Length) | ConvertFrom-Json
if ([int]$testResult.total -le 0 -or [int]$testResult.suite_count -le 0) {
    throw "Headless test run executed no tests."
}
if ([int]$testResult.failed -gt 0) {
    throw "Headless test run reported $($testResult.failed) failure(s)."
}
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
