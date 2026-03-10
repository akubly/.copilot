# prompt-audit

User-prompt-submitted hook that logs prompts for session observability.

## What it does

Fires on every user prompt submission and appends a JSON Lines entry to
`$env:TEMP\copilot-session\prompts.jsonl` containing:
- ISO 8601 timestamp
- Prompt text (truncated to 500 chars)

## Why

Session-summary persists tool stats and file modifications, but has zero
visibility into what the user actually asked. This hook fills the biggest
observability blind spot — the "why" behind the session.

Downstream consumers:
- `session-summary/persist.ps1` reads `prompts.jsonl` to include prompt
  count and first prompt text in persisted session state
- `skill-lifecycle/summary.ps1` reports prompt count in session-end summary
- Cross-session analysis can detect recurring patterns (e.g., user
  frequently asks about same component → knowledge gap signal)

## Sidecar File Format

```jsonl
{"timestamp":"2026-03-10T12:00:00Z","prompt":"Fix the authentication bug in NCSI"}
```

## Performance

Script logic is <5ms. Dominant cost is PowerShell process startup (~300ms).
Fires once per user prompt (infrequent relative to tool calls).
