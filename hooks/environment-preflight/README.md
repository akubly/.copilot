# environment-preflight

Session start hook that validates environment prerequisites.

## What it does

Runs lightweight checks at session start to detect whether key tools and environments are available:

- **Razzle** (`$env:SDXROOT`) — required for OS builds, signing, and most repo operations.
- **Node.js** — required for MCP servers and tooling.
- **Git** — required for version control operations.

Results are printed as `[OK]` or `[--]` lines so the agent and user can see at a glance what's available. Missing tools are reported as informational (not errors) since not every session needs every tool.

## Why

Many skills fail late with cryptic errors when prerequisites are missing. This hook surfaces the gaps early so the agent can adapt its strategy or prompt the user to start Razzle before attempting builds.
