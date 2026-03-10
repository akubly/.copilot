# Concept: AI-Assisted Engineering

Principles for responsible AI use in Windows OS development, internalized from
MobCon's AI Guidelines and refined through real working experience.

## Core Principle

**AI assists; humans own.** AI is a productivity multiplier and design
reviewer — not a decision-maker. The human engineer remains fully accountable
for correctness, security, and auditability of all outputs, regardless of
how much AI contributed to producing them.

## The Trust Spectrum

Not all AI-assisted work carries equal risk. Our working history reveals a
clear calibration of where AI earns autonomy vs. where it needs oversight:

### Higher autonomy (AI does well independently)
- **Codebase exploration and search** — tracing call graphs, finding
  implementations, understanding unfamiliar components
- **Boilerplate and scaffolding** — containment patterns, test stubs,
  build file structure, RAII wrappers
- **Systematic processing** — de-duplication, categorization, formatting,
  style enforcement, naming convention checks
- **Build and test execution** — running builds, collecting results,
  parsing test output
- **Knowledge retrieval** — querying Kusto, searching ADO, looking up
  documentation

### Lower autonomy (AI needs human steering at decision points)
- **Scope decisions** — what to fix AND what NOT to fix. AI's first instinct
  is often too broad (fix-scoping: "first thought might be wrong")
- **Design tradeoffs** — choosing between approaches requires understanding
  ecosystem fit, maintenance cost, and team conventions (WITL: 4 designs
  killed by review before reaching the right one)
- **Hidden cost analysis** — solutions that "look free" may carry maintenance
  burden or fragile dependencies (__imp_ anti-pattern)
- **Execution ordering** — what to do FIRST matters; AI may optimize the
  wrong thing (PCH boundary before include graph)
- **Ecosystem fit** — matching tooling to infrastructure conventions rather
  than reaching for the "modern" general-purpose tool (gvfs vs scalar)

### Critical human verification required
- **Sub-agent output scope** — AI interprets instructions correctly but
  may apply them too broadly (41-feature removal: verify diff before commit)
- **Confidence without evidence** — AI produces plausible, internally
  consistent, completely wrong results with no error signal (3 PDBs,
  3 answers: verify with independent evidence)
- **Correctness, performance, and security claims** — any assertion about
  these properties requires explicit validation and documentation

## Per-Phase Guidelines

### Specifications and Design
- AI excels at: outlines, alternatives, tradeoff analysis, failure mode
  brainstorming, clarity improvements, diagram generation
- Before review: validate all AI-generated claims with references; explore
  alternatives; understand pros/cons
- Key risk: AI may present plausible-sounding claims without factual basis

### Code and Tests
- AI excels at: exploration, boilerplate, containment, test generation,
  code-from-spec proposals, useful comments
- Before PR: review full implementation, unit/functional/regression testing,
  validate logging/telemetry, understand security/performance implications
- Key risk: "triple check" is not enough — need structured verification
  (adversarial review, diff verification, scope analysis)

### Bug Investigation
- AI can assist in investigation, but recommendations cannot be taken at
  face value
- Challenge and validate through testing
- Key risk: AI may solve the wrong problem or propose a fix with unintended
  side effects

## Structural Safeguards

Two mandatory gates encode these principles into every workflow:

### 1. Decision-Point Gate
Before making any choice between alternatives — implementation approach,
architecture decision, naming, API shape, etc. — STOP and present the
options to the human engineer. Include:
- What the options are
- Tradeoffs of each
- Which the agent leans toward and why
- Wait for human input before proceeding

This applies even to choices that seem obvious. The purpose is auditability
and shared understanding, not just catching errors.

### 2. Pre-Output Persona Review Gate
Before presenting ANY work output — code, commit messages, PR descriptions,
review comments, designs, documents — invoke a structured persona review.
Each persona evaluates the output from a specific angle. Results are
discussed item by item with the human engineer. Nothing leaves the machine
until the human approves.

## Anti-Patterns

### "It looks right" ≠ "It is right"
AI outputs are fluent, well-formatted, and internally consistent. This
makes them HARDER to review critically, not easier. Automation bias —
unconsciously lowering scrutiny on professional-looking output — is a
real risk. Counter with structured review mechanisms, not just "be careful."

### "AI said it, so it must be validated"
The mere fact that AI generated something does not constitute validation.
The human must independently verify claims through testing, reference
checks, and domain expertise. If you can't explain WHY the AI's output
is correct, you haven't validated it.

### "Zero product code changes" ≠ "Zero cost"
Solutions that avoid touching production code may carry hidden costs:
reliance on implementation details, tooling fragility, or ecosystem
mismatch. Evaluate maintenance burden, not just immediate elegance.

## Related Concepts
- **fix-scoping** — "first thought might be wrong" discipline
- **containment** — partitioning AI-assisted changes behind feature toggles
- **characterization-testing** — pinning behavior before modifying it
- **root-cause-analysis** — structured investigation (AI traces, human validates)

## Related Technologies
- **persona-review-panels** — work-type-specific review persona definitions
- **pr-review-voice** — encoding human voice standards for AI-authored text

## Related Skills
- **persona-review** — invocable workflow implementing the review gate

## Origin
- MobCon AIGuidelines document (Jean Khawand, Sathya Karivaradaswamy)
- Refined through working experience 2026-02-19 through 2026-03-08
