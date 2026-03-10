# governance-audit

Session end hook that checks containment coverage for modified source files.

## What it does

At session end, cross-references modified source files (from `git diff`) against containment records in the session database's `containment_actions` table. Flags any `.cpp` or `.h` files that were modified without a corresponding Velocity feature flag containment entry.

## Why

Continuous Delivery in Windows requires that all product code changes are behind Velocity feature flags. This hook acts as a safety net — if the agent modified source files during a session but didn't run the `add-containment` skill, the audit surfaces the gap before the session ends. This prevents uncontained changes from reaching a PR.

## Current state

Stub implementation that logs intent. Full implementation would query `git diff --name-only` and join against the session DB.
