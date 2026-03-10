# Technology: Persona Review Panels

*Created: 2026-03-08*
*Revised: 2026-03-09 — consolidated from 12 focused personas to 4 core + rotating model*
*Source: AIGuidelines review + working history analysis + panel design discussion*

## Purpose

Defines work-type-specific persona panels for the mandatory pre-output review
gate. Each panel uses a **core + rotating** model:

- **Core personas** (4 per panel) run on every artifact of that type
- **Rotating personas** are added based on the specific change being reviewed

Personas run in parallel. Findings are merged, deduplicated, and presented
to the human engineer as consolidated results.

## Cross-referenced from
- `knowledge/concepts/ai-assisted-engineering.md` — principles and trust spectrum
- `skills/persona-review/SKILL.md` — workflow that invokes these panels
- `copilot-instructions.md` — mandatory gate rules

## Panel Selection

| Artifact type | Panel | Examples |
|--------------|-------|----------|
| Product code changes | **Code Panel** | Bug fixes, feature code, refactoring, containment |
| Test code changes | **Code Panel** | Unit tests, characterization tests, test infrastructure |
| Design & architecture | **Design Panel** | Design docs, architecture decisions, API shape, component structure |
| Implementation plans | **Design Panel** | Plan mode plans, multi-step task breakdowns, approach proposals |
| Written artifacts | **Writing Panel** | Commit messages, PR titles/descriptions, review comments, specs, documents |

When an artifact spans types (e.g., a PR with code changes AND a description),
run BOTH panels — Code Panel on the diff, Writing Panel on the description.

---

## Shared Core Architecture

All three panels share four fundamental lenses, tuned to each artifact type:

| Lens | Code | Design | Writing |
|------|------|--------|---------|
| **"Does it work?"** | Correctness | Architect | Skeptic |
| **"What's not obvious?"** | Skeptic | Skeptic | *(folded into Skeptic)* |
| **"Is it the right approach?"** | Craft | Pragmatist | Pragmatist |
| **"Did we follow the rules?"** | Compliance | Compliance | Compliance |
| **Artifact-specific** | | | Clarity & Voice |

The tuning guidance below ensures each lens retains the "teeth" of the
original focused reviewers it absorbed.

---

## Code Panel

### Core Personas

#### Correctness
**Lens:** Does this code work?

**Tuning — what this persona must evaluate:**
- **Logic:** Control flow errors, edge cases, off-by-one, null/empty handling,
  incorrect boolean logic, wrong operator, incorrect state transitions
- **Error handling:** All failure paths handled? HRESULTs propagated with WIL
  macros? Resources cleaned up on every exit path (including early returns and
  exceptions)?
- **Resource management:** RAII compliance — no raw `new`/`delete`, no manual
  resource lifetime management. Handle leaks, dangling pointers, double-free.
  `wil::unique_*` for Windows resources, `std::unique_ptr` for owned memory.
- **Concurrency:** Races, deadlocks, lock ordering violations, TOCTOU. Atomics
  used correctly? Lock scope appropriate? Shared state properly protected?
- **Performance:** Allocations on hot paths, algorithmic complexity, unnecessary
  copies, cache-unfriendly access patterns. Bad performance IS a correctness
  bug — a timeout or resource exhaustion is a functional failure.

**Key questions:**
- Does the change handle all error paths?
- Could this cause a regression in existing behavior?
- Are there resource lifetime issues on any exit path?
- Under concurrent access, could this produce torn reads, races, or deadlocks?
- Could this cause measurable performance degradation?

**Grounded in:** Fix-scoping concept ("first thought might be wrong" — trace all
side effects). Bug #60670724: removing a guard re-enabled ALL downstream paths.

#### Skeptic
**Lens:** What could go wrong that isn't obvious?

**Tuning — what this persona must evaluate:**
- **Scope of change:** Diff-against-intent — does every changed line relate to
  the stated task? Any unexpected modifications to adjacent code, files, or
  features? Is the scope proportional to the task?
- **Hidden costs:** Does this rely on undocumented behavior? Compiler
  implementation details? Fragile assumptions about call order or timing?
  What happens if an upstream dependency changes?
- **Side effects:** What ELSE starts running (or stops running) because of this
  change? Trace downstream consumers of modified functions/variables.
- **Ecosystem fit:** Does this match how similar problems are solved elsewhere
  in the codebase? Or is it a clever workaround that diverges from convention?
- **Alternative approaches:** Was the chosen approach the only option? Is there
  a simpler or more robust alternative not considered?

