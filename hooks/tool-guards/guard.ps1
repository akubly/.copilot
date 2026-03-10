# guard.ps1 — preToolUse safety guards for Copilot CLI
#
# Five guards in one script:
#   1. COMMIT GUARD       — blocks git commit/push/merge and destructive git ops
#   2. SECRET LEAK GUARD  — blocks commands exposing credentials
#   3. PROCESS KILL GUARD — blocks name-based process killing
#   4. VFS GUARD          — blocks recursive file traversals in VFS-for-Git repos
#   5. BUILD PRE-CHECK    — blocks build commands missing prerequisites
#
# Guards 1-3 are universal (run always). Guards 4-5 are conditional
# (VFS repos only / Razzle builds only).
#
# Runs on every tool call. Fast path (<5ms) for non-matching tools.
# Outputs {"permissionDecision":"deny",...} to block; exits silently to allow.
# Fails open on any error.

$ErrorActionPreference = 'SilentlyContinue'

# ── Read hook input from stdin ──
try {
    $raw = [System.IO.StreamReader]::new([Console]::OpenStandardInput()).ReadToEnd()
    $hookData = $raw | ConvertFrom-Json
} catch { exit 0 }

$toolName = $hookData.toolName

# Fast path: only inspect shell commands, grep, and glob
if ($toolName -notin @('powershell', 'bash', 'grep', 'glob')) { exit 0 }

# Parse toolArgs (may be a JSON string or already-parsed object)
$rawArgs = $hookData.toolArgs
try {
    if ($rawArgs -is [string]) { $toolArgs = $rawArgs | ConvertFrom-Json }
    else { $toolArgs = $rawArgs }
} catch { exit 0 }

if (-not $toolArgs) { exit 0 }

$cwd = $hookData.cwd
$command = if ($toolName -in @('powershell', 'bash')) { $toolArgs.command } else { $null }

# ═══════════════════════════════════════════════════════════════
# GUARD 1: Unblessed Git Operations  (universal)
# ═══════════════════════════════════════════════════════════════
# Git commit, push, merge, and destructive operations require
# explicit user approval. The deny message tells the agent to
# present the command to the user and wait for confirmation.
#
# Blocked:  git commit, ci, push, merge, rebase, reset --hard, clean -fd
# Allowed:  git add, status, diff, log, show, stash, checkout, switch,
#           branch, fetch, config, remote, tag, cherry-pick (read-only or safe)

if ($command -match '\bgit\b') {
    $gitBlocked = @(
        '\bgit\s+commit(\s|$)'       # git commit (any flags)
        '\bgit\s+ci(\s|$)'           # git ci (common alias)
        '\bgit\s+push(\s|$)'         # git push (any remote/branch)
        '\bgit\s+merge(\s|$)'        # git merge (not merge-base)
        '\bgit\s+rebase(\s|$)'       # git rebase
        '\bgit\s+reset\s+--hard'     # git reset --hard (data loss)
        '\bgit\s+clean\s+-\w*[fd]'   # git clean -fd (file deletion)
    )

    foreach ($pat in $gitBlocked) {
        if ($command -match $pat) {
            @{
                permissionDecision       = 'deny'
                permissionDecisionReason = "Blocked: git operation requires explicit user approval. Present the exact command to Aaron and wait for confirmation before retrying."
            } | ConvertTo-Json -Compress
            exit 0
        }
    }
}

# ═══════════════════════════════════════════════════════════════
# GUARD 2: Secret Leak Prevention  (universal)
# ═══════════════════════════════════════════════════════════════
# Block shell commands that expose credentials or sensitive tokens.

if ($command) {
    $secretPatterns = @(
        '\$env:TOKEN\b'
        '\$env:PAT\b'
        '\$env:PASSWORD\b'
        '\$env:SECRET\b'
        '\$env:API_KEY\b'
        '\$env:GH_TOKEN\b'
        '\$env:GITHUB_TOKEN\b'
        'Authorization:\s*Bearer\s+\S+'
        '-Headers.*Authorization'
    )

    foreach ($pat in $secretPatterns) {
        if ($command -match $pat) {
            @{
                permissionDecision       = 'deny'
                permissionDecisionReason = "Blocked: command appears to expose credentials ($($Matches[0])). Use secure credential retrieval instead of embedding secrets in commands."
            } | ConvertTo-Json -Compress
            exit 0
        }
    }
}

# ═══════════════════════════════════════════════════════════════
# GUARD 3: Process Kill Safety  (universal)
# ═══════════════════════════════════════════════════════════════
# Block name-based process killing (dangerous, can hit unrelated
# processes). Only PID-based killing is allowed.

