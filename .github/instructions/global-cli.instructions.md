---
description: "CLI-specific workflow guidance for Copilot CLI and PowerShell environments working with Windows OS repositories"
title: "Windows OS Development Instructions (CLI)"
version: "1.1.0"
owner: "aep-es-copilot@microsoft.com"
---

# CLI Workflow Instructions

<!-- ENVIRONMENT GATE -->
**STOP**: These instructions are ONLY for CLI environments (Copilot CLI, ghcp, terminal-based AI assistants).
- If running as GitHub Copilot in VS Code or another IDE: **IGNORE THIS ENTIRE FILE**.
- If `${workspaceFolder}` expands correctly: **IGNORE THIS ENTIRE FILE**.

## Search Strategy

Local search tools (`grep`, `glob`, `find`, `Get-ChildItem`) are **banned for broad searches**. They trigger VFS hydration and will fail or hang.

### Decision Tree

**STEP 1: Determine search scope**

- **Broad search** (implementations, APIs, functions, components across the OS):
  → Use `Search-Code`. It queries the ADO remote index without triggering VFS hydration.

- **Local search** (files you just created, uncommitted changes, known paths):
  → Use targeted local file reads for exact, known paths only.

**STEP 2: Select tool**

**Use `Search-Code` (DEFAULT):**
- Function/API implementations anywhere in the codebase
- Components, subsystems, or modules outside the working directory
- Architecture and cross-repo dependencies
- Patterns, symbols, or code across the OS tree
- Any search beyond the current directory
- Unknown file locations

```powershell
Search-Code -AccountName microsoft -SearchText "CreateWindow ext:cpp path:shell/Taskbar" -Branches "official/ge_current_directshell" -Repo os.2020 -Top 100
```

Setup: see [ado-access.instructions.md](./ado-access.instructions.md).

**Use local file reads ONLY for:**
- Files with known exact paths
- Recently created or modified local files
- Uncommitted changes in the working directory

**Banned** (VFS hydration cost):
- `grep`, `findstr`, `Select-String` across directory trees
- `Get-ChildItem -Recurse`, `dir /s`, `find`
- `glob` patterns at the repository root
- Any recursive file system traversal

`Search-Code` is the default search tool. It has full repository visibility via the ADO remote index without VFS hydration. Local tools see less than 1% of the codebase. Always use `Search-Code` unless reading a file at a known path.

## PowerShell Modules for CLI Workflows

For Azure DevOps operations (search, PRs, work items, branches), see [ado-access.instructions.md](./ado-access.instructions.md).

## Build Commands

Use the Razzle `build` command directly.

Build requires a Razzle environment. Check for `$env:SDXROOT`.
- If set: Razzle is active. Set `BUILD_DASHBOARD=0` before building.
- If not set: Instruct the user to exit, start Razzle, relaunch `agency copilot`, and retry.

### Build Changed Directories

Build only directories containing changed files:
```powershell
# Get directories with changed files (compared to upstream)
$upstream = git rev-parse --abbrev-ref '@{upstream}'
$changedDirs = git diff --name-only $upstream | ForEach-Object { 
    $dir = Split-Path $_ -Parent
    if ($dir -ne '') { $dir }
} | Sort-Object -Unique
```

**Build multiple directories in one operation:**
```powershell
# Build all changed directories together (ensures proper pass-order)
build -parent -dir ($changedDirs -join ";")
```
### Build Alias Reference

Expand these aliases before execution:

| Alias | Expands to |
| ----- | --------------- |
| bz | build |
| bp | build -parent |
| bcz | build -c |
| bcp | build -c -parent |

### Build Commands Reference

| Command | Use Case |
|---------|----------|
| `build -parent` | Initial build on new branch (resolves dependencies) |
| `build` | Incremental builds (faster, no `-parent` or `-c`) |
| `build -c` | Clean build (dependency changes require full rebuild) |
| `build -dir <paths>` | Build specific directories (paths relative to `$env:SDXROOT`) |
| `build -0` | Pass 0 only (headers/IDL) |
| `build -L` | Compile only (no link) |
| `build -l` | Link only |
| `build -partial` | Build upstream AND downstream dependencies (slow) |

**Build Multiple Directories:**
```powershell
# Use semicolon separator with single quotes in PowerShell
build -dir 'pcshell\shell\Taskbar;pcshell\shell\StartMenu'

# Or use a response file for many directories
$dirs | ForEach-Object { "$_ \" } | Out-File -Encoding ascii $env:temp\tobuild.list
build -parent -dir "@$env:temp\tobuild.list"
```

### Reachability Check

Verify a directory is reachable from `$env:SDXROOT` through the `dirs` file chain before building:

```powershell
function Test-Buildable($dir) {
    if ($dir -eq $env:SDXROOT) { return $true }
    
    $leaf = (Split-Path -Leaf $dir).ToLower()
    $parent = Split-Path -Parent $dir
    $parentDirs = Join-Path $parent "dirs"
    
    if (!(Test-Path $parentDirs)) {
        Write-Warning "Not buildable: $parent has no dirs file"
        return $false
    }
    
    $found = (Get-Content $parentDirs) -match "^$([regex]::Escape($leaf))(\s|$)"
    return $found -and (Test-Buildable $parent)
}
```

## Branching Conventions

- Base changes on "official" branches (e.g., `official/ge_current_directshell`)
- Name topic branches `user/<alias>/<description>`

## Pull Requests and CI

- Push to trigger CI builds
- PRIME build success gates PR completion
