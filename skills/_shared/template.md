# Skill Template

Canonical template for all invocable skills. Every `SKILL.md` must follow this structure.

## Required Sections

```markdown
---
name: skill-name
description: One-line description of what the skill does and when to use it.
requires:
  env: [razzle, tshell, nebula]    # Environment requirements
  mcp: [bluebird, ado, memory]     # MCP server requirements
  tools: [build, node, git]        # CLI tool requirements
---

Use this skill when asked:
- "Natural language trigger phrase 1"
- "Natural language trigger phrase 2"
- "Natural language trigger phrase 3"

## Goal

1. First high-level step
2. Second high-level step
3. ...

## Prerequisites (Read First)

*(Optional — include when the skill depends on must-read concept/technology files)*

- **`knowledge/concepts/X.md`** — Brief description of why this must be read first.

## Modes

*(Optional — include when skill behavior varies by orchestration context)*

| Mode | When | Behavior |
|------|------|----------|
| Autonomous | Inside orchestrator skill | Full auto |
| Interactive | Standalone | Present choices |

## Inputs

| Input | Source | Fallback |
|---|---|---|
| requiredInput | session_state or prior skill output | Ask user |

## Workflow

### 1) Step name
Detailed instructions with code blocks...

## Error Recovery

*(Optional but recommended for multi-step skills)*

| Problem | Likely Cause | Recovery |
|---------|-------------|----------|
| Step N fails | ... | ... |

## Session DB Persistence

### Domain Table
\`\`\`sql
CREATE TABLE IF NOT EXISTS skill_specific_table (...);
\`\`\`

## Related Skills

- **Upstream**: `skill-name` (provides X)
- **Downstream**: `skill-name` (consumes X)
- **Reference**: `knowledge/concepts/X.md` (supplementary depth)

## Required Output

1. What the skill produces
2. ...

## Constraints

- Hard requirements and guard rails
- Environment prerequisites
- Idempotency guarantees
```

## Section Order

1. Frontmatter (name, description, requires)
2. Trigger phrases
3. Goal
4. Prerequisites (Read First) — optional
5. Modes — optional
6. Inputs
7. Workflow
8. Error Recovery — optional but recommended
9. Session DB Persistence
10. Related Skills
11. Required Output
12. Constraints

## `requires:` Schema

| Field | Values | Meaning |
|-------|--------|---------|
| `env` | `razzle`, `tshell`, `nebula` | Active environment needed |
| `mcp` | `bluebird`, `ado`, `memory`, `IntelligentTesting`, `ms-fabric-rti`, `DataLayer`, `DebugAnalysis` | MCP server must be configured |
| `tools` | `build`, `node`, `npm`, `git`, `python`, `link` | CLI tool must be available |

## Validation Rules

- All skills MUST have: frontmatter, ≥1 trigger phrase, Inputs, Workflow, Constraints, Required Output
- All `Related Skills` paths must resolve to existing files
- No workflow-level `.md` files at `skills/` root — they must be inside skill directories
- Concepts and technologies live in `knowledge/`, not `skills/`
- Fallback column in Inputs table must not be blank ("Ask user" is valid)
