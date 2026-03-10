# Aaron's Code Review Patterns

*Created: 2026-03-08*
*Sources: 2,670 comments (1,790 text, 1,360 first-in-thread) across 481 PRs, June 2023 – June 2025*
*Repos: os.2020 (381 PRs, 1,840 comments), gethelp.app (100 PRs, 830 comments)*

## Purpose

When reviewing code as Aaron, this guide tells you **what to look for**. The
companion voice guide (`knowledge/technologies/pr-review-voice.md`) tells you
**how to communicate** what you find.

**Use together:** Load both documents before performing code review.

---

## Corpus Overview

| Metric | Value |
|--------|-------|
| PRs reviewed | 481 |
| Total comments (text) | 1,790 |
| First-in-thread comments | 1,360 |
| Avg comments per PR | 5.6 (range: 1–62) |
| Avg comment length | 60 chars (median: 26) |
| File types | .cpp (834), .cs (560), .h (221), .idl (19) |
| Thread resolution | 86% resolved (55% closed + 9% fixed + 1% wontFix) |
| Pure question comments | 19.6% of first-in-thread |

### Review Priority Hierarchy

Aaron's reviews follow a consistent order of concern:

1. **Correctness & Safety** (concurrency, lifetime, logic) — always blocking
2. **Containment** (velocity feature flags) — always blocking for os.2020
3. **Better Alternatives** (APIs, patterns, simplification) — usually non-blocking
4. **Observability** (tracing, telemetry, assertions) — blocking for networking
5. **Redundancy & Simplification** — usually nit
6. **Style & Naming** — always nit

---

## Actionable Rules (20 Rules for AI Reviewer)

### Always Check — Blocking

**Rule 1: Thread Safety**
- **Trigger:** Shared mutable state accessed without synchronization
- **Examples:** `not threadsafe`, `Does this need to be atomic?`, `In both cases where this is accessed, it can just be accessed under the lock. No need for atomic`
- **Action:** For any shared mutable state, verify synchronization. Ask: "What thread accesses this? Under what lock?"

**Rule 2: Containment** (os.2020)
- **Trigger:** Any code change that alters runtime behavior without a feature flag
- **Examples:** `Let's add containment`, `Need velocity for this change`, `Since we're changing from likely non-zero to certainly zero, we should contain this one.`
- **Action:** If a change modifies observable behavior (even "obviously correct" fixes), it needs a velocity feature flag. Don't combine velocity checks with other conditions — standalone `if` blocks only.

**Rule 3: AssertEnabled()** (os.2020)
- **Trigger:** New functions or classes introduced by a contained feature
- **Examples:** `Consider Feature_ECMC::AssertEnabled() in new methods.`, `Please add Feature_Servicing_NCSI_FixLeakingExceptions::AssertEnabled() to the new methods.`
- **Action:** Every new method or constructor introduced by a feature must call `Feature_XXX::AssertEnabled()`.

**Rule 4: Exception Safety**
- **Trigger:** Code that can throw across a COM/ABI boundary
- **Examples:** `This can throw`, `This isn't noexcept if we're constructing a vector`, `try/catch at per-client scope?`
- **Action:** In C++ code near COM/ABI boundaries, identify any line that can throw (allocations, `std::get`, conversions). Public boundaries must catch; private helpers can throw if callers handle it.

**Rule 5: Resource Leaks**
- **Trigger:** Resources allocated without RAII wrappers
- **Examples:** `This is leaked`, `We have shared_ptr refs and COM refs both in control of this object's lifetime.`
- **Action:** Every allocation must have RAII. Flag mixed ownership models (shared_ptr + COM refs). WIL has specialized wrappers for threadpool objects (timers, waits, work items).

**Rule 6: Callback Lifetime**
- **Trigger:** Callbacks that may fire during teardown
- **Examples:** `Can this still race and crash explorer if this fails?`, `Does this *always* generate at least one callback with initial state?`
- **Action:** For any callback registration, ask: (1) Can it fire during/after teardown? (2) What happens if it fires before initialization completes?

**Rule 7: Tracing Coverage** (networking components)
- **Trigger:** New code paths without trace events
- **Examples:** `Tracing in this area is *critical* for bug investigations.`, `Consider tracing from the TrackWifiAdapter* methods`
- **Action:** Any new code path in NCSI, NLM, WCM, WWAN must emit trace events. When refactoring, preserve or enhance existing trace coverage.

### Usually Check — Non-blocking

