# Concept: AI-Assisted Engineering

## Core Principle

**AI assists; humans own.** AI is a productivity multiplier and design reviewer — not a decision-maker. The human engineer remains fully accountable for correctness, security, and auditability.

AI-generated output must be treated as a *draft from a knowledgeable but fallible colleague* — useful, often excellent, but never authoritative on its own.

---

## The Trust Spectrum

Not all tasks carry equal risk when delegated to AI. Calibrate autonomy based on consequence severity and verifiability.

### Higher autonomy (AI does well independently)

| Task | Why it works |
|------|-------------|
| Codebase exploration and search | Bounded scope, verifiable results |
| Boilerplate and scaffolding | Pattern-driven, low ambiguity |
| Systematic processing (categorization, formatting, style enforcement) | Rule-based, deterministic intent |
| Build and test execution | Observable outcomes, pass/fail signals |
| Knowledge retrieval | Factual lookup, cross-referenceable |

### Lower autonomy (AI needs human steering at decision points)

| Task | Why human judgment is needed |
|------|------------------------------|
| **Scope decisions** | AI's first instinct is often too broad — it optimizes for completeness over precision |
| **Design tradeoffs** | Requires understanding ecosystem fit, maintenance cost, and team conventions |
| **Hidden cost analysis** | Solutions that "look free" may carry maintenance burden, tooling fragility, or coupling risk |
| **Execution ordering** | What to do FIRST matters — AI tends to flatten priorities into parallel lists |
| **Ecosystem fit** | Matching tooling, libraries, and patterns to infrastructure conventions |

### Critical human verification required

| Risk | Description |
|------|-------------|
| **Sub-agent output scope** | AI may apply instructions too broadly, changing more than intended |
| **Confidence without evidence** | AI produces plausible, internally consistent, completely wrong results with high fluency |
| **Correctness, performance, and security claims** | AI cannot prove its own output correct — verification must be external |

---

## Per-Phase Guidelines

### Specifications and Design

- **AI excels at:** Outlines, alternatives enumeration, tradeoff analysis, failure mode brainstorming, checklist generation
- **Before review:** Validate all AI-generated claims with references; explore alternatives the AI didn't suggest; question assumptions
- **Key risk:** AI may present plausible claims without factual basis — it generates *plausible reasoning*, not *verified reasoning*

### Code and Tests

- **AI excels at:** Exploration, boilerplate, test generation, code-from-spec proposals, refactoring within well-defined constraints
- **Before commit:** Review the full implementation (not just the diff summary), run tests, validate security and performance implications, check edge cases
- **Key risk:** AI output needs structured verification, not just "looks right" — fluent code is not necessarily correct code

### Bug Investigation

- **AI excels at:** Hypothesis generation, log analysis, pattern matching against known failure modes, bisection strategy
- **Before acting:** Challenge and validate every recommendation through testing; confirm the hypothesis before implementing the fix
- **Key risk:** AI may solve the wrong problem (treating symptoms instead of root cause) or propose a fix with unintended side effects that only manifest under specific conditions

---

## Structural Safeguards

Two mandatory gates protect against AI over-trust:

### 1. Decision-Point Gate

Before making consequential choices, AI must **present options** rather than act unilaterally:

- What are the alternatives?
- What are the tradeoffs of each?
- What information is missing?
- What is the recommended option, and why?

The human selects. The AI executes.

### 2. Pre-Output Persona Review Gate

Before presenting any significant output (code changes, design proposals, investigation conclusions), apply a structured review:

- **Skeptic perspective:** What could be wrong? What assumptions are unvalidated?
- **Scope perspective:** Is this changing more than necessary? Are there side effects?
- **Ecosystem perspective:** Does this fit the project's conventions, tooling, and maintenance expectations?

This review should be systematic, not perfunctory. The goal is to catch the class of errors that fluent output obscures.

---

## Anti-Patterns

### "It looks right" ≠ "It is right"

AI outputs are fluent, well-formatted, and internally consistent. This makes them **harder** to review critically than poorly written human output. The polish creates a false signal of correctness.

**Counter:** Use structured review mechanisms. Read for logic, not for prose quality. Test behavior, not appearance. When reviewing AI output, actively look for what's *missing* rather than evaluating what's *present*.

### "AI said it, so it must be validated"

The mere fact that AI generated something does not constitute validation. AI can produce confident explanations for incorrect conclusions. It can cite patterns that don't apply. It can generate tests that pass but don't test what they claim to test.

**Counter:** Independently verify through testing, reference checks, and domain expertise. Treat AI output as a hypothesis, not a conclusion.

### "Zero product code changes" ≠ "Zero cost"

Solutions that avoid production code changes may appear lower-risk, but they can carry hidden costs:

- **Reliance on implementation details** — tests or tooling that depend on internal behavior break when internals change
- **Tooling fragility** — custom scripts and workarounds accumulate maintenance burden
- **Ecosystem mismatch** — solutions that work around established patterns rather than working within them create confusion and inconsistency

**Counter:** Evaluate total cost of ownership, not just immediate risk. Sometimes the "bigger" change is actually the cheaper one long-term.

---

## Summary

| Principle | Practice |
|-----------|----------|
| AI assists; humans own | Engineer is accountable for all output |
| Calibrate autonomy to risk | High autonomy for exploration; human gates for decisions |
| Verify, don't trust | Structured review before every consequential output |
| Challenge scope | AI's first answer is often too broad — narrow deliberately |
| Test behavior, not appearance | Fluent output obscures errors — test the actual behavior |
| Evaluate total cost | "Zero code changes" may still carry hidden costs |

---

## Related

- **Concepts:** fix-scoping, containment, characterization-testing, root-cause-analysis
- **Technologies:** persona-review-panels, pr-review-voice
- **Skills:** persona-review
