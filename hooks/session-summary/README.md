# session-summary

Session end hook that persists session state for cross-session recall.

## What it does

At session end, reads sidecar files written by other hooks and persists a
session summary to durable storage:

- **`~/.copilot/session-state/last-session.json`** — Full summary of the
  most recent session (branch, repo, modified files, tool stats, errors).
  The next session's agent can read this to understand prior context.
- **`~/.copilot/session-state/session-history.jsonl`** — Rolling history
  of the last 20 sessions (one JSON object per line). Useful for pattern
  analysis across sessions.

### Data collected

- **Git context** — current branch and repo name
- **Modified files** — from `modified-files.log` sidecar (session-scoped)
- **Tool execution stats** — total calls, failures, denials
- **Error count** — from `errors.jsonl` sidecar

## Why

Each Copilot CLI session gets a fresh context. Without persistence, expensive
state (what was changed, what failed, which branch was active) is lost between
sessions. This hook bridges the gap by writing to files that survive session
shutdown.

## Limitations

Hooks can't access the agent's session SQLite DB or memory MCP server.
VM credentials, build artifacts, and snapshot state live in the session DB
and can't be persisted by this hook. For those, the agent itself should write
to memory MCP before session end (enforced by instruction, not hook).

## Sidecar input files

| File | Written by | Content |
|------|-----------|---------|
| `modified-files.log` | `post-tool-tracking` | File paths (one per line) |
| `tool-stats.csv` | `post-tool-tracking` | `HH:mm:ss,toolName,resultType` |
| `errors.jsonl` | `error-tracking` | JSON Lines error records |
