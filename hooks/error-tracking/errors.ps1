# errorOccurred hook: error breadcrumb tracking
#
# Logs every agent error to a JSONL sidecar file for post-session analysis.

$ErrorActionPreference = 'SilentlyContinue'

try {
    $raw = [System.IO.StreamReader]::new([Console]::OpenStandardInput()).ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch { exit 0 }

$sidecarDir = Join-Path $env:TEMP 'copilot-session'
if (-not (Test-Path $sidecarDir)) {
    New-Item -ItemType Directory -Path $sidecarDir -Force | Out-Null
}

$errFile = Join-Path $sidecarDir 'errors.jsonl'

try {
    $entry = @{
        timestamp = Get-Date -Format 'o'
        name      = $hookData.error.name
        message   = $hookData.error.message
        # Truncate stack to first 3 lines to keep file manageable
        stack     = if ($hookData.error.stack) {
            ($hookData.error.stack -split "`n" | Select-Object -First 3) -join "`n"
        } else { $null }
    } | ConvertTo-Json -Compress

    Add-Content -Path $errFile -Value $entry
} catch { }

exit 0
