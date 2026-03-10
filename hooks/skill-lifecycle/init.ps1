# Skill Lifecycle Hook - Session Start
# Sets up sidecar directory, loads prior session context, and validates config.

$ErrorActionPreference = 'SilentlyContinue'

# Read hook input for session context
try {
    $raw = [System.IO.StreamReader]::new([Console]::OpenStandardInput()).ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch { }

# Create sidecar directory (shared by all hooks in this session)
$sidecarDir = Join-Path $env:TEMP 'copilot-session'
if (Test-Path $sidecarDir) {
    # Clean stale files from a prior session
    Remove-Item (Join-Path $sidecarDir '*') -Force -ErrorAction SilentlyContinue
} else {
    New-Item -ItemType Directory -Path $sidecarDir -Force | Out-Null
}

# Record session start time for summary hook
Set-Content (Join-Path $sidecarDir 'session-start.txt') (Get-Date -Format 'o') -NoNewline

$source = if ($hookData.source) { $hookData.source } else { 'unknown' }
$copilotDir = Join-Path $env:USERPROFILE '.copilot'

# ── Memory Prefetch: surface last session context ──
$lastSession = Join-Path (Join-Path $copilotDir 'session-state') 'last-session.json'
if (Test-Path $lastSession) {
    try {
        $prev = Get-Content $lastSession -Raw | ConvertFrom-Json
        $branch = if ($prev.branch) { $prev.branch } else { '?' }
        $files = if ($prev.modifiedFiles) { $prev.modifiedFiles.Count } else { 0 }
        Write-Host "[memory-prefetch] Last session: branch=$branch, $files files modified, $($prev.toolStats.total) tool calls" -ForegroundColor DarkGray
    } catch { }
}

# ── Agent-Skill Alignment Check ──
$skillsDir = Join-Path $copilotDir 'skills'
$agentsDir = Join-Path $copilotDir 'agents'
if ((Test-Path $skillsDir) -and (Test-Path $agentsDir)) {
    try {
        $actualSkills = @(Get-ChildItem $skillsDir -Directory |
            Where-Object { $_.Name -ne '_shared' } |
            ForEach-Object { $_.Name })

        $agentFiles = @(Get-ChildItem $agentsDir -File -Filter '*.agent.md')
        foreach ($agentFile in $agentFiles) {
            $content = Get-Content $agentFile.FullName -Raw
            # Extract skill names from backtick-delimited lists
            $mentioned = @([regex]::Matches($content, '`([a-z][\w-]+)`') |
                ForEach-Object { $_.Groups[1].Value } |
                Where-Object { $actualSkills -contains $_ -or $_ -match '-' })

            $missing = @($actualSkills | Where-Object {
                $_ -notin $mentioned -and
                $_ -ne 'playwright-cli' -and  # not all agents need all skills
                $_ -ne '_shared'
            })

            # Only report if agent lists skills AND is missing some
            if ($mentioned.Count -gt 10 -and $missing.Count -gt 0) {
                $agentName = $agentFile.BaseName -replace '\.agent$', ''
                Write-Host "[agent-alignment] $agentName is missing $($missing.Count) skills: $($missing[0..2] -join ', ')$(if($missing.Count -gt 3){', ...'})" -ForegroundColor DarkGray
            }
        }
    } catch { }
}

# ── TODO Sync: load persistent todos into sidecar for session-end merge ──
$todoFile = Join-Path (Join-Path $copilotDir 'personal') 'todo.md'
if (Test-Path $todoFile) {
    try {
        # Copy to sidecar so session-end can diff against it
        Copy-Item $todoFile (Join-Path $sidecarDir 'todo-snapshot.md') -Force
    } catch { }
}

# ── Branch Health Check ──
try {
    $gitDir = & git rev-parse --git-dir 2>$null
    if ($gitDir) {
        $behind = & git rev-list --count 'HEAD..@{upstream}' 2>$null
        if ($behind -and [int]$behind -gt 50) {
            Write-Host "[branch-health] WARNING: Branch is $behind commits behind upstream — consider rebasing" -ForegroundColor Yellow
        }
    }
} catch { }

# ── TODO awareness ──
$todoFile = Join-Path (Join-Path $copilotDir 'personal') 'todo.md'
if (Test-Path $todoFile) {
    try {
        $todoLines = @(Get-Content $todoFile | Where-Object { $_ -match '^\s*-\s*\[[ ]\]' })
        if ($todoLines.Count -gt 0) {
            Write-Host "[todo-sync] $($todoLines.Count) pending TODO items in personal/todo.md" -ForegroundColor DarkGray
        }
    } catch { }
}

Write-Host "[skill-lifecycle] Session initialized ($source)" -ForegroundColor DarkGray
