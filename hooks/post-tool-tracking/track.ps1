# postToolUse hooks: file modification tracking + tool stats + build artifacts + skill lint
#
# Logs every edit/create tool call with file path to a sidecar file.
# Also logs tool execution results for session-end summary.
# Detects build completions and skill file modifications.
# Fast path: ~5ms for non-matching tools (just stdin read + exit).

$ErrorActionPreference = 'SilentlyContinue'

try {
    $raw = [System.IO.StreamReader]::new([Console]::OpenStandardInput()).ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch { exit 0 }

$toolName = $hookData.toolName
$resultType = $hookData.toolResult.resultType
$resultText = $hookData.toolResult.textResultForLlm

# Parse toolArgs once
$rawArgs = $hookData.toolArgs
try {
    if ($rawArgs -is [string]) { $toolArgs = $rawArgs | ConvertFrom-Json }
    else { $toolArgs = $rawArgs }
} catch { $toolArgs = $null }

# Sidecar directory for this terminal session
$sidecarDir = Join-Path $env:TEMP 'copilot-session'
if (-not (Test-Path $sidecarDir)) {
    New-Item -ItemType Directory -Path $sidecarDir -Force | Out-Null
}

# ── File modification tracking ──
# Log every edit/create with the file path for governance-audit
if ($toolName -in @('edit', 'create') -and $toolArgs) {
    try {
        $filePath = $toolArgs.path
        if ($filePath) {
            $logFile = Join-Path $sidecarDir 'modified-files.log'
            Add-Content -Path $logFile -Value $filePath -NoNewline:$false
        }
    } catch { }
}

# ── Build artifact tracking ──
# After shell commands that look like builds, log outcome
if ($toolName -in @('powershell', 'bash') -and $toolArgs.command) {
    $cmd = $toolArgs.command
    # Match Razzle build commands
    if ($cmd -match '^\s*(build|bz|bp|bcz|bcp)\b') {
        try {
            $buildFile = Join-Path $sidecarDir 'builds.jsonl'
            $entry = @{
                timestamp = Get-Date -Format 'HH:mm:ss'
                command   = $cmd.Substring(0, [Math]::Min($cmd.Length, 120))
                result    = "$resultType"
            } | ConvertTo-Json -Compress
            Add-Content -Path $buildFile -Value $entry
        } catch { }
    }
}

# ── Skill lint trigger ──
# When a skill file is modified, flag it for lint checking
if ($toolName -in @('edit', 'create') -and $toolArgs.path) {
    if ($toolArgs.path -match '[/\\]skills[/\\]') {
        try {
            $lintFlag = Join-Path $sidecarDir 'skills-modified.flag'
            Add-Content -Path $lintFlag -Value $toolArgs.path
        } catch { }
    }
}

# ── Test result tracking ──
# After TAEF/Test-Device test runs, log outcomes
if ($toolName -in @('powershell', 'bash') -and $toolArgs.command) {
    $cmd = $toolArgs.command
    if ($cmd -match '\b(te\.exe|Test-Device|testd|Invoke-Taef)\b') {
        try {
            $testFile = Join-Path $sidecarDir 'test-results.jsonl'
            $passed = 0; $failed = 0
            if ($resultText -match '(\d+)\s+(?:passed|Passed)') { $passed = [int]$Matches[1] }
            if ($resultText -match '(\d+)\s+(?:failed|Failed)') { $failed = [int]$Matches[1] }
            $entry = @{
                timestamp = Get-Date -Format 'HH:mm:ss'
                command   = $cmd.Substring(0, [Math]::Min($cmd.Length, 120))
                result    = "$resultType"
                passed    = $passed
                failed    = $failed
            } | ConvertTo-Json -Compress
            Add-Content -Path $testFile -Value $entry
        } catch { }
    }
}

# ── VM interaction tracking ──
# After TShell/Nebula commands, log VM interactions
if ($toolName -in @('powershell', 'bash') -and $toolArgs.command) {
    $cmd = $toolArgs.command
    if ($cmd -match '\b(Enter-Device|Invoke-Command.*-Session|tshell|Connect-Device|New-NebulaVM)\b') {
        try {
            $vmFile = Join-Path $sidecarDir 'vm-interactions.jsonl'
            $entry = @{
                timestamp = Get-Date -Format 'HH:mm:ss'
                command   = $cmd.Substring(0, [Math]::Min($cmd.Length, 120))
                result    = "$resultType"
            } | ConvertTo-Json -Compress
            Add-Content -Path $vmFile -Value $entry
        } catch { }
    }
}

# ── Tool execution stats ──
# Append a CSV row for every tool call: timestamp,tool,result
try {
    $statsFile = Join-Path $sidecarDir 'tool-stats.csv'
    $ts = Get-Date -Format 'HH:mm:ss'
    Add-Content -Path $statsFile -Value "$ts,$toolName,$resultType"
} catch { }

exit 0
