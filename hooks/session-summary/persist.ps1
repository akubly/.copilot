# Session Summary Hook
# Persists session state to a durable file for cross-session recall.
#
# Since hooks can't access the session SQLite DB or memory MCP server,
# this hook reads sidecar files and writes a summary to a persistent
# location that the next session's agent can discover.

$ErrorActionPreference = 'SilentlyContinue'

try {
    $raw = [System.IO.StreamReader]::new([Console]::OpenStandardInput()).ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch { }

$cwd = if ($hookData.cwd) { $hookData.cwd } else { $PWD.Path }
$reason = if ($hookData.reason) { $hookData.reason } else { 'unknown' }
$copilotDir = Join-Path $env:USERPROFILE '.copilot'

$sidecarDir = Join-Path $env:TEMP 'copilot-session'
if (-not (Test-Path $sidecarDir)) {
    Write-Host "[session-summary] No sidecar data to persist" -ForegroundColor DarkGray
    exit 0
}

# ── Collect session metadata ──
$summary = @{
    timestamp   = Get-Date -Format 'o'
    cwd         = $cwd
    reason      = $reason
    branch      = $null
    repo        = $null
    modifiedFiles = @()
    toolStats   = @{ total = 0; failures = 0; denials = 0 }
    errorCount  = 0
}

# Git context
try {
    $summary.branch = (& git -C $cwd rev-parse --abbrev-ref HEAD 2>$null)
    $remote = (& git -C $cwd remote get-url origin 2>$null)
    if ($remote -match '/([^/]+?)(?:\.git)?$') { $summary.repo = $Matches[1] }
} catch { }

# Modified files
$modFile = Join-Path $sidecarDir 'modified-files.log'
if (Test-Path $modFile) {
    $summary.modifiedFiles = @(Get-Content $modFile | Where-Object { $_ } | ForEach-Object { "$_" })
}

# Tool stats
$statsFile = Join-Path $sidecarDir 'tool-stats.csv'
if (Test-Path $statsFile) {
    $lines = @(Get-Content $statsFile)
    $summary.toolStats.total = $lines.Count
    $summary.toolStats.failures = @($lines | Where-Object { $_ -match ',failure$' }).Count
    $summary.toolStats.denials = @($lines | Where-Object { $_ -match ',denied$' }).Count
}

# Errors
$errFile = Join-Path $sidecarDir 'errors.jsonl'
if (Test-Path $errFile) {
    $summary.errorCount = @(Get-Content $errFile).Count
}

# Prompts
$promptFile = Join-Path $sidecarDir 'prompts.jsonl'
if (Test-Path $promptFile) {
    $promptLines = @(Get-Content $promptFile | Where-Object { $_ })
    $summary.promptCount = $promptLines.Count
    if ($promptLines.Count -gt 0) {
        try {
            $firstPrompt = $promptLines[0] | ConvertFrom-Json
            $summary.firstPrompt = $firstPrompt.prompt
        } catch { }
    }
}

# Turn warnings
$warningFile = Join-Path $sidecarDir 'turn-warnings.jsonl'
if (Test-Path $warningFile) {
    $summary.turnWarnings = @(Get-Content $warningFile | Where-Object { $_ }).Count
}

# Subagent usage
$subagentFile = Join-Path $sidecarDir 'subagents.jsonl'
if (Test-Path $subagentFile) {
    $summary.subagentCount = @(Get-Content $subagentFile | Where-Object { $_ }).Count
}

# Test results
$testFile = Join-Path $sidecarDir 'test-results.jsonl'
if (Test-Path $testFile) {
    $testLines = @(Get-Content $testFile | Where-Object { $_ })
    $summary.testRuns = $testLines.Count
}

# VM interactions
$vmFile = Join-Path $sidecarDir 'vm-interactions.jsonl'
if (Test-Path $vmFile) {
    $summary.vmInteractions = @(Get-Content $vmFile | Where-Object { $_ }).Count
}

# ── Persist to durable location ──
# Write to ~/.copilot/session-state/last-session.json
# The next session's agent or memory-prefetch hook can read this.
$persistDir = Join-Path (Join-Path $env:USERPROFILE '.copilot') 'session-state'
if (-not (Test-Path $persistDir)) {
    New-Item -ItemType Directory -Path $persistDir -Force | Out-Null
}

$persistFile = Join-Path $persistDir 'last-session.json'
$summary | ConvertTo-Json -Depth 3 | Set-Content $persistFile -Encoding UTF8

# Also append to a rolling session history (last 20 sessions)
$historyFile = Join-Path $persistDir 'session-history.jsonl'
$summaryLine = $summary | ConvertTo-Json -Depth 3 -Compress
Add-Content -Path $historyFile -Value $summaryLine

# Trim history to last 20 entries
if (Test-Path $historyFile) {
    $historyLines = @(Get-Content $historyFile)
    if ($historyLines.Count -gt 20) {
        $historyLines | Select-Object -Last 20 | Set-Content $historyFile
    }
}

$fileCount = $summary.modifiedFiles.Count
Write-Host "[session-summary] Persisted: $fileCount files, $($summary.toolStats.total) tool calls -> $persistFile" -ForegroundColor DarkGray

# ── Diary auto-entry ──
# If the session had significant activity, append a brief diary entry.
# Significance: modified source files OR errors recovered from.
$isSignificant = ($summary.modifiedFiles.Count -gt 0) -or ($summary.errorCount -gt 0)
if ($isSignificant) {
    try {
        $diaryDir = Join-Path (Join-Path $copilotDir 'personal') 'diary'
        if (Test-Path $diaryDir) {
            $today = Get-Date -Format 'yyyy-MM-dd'
            $diaryFile = Join-Path $diaryDir "$today.md"
            $ts = Get-Date -Format 'HH:mm'

            $entry = @()
            $entry += ""
            $entry += "## Session at $ts (auto-logged)"
            $entry += ""

            if ($summary.branch) { $entry += "- **Branch:** $($summary.branch)" }
            $entry += "- **Tool calls:** $($summary.toolStats.total) ($($summary.toolStats.failures) failed)"

            if ($summary.modifiedFiles.Count -gt 0) {
                $entry += "- **Files modified:** $($summary.modifiedFiles.Count)"
                $summary.modifiedFiles | Select-Object -First 5 | ForEach-Object {
                    $short = "$_" -replace '^.*[/\\]src[/\\]', ''
                    $entry += "  - $short"
                }
                if ($summary.modifiedFiles.Count -gt 5) {
                    $entry += "  - ...and $($summary.modifiedFiles.Count - 5) more"
                }
            }

            if ($summary.errorCount -gt 0) {
                $entry += "- **Errors:** $($summary.errorCount)"
            }

            $entry += ""

            $entryText = $entry -join "`n"

            if (Test-Path $diaryFile) {
                Add-Content -Path $diaryFile -Value $entryText
            } else {
                $header = "# Diary: $today`n"
                Set-Content -Path $diaryFile -Value ($header + $entryText) -Encoding UTF8
            }
            Write-Host "[diary] Auto-logged session summary to $diaryFile" -ForegroundColor DarkGray
        }
    } catch { }
}

# ── TODO Sync: detect new todos from session ──
# Compare the todo snapshot from session start with current state.
# Since we can't read the session SQL DB, we write a marker that
# the agent's instructions can check.
$todoSnapshot = Join-Path $sidecarDir 'todo-snapshot.md'
$currentTodo = Join-Path (Join-Path $copilotDir 'personal') 'todo.md'
if ((Test-Path $todoSnapshot) -and (Test-Path $currentTodo)) {
    try {
        $snapHash = (Get-FileHash $todoSnapshot -Algorithm MD5).Hash
        $currHash = (Get-FileHash $currentTodo -Algorithm MD5).Hash
        if ($snapHash -ne $currHash) {
            Write-Host "[todo-sync] todo.md was updated during this session" -ForegroundColor DarkGray
        }
    } catch { }
}
