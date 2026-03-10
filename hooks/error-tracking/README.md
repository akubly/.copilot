# error-tracking

Error-occurred hook that logs agent errors for post-session analysis.

## What it does

Fires on every agent error and appends a JSON Lines entry to
`$env:TEMP\copilot-session\errors.jsonl` containing:
- ISO 8601 timestamp
- Error name/type
- Error message
- First 3 lines of stack trace (truncated for size)

## Sidecar File Format

```jsonl
{"timestamp":"2026-03-10T00:05:00Z","name":"TimeoutError","message":"Network timeout","stack":"..."}
```

## Why

Errors during agent execution are ephemeral — they appear in the conversation
but aren't persisted for pattern analysis. This hook creates a durable error
log that:
- The `skill-lifecycle` summary hook reads at session end to report error count
- Can be reviewed across sessions to detect recurring failure patterns
- Feeds into the `error_breadcrumbs` mental model from the observability schema

## Performance

Script logic is <10ms. Dominant cost is PowerShell process startup (~300ms).