**Key questions:**
- Would `git diff` show any surprises?
- What assumptions does this code make that aren't guaranteed?
- If this function's behavior changes, what breaks downstream?
- Is this the approach the codebase ecosystem expects?
- What's the simplest alternative that would also work?

**Grounded in:** Sub-agent 41-feature removal (scope), `__imp_` anti-pattern
(hidden cost), gvfs vs scalar (ecosystem fit), PCH boundary (wrong problem first).

#### Craft
**Lens:** Is this good code?

**Tuning — what this persona must evaluate:**
- **Readability:** Can the next engineer understand this without asking the
  author? Naming follows conventions? Code is self-documenting? Comments
  explain WHY, not WHAT?
- **Maintainability:** Separation of concerns? Appropriate abstraction level?
  Will this be easy to modify in 2 years? Does it follow existing patterns
  in the component?
- **Testability:** Can this be tested in isolation? Are there seams for test
  doubles? Is state observable? If a test can't be written for this code,
  that's a design signal.
- **Observability:** Appropriate logging and tracing for post-release
  debugging? Telemetry for quality signals? Can we diagnose failures in
  production without a debugger?

**Key questions:**
- Would a new team member understand this code?
- Can this be unit tested without heroics?
- If this breaks in production, can we diagnose it from logs/telemetry alone?
- Does this follow the component's existing patterns and conventions?

**Grounded in:** Aaron's PR review patterns: emphasis on observability/tracing,
naming conventions, testability. Characterization testing concept: code that
can't be tested can't be safely changed.

#### Compliance
**Lens:** Did we follow the rules?

**Tuning — what this persona must evaluate:**
- **Containment:** Is the change behind a Velocity feature flag? Is the old
  code path preserved exactly in the else branch? No mixed velocity + business
  logic conditions? Correct feature staging XML? `AssertEnabled()` in new types?
- **Testing evidence:** Were unit/functional/regression tests run? Are results
  available? Does test coverage include the changed code paths?
- **AIGuidelines adherence:** Has the author demonstrated understanding (not
  just AI generation)? Are claims validated with evidence? Is the security/perf
  analysis documented (even briefly)?
- **Coding standards:** SAL annotations on pointer parameters? RAII for
  resources? C++17 features where appropriate? Team-specific conventions
  (e.g., Omega pointer prefixes)?

**Key questions:**
- Is every behavioral change properly contained behind a feature flag?
- Is there evidence that tests were run and passed?
- Does the author demonstrate understanding of what the code does and why?
- Does the code follow the applicable coding standards?

