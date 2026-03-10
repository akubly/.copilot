# agentStop hook: per-turn checkpoint
#
# After each agent response, checks for:
#   1. Source files modified without a build attempt
#   2. Source files modified without containment signals
# Writes warnings to sidecar so skill-lifecycle summary can report them.

$ErrorActionPreference = 'SilentlyContinue'

try {
    $raw = [System.IO.StreamReader]::new([Console]::OpenStandardInput()).ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch { exit 0 }

$sidecarDir = Join-Path $env:TEMP 'copilot-session'
if (-not (Test-Path $sidecarDir)) { exit 0 }

$modFile = Join-Path $sidecarDir 'modified-files.log'
$buildFile = Join-Path $sidecarDir 'builds.jsonl'
$offsetFile = Join-Path $sidecarDir 'checkpoint-offset.txt'
$warningFile = Join-Path $sidecarDir 'turn-warnings.jsonl'

# ── Determine new modifications since last checkpoint ──
$lastOffset = 0
if (Test-Path $offsetFile) {
    try { $lastOffset = [int](Get-Content $offsetFile -Raw).Trim() } catch { }
}

if (-not (Test-Path $modFile)) { exit 0 }

$allMods = @(Get-Content $modFile | Where-Object { $_ })
$newMods = @($allMods | Select-Object -Skip $lastOffset)

# Update offset for next checkpoint
Set-Content $offsetFile $allMods.Count -NoNewline

if ($newMods.Count -eq 0) { exit 0 }

# ── Filter to C++ source files ──
$sourceFiles = @($newMods | Where-Object {
    $_ -match '\.(cpp|cxx|c|h|hpp|hxx|inl|w|wxx)$'
})

if ($sourceFiles.Count -eq 0) { exit 0 }

# ── Check 1: Build verification ──
# Were there any builds since last checkpoint?
$buildsSinceCheckpoint = $false
if (Test-Path $buildFile) {
    $builds = @(Get-Content $buildFile)
    # Simple heuristic: if build count > last known build count
    $lastBuildCount = 0
    $buildCountFile = Join-Path $sidecarDir 'checkpoint-build-count.txt'
    if (Test-Path $buildCountFile) {
        try { $lastBuildCount = [int](Get-Content $buildCountFile -Raw).Trim() } catch { }
    }
    if ($builds.Count -gt $lastBuildCount) {
        $buildsSinceCheckpoint = $true
    }
    Set-Content $buildCountFile $builds.Count -NoNewline
}

# ── Check 2: Containment signals ──
$containmentFound = $false
foreach ($f in $sourceFiles) {
    if (Test-Path $f) {
        $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
        if ($content -match 'IsEnabled\(\)|AssertEnabled\(\)') {
            $containmentFound = $true
            break
        }
    }
}

# Also check if any FeatureStaging XML was modified this session
$allFeatureXml = @($allMods | Where-Object { $_ -match 'FeatureStaging.*\.xml$' })
if ($allFeatureXml.Count -gt 0) { $containmentFound = $true }

# ── Emit warnings ──
$warnings = @()

if (-not $buildsSinceCheckpoint) {
    $warnings += @{
        type    = 'no-build'
        message = "$($sourceFiles.Count) C++ file(s) modified this turn without a build attempt"
        files   = @($sourceFiles | Select-Object -First 5)
    }
}

if (-not $containmentFound) {
    $warnings += @{
        type    = 'no-containment'
        message = "$($sourceFiles.Count) C++ file(s) modified without containment signals"
        files   = @($sourceFiles | Select-Object -First 5)
    }
}

foreach ($w in $warnings) {
    try {
        $entry = @{
            timestamp = Get-Date -Format 'o'
            type      = $w.type
            message   = $w.message
            files     = $w.files
        } | ConvertTo-Json -Compress
        Add-Content -Path $warningFile -Value $entry
    } catch { }
}

if ($warnings.Count -gt 0) {
    $types = ($warnings | ForEach-Object { $_.type }) -join ', '
    Write-Host "[turn-checkpoint] Warnings: $types ($($sourceFiles.Count) source files)" -ForegroundColor DarkYellow
}

exit 0
