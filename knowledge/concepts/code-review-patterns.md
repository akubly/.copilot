# Aaron's Code Review Patterns

*Derived from 2,670 comments across 481 PRs*

## Purpose

When reviewing code as Aaron, this document tells you **WHAT to look for**. The voice guide (`pr-review-voice.md`) tells you **HOW to communicate** what you find.

These patterns are language-agnostic principles grounded in real review behavior. They apply to C++, C#, and any systems-level codebase. Adapt the specific examples to the language and framework at hand.

## Corpus Overview

- **2,670 comments** across **481 PRs**
- 1,790 text comments, average 60 characters (median 26)
- 19.6% pure questions — questions are the primary review tool
- 86% thread resolution rate
- Typical review depth: 5–6 comments per PR

## Review Priority Hierarchy

Every comment falls into one of four severity tiers. Assign severity explicitly — it tells the author how to prioritize.

| Priority | Severity | Meaning |
|----------|----------|---------|
| 1. **Correctness & Safety** | Always blocking | Must fix before merge. Bugs, crashes, data corruption, security holes. |
| 2. **Better Alternatives** | Usually non-blocking | Strongly suggested improvement. Won't block if author pushes back with rationale. |
| 3. **Redundancy & Simplification** | Usually nit | Clean-up opportunity. Nice to fix but not worth a re-review cycle. |
| 4. **Style & Naming** | Always nit | Cosmetic. Fix if touching the line anyway; never block on these. |

---

## The 20 Actionable Rules

### Always Check — Blocking (Rules 1–7)

These are correctness and safety issues. If you spot one, it blocks the PR.

---

#### Rule 1: Thread Safety

**Trigger:** Shared mutable state accessed from multiple threads without synchronization.

**Example comments:**
- "Not threadsafe"
- "Does this need to be atomic?"
- "What protects this field from concurrent access?"
- "This read races with the write on line N"

**Action:** Verify every shared mutable field is protected by a lock, atomic, or documented single-threaded contract. Flag unguarded reads as well as writes.

---

#### Rule 2: Exception Safety

**Trigger:** Exceptions that can escape function boundaries, cross ABI/API surfaces, or leave objects in inconsistent state.

**Example comments:**
- "This can throw"
- "try/catch at function scope?"
- "If this throws, the caller has no way to handle it"
- "Exception can cross the API boundary here"

**Action:** Ensure exceptions are caught before crossing API boundaries. Verify that partial-mutation paths are rolled back or use RAII to maintain invariants.

---

#### Rule 3: Resource Leaks

**Trigger:** Allocations, handles, or resources that are not matched by a deterministic cleanup mechanism (RAII wrapper, `using` block, destructor).

**Example comments:**
- "This is leaked"
- "Consider an RAII wrapper here"
- "Who owns this allocation?"
- "Missing cleanup on the error path"

**Action:** Every `new`, `malloc`, `CreateHandle`, `open`, or equivalent must have a matching RAII owner or deterministic disposal. Check error paths — early returns often skip cleanup.

---

#### Rule 4: Callback Lifetime

**Trigger:** Callbacks, event handlers, or weak references that can fire during or after the owning object's teardown.

**Example comments:**
- "Can this fire during teardown?"
- "What prevents a callback after destruction?"
- "The weak reference could be dangling here"
- "Race between unregister and callback dispatch"

**Action:** Verify that callback registration is paired with unregistration, and that the unregistration is sequenced before destruction. Check for weak-reference / prevent-destroy patterns.

---

#### Rule 5: Error Propagation

**Trigger:** Return values ignored, wrong error type returned, or errors silently swallowed.

**Example comments:**
- "Should this propagate the error?"
- "Return value unchecked"
- "Should this return an error code instead of a bool?"
- "Log-and-continue — is that intentional?"

**Action:** Every fallible call should have its result checked or explicitly discarded with a comment. Verify the error type matches the function's contract (e.g., `HRESULT` vs. exception vs. `bool`).

---

#### Rule 6: Logic Correctness

**Trigger:** Wrong operator, wrong order of operations, off-by-one, wrong variable, incorrect scope of a change.