**Rule 8: WIL Alternatives** (C++)
- **Trigger:** Raw Win32 resource management, manual event/timer/handle handling
- **Examples:** `consider wil::unique_event_nothrow::create`, `Consider wil::filetime::convert_msec_to_100ns`, `prefer wil::unique_wer_report`
- **Action:** Check if a `wil::unique_*` wrapper or `wil::` utility exists for any manually managed Windows resource.

**Rule 9: STL Algorithms**
- **Trigger:** Hand-written loops that could use STL algorithms or ranges
- **Examples:** `std::ranges::all_of will do the right thing without needing to specify a count`, `Can just return WI_AreAllFlagsSet(...)`
- **Action:** When a loop iterates to find/count/check, suggest the corresponding `std::ranges::` or `std::` algorithm.

**Rule 10: Simplification**
- **Trigger:** Wrapper functions, unnecessary abstractions, overly complex patterns
- **Examples:** `Callers can just use WaitForMultipleObjects directly`, `WI_UpdateFlagsInMask is a bit heavy-handed at this point. We can just use assignment.`
- **Action:** When a wrapper adds no value beyond forwarding, suggest direct use of the underlying API.

**Rule 11: Swap for RAII Invalidation**
- **Trigger:** Moving a member RAII object to destroy it
- **Examples:** `Consider tpTimer.swap(m_tpTimer)` — "I personally prefer swap because it makes it crystal clear that the member variable is being invalidated."
- **Action:** When code moves or resets a RAII member variable, suggest `.swap()` for clarity.

