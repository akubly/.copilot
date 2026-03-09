---
name: persona-review
description: Review any work artifact through a work-type-specific persona panel before it leaves the machine. Findings are discussed item by item with the human engineer.
requires:
  concepts: [ai-assisted-engineering]
  technologies: [persona-review-panels, review-voice]
---

Use this skill when:
- About to present code changes (product or test)
- About to present a commit message, PR title, PR description, or review comment
- About to present a design decision or architecture proposal
- About to present any document or written artifact
- Explicitly asked to review an artifact

**This skill is MANDATORY before any work output leaves the machine.**

## Goal

1. Select the appropriate persona panel for the artifact type.
2. Spawn all personas in parallel to review the artifact.
3. Collect, merge, deduplicate, and categorize findings.
4. Present consolidated findings to the human engineer — with reasoning
   (learning opportunity) and **specific validation guidance** (diffs to
   review, tests to run, references to check).
5. Track the human's disposition on each finding.
6. If findings lead to changes, offer to re-run the panel on the modified artifact.
7. Mark the artifact as reviewed only after the human confirms.

**Persona review is pre-validation triage** — it directs attention to
where issues may exist. It is not validation itself. After surfacing
concerns, the agent guides the engineer through the actual validation:
specific diffs, test execution, reference verification. The human
validates; the agent helps them do it efficiently.

**Mechanical validations** (running tests, executing builds, checking
references) **can and should be performed by the agent** when capable.
The results must be presented in a **verifiable** way — test logs
available locally, CI/CD test pass URLs, build output files, linked
references the human can open. The agent asserts with evidence, not
just claims. The human spot-checks the evidence rather than re-running
everything.

## Inputs

- `artifact` — the work product to review (code diff, text, design doc, etc.)
- `artifactType` — one of: `code`, `design`, `writing`
- `taskContext` — brief description of what the human is trying to accomplish
- `priorFindings` (optional) — findings from a previous review cycle on the
  same artifact (for re-review after changes)

## Prerequisites (Read First)

- **`knowledge/concepts/ai-assisted-engineering.md`** — Core principles:
  trust spectrum, human accountability, anti-patterns
- **`knowledge/technologies/persona-review-panels.md`** — Panel definitions,
  persona focus areas, shared prompt template
- **`knowledge/technologies/review-voice.md`** — Required by Voice Reviewer
  persona (writing panel only)

## Workflow

### 1) Classify the artifact and select panel

Determine the artifact type and select the corresponding panel from
`persona-review-panels.md`:

| Artifact type | Panel |
|--------------|-------|
| Product code, test code, scripts, diffs | **Code Panel** |
| Design docs, architecture decisions, API shape | **Design Panel** |
| Commit messages, PR titles/descriptions, review comments, documents | **Writing Panel** |

When an artifact spans types (e.g., a PR with code changes AND a description),
run BOTH panels — Code Panel on the diff, Writing Panel on the description.

```sql
CREATE TABLE IF NOT EXISTS persona_review (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    artifact_type TEXT NOT NULL,
    panel TEXT NOT NULL,
    task_context TEXT,
    status TEXT DEFAULT 'in_progress',
    created_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT
);

CREATE TABLE IF NOT EXISTS persona_findings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    review_id INTEGER REFERENCES persona_review(id),
    persona TEXT NOT NULL,
    location TEXT,
    finding_type TEXT NOT NULL,
    finding TEXT NOT NULL,
    severity TEXT NOT NULL,
    recommendation TEXT,
    reasoning TEXT,
    disposition TEXT DEFAULT 'pending',
    human_notes TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

INSERT INTO persona_review (artifact_type, panel, task_context)
VALUES ('<type>', '<panel>', '<context>');
```

### 2) Spawn persona sub-agents in parallel

For each persona in the selected panel, spawn a sub-agent using the
`task` tool with `agent_type: "general-purpose"` and `mode: "background"`.

Each persona receives:
- The shared prompt template from `persona-review-panels.md`
- The artifact content
- The task context
- Their specific focus area and key questions

**All personas run in parallel** — this is critical for keeping the review
fast and minimizing the impatience/skip pressure identified in our
engineering principles (review as a value-add, not a bottleneck).

**Prompt structure for each persona:**

```
You are the [PERSONA NAME] reviewing a [ARTIFACT TYPE].

Your focus: [FOCUS DESCRIPTION from panel definition]

Key questions to evaluate:
[KEY QUESTIONS from panel definition]

## The Artifact
[ARTIFACT CONTENT]

## Task Context
[BRIEF DESCRIPTION OF WHAT THE HUMAN IS TRYING TO ACCOMPLISH]

Review the artifact and produce a list of findings. For each finding:
1. **Location** — where in the artifact (line, section, specific text)
2. **Type** — concern, suggestion, question, or praise
3. **Finding** — your observation
4. **Reasoning** — explain WHY this matters, what could go wrong, and what
   the human should understand about this issue. This is a learning
   opportunity — help the engineer build judgment, not just pass/fail.
5. **Severity** — blocking (must fix), important (should fix), minor (nice to fix)
6. **Recommendation** — specific action to address the finding (if applicable)

Be precise and actionable. Do not flag things that are correct. Quality over
quantity — 3 real findings beat 10 nitpicks.
```

### 3) Collect and deduplicate findings

After all personas complete:

1. Read each persona's output via `read_agent`.
2. Parse findings into structured form.
3. Deduplicate: merge findings from different personas that identify the
   same issue (note which personas agreed — consensus strengthens the finding).
4. Categorize by severity: blocking → important → minor.

