# subagentStop hook: subagent tracking
#
# Logs every subagent completion for utilization analysis.
# Tracks which custom agents are actually used and how often.

$ErrorActionPreference = 'SilentlyContinue'

try {
    $raw = [System.IO.StreamReader]::new([Console]::OpenStandardInput()).ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch { exit 0 }

$sidecarDir = Join-Path $env:TEMP 'copilot-session'
if (-not (Test-Path $sidecarDir)) {
    New-Item -ItemType Directory -Path $sidecarDir -Force | Out-Null
}

$subagentFile = Join-Path $sidecarDir 'subagents.jsonl'

try {
    $entry = @{
        timestamp = Get-Date -Format 'o'
    } | ConvertTo-Json -Compress

    Add-Content -Path $subagentFile -Value $entry
} catch { }

exit 0