**Example comments:**
- "Should this be `==` rather than `=`?"
- "Should this be `&&` not `||`?"
- "Off-by-one — should this be `<` not `<=`?"
- "This condition is always true"

**Action:** Read the logic literally. Trace a concrete value through the branch. Check boundary conditions. Verify the change doesn't affect more cases than intended.

---

#### Rule 7: Feature Containment

**Trigger:** Behavioral changes shipped without a feature flag or equivalent rollback mechanism.

**Example comments:**
- "This needs a feature flag"
- "What's the rollback plan if this regresses?"
- "This changes default behavior — should it be gated?"
- "Can this be disabled independently?"

**Action:** Every behavioral change should be behind a feature flag, experiment, or configuration gate. Verify that disabling the flag preserves the exact prior behavior.

---

### Usually Check — Non-blocking (Rules 8–14)

These improve code quality but don't indicate bugs. Flag them, but don't block unless the author agrees.

---

#### Rule 8: Better API / Library

**Trigger:** Hand-rolled code that duplicates existing library functionality.

**Example comments:**
- "There's a utility for this already"
- "Consider using the standard library version"
- "This is reimplementing X"
- "The framework provides a helper for this pattern"

**Action:** Point to the existing API. If the hand-rolled version handles edge cases the library doesn't, note it as intentional.

---

#### Rule 9: Algorithm Simplification

**Trigger:** Verbose loop that could be replaced by a standard algorithm, LINQ query, or range-based operation.

**Example comments:**
- "This loop is just a `find_if`"
- "Could use `std::any_of` here"
- "LINQ `Where` + `Select` would simplify this"

**Action:** Suggest the simpler form. Don't insist if the loop is clearer in context or handles complex mutation.

---

#### Rule 10: Unnecessary Abstraction

**Trigger:** Wrapper class or function that adds no value over calling the underlying API directly.

**Example comments:**
- "Does this wrapper add anything?"
- "This just forwards to the underlying call"
- "Consider removing the indirection"

**Action:** If the wrapper doesn't add error handling, logging, lifetime management, or type safety, suggest removing it.

---

#### Rule 11: Named Constants

**Trigger:** Magic numbers or string literals embedded in logic without explanation.

**Example comments:**
- "What does `42` mean here?"
- "Consider a named constant"
- "Magic number — hard to maintain"

**Action:** Extract to a `constexpr`, `const`, or `enum` with a descriptive name. Exception: `0`, `1`, `nullptr`, and empty string are generally fine.

---

#### Rule 12: Scope / Lifetime Mismatch

**Trigger:** RAII object or resource whose scope is wider or narrower than its intended lifetime.

**Example comments:**
- "This lock is held too long"
- "This temporary outlives its use"
- "Move the declaration into the inner scope"

**Action:** Tighten scope to match actual usage. Especially important for locks, file handles, and network connections.

---

#### Rule 13: Simplify Boolean Logic

**Trigger:** Nested conditionals, double negation, or deep if/else chains that could be early returns or simplified expressions.

**Example comments:**
- "Early return would simplify this"
- "Double negation — hard to read"
- "Invert the condition and return early"

**Action:** Suggest guard clauses (early return on failure) and flattened logic. De Morgan's law simplifications are fair game.

---

#### Rule 14: Disposable Resource Management (C#)

**Trigger:** `IDisposable` objects not wrapped in `using` statements or blocks.

**Example comments:**
- "Should this be in a `using` block?"
- "`Dispose` is never called"
- "Wrap in `using` to ensure cleanup"

**Action:** Every `IDisposable` should be in a `using` statement unless ownership is explicitly transferred. In C++, this maps to RAII wrappers for non-RAII resources.

---

### Always Nit (Rules 15–20)

Cosmetic and style issues. Mention if you notice them, but never block a PR for these.

---

#### Rule 15: Const Promotion

**Trigger:** Variable or parameter that is never modified but not declared `const` / `readonly` / `final`.

**Example comments:**
- "Can this be `const`?"
- "Mark as `readonly`"

**Action:** Suggest adding `const`. This is always a nit — it improves signal but doesn't change behavior.

---

#### Rule 16: Alphabetical Sorting

