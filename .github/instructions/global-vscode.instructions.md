---
applyTo: "**"
description: "VS Code-specific workflow guidance for GitHub Copilot in VS Code working with Windows OS repositories"
title: "Windows OS Development Instructions (VS Code)"
version: "1.0.0"
owner: "aep-es-copilot@microsoft.com"
---

# VS Code Workflow Instructions

<!-- ENVIRONMENT GATE -->
**STOP**: These instructions are ONLY for GitHub Copilot running in VS Code.
- If you are Copilot CLI (ghcp), terminal-based AI, or any non-VS Code environment: **IGNORE THIS ENTIRE FILE**.
- If VS Code-specific variables like `${workspaceFolder}` do not expand: **IGNORE THIS ENTIRE FILE**.

## Build and Command Execution

### Tool Selection Decision Tree

**STEP 1: Is this a BUILD operation?**
- If YES → Use `#run_wave_build` (if available)
- If `#run_wave_build` is NOT available → Use existing default task in workspace `tasks.json` (if exists)
- If NO default task exists → Use manual terminal commands as last resort

**STEP 2: Is this a NON-BUILD Windows OS development command that needs Razzle environment?**
- Examples: Running Windows dev tools, executing OS-specific scripts, using build utilities
- If YES → Use `#run_razzle_command` (if available)
- If `#run_razzle_command` is NOT available → Use standard terminal execution

**STEP 3: Is this a general command unrelated to Windows OS development?**
- Examples: File operations, git commands, general utilities
- Use standard terminal execution

### Tool Rules

1. **`#run_wave_build`**: ONLY for build operations, ALWAYS preferred when available for builds
2. **`#run_razzle_command`**: For ANY non-build Windows OS development command that needs Razzle environment
3. **Never modify workspace**: DO NOT create or edit `tasks.json` files under any circumstances
4. **Tool availability check**: Always verify tool availability before attempting to use
5. **Build failure handling**: On build failures, CONTINUE to use `#run_wave_build` for subsequent build attempts. Do NOT switch to alternative tools after a build failure - maintain consistency with the preferred tool

### Build Verification Behavior

**After making code changes, be eager to verify correctness by building:**
- When you complete a set of code changes, proactively suggest building to verify the changes compile correctly
- **ALWAYS ask permission before initiating a build** - Razzle builds can be slow and resource-intensive
- Phrase suggestions like: "I've completed the changes. Would you like me to build to verify they compile correctly? (Note: Razzle builds can take several minutes)"
- If the user declines, respect their decision and continue with other tasks
- After a successful build, summarize what was validated
- After a failed build, analyze errors and propose fixes

## Search Strategy

The Windows OS repository is massive. Workspaces are typically scoped to small subdirectories, which severely limits standard search tools like `file_search`, `grep_search`, and `semantic_search` - they ONLY see files in the open workspace folder.

### Decision Tree

**STEP 1: Determine search scope**

- **Broad repository search needed?** (finding implementations, APIs, functions, components across the OS)
  - Examples: "find LocalAlloc implementation", "find the TCP/IP stack implementation", "locate WinSock API handlers", "find all uses of a kernel API"
  - Use `#engineering_copilot` - it searches the ENTIRE indexed OS repository
  - **PREFERRED**: When in doubt, default to `#engineering_copilot` as it has full repository visibility
  
- **Local workspace search needed?** (files you just created, local uncommitted changes, workspace-specific files)
  - Examples: "read this file in my workspace", "search this directory", "find my new code"
  - Use standard tools: `file_search`, `grep_search`, `read_file`, `semantic_search`
  - **ONLY use when**: You are certain the content exists in your open workspace folder

**STEP 2: Apply the right tool**

**Use `#engineering_copilot` (GENERALLY PREFERRED):**
- Finding function/API implementations anywhere in the OS codebase
- Locating components, subsystems, or modules outside your workspace
- Understanding architecture and dependencies across the repository
- Searching for patterns, symbols, or code across the entire OS tree
- Any search where you need visibility beyond your current workspace folder
- When you don't know the exact location of what you're looking for
- **Default choice**: Use this unless you have a specific reason to use local tools

**Use local search tools (`file_search`, `grep_search`, `read_file`, `semantic_search`) ONLY when:**
- Reading files that are only in your open workspace (you know the path)
- Searching recently created or modified local files
- Examining uncommitted changes in your working directory
- You already confirmed the exact file path exists in your workspace folder

**Key Principle**: `#engineering_copilot` is the PREFERRED and DEFAULT search tool. It sees the full repository. Local tools are blind to 99%+ of the codebase if your workspace is scoped to a small directory. When in doubt about where something is located, or when searching for OS functionality/implementations, ALWAYS use `#engineering_copilot`.