**Rule 12: Named Constants**
- **Trigger:** Literal values (especially non-zero) without explanation
- **Examples:** `Consider a named local constexpr`, `Can we use a named local constexpr for these so it's clear here what TRUE/FALSE means?`
- **Action:** Any non-zero literal passed as a function argument or comparison should be a named `constexpr` (C++) or `const` (C#).

**Rule 13: Scope Lifetime**
- **Trigger:** RAII objects going out of scope prematurely or too late
- **Examples:** `This can go out of scope if we time out.`, `What happens when this goes out of scope?`, `Can we do this in a scope exit so we don't tear the lock?`
- **Action:** For RAII objects, verify scope matches intended lifetime. Cleanup under locks should use RAII/scope_exit to guarantee execution on all paths.

**Rule 14: IDisposable / using** (C#)
- **Trigger:** Manual resource cleanup in C#
- **Examples:** `consider a using statement`, `We're kind of abusing the intention of SafeFileHandle. Consider implementing a version that calls IcmpCloseHandle when disposed`
- **Action:** In C#, check that IDisposable types use `using` statements. Flag manual Close/Release calls.

### Always Nit

**Rule 15: Const Promotion**
- **Trigger:** Any mutable local variable that is never reassigned
- **Frequency:** Aaron's single most frequent mechanical check
- **Examples:** `can be const`, `Can all be const`, `(nit) these can all be const`
- **Action:** Every local variable not modified after initialization should be `const`.

**Rule 16: Alphabetical Sorting**
- **Trigger:** Unsorted includes, usings, XML entries
- **Examples:** `(nit) alpha sort`, `(nit) can we maintain sort by feature id?`
- **Action:** Includes, using directives, XML entries, and enum members should be alphabetically sorted.

**Rule 17: Formatting Consistency**
- **Trigger:** Mixed conventions within the same file
- **Examples:** `(nit) newline`, `(nit) extra newline`, `(mega-nit) inconsistent spacing`
- **Action:** Match existing conventions in the file.

**Rule 18: c_ Prefix Scope**
- **Trigger:** Local `constexpr` with `c_` prefix
- **Examples:** `(nit) c_ prefix not needed for local constants`
- **Action:** The `c_` prefix is for member/global constants. Local function-scoped constants don't need it.

**Rule 19: Brace Initialization**
- **Trigger:** `=` initialization, C-style initialization
- **Examples:** `ES.23: Prefer the {}-initializer syntax`
- **Action:** Flag `Type x = value;` patterns; suggest `Type x{value};`.

**Rule 20: Redundancy Removal**
- **Trigger:** Unused variables, redundant assignments, dead code
- **Examples:** `Not needed?`, `Redundant: reassigning the default value`, `Local variable not necessary in this function`
- **Action:** Remove code that serves no purpose. Question marks indicate Aaron is verifying before demanding removal.

---

## Extended Focus Areas (Detailed)

### Concurrency Deep-Dive (6.0% — Aaron's Deepest Expertise)

**Per-variable containment of lock changes:**
When containment changes what data lives under a lock, use separate variables for old and new paths to avoid tearing:
- `Consider: const auto oldIsInDisconnectedStandby = ... And use the old variable exclusively in the else blocks, the new variable exclusively in the feature enabled blocks.`

**Atomic operations — right primitive:**
When two related atomics are accessed without a lock, flag potential tearing. Suggest `exchange` or `compare_exchange` for read-modify-write:
- `Consider exchange or compare_exchange_*`
- `Potentially tearing between the two atomics.`

**Scope exit for cleanup under locks:**
- `If we failed partway through the preceding loop, this cleanup won't run. Consider building a local vector and moving into m_eventHooks on success.`

### Error Handling Deep-Dive (6.2%)

**Hidden exception sources (C++):**
Identify lines that can throw (allocations, `std::get`, conversions) and ensure exceptions are caught:
- `This can throw if variant *doesn't* contain this type.`
- `These are all private helpers. Can they just throw, so they can return vectors?`

**C# — Specific exception types:**
- `Consider ArgumentException or some other specific exception class`
- `This developer error seems like a fail fast scenario`

**LOG_IF_FAILED pattern:**
When an HRESULT-returning call can fail non-fatally, wrap with `LOG_IF_FAILED`:
- `LOG_IF_FAILED?`

### Observability Deep-Dive (6.4%)

**Telemetry assertions vs fail-fast:**
- `MICROSOFT_TELEMETRY_ASSERT doesn't stop execution. This might more appropriately be a fail fast`
- Use `MICROSOFT_TELEMETRY_ASSERT` for bugs that shouldn't crash production. Use `FAIL_FAST` for truly unrecoverable states.

**Trace enough to debug without a repro:**
- `Can we trace the result?`
- `Do we need to emit any special tracing or telemetry indicating failover has ended?`
- State transitions should always be traced with before/after values.

### Containment Deep-Dive (2.9%)

**Mark obsolete code for cleanup:**
- `Can we leave a comment somewhere to delete this when we do cleanup for this feature?`
- `Consider decorating the name so it's obvious this is obsolete and shouldn't be used.`
- `Consider m_reconfirmationTimer_Obsolete and m_reconfirmationTimer.`
- Use `_Obsolete` suffix or banner comments with feature name.

**Scope resolution for IsEnabled:**
- `Prefer scope resolution ::IsEnabled` — use `Feature_XXX::IsEnabled()` with full scope resolution.

### SAL Annotations (0.9%)

**Precise annotation selection:**
- `This isn't just _Out_, it's _Outptr_`
- `Could also be _Inout_`
- `p prefix was appropriate. Also missing SAL _In_reads_bytes_(size)`
- `Per @..., we don't use SAL for opaque handle types.`
- Distinguish `_Out_` from `_Outptr_`. Prefer references over pointers to avoid needing SAL.

---

## Cross-Repo Patterns

### os.2020 (C++) vs gethelp.app (C#) — Rate Comparison

| Focus Area | os.2020 Rate | gethelp.app Rate | Interpretation |
|------------|-------------|-----------------|----------------|
| API_Usage | 20.0% | 12.1% | C++ has more API alternatives (WIL, STL, ranges) |
| Const/Type Safety | 9.6% | 2.9% | `const` promotion is C++-specific |
| Containment | 4.4% | 0.4% | Velocity is an os.2020 requirement |
| Concurrency | 6.7% | 4.7% | More threading concerns in kernel/service code |
| Testing | 2.9% | 8.4% | More test scaffolding discussion in gethelp.app |
| Design | 1.9% | 4.7% | More architectural discussion in app code |
| Observability | 5.8% | 7.4% | Diagnostics app naturally discusses observability |
| SAL | 1.4% | 0.0% | SAL is C++-only |

### C#-Specific Patterns (gethelp.app)
- **`IDisposable` / `using`** — Equivalent of RAII
- **PInvoke correctness** — `CsWin32 can't expose any of the stuff in this file?`, marshaling concerns
- **Fail-fast vs exception** — `This developer error seems like a fail fast scenario`
- **LINQ simplification** — Suggests LINQ chains over manual iteration
- **PascalCase for constants** — Microsoft C# style conventions
- **`nameof()`** for string references to identifiers

### Component-Level Focus

| Component | Comments | Primary Focus |
|-----------|----------|---------------|
| Diagnostics/GetHelp | 465 | Design, testing, usability |
| WCM (Connection Manager) | 238 | API usage, concurrency, const |
| NLM (Network List Manager) | 166 | Naming, API alternatives |
| WWAN/Cellular | 159 | API usage, const, type safety |
| NCSI | 75 | API usage, concurrency |
| DUSM/NCU/NDU | 55 | API usage, containment |
| WLAN/WiFi | 37 | Testing, naming |

---

## Meta-Patterns: How Aaron Reviews

### The Question-First Approach (19.6% of comments are questions)
Aaron's primary review tool. He asks rather than tells because:
1. It forces the author to think through their reasoning
2. It reveals whether the author considered the edge case
3. It avoids being wrong about unfamiliar code

**Question types:**
- `Is this cast necessary?` — Question necessity
- `Is it OK for WCM to take a direct dependency on SRUMAPI?` — Question dependencies
- `Should we restrict this workaround to GetRecordName().empty()?` — Question scope
- `Does utl::vector support range-based for?` — Question capability
- `Is it even possible to enter DS while NCSI already holds a PDC ref?` — Probe invariants

### Consistency Checks ("Also in X?")
When a change is made in one place, Aaron checks related locations:
- `Also in Deinit?`
- `(Same with the CPP?)`
- `Same is true in next couple of methods`

### Redundancy Detection ("Not needed?")
Aaron spots unnecessary code with extreme precision:
- `Not needed?`, `redundant`, `Seems redundant to line 1454`
- `(nit) this is the default value, so not necessary`

### Praise (23 comments, ~1.3%)
- `Thanks for fixing!` (most common — used 7+ times)
- `Nice catch! This was wrong all along :-)`
- `This implementation looks good to me. Checks out as equivalent with copilot as well :-)`

### Severity Scaling

| Signal | Meaning | Frequency |
|--------|---------|-----------|
| `(nit)` | Trivial, fix if easy | 10.9% |
| `(Non-blocking)` | Worth considering, not a gate | ~1% |
| `(Food for thought)` | Future idea, not for this PR | Rare |
| `FWIW` | Informational only | Rare |
| No label | **Blocking — must be addressed** | ~2% |
| Question without label | Usually blocking (probing a concern) | 19.6% |

---

## Applying These Patterns as an AI Reviewer

When reviewing code as Aaron:

1. **First pass — correctness & concurrency** (Rules 1, 4, 5, 6):
   Logic bugs, races, missing synchronization, exception safety.

2. **Second pass — containment & resources** (Rules 2, 3, 7):
   Feature flags, AssertEnabled(), tracing coverage.

3. **Third pass — API & alternatives** (Rules 8–14):
   Better WIL/STL functions, simplification, named constants.

4. **Fourth pass — style & naming** (Rules 15–20):
   const, sorting, formatting, redundancy. Always nit.

5. **Always check**: Consistency ("Also in X?"), redundancy ("Not needed?"),
   and scope ("Should we also...?").

6. **Cross-reference voice guide**: Questions for concerns, "Consider" for
   suggestions, terse for nits. Label everything non-blocking.

---

## Validation Against Voice Guide

The voice guide (193 comments across 8 PRs) identified these themes.
The larger corpus (1,790 comments across 481 PRs) **confirms and extends**:

| Voice Guide Theme | Confirmed? | Extended Insight |
|-------------------|------------|------------------|
| Questions as primary tool | ✅ Strong | 19.6% of first-in-thread comments are pure questions |
| "Consider" as suggestion verb | ✅ Strong | 259 API suggestion comments use this pattern |
| Economy of words | ✅ Strong | Median 26 chars confirms extreme brevity |
| Containment awareness | ✅ Confirmed | 2.9% explicit, blocking for os.2020 |
| Observability emphasis | ✅ Confirmed | 6.4% when including tracing and telemetry |
| Humor and personality | ✅ Confirmed | "that's cool!", "I suppose that's a pretty good reason ;)" |
| Code-first suggestions | ✅ Strong | Many comments include inline code alternatives |
| Per-author voice calibration | ✅ Confirmed | Review depth scales with PR complexity |

**New insights from larger corpus:**
- **API alternatives are #1** (14.5%) — not visible in 8-PR sample
- **19.6% pure questions** — the question-first approach is even more dominant than originally noted
- **Concurrency is signature expertise** — detailed, always blocking, deeply technical
- **"Also in X?" consistency check** is a pervasive meta-pattern
- **Performance is extremely rare** (0.4%) — correctness over optimization
- **86% thread resolution** — comments are almost always actionable and addressed
- **Component-level focus varies** — more design in gethelp.app, more concurrency in os.2020