```sql
INSERT INTO persona_findings (review_id, persona, location, finding_type,
    finding, severity, recommendation, reasoning)
VALUES (<review_id>, '<persona(s)>', '<location>', '<type>',
    '<finding>', '<severity>', '<recommendation>', '<reasoning>');
```

### 4) Present findings to the human engineer

Present **consolidated** findings (merged across personas), ordered by
severity (blocking first).

For each finding, include:
- Which persona(s) raised it (consensus strengthens the finding)
- The specific location in the artifact
- The finding and its reasoning (this is the TEACHING component —
  explain why it matters so the engineer builds judgment)
- The severity and recommended action
- **Validation guidance** — specific steps the human can take to verify
  the finding: a targeted diff to review, a test to run, a reference to
  check, a code path to trace. **When the agent can perform mechanical
  validation itself** (run tests, check references, execute builds), it
  should do so and present the results with verifiable evidence (local
  test logs, CI/CD test pass URLs, build output files, clickable reference
  links). The human spot-checks evidence rather than re-running.

**After presenting each finding, wait for the human's disposition:**
- **Accept** — the finding is valid; will address it
- **Modify** — the finding has merit but the recommendation needs adjustment
- **Reject** — the finding is not applicable (human explains why)
- **Discuss** — the human wants to explore the issue further before deciding

```sql
UPDATE persona_findings SET disposition = '<disposition>',
    human_notes = '<notes>' WHERE id = <finding_id>;
```

### 5) Summarize and determine next action

After all findings are discussed:

1. Summarize: how many accepted, modified, rejected.
2. If any findings were accepted or modified that require artifact changes:
   - Offer to re-run the panel after changes are made (re-review cycle)
   - Store the current findings as `priorFindings` for the next cycle
   - On re-review, personas receive prior findings and focus on whether
     the issues were addressed (not a full fresh review)
3. If no changes needed, or human confirms changes are complete:
   - Mark the review as complete

```sql
UPDATE persona_review SET status = 'complete', completed_at = datetime('now')
WHERE id = <review_id>;
```

### 6) Release the artifact

Only after the review is marked complete may the artifact proceed:
- Code → commit, push, or present to human
- Writing → post, send, or include in PR
- Design → present to reviewers or document

## Anti-Anchoring (Instantiation of "First Thought Might Be Wrong")

When reviewing bug investigation conclusions or proposed fixes, the
anti-anchoring discipline applies with additional rigor. This fires
**during reasoning, before the persona review** — it is part of the
thinking discipline, not a post-hoc check:

1. Before forming a primary hypothesis, enumerate at least two
   alternative explanations
2. Identify evidence that would distinguish between the hypotheses
3. Check whether that evidence exists
4. Present BOTH the primary hypothesis and alternatives to the human

This prevents premature convergence on the first plausible explanation.
The persona review then verifies that the anti-anchoring discipline was
actually applied — it is the backstop, not the mechanism.

## Constraints

- **Analysis only** — the review skill does not modify the artifact itself.
  It produces findings; the calling agent or human makes changes.
- **Parallel execution** — all personas MUST run in parallel for speed.
  Sequential execution is unacceptable (impatience pressure leads to
  skipping reviews entirely).
- **Teaching, not just gating** — every finding MUST include reasoning that
  helps the engineer understand the issue, not just a pass/fail verdict
  (review as learning mechanism).
- **Full panel always** — no threshold or shortcut. Every artifact gets
  the full panel for its type. No exceptions.
- **Re-review is lighter and capped** — when re-running after changes,
  personas focus on whether accepted findings were addressed, not a full
  fresh review. Re-review runs at most once. If the second review produces
  new findings, present them as advisory (logged but not gating) — the
  human decides whether to address them without further review cycles.

## Session DB Persistence

### Review Tracking Tables

```sql
-- Tables created in Step 1 (repeated here for reference)
CREATE TABLE IF NOT EXISTS persona_review (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    artifact_type TEXT NOT NULL,
    panel TEXT NOT NULL,
    task_context TEXT,
    status TEXT DEFAULT 'in_progress',
    created_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT
);

CREATE TABLE IF NOT EXISTS persona_findings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    review_id INTEGER REFERENCES persona_review(id),
    persona TEXT NOT NULL,
    location TEXT,
    finding_type TEXT NOT NULL,
    finding TEXT NOT NULL,
    severity TEXT NOT NULL,
    recommendation TEXT,
    reasoning TEXT,
    disposition TEXT DEFAULT 'pending',
    human_notes TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);
```

### Observability

```sql
CREATE TABLE IF NOT EXISTS skill_execution_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    skill TEXT NOT NULL,
    started_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT,
    status TEXT DEFAULT 'running',
    error TEXT
);

-- At skill start:
INSERT INTO skill_execution_log (skill, status)
VALUES ('persona-review', 'running');

-- At skill completion:
UPDATE skill_execution_log SET completed_at = datetime('now'), status = 'done'
WHERE id = (SELECT MAX(id) FROM skill_execution_log
    WHERE skill = 'persona-review' AND status = 'running');
```

## Related Skills

- **Upstream**: Any skill that produces an artifact (code, design, writing)
  should invoke persona-review before presenting the artifact to the human.
- **Concepts**: `ai-assisted-engineering` (principles)
- **Technologies**: `persona-review-panels` (panel definitions),
  `review-voice` (Voice Reviewer reference)

## Evolution

This skill and its panels are a starting point. Track feedback:
- Which persona findings are consistently accepted vs rejected?
- Which personas produce the most signal vs noise?
- Are there artifact types that need their own panel?
- Does re-review after changes add value or just friction?

Update `persona-review-panels.md` and this skill based on real usage data.
Record significant learnings in `knowledge/concepts/ai-assisted-engineering.md`
and diary entries.
