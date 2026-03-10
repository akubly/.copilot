# Skill Lifecycle Hook - Session End
# Reads sidecar files to produce a session activity summary

$ErrorActionPreference = 'SilentlyContinue'

# Read hook input
try {
    $raw = [System.IO.StreamReader]::new([Console]::OpenStandardInput()).ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch { }

$reason = if ($hookData.reason) { $hookData.reason } else { 'unknown' }
$sidecarDir = Join-Path $env:TEMP 'copilot-session'

if (-not (Test-Path $sidecarDir)) {
    Write-Host "[skill-lifecycle] Session ended ($reason) - no sidecar data" -ForegroundColor DarkGray
    exit 0
}

# ── Compute session duration ──
$duration = ''
$startFile = Join-Path $sidecarDir 'session-start.txt'
if (Test-Path $startFile) {
    try {
        $start = [DateTime]::Parse((Get-Content $startFile -Raw).Trim())
        $elapsed = (Get-Date) - $start
        $h = [Math]::Floor($elapsed.TotalHours)
        $m = $elapsed.Minutes
        $s = $elapsed.Seconds
        $duration = " | duration: ${h}h${m}m${s}s"
    } catch { }
}

# ── Tool execution stats ──
$toolSummary = ''
$statsFile = Join-Path $sidecarDir 'tool-stats.csv'
if (Test-Path $statsFile) {
    $lines = @(Get-Content $statsFile)
    $total = $lines.Count
    $failures = @($lines | Where-Object { $_ -match ',failure$' }).Count
    $denials = @($lines | Where-Object { $_ -match ',denied$' }).Count
    $toolSummary = " | tools: $total calls"
    if ($failures -gt 0) { $toolSummary += ", $failures failed" }
    if ($denials -gt 0) { $toolSummary += ", $denials denied" }
}

# ── File modification count ──
$modSummary = ''
$modFile = Join-Path $sidecarDir 'modified-files.log'
if (Test-Path $modFile) {
    $modCount = @(Get-Content $modFile | Where-Object { $_ }).Count
    $modSummary = " | files modified: $modCount"
}

# ── Error count ──
$errSummary = ''
$errFile = Join-Path $sidecarDir 'errors.jsonl'
if (Test-Path $errFile) {
    $errCount = @(Get-Content $errFile).Count
    if ($errCount -gt 0) {
        $errSummary = " | errors: $errCount"
    }
}

# ── Prompt count ──
$promptSummary = ''
$promptFile = Join-Path $sidecarDir 'prompts.jsonl'
if (Test-Path $promptFile) {
    $promptCount = @(Get-Content $promptFile | Where-Object { $_ }).Count
    if ($promptCount -gt 0) {
        $promptSummary = " | prompts: $promptCount"
    }
}

# ── Turn warnings ──
$turnWarnSummary = ''
$warningFile = Join-Path $sidecarDir 'turn-warnings.jsonl'
if (Test-Path $warningFile) {
    $warnCount = @(Get-Content $warningFile | Where-Object { $_ }).Count
    if ($warnCount -gt 0) {
        $turnWarnSummary = " | turn-warnings: $warnCount"
    }
}

# ── Subagent usage ──
$subagentSummary = ''
$subagentFile = Join-Path $sidecarDir 'subagents.jsonl'
if (Test-Path $subagentFile) {
    $subCount = @(Get-Content $subagentFile | Where-Object { $_ }).Count
    if ($subCount -gt 0) {
        $subagentSummary = " | subagents: $subCount"
    }
}

# ── Test results ──
$testSummary = ''
$testFile = Join-Path $sidecarDir 'test-results.jsonl'
if (Test-Path $testFile) {
    $testLines = @(Get-Content $testFile | Where-Object { $_ })
    if ($testLines.Count -gt 0) {
        $testSummary = " | test runs: $($testLines.Count)"
    }
}

# ── Build summary ──
$buildSummary = ''
$buildFile = Join-Path $sidecarDir 'builds.jsonl'
if (Test-Path $buildFile) {
    $builds = @(Get-Content $buildFile)
    $buildTotal = $builds.Count
    $buildFails = @($builds | Where-Object { $_ -match '"result"\s*:\s*"failure"' }).Count
    $buildSummary = " | builds: $buildTotal"
    if ($buildFails -gt 0) { $buildSummary += " ($buildFails failed)" }
}

# ── Skill lint warnings ──
$lintSummary = ''
$lintFlag = Join-Path $sidecarDir 'skills-modified.flag'
if (Test-Path $lintFlag) {
    $modSkills = @(Get-Content $lintFlag | Where-Object { $_ }).Count
    $lintSummary = " | skill files modified: $modSkills (run lint-skills.ps1)"
}

Write-Host "[skill-lifecycle] Session ended ($reason)$duration$toolSummary$modSummary$buildSummary$errSummary$promptSummary$turnWarnSummary$subagentSummary$testSummary$lintSummary" -ForegroundColor DarkGray
