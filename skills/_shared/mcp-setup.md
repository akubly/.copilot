# MCP Server Setup Guide

Required MCP servers for the skill corpus and how to install them.

## Universal MCP Servers (npm-based)

These install automatically via npx — no manual setup needed.

### Azure DevOps (`ado`)
```json
"ado": {
  "command": "npx",
  "args": ["-y", "@azure-devops/mcp@latest", "${input:ado_org}"]
}
```
- **Required by:** bug-triage, create-pull-request, and all ADO-interacting skills
- **Setup:** Automatic via npx. Prompts for ADO organization on first use.

### Memory (`memory`)
```json
"memory": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-memory"]
}
```
- **Required by:** Cross-session recall, knowledge persistence
- **Setup:** Automatic via npx

### Sequential Thinking (`sequential-thinking`)
```json
"sequential-thinking": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
}
```
- **Required by:** Complex multi-step reasoning tasks
- **Setup:** Automatic via npx

### Azure MCP (`azure-mcp-server`)
```json
"azure-mcp-server": {
  "command": "npx",
  "args": ["-y", "@azure/mcp@latest", "server", "start"]
}
```
- **Required by:** Azure resource operations
- **Setup:** Automatic via npx

### Fabric RTI (`ms-fabric-rti`)
```json
"ms-fabric-rti": {
  "command": "uvx",
  "args": ["microsoft-fabric-rti-mcp"]
}
```
- **Required by:** investigate-telemetry-asserts (Kusto queries)
- **Setup:** Requires `uvx` (from `uv` Python package manager). Install: `pip install uv`

## Windows-Specific MCP Servers

These require manual installation or PATH configuration.

### DataLayer (`DataLayer`)
- **Required by:** Trace analysis, performance investigation
- **Install:** Download from internal tool share (contact engineering systems team)
- **Config:** Set path in mcp-config.json:
```json
"DataLayer": {
  "command": "${input:datalayer_path}"
}
```

### IntelligentTesting (`IntelligentTesting`)
- **Required by:** find-tests-for-topic-branch-changes
- **Install:** Available via internal Heimdall tooling. Must be on PATH.
- **Config:**
```json
"IntelligentTesting": {
  "command": "Heimdall.IntelligentTesting.MCPServer"
}
```

### DebugAnalysis (`DebugAnalysis`)
- **Required by:** Crash dump analysis, debug investigation
- **Install:** Available via internal diagnostics tooling. Must be on PATH.
- **Config:**
```json
"DebugAnalysis": {
  "command": "Microsoft.Diagnostics.Analysis.DebugAnalysis.MCP.exe"
}
```

## PowerShell Modules

### VstsRestApiHelpers
- **Required by:** Code search (Search-Code), PR management, work item operations
- **Install:** Included with IxpTools or available at `$env:SDXROOT/src/utilities/PowerShell/Modules/VstsRestApiHelpers`
- **Load:**
```powershell
$ixpPath = Split-Path (Get-Module -ListAvailable IxpTools).Path
Import-Module "$ixpPath/VstsRestHelpers/src/VstsRestApiHelpers.psd1"
```

## Verification

Run the environment-preflight hook to check all prerequisites:
```powershell
& ~/.copilot/hooks/environment-preflight/check.ps1
```
