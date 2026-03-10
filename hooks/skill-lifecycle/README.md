# skill-lifecycle

Session lifecycle hook for cross-skill observability.

## What it does

- **Session start**: Creates shared observability tables (`skill_execution_log`, `session_config`, `error_breadcrumbs`) in the session database so all skills can log their execution, configuration, and errors into a unified schema.
- **Session end**: Logs a summary of skill executions, errors encountered, and overall session health.

## Why

Skills execute independently but benefit from shared telemetry. This hook establishes the common tables at session start so any skill can write to them without needing to create tables itself, avoiding race conditions and schema conflicts.
