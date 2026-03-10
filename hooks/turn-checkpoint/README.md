# turn-checkpoint

Agent-stop hook that performs per-turn safety checks.

## What it does

Fires after every main agent response and checks whether source file
modifications in the current turn have corresponding build attempts and
containment signals. Writes warnings to
`$env:TEMP\copilot-session\turn-warnings.jsonl`.

### Check 1: Build Verification

Detects when C++ source files were modified in the current turn but no
Razzle build was attempted. This catches the common pattern of editing
code without verifying it compiles.

### Check 2: Containment Signals

Detects when C++ source files were modified but no `IsEnabled()`,
`AssertEnabled()`, or FeatureStaging XML modifications appear in the
session's changeset. This is an early warning — governance-audit does
a more thorough check at session end.

## How It Tracks "Current Turn"

Uses a checkpoint offset file (`checkpoint-offset.txt`) to remember how
many lines of `modified-files.log` were present at the last checkpoint.
On each agentStop, it processes only the new lines.

## Why

`governance-audit` only runs at session end. In a 10-turn session, a
containment gap from turn 2 isn't surfaced until the session is over.
This hook provides per-turn feedback so the agent can self-correct early.

## Sidecar Files

| File | Purpose |
|------|---------|
| `turn-warnings.jsonl` | Written: per-turn warnings |
| `checkpoint-offset.txt` | Read/write: tracks last-checked position |
| `checkpoint-build-count.txt` | Read/write: tracks build count |
| `modified-files.log` | Read: from post-tool-tracking |
| `builds.jsonl` | Read: from post-tool-tracking |

## Performance

Script logic is <20ms (includes file reads for containment pattern matching).
Fires once per agent response (moderate frequency, acceptable).
