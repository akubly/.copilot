# post-tool-tracking

Post-tool-use hook that logs file modifications and tool execution statistics.

## What it does

Fires after every tool execution and records two types of data to sidecar
files under `$env:TEMP\copilot-session\`:

### File Modification Tracking

When `edit` or `create` tools complete, logs the file path to
`modified-files.log` (one path per line). This gives downstream hooks
(especially `governance-audit`) a precise, session-scoped list of every
file the agent touched — more accurate than `git diff` which includes
pre-session changes.

### Tool Execution Stats

Logs every tool call to `tool-stats.csv` with timestamp, tool name, and
result type (success/failure/denied). Used by `skill-lifecycle` summary
to report session activity.

## Sidecar File Format

```
$env:TEMP\copilot-session\
├── modified-files.log    # One absolute file path per line
└── tool-stats.csv        # HH:mm:ss,toolName,resultType
```

## Why

Hooks can't access the agent's session SQLite database. Sidecar files
bridge this gap — postToolUse hooks write data that sessionEnd hooks read.
This is the foundational data collection layer that enables governance-audit
and skill-lifecycle summary hooks.

## Performance

Script logic is <10ms. Dominant cost is PowerShell process startup (~300ms).
