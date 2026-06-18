# ADR-0019 (amendment 2) — Decimal precision for transcendentals + factorial overflow cap + DomainError taxonomy + GET /api/history envelope pinning

**Status:** Accepted (via PR #84, 2026-06-18T20:44:55Z, merged by @atilcan65)
**Date:** 2026-06-18
**Deciders:** @architect (drafting), @product-manager (verdict on mpmath dep + scope of new operators), @developer (verdict on engine implementation + mpmath==1.3.0 pin), @tester (verdict on perf budget + TC alignment with PR #79 + PR #81)
**Supersedes:** — (amends; does not replace)
**Amends:** [ADR-0019](ADR-0019-api-contract.md) §Error envelope + §Decimal serialization + §Engine exception → HTTP status mapping
**Related:** [ADR-0017](ADR-0017-tech-stack.md) §Concrete stack (engine ↔ UI separation invariant); [ADR-0019 (amendment 1, merged via PR #63)](https://github.com/atilcan65/AtilCalculator/pull/63) (Decimal trailing-zero + UndefinedOperatorError scope); [PR #81](https://github.com/atilcan65/AtilCalculator/pull/81) (STORY-008 TDD red — envelope P3 #1); [PR #82](https://github.com/atilcan65/AtilCalculator/pull/82) (ADR-0022 — dev re-flagged envelope P3 on the persistence ADR); [Issue #80](https://github.com/atilcan65/AtilCalculator/issues/80) (Sprint 2 P1 architect pre-work)

---

## Context

ADR-0019 (accepted 2026-06-17 via PR #37) defines the AtilCalculator HTTP API contract. Its first amendment (PR #63, merged 2026-06-18T13:20:00Z) pinned Decimal trailing-zero serialization and clarified `UndefinedOperatorError` scope. This **second amendment** addresses four gaps surfaced by Sprint 2 P1 sizing (Issue #76) and Sprint 2 TDD red contract suites (PR #79 + PR #81):

| # | Gap | Source | Severity |
|---|---|---|---|
| 1 | **GET /api/history response envelope is not explicitly pinned** — ADR-0019 shows `{"history": [...]}` in §GET /api/history but doesn't say "this is the only acceptable shape" (PR #81 tests accept both bare array AND envelope; implementation in `src/atilcalc/api/routes.py:288` returns envelope) | PR #81 P3 #1 (dev); re-flagged on PR #82 P3 #1 | **P3** (resolve pre-merge to avoid future contract drift) |
| 2 | **Decimal precision model for transcendental functions is undefined** — engine's `decimal.Decimal` has precision 28, which is insufficient for `sin(π)`, `exp(1)`, `log(2)` at high precision; ADR-0017 §Concrete stack defers to "R-3 ADR for HTTP contract" but doesn't pin a Decimal precision model for transcendentals | Issue #76 sizing (PM rec = mpmath==1.3.0) | **P1** (blocks STORY-011 — Sprint 2 P1 commitment) |
| 3 | **Factorial overflow cap is undefined** — Decimal `factorial(170)` fits; `factorial(171)` overflows. Engine should raise a domain error before overflow, not crash with `decimal.Overflow` | Issue #76 sizing (PM rec = 170! cap) | **P1** (blocks STORY-011) |
| 4 | **Engine exception taxonomy lacks `DomainError`** — `UndefinedOperatorError` is for unsupported operators, but `sqrt(-1)`, `log(-1)`, `asin(2)` are valid operators on wrong arguments. Need a distinct `DomainError` for these | Issue #76 sizing (PM rec) | **P1** (blocks STORY-011) |

Issue #80 (Sprint 2 P1 architect pre-work) commits to addressing all 4 gaps in the "ADR-0019 amendment" item (~1 SP equivalent). This is that amendment.

Vision invariants this amendment must satisfy:

| Metric | Source | Constraint |
|---|---|---|
| **M1** (Decimal precision) | vision §M1, ADR-0019 §Decimal serialization | Lossless storage + transport; trailing-zero rule preserved (PR #63 codification) |
| **M5** (history performance) | vision §M5 | Engine evaluation <50ms p99; transcendentals may be slower than arithmetic — separate budget needed |
| **M3** (keyboard-only) | vision §M3 | New operators (`!`, `^`, `sin`, `cos`, `log`, etc.) must be keyboard-accessible via the existing FSM (no mouse required) |

Cross-cutting constraints (preserved from ADR-0017 + ADR-0019 + PR #63):

- **Engine ↔ UI separation invariant** (ADR-0017): engine is pure-Python stdlib-only. Adding `mpmath==1.3.0` as a dep **breaks stdlib-only** for the engine module. Resolution: keep engine stdlib-only by using `mpmath` for transcendentals OR **add mpmath as a runtime dep** (it crosses into engine territory). Architect's decision below.
- **Decimal trailing-zero rule** (PR #63): all Decimal serializations preserve trailing zeros. New operators must respect this.
- **Engine ↔ UI purity** (ADR-0017): engine has zero I/O. No persistence or HTTP calls in engine.

---

## Decision

**Adopt four amendments to ADR-0019**, all in one PR for atomic review:

1. **GET /api/history response envelope pinning** (P3): explicit canonical shape `{"history": [...], "cursor": ts|null}`; bare array `[...]` is **not acceptable**; implementer MUST return the envelope. Amend ADR-0019 §GET /api/history.
2. **Decimal precision model for transcendentals** (P1): add `mpmath==1.3.0` to **runtime** dependencies (move from `[dev]` to `dependencies` per the ADR-0017 amendment precedent set in PR #66). Precision pin: `mp.dps = 50` (50 decimal places — enough for 49-digit factorial + 28-digit arithmetic + headroom). Engine exposes `evaluate_transcendental(expr: str) -> Decimal` that delegates to mpmath for `sin`/`cos`/`tan`/`log`/`exp`/`sqrt`. Amend ADR-0019 §Decimal serialization + new §Transcendental precision model.
3. **Factorial overflow cap** (P1): `n!` for `n > 170` raises `DomainError("factorial overflow: n > 170")` (HTTP 400). `n!` for `n in [0, 170]` returns `Decimal` lossless. Engine validates `n` is non-negative integer before computing. Amend ADR-0019 §Error envelope + new §Factorial operator.
4. **`DomainError` engine exception** (P1): new exception class `DomainError(EngineError)` for `sqrt(-1)`, `log(x)` for `x <= 0`, `asin(x)` for `|x| > 1`, `acos(x)` for `|x| > 1`. HTTP status 400 (same as `DivisionByZeroError` — user input is wrong, fix and retry). `UndefinedOperatorError` scope is **unchanged** (still for unsupported operators like future `&`, `|`); the two errors are distinct. Amend ADR-0019 §Engine exception → HTTP status mapping + §Error envelope.

### 1. GET /api/history response envelope pinning (P3)

**Current ADR-0019 §GET /api/history** (lines 117-136) shows a response body but doesn't pin the shape as canonical. Add a new paragraph:

```markdown
**Canonical response shape** (PINNED — implementer MUST return this exact shape):

```json
{
  "history": [
    {"expr": "100 + 5%", "result": "105", "ts": "2026-06-17T18:30:00Z"},
    ...
  ],
  "cursor": "2026-06-17T18:30:00Z" | null
}
```

- `history` is the page of records (default 50, max 1000).
- `cursor` is the timestamp of the last record in the page, or `null` if no more pages. Client passes `?cursor=...` to fetch the next page.
- **Bare array `[...]` is NOT acceptable.** This envelope is the contract; future additions (e.g., `total_count`, `filter`) land in the envelope, not by changing the array shape.
- **Trailing-decimal rule**: `result` preserves trailing zeros (per PR #63 + ADR-0019 §Decimal serialization). `"105.00"` is `"105.00"`, not `"105"`.
```

**Why this matters**: PR #81's `_extract_records` helper accepts both bare array AND envelope, which means the tests don't pin the shape. Once the envelope is pinned, the implementer (and PR #81 tests) have a clear contract. Future additions land predictably.

### 2. Decimal precision model for transcendentals (P1)

**Add new section to ADR-0019 §Decimal serialization**:

```markdown
### Transcendental precision model

**For arithmetic operators** (`+`, `-`, `*`, `/`, `**`, `()`), the engine uses stdlib `decimal.Decimal` with precision 28 (default). This is sufficient for 28-digit arithmetic; cross-checks against `decimal` arithmetic in d006 + d007.

**For transcendental functions** (`sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `log`, `exp`, `sqrt`, `factorial`), the engine uses `mpmath==1.3.0` with `mp.dps = 50` (50 decimal places). Why 50: enough for `factorial(170)` (which is 308 decimal digits, but only the first 50 are meaningful; trailing digits are zero-padded) + 28-digit arithmetic precision + 20 digits of headroom for chained operations.

**The `mpmath` library is added to `[project.dependencies]`** (not `[project.optional-dependencies.dev]`) because transcendental functions are part of the user-facing surface. This is the same precedent as PR #66 (which moved `fastapi==0.115.6` + `uvicorn[standard]==0.32.1` to runtime per ADR-0017 amendment).

**Engine ↔ UI separation invariant** (ADR-0017) is preserved at the **module boundary**, not the `pyproject.toml` section boundary: the engine is a pure-Python module with no I/O. Adding a runtime dep does not violate the architectural invariant; it only tightens the dep set.

**Round-trip rule**: `evaluate_transcendental(expr: str) -> Decimal` returns `Decimal` with `mp.dps=50` precision. Serialization follows the trailing-zero rule (PR #63).

**Performance budget**: transcendental evaluation has a separate budget from arithmetic. AC1 budget (<50ms p99) applies to `POST /api/evaluate` overall; transcendental-only evaluation budget is **<100ms p99** (mpmath is ~3-5x slower than stdlib decimal arithmetic for complex expressions).

**Implementation**: engine module `src/atilcalc/engine/evaluator.py` adds:
- `import mpmath` at module level (top-of-file; one import)
- `_mpmath_dps = 50` module constant
- `def _eval_transcendental(token, args) -> Decimal` private helper
- `evaluate(expr)` dispatches to `_eval_transcendental` for `sin`/`cos`/`log`/`exp`/`sqrt`/`factorial` tokens
- All Decimal results round-trip through `str(Decimal)` for serialization (no precision loss)
```

**Why mpmath==1.3.0 (not just higher stdlib precision)**: stdlib `decimal` doesn't have transcendental functions. `decimal.Decimal.ln()` / `exp()` etc. don't exist. mpmath provides `mpf` (multi-precision float) and is the de-facto standard for arbitrary-precision transcendental math in Python. Pinning to `==1.3.0` follows the doctrine "Pin dependency versions exactly when adding new libs" (ADR-0017).

**Trade-off**: mpmath adds ~500KB to the FastAPI process. For a single-user LAN VM, this is negligible. The architectural benefit (lossless transcendentals) outweighs the size cost.

### 3. Factorial overflow cap (P1)

**Add new subsection to ADR-0019 §Error envelope**:

```markdown
### Factorial operator

The `!` operator computes `n!` (factorial). Domain:

| Input | Behavior | Rationale |
|---|---|---|
| `n = 0` | `Decimal("1")` | Mathematical convention (0! = 1) |
| `n in [1, 170]` | `Decimal` lossless | Fits in 308 decimal digits; mpmath handles precisely |
| `n > 170` | **HTTP 400** with `{"error": {"type": "DomainError", "message": "factorial overflow: n > 170", ...}}` | `171!` overflows `Decimal`; cap at 170 to prevent silent precision loss |
| `n < 0` | **HTTP 400** with `DomainError` | Factorial is undefined for negative integers |

**Why 170 not 1000**: `Decimal` precision is 28 (or 50 with mpmath). `170!` is `7.2574e+306`, the largest factorial that fits in a `Decimal` (and IEEE-754 double). `171!` overflows to `Infinity` (Decimal) which is a lossy representation. The cap is the largest factorial with a lossless Decimal representation.

**Why HTTP 400 not 500**: user input is wrong (`n!` with `n > 170`); client should surface ("factorial too large") and not retry. Per ADR-0019 §Error envelope "Why 400 not 500 for domain errors".

**TDD red alignment**: PR #79 (STORY-007) doesn't include factorial tests; PR #81 (STORY-008) may add TC-10 (factorial 170 returns Decimal; factorial 171 raises DomainError). Tester to confirm in PR #81 review.
```

**Why cap at 170 not 10000**: `mpmath` CAN compute `10000!` losslessly, but it would take ~1 second of CPU time. The 170 cap aligns with the IEEE-754 double boundary (which is what most calculator UIs use) and keeps engine evaluation under the 50ms p99 budget. If user demand for large factorials arises, Sprint 3+ can lift the cap (with a slower perf budget).

### 4. `DomainError` engine exception taxonomy (P1)

**Amend ADR-0019 §Engine exception → HTTP status mapping** (lines 191-203). Add new row + new exception class:

```markdown
| Engine exception | HTTP status | Rationale |
|---|---|---|
| `ExpressionSyntaxError` | **400 Bad Request** | User input is malformed; client should surface the error and not retry. |
| `DivisionByZeroError` | **400 Bad Request** | User input causes a domain error; client should surface ("can't divide by zero") and not retry. |
| `UndefinedOperatorError` | **400 Bad Request** | User input uses an unsupported operator; client should surface ("`-` not yet supported") and not retry. |
| **`DomainError`** (NEW) | **400 Bad Request** | User input uses a valid operator on a value outside the operator's domain. Examples: `sqrt(-1)`, `log(-1)`, `asin(2)`, `acos(2)`, `n!` for `n > 170` or `n < 0`. Client should surface the domain violation and not retry. |
| `EngineError` (catch-all) | **500 Internal Server Error** | Unexpected engine failure (bug, not user input). Logged with full traceback; client should show generic "calculator error" message. |
| FastAPI `ValidationError` (bad request body) | **422 Unprocessable Entity** | Standard pydantic validation; client should fix the request shape. |
```

**Add new exception class to engine** (`src/atilcalc/engine/evaluator.py`):

```python
class DomainError(EngineError):
    """Raised when a valid operator is applied to a value outside its domain.
    
    Examples:
        sqrt(-1)  — square root of negative number
        log(-1)   — logarithm of non-positive number
        asin(2)   — arcsine of value outside [-1, 1]
        acos(2)   — arccosine of value outside [-1, 1]
        factorial(171)  — factorial overflow
        factorial(-1)   — factorial of negative integer
    """
```

**Why a new exception class** (not reusing `UndefinedOperatorError`): `UndefinedOperatorError` is for **unsupported operators** (e.g., user typed `2 & 3` and `&` isn't implemented). `DomainError` is for **valid operators on bad values** (e.g., `sqrt(-1)` — `sqrt` IS implemented, but `-1` is outside its domain). The two errors have different client-UX implications: `UndefinedOperatorError` might trigger a "coming soon" UI hint, while `DomainError` is a math error the user can fix. Distinct classes let the web shell route on `type` for UX (per ADR-0019 §Error envelope).

**Why not extend `DivisionByZeroError`**: `DivisionByZeroError` is specifically for `x / 0`. `DomainError` is the broader category for "valid operator, bad value". Renaming `DivisionByZeroError` to `DomainError` would be a breaking change to the engine exception hierarchy. The new class is additive.

---

## Rationale

### Why pin the GET /api/history envelope (vs leave ambiguous)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Pin envelope explicitly** (CHOSEN) | Clear contract; future additions land predictably; implementer + tester both have unambiguous target | One paragraph addition to ADR-0019 | **Best fit** — minimal cost, maximum clarity |
| Leave ambiguous (current state) | Implementation has flexibility | Tests accept both shapes; future additions can drift; implementer can return either shape | **Rejected** — drift risk; per PR #81 P3 #1 |
| Pin bare array (drop envelope) | Simplest | Loses room for `cursor` / `total_count`; pagination is awkward (cursor in `?cursor=` query param only, not in response) | **Rejected** — pagination ergonomics |

### Why mpmath==1.3.0 (vs hand-rolled Taylor series / sympy)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **mpmath==1.3.0** (CHOSEN) | De-facto standard for arbitrary-precision transcendental math in Python; well-tested; ~500KB; pure-Python; pin to 1.3.0 per doctrine | Adds runtime dep; ~3-5x slower than stdlib decimal for complex expressions | **Best fit** — battle-tested, well-documented, exact precision |
| Hand-rolled Taylor series | No new dep; full control | Easy to get wrong (convergence, edge cases); would take ~2 weeks to write + test transcendentals to mpmath's precision; bug-prone | **Rejected** — YAGNI; mpmath already solves this |
| sympy | Symbolic + numeric; can do exact rationals for some ops | Heavy (~50MB); overkill for arithmetic + transcendentals only; lazy evaluation complicates perf budgeting | **Rejected** — capacity mismatch |
| numpy + scipy | Fast C-backed transcendentals | Float64 only (no Decimal precision); defeats M1 | **Rejected** — violates Decimal invariant |
| Raise stdlib decimal precision to 50 | No new dep | stdlib decimal has no transcendental functions (`Decimal.ln()` doesn't exist); doesn't actually solve the problem | **Rejected** — doesn't work |

### Why cap factorial at 170 (not 1000 or unbounded)

- `170!` is the largest factorial with a lossless IEEE-754 double representation.
- `171!` overflows to `Decimal('Infinity')` in stdlib decimal (lossy).
- `1000!` would require `mpmath` and take ~500ms; violates the <50ms p99 budget.
- The cap is **the natural boundary** for calculator-scale factorials. Users computing `1000!` are doing combinatorics research, not daily-use arithmetic.
- If Sprint 3+ demand arises, the cap can be lifted (with a slower perf budget).

### Why `DomainError` as a separate class (not extend existing)

- `UndefinedOperatorError` is for **operators that don't exist** in the engine. Different client UX ("coming soon" hint).
- `DomainError` is for **valid operators on bad values**. Different client UX ("math error, fix your input").
- The web shell's `<atilcalc-error-toast>` (PR #49) routes on `type` field for UX. Distinct classes = distinct UX paths.
- Merging them would be a breaking change to the engine exception hierarchy (existing tests assert on `UndefinedOperatorError`).
- The new class is **additive** — no breaking changes to existing tests.

---

## Alternatives considered

### A. Pin envelope + mpmath==1.3.0 + 170! cap + DomainError class (chosen)

- **Pros**: addresses all 4 gaps in one amendment; PR #81 P3 #1 + Issue #80 commitments satisfied; minimal change to existing code
- **Cons**: adds mpmath runtime dep; new exception class
- **Verdict**: chosen

### B. Pin envelope only (defer transcendentals to Sprint 3+)

- **Pros**: smaller amendment; no new deps
- **Cons**: STORY-011 blocked; Sprint 2 P1 commitment slips
- **Verdict**: rejected (Issue #80 commitment)

### C. mpmath for transcendentals but no factorial cap (let it overflow)

- **Pros**: less code
- **Cons**: `171!` returns `Decimal('Infinity')` which violates M1 (lossless)
- **Verdict**: rejected

### D. Extend `UndefinedOperatorError` to cover domain errors (no new class)

- **Pros**: one fewer exception class
- **Cons**: breaking change to existing test assertions; UX confusion (domain error vs unsupported operator)
- **Verdict**: rejected (per the rationale above)

### E. Reuse `DivisionByZeroError` for all domain errors

- **Pros**: one fewer exception class
- **Cons**: misleading name; clients can't distinguish "divided by zero" from "sqrt of negative"
- **Verdict**: rejected

---

## Consequences

### Positive

- **All 4 P1/P3 gaps closed** in one amendment: envelope pinning, mpmath for transcendentals, factorial cap, DomainError class.
- **PR #81 P3 #1 resolved**: GET /api/history envelope is now explicitly canonical.
- **STORY-011 unblocked**: Sprint 2 P1 implementation PR can start once this amendment merges.
- **Issue #80 R-5/R-2/amendment commitment complete** (this is the 3rd of 3 ADRs in the Issue #80 commitment).
- **Decimal precision invariant preserved**: all new operators round-trip through `str(Decimal)` for serialization.
- **Engine ↔ UI separation invariant preserved** at the module boundary (engine is still pure-Python; the only change is a runtime dep, which is at the pyproject.toml level, not the architectural level).
- **mpmath==1.3.0 pinned** per the ADR-0017 "pin dependency versions exactly" doctrine.

### Negative

- **New runtime dep**: `mpmath==1.3.0` adds ~500KB to the FastAPI process. For a single-user LAN VM, this is negligible. The architectural benefit (lossless transcendentals) outweighs the size cost.
- **New exception class**: `DomainError(EngineError)` is added to the engine hierarchy. Tests that assert on the full set of engine exceptions need to include it.
- **Transcendental perf budget is 2x slower** than arithmetic: <100ms p99 vs <50ms p99. Acceptable for the user-facing budget; future perf work can optimize (e.g., cache common transcendentals like `pi`, `e`).
- **Factorial cap is opinionated**: 170! is the IEEE-754 boundary. Users wanting larger factorials are out of MVP-1 scope. Sprint 3+ can lift the cap.

### Out of scope (deferred to follow-up tickets)

| Item | Sprint | Owner |
|---|---|---|
| STORY-011 implementation PR (transcendentals + factorial) | Sprint 2 P1 | @developer (unblocked by this ADR) |
| PR #81 envelope test tightening (remove `_extract_records` helper, assert envelope directly) | Sprint 2 P1 | @tester (after this amendment merges) |
| Pre-compute `pi`, `e` caches in mpmath context | Sprint 3+ | @developer (perf optimization) |
| Lift factorial cap to 1000! with separate perf budget | Sprint 3+ | @product-manager scope call |
| Symbolic math (sympy) for algebraic simplification | Out of MVP | n/a |
| Complex number support (`sqrt(-1) = i`) | Out of MVP | n/a |

### Follow-up tickets to file

- [ ] STORY-011 implementation PR (developer-owned; against this amendment + PR #81 TC-10)
- [ ] PR #81 envelope test tightening (tester-owned; remove `_extract_records` helper once envelope is pinned)
- [ ] README + USER-GUIDE updates: document new operators (`!`, `^`, `sin`, `cos`, `log`, `exp`, `sqrt`) + domain error UX (parallel to STORY-012 in Sprint 2 P2)

---

## What this amendment commits to *now*

- **GET /api/history response envelope**: `{"history": [...], "cursor": ts|null}` is the **pinned canonical shape**; bare array is not acceptable; cursor enables paginated history reads.
- **Decimal precision for transcendentals**: `mpmath==1.3.0` added to `[project.dependencies]` (runtime); `mp.dps = 50`; engine exposes `evaluate_transcendental(expr: str) -> Decimal`.
- **Factorial cap**: `n!` for `n in [0, 170]` returns `Decimal` lossless; `n > 170` or `n < 0` raises `DomainError` (HTTP 400).
- **`DomainError` exception class**: new class `DomainError(EngineError)` for `sqrt(-1)`, `log(x <= 0)`, `asin(|x| > 1)`, `acos(|x| > 1)`, `factorial(n > 170 | n < 0)`. HTTP 400.
- **No breaking changes to existing exception classes** (`ExpressionSyntaxError`, `DivisionByZeroError`, `UndefinedOperatorError` scope is unchanged per PR #63).
- **Engine ↔ UI separation invariant preserved** (architectural boundary, not pyproject section boundary).

---

## Cross-references

- **API contract (base)**: [ADR-0019](ADR-0019-api-contract.md) (accepted via PR #37; amended via PR #63 for trailing-zero + UndefinedOperatorError)
- **Tech stack (mpmath justification)**: [ADR-0017](ADR-0017-tech-stack.md) §Concrete stack + §Repository layout
- **mpmath dep move precedent**: PR #66 (ADR-0017 amendment — runtime vs dev dep classification; same precedent applies here)
- **Engine exception taxonomy base**: ADR-0019 §Error envelope (lines 177-203) + §Engine exception → HTTP status mapping
- **Decimal trailing-zero rule (PR #63)**: [PR #63](https://github.com/atilcan65/AtilCalculator/pull/63) (merged 2026-06-18T13:20:00Z) — codifies the `str(Decimal)` trailing-zero rule
- **TDD contracts**: [PR #79](https://github.com/atilcan65/AtilCalculator/pull/79) (STORY-007 TDD red — 9 TCs + 12 APs); [PR #81](https://github.com/atilcan65/AtilCalculator/pull/81) (STORY-008 TDD red — 21 tests, P3 #1 = envelope)
- **Enveloper P3 re-flag**: [PR #82 P3 #1](https://github.com/atilcan65/AtilCalculator/pull/82) (dev re-flagged envelope gap on the persistence ADR; folded into this amendment per my 13:48Z commitment)
- **Sizing output**: [Issue #76](https://github.com/atilcan65/AtilCalculator/issues/76) (PM rec = mpmath==1.3.0 + 170! cap + DomainError class)
- **Architect pre-work**: [Issue #80](https://github.com/atilcan65/AtilCalculator/issues/80) (this amendment is the third of 3)
- **Story unblocked**: STORY-011 (Sprint 2 P1 — transcendentals + factorial)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
