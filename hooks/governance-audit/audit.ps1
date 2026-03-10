# Governance Audit Hook
# Checks that source modifications have containment records

$ErrorActionPreference = 'SilentlyContinue'

# Read hook input
try {
    $raw = [System.IO.StreamReader]::new([Console]::OpenStandardInput()).ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch { }

$cwd = if ($hookData.cwd) { $hookData.cwd } else { $PWD.Path }

# ── Collect modified source files ──
# Source 1: sidecar file from postToolUse (session-scoped, precise)
$modifiedFiles = @()
$sidecarDir = Join-Path $env:TEMP 'copilot-session'
$modFile = Join-Path $sidecarDir 'modified-files.log'
if (Test-Path $modFile) {
    $modifiedFiles = @(Get-Content $modFile | Where-Object { $_ })
}

# Source 2: git diff as fallback (includes pre-session changes, less precise)
if ($modifiedFiles.Count -eq 0) {
    try {
        $upstream = & git -C $cwd rev-parse --abbrev-ref '@{upstream}' 2>$null
        if ($upstream) {
            $modifiedFiles = @(& git -C $cwd diff --name-only $upstream 2>$null)
        }
    } catch { }
}

if ($modifiedFiles.Count -eq 0) {
    Write-Host "[governance-audit] No modified files detected" -ForegroundColor DarkGray
    exit 0
}

# ── Filter to C++ source files ──
$sourceFiles = @($modifiedFiles | Where-Object {
    $_ -match '\.(cpp|cxx|c|h|hpp|hxx|inl|w|wxx)$'
})

if ($sourceFiles.Count -eq 0) {
    Write-Host "[governance-audit] $($modifiedFiles.Count) files modified, none are C++ source" -ForegroundColor DarkGray
    exit 0
}

# ── Check for containment signals ──
# Heuristic: look for FeatureStaging XML modifications or IsEnabled() patterns
# in the same changeset. This is imperfect but catches the common case.
$containmentSignals = @($modifiedFiles | Where-Object {
    $_ -match 'FeatureStaging.*\.xml$' -or $_ -match '\.vcxitems$'
})

$containedPatternFound = $false
foreach ($f in $sourceFiles) {
    if (Test-Path $f) {
        $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
        if ($content -match 'IsEnabled\(\)|AssertEnabled\(\)') {
            $containedPatternFound = $true
            break
        }
    }
}

# ── Report ──
if ($containmentSignals.Count -gt 0 -or $containedPatternFound) {
    Write-Host "[governance-audit] $($sourceFiles.Count) C++ files modified - containment signals found" -ForegroundColor DarkGray
} else {
    Write-Host "[governance-audit] WARNING: $($sourceFiles.Count) C++ files modified but no containment detected" -ForegroundColor Yellow
    Write-Host "  Modified source files:" -ForegroundColor Yellow
    $sourceFiles | Select-Object -First 10 | ForEach-Object {
        Write-Host "    $_" -ForegroundColor Yellow
    }
    if ($sourceFiles.Count -gt 10) {
        Write-Host "    ... and $($sourceFiles.Count - 10) more" -ForegroundColor Yellow
    }
    Write-Host "  Consider running the add-containment skill." -ForegroundColor Yellow
}
