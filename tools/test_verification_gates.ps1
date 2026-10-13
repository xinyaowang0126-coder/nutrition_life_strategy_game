[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$verificationPath = Join-Path $PSScriptRoot "verify_project.ps1"
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($verificationPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw "Verification script has syntax errors: $parseErrors" }

# Import only gate functions, without launching Godot or exporting anything.
$functionNames = @("Assert-NoScriptFailures", "Assert-HeadlessTestResult", "Get-WebPackPaths", "Assert-CleanWebPack")
foreach ($functionName in $functionNames) {
    $definition = $ast.Find({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
    }, $false)
    if ($null -eq $definition) { throw "Missing verification gate: $functionName" }
    . ([scriptblock]::Create($definition.Extent.Text))
}
$script:checks = 0

function Expect-Rejected {
    param([string]$Label, [scriptblock]$Action, [string]$MessagePattern)
    try { $null = & $Action }
    catch {
        if ($_.Exception.Message -notlike $MessagePattern) { throw "$Label failed for an unexpected reason: $_" }
        $script:checks++
        return
    }
    throw "$Label was incorrectly accepted."
}

function New-TestPack {
    param([int]$Version, [string[]]$Paths, [string]$Payload = "", [switch]$EmptyProjectSettings)
    $stream = New-Object IO.MemoryStream
    $writer = New-Object IO.BinaryWriter($stream)
    $writer.Write([uint32]0x43504447)
    $writer.Write([uint32]$Version)
    foreach ($value in @(4, 7, 2, 2)) { $writer.Write([uint32]$value) }
    $writer.Write([uint64]0)
    if ($Version -ge 3) { $writer.Write([uint64]104) }
    $writer.Write((New-Object byte[] 64))
    $writer.Write([uint32]$Paths.Count)
    foreach ($path in $Paths) {
        $bytes = [Text.Encoding]::UTF8.GetBytes($path)
        $writer.Write([uint32]$bytes.Length)
        $writer.Write($bytes)
        $writer.Write([uint64]0)
        $writer.Write([uint64]$(if ($path -match '(^|/)project\.binary$' -and -not $EmptyProjectSettings) { 1 } else { 0 }))
        $writer.Write((New-Object byte[] 16))
        $writer.Write([uint32]0)
    }
    $writer.Write([Text.Encoding]::UTF8.GetBytes($Payload))
    $writer.Flush()
    $result = $stream.ToArray()
    $writer.Dispose()
    $stream.Dispose()
    return ,$result
}

$green = 'MCP_TEST_RESULT={"passed":1,"failed":0,"skipped":0,"total":1,"suite_count":1}'
$null = Assert-HeadlessTestResult -Output @($green)
$script:checks++
Expect-Rejected "Setup script error with green counts" { Assert-HeadlessTestResult -Output @("SCRIPT ERROR: setup failed", $green) } '*script failure*'
Expect-Rejected "Teardown parse error with green counts" { Assert-HeadlessTestResult -Output @($green, "Parse Error: teardown failed") } '*script failure*'
Expect-Rejected "Missing summary" { Assert-HeadlessTestResult -Output @("no result") } '*did not emit*'
Expect-Rejected "Zero tests" { Assert-HeadlessTestResult -Output @('MCP_TEST_RESULT={"passed":0,"failed":0,"skipped":0,"total":0,"suite_count":0}') } '*no passing tests*'
Expect-Rejected "All skipped" { Assert-HeadlessTestResult -Output @('MCP_TEST_RESULT={"passed":0,"failed":0,"skipped":1,"total":1,"suite_count":1}') } '*no passing tests*'
Expect-Rejected "Inconsistent counts" { Assert-HeadlessTestResult -Output @('MCP_TEST_RESULT={"passed":1,"failed":0,"skipped":0,"total":2,"suite_count":1}') } '*inconsistent result counts*'
$null = Assert-HeadlessTestResult -Output @("ERROR: Failed to read the root certificate store.", $green)
$script:checks++

# These are synthetic directory fixtures; they do not claim to be runnable exports.
$requiredPaths = @(
    "project.binary",
    "scenes/main_menu/MainMenu.tscn", "scenes/game_v2/GameRootV2.tscn",
    "scenes/game_v2/components/CompactChoiceCard.tscn", "scenes/game_v2/components/NewDayPopup.tscn",
    "scenes/game_v2/stages/MealSourceStage.tscn", "scripts/GameData.gd",
    "scripts/systems/MealResolver.gd", "scripts/systems/NutritionLedger.gd",
    "scripts/systems/WeeklyEventService.gd", "scripts/systems/DayCarryoverService.gd",
    "scripts/systems/RecoveryStateService.gd", "scripts/systems/RecoveryRules.gd",
    "scripts/systems/RecoveryGameplayService.gd", "scripts/systems/GameplayBalanceRules.gd",
    "scripts/health/HealthGuidanceFeatureFlags.gd", "scripts/health/HealthDataStore.gd",
    "scripts/health/HealthDataValidator.gd", "scripts/health/HealthEvidenceRegistry.gd",
    "scripts/health/HealthXmlStructure.gd", "scripts/health/MealHealthSnapshot.gd",
    "scripts/health/MealHealthArchive.gd",
    "scripts/ui_v2/NewDayPopup.gd", "scripts/ui_v2/stages/MealStageBase.gd",
    "data/cards/foods.xml", "data/health/food_health_profiles.xml", "data/health/evidence_registry.xml",
    "assets/generated/cards/sample.png", "assets/generated/ui_v2/day_popup/states/clear_focus.png",
    "assets/generated/ui_v2/day_popup/events/mock_exam_notice.png", "assets/generated/ui_v2/day_popup/events/rainy_day.png"
)
foreach ($version in @(2, 3, 4)) {
    $bytes = New-TestPack -Version $version -Paths $requiredPaths
    $paths = Get-WebPackPaths -PackBytes $bytes
    if (($paths -join "|") -ne ($requiredPaths -join "|")) { throw "PCK v$version directory mismatch." }
    $script:checks++
}
Expect-Rejected "Truncated PCK" { Get-WebPackPaths -PackBytes ([byte[]]@(71, 68, 80, 67)) } '*'

$testDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) ("artifacts\verification-gates-" + [Guid]::NewGuid().ToString("N"))
$null = New-Item -ItemType Directory -Path $testDirectory
$packPath = Join-Path $testDirectory "fixture.pck"
try {
    [IO.File]::WriteAllBytes($packPath, (New-TestPack -Version 4 -Paths $requiredPaths))
    Assert-CleanWebPack -PackPath $packPath
    $script:checks++

    $missingSettings = $requiredPaths | Where-Object { $_ -ne "project.binary" }
    [IO.File]::WriteAllBytes($packPath, (New-TestPack -Version 4 -Paths $missingSettings))
    Expect-Rejected "Project settings must be packaged" { Assert-CleanWebPack -PackPath $packPath } '*missing required production content: project.binary*'
    [IO.File]::WriteAllBytes($packPath, (New-TestPack -Version 4 -Paths $requiredPaths -EmptyProjectSettings))
    Expect-Rejected "Export failure cannot leave empty project settings" { Assert-CleanWebPack -PackPath $packPath } '*empty project settings*'
    $missingBalance = $requiredPaths | Where-Object { $_ -ne "scripts/systems/GameplayBalanceRules.gd" }
    [IO.File]::WriteAllBytes($packPath, (New-TestPack -Version 4 -Paths $missingBalance))
    Expect-Rejected "Balance runtime must be packaged" { Assert-CleanWebPack -PackPath $packPath } '*missing required production content: scripts/systems/GameplayBalanceRules*'
    $missingProfile = @($requiredPaths | Where-Object { $_ -ne "data/health/food_health_profiles.xml" })
    [IO.File]::WriteAllBytes($packPath, (New-TestPack -Version 4 -Paths $missingProfile -Payload "res://data/health/food_health_profiles.xml"))
    Expect-Rejected "Payload path constant cannot substitute for XML entry" { Assert-CleanWebPack -PackPath $packPath } '*missing required production content: data/health/food_health_profiles.xml*'
    $missingEvidence = @($requiredPaths | Where-Object { $_ -ne "data/health/evidence_registry.xml" })
    [IO.File]::WriteAllBytes($packPath, (New-TestPack -Version 4 -Paths $missingEvidence -Payload "res://data/health/evidence_registry.xml"))
    Expect-Rejected "Evidence XML must also be an entry" { Assert-CleanWebPack -PackPath $packPath } '*missing required production content: data/health/evidence_registry.xml*'
    $missingHealthScript = @($requiredPaths | Where-Object { $_ -ne "scripts/health/HealthGuidanceFeatureFlags.gd" })
    [IO.File]::WriteAllBytes($packPath, (New-TestPack -Version 4 -Paths $missingHealthScript -Payload "res://scripts/health/HealthGuidanceFeatureFlags.gd"))
    Expect-Rejected "Health script path constants cannot substitute for packaged code" { Assert-CleanWebPack -PackPath $packPath } '*missing required production content: scripts/health/HealthGuidanceFeatureFlags*'
    foreach ($runtimeScript in @('scripts/systems/RecoveryStateService.gd', 'scripts/systems/RecoveryRules.gd', 'scripts/systems/RecoveryGameplayService.gd')) {
        $missingRuntimeScript = @($requiredPaths | Where-Object { $_ -ne $runtimeScript })
        [IO.File]::WriteAllBytes($packPath, (New-TestPack -Version 4 -Paths $missingRuntimeScript -Payload ("res://" + $runtimeScript)))
        $runtimePrefix = $runtimeScript.Substring(0, $runtimeScript.Length - 3)
        Expect-Rejected ("Recovery runtime dependency must be packaged: " + $runtimeScript) { Assert-CleanWebPack -PackPath $packPath } ("*missing required production content: " + $runtimePrefix + "*")
    }
    [IO.File]::WriteAllBytes($packPath, (New-TestPack -Version 4 -Paths ($requiredPaths + "addons/godot_ai/plugin.gd")))
    Expect-Rejected "Development plugin leak" { Assert-CleanWebPack -PackPath $packPath } '*development or legacy content*'
    [IO.File]::WriteAllBytes($packPath, (New-TestPack -Version 4 -Paths ($requiredPaths + "addons/release_guard/plugin.gd")))
    Expect-Rejected "Project export guard must also stay out of releases" { Assert-CleanWebPack -PackPath $packPath } '*development or legacy content*'
}
finally {
    if (Test-Path -LiteralPath $packPath) { Remove-Item -LiteralPath $packPath -Force }
    Remove-Item -LiteralPath $testDirectory -Force
}

# Inspect the checked-in legacy pack without changing it or treating it as current.
$legacyPack = Join-Path (Split-Path -Parent $PSScriptRoot) "Play\index.pck"
if (Test-Path -LiteralPath $legacyPack) {
    $paths = Get-WebPackPaths -PackBytes ([IO.File]::ReadAllBytes($legacyPack))
    if (-not ($paths -match 'scenes/game_v2/GameRootV2')) { throw "Legacy PCK did not yield its game scene." }
    $script:checks++
}
Write-Host "Verification gate checks passed: $script:checks."