**Trigger:** `#include`, `using`, or import statements that are not sorted alphabetically within their group.

**Example comments:**
- "Sort includes"
- "Alphabetize these `using` statements"

**Action:** Sort within groups. Don't re-sort across groups (e.g., system vs. project headers).

---

#### Rule 17: Formatting Consistency

**Trigger:** Formatting that doesn't match the surrounding file's conventions.

**Example comments:**
- "Match the file's existing style"
- "Inconsistent indentation"
- "Brace style doesn't match the rest of the file"

**Action:** Match the file. Don't impose a global style on a file that uses a different one. Autoformatters are preferred over manual fixes.

---

#### Rule 18: Brace Initialization (C++)

**Trigger:** Using `=` initialization where brace initialization (`{}`) would be clearer and prevent narrowing conversions.

**Example comments:**
- "Use brace initialization"
- "Narrowing conversion — braces would catch this"

**Action:** Prefer `Type x{value}` over `Type x = value` in C++. This is language-specific — adapt to C#/Java conventions as appropriate.

---

#### Rule 19: Redundancy Removal

**Trigger:** Unused variables, unreachable code, redundant conditions, or dead assignments.

**Example comments:**
- "This variable is unused"
- "Dead code — can this be removed?"
- "This condition is always true"
- "Not needed?"

**Action:** Remove dead code. If it's intentionally kept for future use, it should have a comment explaining why.

---

#### Rule 20: Variable Placement

**Trigger:** Variables declared far from their first use, or declared at function scope when a tighter scope is possible.

**Example comments:**
- "Declare at point of first use"
- "Move this closer to where it's used"
- "Can this be scoped to the inner block?"

**Action:** Declare variables as close to first use as possible. This reduces cognitive load and makes ownership clearer.

---

## Meta-Patterns

Beyond the 20 rules, Aaron's reviews exhibit recurring meta-patterns — higher-order habits that apply across all categories.

### The Question as Primary Tool (19.6% of all comments)

Questions are more effective than statements for non-blocking feedback. They invite the author to think rather than defend.

| Pattern | Purpose | Example |
|---------|---------|---------|
| "Not needed?" | Spot redundancy | "Is this wrapper still needed?" |
| "Also in X?" | Check consistency | "Should the same change apply to the sibling function?" |
| "Should we also...?" | Question scope | "Should we also update the documentation?" |
| "Is it even possible...?" | Probe invariants | "Is it even possible for this to be null at this point?" |
| "What happens if...?" | Explore edge cases | "What happens if the callback fires after shutdown?" |

### Consistency Checks

When reviewing a change to one location, always ask: **does the same pattern exist elsewhere?** If so, either fix all instances or explicitly scope the PR to one.

### Scope Awareness

Before suggesting a fix, consider: **is the fix broader than the PR's intent?** If so, suggest it as a follow-up rather than a blocking change. Avoid sending the author on a rabbit-hole investigation.

### Redundancy Detection

Aaron's most common single-word comment pattern is questioning whether something is needed. Apply this lens to:
- Wrapper functions that just forward calls
- Variables that are assigned but only used once
- Conditions that are always true/false
- Error handling that can never trigger

---

## Applying These Patterns

Use a three-pass approach to maintain focus and avoid mixing severity levels:

1. **First pass — Correctness & Concurrency (Rules 1–7):** Read for bugs, races, leaks, and missing containment. These are blocking. Get them right first.

2. **Second pass — API & Alternatives (Rules 8–14):** Look for better approaches, simplifications, and missed library functions. These are suggestions.

3. **Third pass — Style & Naming (Rules 15–20):** Scan for formatting, const-correctness, and dead code. These are nits.

4. **Throughout all passes:** Apply meta-patterns — consistency, redundancy, scope awareness, and questions as the default communication tool.

### Calibrating Review Depth

Not every PR needs the same depth. Calibrate based on:

- **Risk of the change:** Core logic changes get deeper review than test-only or config changes
- **Author experience:** New contributors benefit from more detailed feedback; veterans need less
- **Size of the change:** Large PRs need more focus on architecture; small PRs on correctness
- **Area familiarity:** Review more carefully in areas you know less about — your fresh eyes catch assumptions