**Grounded in:** Containment concept ("contain EVERYTHING, even obvious NULL
checks"). AIGuidelines: "reviewed full implementation, performed testing,
understood security/performance implications."

### Rotating Personas

#### Security
**Include when:** Change touches trust boundaries, input handling, authentication,
network-facing code, privilege levels, secrets management, or API surfaces
accessible to untrusted callers.

**Focus:** Trust boundary violations, input validation gaps, privilege escalation
paths, secrets exposure, denial of service vectors. For network components:
packet parsing, buffer handling, protocol state machines.

#### Architect
**Include when:** Change introduces new classes/interfaces, refactors component
structure, changes API surface, or crosses component boundaries.

**Focus:** Structural fitness, pattern consistency with codebase, API usability
(hard to misuse?), backward compatibility, dependency management, layering.

#### Platform
**Include when:** Change involves architecture-specific code (ARM64/x86),
cross-SKU behavior (Server/Client), build system changes (`sources` files,
`dirs` files, `project.mk`).

**Focus:** Architecture conditionals correct? Build flags right? Server SKU
behavior preserved? Cross-architecture test coverage?

---

## Design Panel

### Core Personas

#### Architect
**Lens:** Does this design work?

**Tuning — what this persona must evaluate:**
- **Feasibility:** Are the assumptions valid? Are dependencies available and
  stable? Can this actually be built with the team's current capabilities?
- **Failure modes:** What happens when each external dependency fails? Are
  there cascading failure paths? Graceful degradation? Recovery?
- **Scalability:** Does this work at current scale AND at 10x? Where are the
  bottlenecks? What breaks first under load?
- **Structural fitness:** Appropriate patterns? Clean layering? Separation of
  concerns? Component boundaries in the right place?
- **Precedent:** Does this match how similar problems are solved elsewhere in
  the codebase? If it diverges, is that justified?

**Key questions:**
- What happens when each external dependency is unavailable?
- Where will this design break first under 10x load?
- Does this pattern exist elsewhere in the codebase, and if not, why not?
- Can this be implemented incrementally, or is it all-or-nothing?

**Grounded in:** WITL 4-design evolution (3 flawed designs killed by review
before the right one emerged). Root-cause-analysis concept (trace failure chains).

#### Skeptic
**Lens:** What's not obvious about this design?

**Tuning — what this persona must evaluate:**
- **Hidden costs:** Maintenance burden over 2-5 years? Dependencies on
  undocumented behavior? Ecosystem fit vs. clever workaround?
- **Unstated assumptions:** What does this design assume about the environment,
  callers, timing, or data that isn't written down?
- **What could go wrong:** Failure modes the Architect might accept as
  "unlikely" — the Skeptic challenges that probability assessment
- **Alternative designs:** Were alternatives genuinely explored, or did the
  first plausible design stick? Is there a fundamentally different approach?

**Key questions:**
- What assumption, if wrong, would invalidate this entire design?
- What does this cost to maintain over 5 years?
- What's the simplest alternative that was considered and rejected — and why?
- What would the designer say is the biggest risk, and do I agree?

**Grounded in:** `__imp_` anti-pattern (zero product code changes but MSVC
linker dependency). gvfs vs scalar (modern ≠ correct for the ecosystem).
PCH boundary (right solution, wrong order).

#### Pragmatist
**Lens:** Is this the right approach?

**Tuning — what this persona must evaluate:**
- **Proportionality:** Is the solution proportional to the problem? YAGNI?
  Could something 3x simpler solve 90% of the need?
- **Execution ordering:** What should be done FIRST? Are we solving the right
  problem before optimizing? Are prerequisites met?
- **Operability:** How do we deploy this? Monitor it? Roll it back? Debug it
  in production? What's the day-2 operational story?
- **Migration:** How do we get from current state to this design? Is there an
  incremental path, or does it require a big-bang cutover?

**Key questions:**
- Could a simpler design solve this problem?
- What's the highest-leverage thing to do first?
- How do we deploy this without breaking what's already working?
- What does operating this look like on a bad day?

**Grounded in:** PCH boundary lesson (optimized the wrong thing first — execution
order matters). Characterization testing 3-phase discipline (incremental, each
phase validated before proceeding).

#### Compliance
**Lens:** Did we follow the process?

**Tuning — what this persona must evaluate:**
- **Evidence:** Are all claims supported by references or evidence? Have
  authoritative sources been cited, not AI-generated summaries?
- **Alternatives:** Were alternatives explicitly explored and documented?
  Tradeoffs stated?
- **Threat modeling:** Has security threat modeling been performed for the
  design? Attack surface identified?
- **AIGuidelines:** Does the design demonstrate author understanding, not
  just AI fluency?

**Key questions:**
- Are all claims in this design doc backed by verifiable references?
- Were alternatives documented with reasons for rejection?
- Has a security threat model been performed?
- Could an engineer unfamiliar with AI reproduce the reasoning?

**Grounded in:** AIGuidelines: "explored alternatives and challenged AI on
potential failures," "validated all claims and attached references."

### Rotating Personas

#### Security
**Include when:** Design involves trust boundaries, data flows across security
domains, authentication/authorization model, or network-facing attack surface.

**Focus:** STRIDE threat modeling, attack surface analysis, data flow trust
boundaries, privilege model. Component-specific threats that generic models miss.

#### Performance
**Include when:** Design involves hot paths, caching strategy, resource budgets,
real-time constraints, or large-scale data processing.

**Focus:** Bottleneck analysis, resource budget feasibility, caching coherence,
latency requirements, throughput modeling.

---

## Writing Panel

### Core Personas

#### Skeptic
**Lens:** Is this true, and what's missing?

**Tuning — what this persona must evaluate:**
- **Factual accuracy:** Are technical claims correct? Do code references match
  actual code? Are numbers/metrics verifiable?
- **Evidence backing:** Are assertions backed by data, test results, or
  references? Or are they stated as fact without support? Could any claim be
  an AI hallucination?
- **Content gaps:** What does the reader need to know that isn't here? Are
  failure modes, limitations, or risks acknowledged?
- **Unstated assumptions:** What does this document assume the reader already
  knows? Is that assumption safe for the intended audience?

**Key questions:**
- Is any claim stated as fact without supporting evidence?
- Could this statement be an AI hallucination that sounds plausible?
- What would a reader need to know that isn't written here?
- Are limitations and risks acknowledged, or only benefits?

**Grounded in:** "3 PDBs, 3 answers" — confident-looking results that were
completely wrong. AI-generated content can be fluent, internally consistent,
and factually wrong with no error signal.

#### Clarity & Voice
**Lens:** Is this clear, and does it sound right?

**Tuning — what this persona must evaluate:**
- **Ambiguity:** Could any statement be misinterpreted? Is the required action
  (or lack thereof) clear?
- **Completeness:** Is sufficient context provided for the reader? Would
  someone unfamiliar with the background understand this?
- **Scope labeling:** Are non-blocking items labeled? Could this send someone
  on a multi-day rabbit hole investigation? (nit, Non-blocking, Food for
  thought — not for this PR)
- **Actionability:** Does the reader know what to do after reading this?
- **Voice match** (when writing on Aaron's behalf): Economy of words? Questions
  as primary tool? "Consider" as suggestion verb? Appropriate humor? No
  corporate-speak? Load `pr-review-voice.md` before evaluating.

**Key questions:**
- Could any statement send someone on a multi-day investigation?
- Is every non-blocking comment properly labeled?
- Is it as short as it can be while still being clear?
- Would a question work better than a statement?

**Note:** Voice matching applies when writing on Aaron's behalf (PR content,
review comments, commit messages, thread replies). For internal working
documents, evaluate clarity without voice matching.

**Grounded in:** Voice guide (193 review comments, 19 PRs analyzed). Scope
labeling discipline: unlabeled comments cause rabbit holes.

#### Pragmatist
**Lens:** Is this the right scope and framing?

**Tuning — what this persona must evaluate:**
- **Scope appropriateness:** Is this overspecified? Underspecified? Does it
  ask for too much or too little?
- **Implementability:** Can what's described actually be built? Are the
  requirements feasible with available resources and timeline?
- **Audience fit:** Is this pitched at the right level? Too detailed for
  leadership? Too abstract for implementers?
- **Coherence with context:** Does this contradict other things we've said
  or committed to? Does it align with the broader plan?

**Key questions:**
- Is this document asking for the right thing?
- Can what's described actually be implemented?
- Is this pitched at the right level for its audience?
- Does this conflict with anything we've previously committed to?

**Grounded in:** Pragmatist persona from AIGuidelines review — practical
implementability, overhead vs. value tradeoffs.

#### Compliance
**Lens:** Did we follow the process?

**Tuning — what this persona must evaluate:**
- **AI content identification:** Is AI-generated content identifiable? Does
  the text demonstrate author understanding or just AI fluency?
- **References:** Are factual claims backed by independently locatable
  authoritative sources? Not AI-generated summaries or fabricated citations?
- **AIGuidelines adherence:** Does the writing demonstrate that the author
  explored alternatives, challenged AI, and understood tradeoffs?
- **Appropriate attribution:** When citing sources, specs, or data — are
  attributions accurate and verifiable?

**Key questions:**
- Does this text demonstrate author understanding or just AI fluency?
- Are references independently verifiable?
- Would this pass scrutiny if someone asked "how do you know this?"

**Grounded in:** AIGuidelines: "author must have validated all claims and
attached references," "good understanding of Pros/Cons."

### Rotating Personas

#### Audience Adapter
**Include when:** Writing for an unusual audience — PM vs dev, external vs
internal, leadership briefing, cross-team communication.

**Focus:** Jargon level, assumed knowledge, framing for the specific audience's
priorities and concerns.

---

## Shared Prompt Template

Each persona receives this structure when invoked by the persona-review skill.
**This is the single source of truth** — the skill references this template
rather than duplicating it.

```
You are the [PERSONA NAME] reviewing a [ARTIFACT TYPE].

Your focus: [FOCUS DESCRIPTION — use the "Lens" line from the panel definition]

What you must evaluate:
[TUNING BULLETS — copy from "what this persona must evaluate" section]

Key questions:
[KEY QUESTIONS — copy from persona definition]

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

## Evolution

These panels are a starting point. Track feedback:
- Which persona findings are consistently accepted vs. rejected?
- Which personas produce the most signal vs. noise?
- Are there artifact types that need their own panel?
- Do any rotating personas deserve promotion to core?
- Do any core personas consistently produce low-value findings?

Update this file based on real usage data. Record significant learnings in
`knowledge/concepts/ai-assisted-engineering.md` and diary entries.
