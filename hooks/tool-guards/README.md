# tool-guards

Pre-tool-use hook that enforces safety guardrails before any tool executes.

## What it does

Intercepts every tool call via the `preToolUse` hook event and can **deny**
execution when safety rules are violated. This is the only hook type that
can change agent behavior — all other hooks are observational.

### Guard 1: Unblessed Git Operations

Blocks `git commit`, `push`, `merge`, `rebase`, `reset --hard`, and
`clean -fd` commands. These operations modify history or push to shared
branches and must have explicit user approval.

**Blocked operations:**
- `git commit` / `git ci` (any flags)
- `git push` (any remote/branch)
- `git merge` (not `merge-base`)
- `git rebase`
- `git reset --hard` (data loss risk)
- `git clean -fd` (file deletion risk)

**Allowed operations:**
- `git add`, `status`, `diff`, `log`, `show` (read-only)
- `git stash`, `checkout`, `switch`, `branch` (local navigation)
- `git fetch`, `config`, `remote`, `tag` (safe operations)
- `git cherry-pick` (topic-branch workflow)

When denied, the agent receives a message instructing it to present the
exact command to the user and wait for confirmation.

### Guard 2: VFS Hydration Safety

In VFS-for-Git repositories (e.g., os.2020), blocks broad file traversals
that would trigger expensive network hydration of thousands of files.

**Blocked in VFS repos:**
- `Get-ChildItem -Recurse`, `gci -Recurse`, `dir /s`
- `findstr /s`, `Select-String` with wildcards
- `grep` or `glob` tool calls when CWD is at or near the repo root

**Not blocked:**
- Targeted file reads at known paths
- Searches scoped to specific subdirectories (depth ≥ 2 from repo root)
- Any operation in non-VFS repos

VFS status is cached per-directory in `$env:TEMP\copilot-vfs-*.txt` to
avoid running `git config` on every tool call.

### Guard 3: Secret Leak Prevention

Blocks shell commands that expose credentials or sensitive tokens:
- `$env:TOKEN`, `$env:PAT`, `$env:PASSWORD`, `$env:SECRET`, `$env:API_KEY`
- `$env:GH_TOKEN`, `$env:GITHUB_TOKEN`
- `Authorization: Bearer` headers in commands

### Guard 4: Process Kill Safety

Blocks name-based process killing which can hit unrelated processes:
- `Stop-Process -Name` / `-ProcessName` (blocked)
- `taskkill /IM` (blocked)
- `Stop-Process -Id` (allowed — PID-based is targeted and safe)

### Guard 5: Build Pre-Check

Before Razzle build commands, verifies:
- `$env:SDXROOT` is set (Razzle environment is active)
- `$env:BUILD_DASHBOARD` is set to `"0"` (suppresses build dashboard)

## Design

- **Fail open:** Any error in the hook script results in `exit 0` (allow).
  The hook should never block legitimate work due to its own bugs.
- **Fast path:** Non-matching tools (`edit`, `view`, `create`, etc.) exit
  in <5ms with no processing.
- **Cache:** VFS status is cached in temp files to avoid repeated `git config`
  calls. Cache persists for the terminal session.

## Performance

The hook fires on **every** tool call. Performance budget:
- Fast path (non-matching tool): <5ms script logic, ~300ms total (PowerShell startup)
- Guard checks: <15ms script logic each
- VFS guard (first call, uncached): ~100ms script logic (git config + cache write)
