# subagent-tracking

Subagent-stop hook that logs subagent completions for utilization analysis.

## What it does

Fires when a subagent (explore, task, code-review, or any custom agent)
completes and appends a JSON Lines entry to
`$env:TEMP\copilot-session\subagents.jsonl`.

## Why

Currently blind to subagent usage patterns. The `task` tool shows up in
post-tool-tracking as a tool call, but we don't have visibility into:
- Which custom agents are actually used (of the 8 defined)
- How often subagents are delegated to vs. handled inline
- Subagent success/failure patterns

This data feeds into session-summary for richer reporting and enables
cross-session analysis of custom agent utilization.

## Limitations

The `subagentStop` hook input schema is not fully documented yet. The
current implementation logs timestamp only. As the hook API matures,
we can capture agent type, duration, and result quality.

## Sidecar File Format

```jsonl
{"timestamp":"2026-03-10T12:05:00Z"}
```

## Performance

Script logic is <5ms. Fires infrequently (only on subagent completions).
