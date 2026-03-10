# userPromptSubmitted hook: prompt audit logging
#
# Logs every user prompt to a sidecar JSONL file for session-summary
# enrichment and cross-session pattern analysis.

$ErrorActionPreference = 'SilentlyContinue'

try {
    $raw = [System.IO.StreamReader]::new([Console]::OpenStandardInput()).ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch { exit 0 }

$sidecarDir = Join-Path $env:TEMP 'copilot-session'
if (-not (Test-Path $sidecarDir)) {
    New-Item -ItemType Directory -Path $sidecarDir -Force | Out-Null
}

$promptFile = Join-Path $sidecarDir 'prompts.jsonl'

try {
    # Truncate long prompts to keep sidecar manageable
    $promptText = if ($hookData.prompt.Length -gt 500) {
        $hookData.prompt.Substring(0, 500) + '...'
    } else {
        $hookData.prompt
    }

    $entry = @{
        timestamp = Get-Date -Format 'o'
        prompt    = $promptText
    } | ConvertTo-Json -Compress

    Add-Content -Path $promptFile -Value $entry
} catch { }

exit 0