if ($command) {
    $processKillBlocked = @(
        'Stop-Process\s+(-Name\b|-ProcessName\b)'
        'taskkill\s+/IM\b'
        'taskkill\s+/im\b'
    )

    foreach ($pat in $processKillBlocked) {
        if ($command -match $pat) {
            @{
                permissionDecision       = 'deny'
                permissionDecisionReason = 'Blocked: name-based process killing is dangerous. Use Stop-Process -Id <PID> with a specific process ID instead.'
            } | ConvertTo-Json -Compress
            exit 0
        }
    }
}

# ═══════════════════════════════════════════════════════════════
# GUARD 4: VFS-for-Git Hydration Safety  (conditional)
# ═══════════════════════════════════════════════════════════════
# Broad file traversals in VFS repos trigger expensive network
# hydration. Block recursive operations and repo-root searches.
# Skipped entirely for non-VFS repos.

if ($cwd) {
    # Cache VFS status per directory (avoid running git on every call)
    $cacheKey = [Math]::Abs($cwd.ToLower().GetHashCode())
    $cacheFile = Join-Path $env:TEMP "copilot-vfs-$cacheKey.txt"

    $isVfs = $false
    if (Test-Path $cacheFile) {
        $isVfs = (Get-Content $cacheFile -Raw).Trim() -eq '1'
    } else {
        try {
            $gvfs = & git -C $cwd config --get core.gvfs 2>$null
            $isVfs = -not [string]::IsNullOrWhiteSpace($gvfs)
        } catch { }
        Set-Content $cacheFile $(if ($isVfs) { '1' } else { '0' }) -NoNewline
    }

    if ($isVfs) {
        # ── Shell commands: block recursive patterns ──
        if ($command) {
            $vfsBlocked = @(
                'Get-ChildItem[^|]*-Recurse'
                '\bgci\b[^|]*-Recurse'
                '\bdir\b\s+/[sS]'
                '\bfindstr\b\s+/[sS]'
                'Select-String[^|]*\\\*'
            )

            foreach ($pat in $vfsBlocked) {
                if ($command -match $pat) {
                    @{
                        permissionDecision       = 'deny'
                        permissionDecisionReason = 'Blocked: recursive file operation in VFS repo triggers expensive hydration. Use Search-Code or scope to a specific subdirectory.'
                    } | ConvertTo-Json -Compress
                    exit 0
                }
            }
        }

        # ── grep/glob: block broad searches near repo root ──
        if ($toolName -in @('grep', 'glob')) {
            $searchPath = $toolArgs.path

            # If no path specified, the tool defaults to CWD
            if (-not $searchPath -or $searchPath -eq '.') {
                try {
                    $repoRoot = (& git -C $cwd rev-parse --show-toplevel 2>$null)
                    if ($repoRoot) {
                        $root = $repoRoot.Replace('/', '\').TrimEnd('\')
                        $cwdNorm = $cwd.TrimEnd('\')
                        $relative = $cwdNorm.Substring($root.Length).TrimStart('\')
                        $depth = if ($relative) {
                            @($relative.Split('\') | Where-Object { $_ }).Count
                        } else { 0 }

                        if ($depth -le 1) {
                            @{
                                permissionDecision       = 'deny'
                                permissionDecisionReason = "Blocked: $toolName near VFS repo root (depth=$depth). Scope to a subdirectory at least 2 levels deep, or use Search-Code."
                            } | ConvertTo-Json -Compress
                            exit 0
                        }
                    }
                } catch { }
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
# GUARD 5: Build Pre-Check  (conditional)
# ═══════════════════════════════════════════════════════════════
# Before Razzle build commands, verify prerequisites that would
# cause predictable failures if missing.

if ($command -match '\bbuild\b' -and $command -notmatch '\bnpm\b|\bgo\b|\bdotnet\b|\bpip\b') {
    # Only check Razzle builds (not npm build, go build, etc.)
    if ($command -match '^\s*(build|bz|bp|bcz|bcp)\b') {
        # Check Razzle environment
        if (-not $env:SDXROOT) {
            @{
                permissionDecision       = 'deny'
                permissionDecisionReason = 'Blocked: Razzle environment not active ($env:SDXROOT not set). Start Razzle first, then relaunch the session.'
            } | ConvertTo-Json -Compress
            exit 0
        }

        # Check BUILD_DASHBOARD suppression
        if ($env:BUILD_DASHBOARD -ne '0') {
            @{
                permissionDecision       = 'deny'
                permissionDecisionReason = 'Blocked: set $env:BUILD_DASHBOARD = "0" before building to suppress the build dashboard.'
            } | ConvertTo-Json -Compress
            exit 0
        }
    }
}

# All checks passed — allow
exit 0
