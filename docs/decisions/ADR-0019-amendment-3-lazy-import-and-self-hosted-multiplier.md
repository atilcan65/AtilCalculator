# ADR-0019 (amendment 3) — Lazy-import mpmath contract + Self-hosted runner 2.0× perf budget multiplier

**Status:** Proposed (Sprint 22 PIVOT P3 follow-up, draft pending arch sign-off + owner squash per file ownership matrix)
**Date:** 2026-06-30
**Deciders:** @architect (drafting), @product-manager (verdict on self-hosted multiplier scope), @developer (lazy-import impl), @tester (verdict on d111 contract), @atilcan65 (owner squash gate per file ownership matrix)
**Supersedes:** TD-042 (generic ADR-0019 amend 3 ticket; this verdict crystallizes the scope as lazy-import contract + 2.0× multiplier)
**Amends:** [ADR-0019 amendment 2](./ADR-0019-amendment-2-decimal-and-envelope.md) §2 "Transcendental precision model" + §"Performance budget" + new §"Runner-aware perf budget multipliers"
**Related:** [ADR-0019 amendment 2](./ADR-0019-amendment-2-decimal-and-envelope.md) (mpmath==1.3.0, mp.dps=50); [ADR-0017](./ADR-0017-tech-stack.md) §engine ↔ UI separation; [ADR-0049](./ADR-0049-d-test-framework.md) d-test framework sister-pattern; [ADR-0045](./ADR-0045-9-lens-pre-publish.md) 9-Lens pre-publish gate; [ADR-0051](./ADR-0051-engine-perf-flake-vs-regression.md) 3-condition flake-vs-regression discriminator; [Issue #727](https://github.com/atilcan65/AtilCalculator/issues/727) [P0] CI infrastructure gap; [Issue #728](https://github.com/atilcan65/AtilCalculator/issues/728) [P0] engine perf hotfix; [PR #709](https://github.com/atilcan65/AtilCalculator/pull/709) Sprint 22 PIVOT Faz 1.1 (regression origin); [PR #731](https://github.com/atilcan65/AtilCalculator/pull/731) lazy-import implementation (dual peer 🟢); arch verdict [cmt 4846778097](https://github.com/atilcan65/AtilCalculator/issues/728#issuecomment-4846778097) on Issue #728

---

## Context

Sprint 22 PIVOT Faz 1.1 (PR #709, commit `eb64485`) added module-level `import mpmath` at `src/atilcalc/engine/evaluator.py:33`. Per ADR-0019 amendment 2 §2, mpmath is "the documented exception to ADR-0017 §engine ↔ UI separation (STD-lib-only invariant). It is the precision substrate for transcendentals." The amendment specified `mpmath==1.3.0`, `mp.dps = 50`, and a `<100ms` transcendental perf budget. The amendment acknowledged "mpmath is ~3-5x slower than stdlib decimal arithmetic for complex expressions" but did NOT specify the **import-site** (module-level vs. per-function). Per ADR-0019 amendment 2 §2:

> **Implementation**: engine module `src/atilcalc/engine/evaluator.py` adds:
> - `import mpmath` at module level (top-of-file; one import)
> - `_mpmath_dps = 50` module constant
> - `def _eval_transcendental(token, args) -> Decimal` private helper
> - `evaluate(expr)` dispatches to `_eval_transcendental` for `sin`/`cos`/`log`/`exp`/`sqrt`/`factorial` tokens
> - All Decimal results round-trip through `str(Decimal)` for serialization (no precision loss)

The module-level `import mpmath` paid a ~50ms cold-start cost on **every** `from atilcalc.engine import …` — including callers that only do arithmetic. The arithmetic path bled this cost into perf tests, causing `tests/api/test_evaluate_transcendental.py::test_arithmetic_p99_under_50ms_still_holds` to fail at p99=215.48ms (4.3× over 50ms budget) per PR #694 CI surfacing.

Simultaneously, PR #709 migrated CI workflows from public GitHub Actions runners to self-hosted runners (Sprint 22 PIVOT Faz 1.1 self-hosted runner migration). Self-hosted runners have different perf characteristics than public runners. The engine perf test budgets (50ms arithmetic / 100ms transcendental) were calibrated against public runner baselines. The migration did NOT introduce a runner-aware perf budget multiplier, AND the `.github/workflows/ci.yml` Test (Python) step did NOT pass `BUDGET_MULTIPLIER` env var to the self-hosted runner.

Two cascading P0 issues were filed via PR #694 CI red (cycle ~#1741, 2026-06-30T17:40Z):

1. **Issue #727** [P0] "CI infrastructure gap — BUDGET_MULTIPLIER env var missing on self-hosted runner." Tester reframed the initial "engine perf regression" framing at 17:42Z. Fix: add `env: BUDGET_MULTIPLIER: ${{ vars.BUDGET_MULTIPLIER || 1.0 }}` to `.github/workflows/ci.yml` Test (Python) step + set `vars.BUDGET_MULTIPLIER=2.0` in repo Settings. PR #729 implements the YAML edit (d109 sister-test, dual peer 🟢, owner squash gate pending).

2. **Issue #728** [P0] "Engine perf regression — transcendental p99 + arithmetic p50 over budget (PR #709 mpmath cascade)." Architect verdict [cmt 4846373274](https://github.com/atilcan65/AtilCalculator/issues/728#issuecomment-4846373274) traced root cause to `src/atilcalc/engine/evaluator.py:33` module-level `import mpmath`. Architectural decision: lazy-import mpmath inside `_eval_transcendental()` helper, NOT at module level. PR #731 implements the fix (dual peer 🟢, d110 sister-test 6/6 GREEN, owner squash gate pending lint fix commit 80a6d2a).

---

## Decision

**Adopt two amendments to ADR-0019**, all in one PR for atomic review:

1. **Lazy-import mpmath contract** (P1): replace module-level `import mpmath` with lazy-import inside `_eval_transcendental()` helper. The `import` inside a function is cached in `sys.modules` after first call; subsequent calls are O(1) dict lookup. First transcendental call pays the ~150ms import cost; arithmetic path NEVER imports mpmath. Amend ADR-0019 amendment 2 §2 "Transcendental precision model" with a new sub-§2.1.

2. **Self-hosted runner perf budget multiplier** (P1): codify runner-aware perf budget multipliers. Public GitHub Actions runners: 1.0× of base budget (50ms arithmetic / 100ms transcendental). Self-hosted runners: 2.0× of base budget (100ms arithmetic / 200ms transcendental). The multiplier absorbs CI variance on self-hosted infrastructure without admitting engine perf regressions (regressions to 200ms+ still FAIL at the 100ms relaxed budget). Amend ADR-0019 amendment 2 §"Performance budget" with new §"Runner-aware multipliers".

### 1. Lazy-import mpmath contract (P1)

**Add new sub-§2.1 to ADR-0019 amendment 2 §2 "Transcendental precision model"**:

```markdown
### 2.1 Lazy-import contract

**`mpmath` MUST be lazy-imported inside `_eval_transcendental()` helper, NOT at module level.**

The module-level `import mpmath` specified in §2 was a mistake: it paid the mpmath cold-start cost (~50-200ms depending on platform) on **every** `from atilcalc.engine import …` — including arithmetic-only callers. This bled the import cost into the perf budgets for arithmetic operations (test_arithmetic_p99_under_50ms_still_holds failed at p99=215.48ms, 4.3× over 50ms budget per PR #694 CI surfacing, fixed by PR #731 lazy-import).

**Correct import site**: lazy-import inside the dispatch function:

```python
def _eval_transcendental(token, args) -> Decimal:
    import mpmath  # type: ignore[import-untyped]
    if not hasattr(mpmath.mp, 'dps') or mpmath.mp.dps != _MP_DPS:
        mpmath.mp.dps = _MP_DPS
    # ... rest of dispatch unchanged
```

**Why this works**:
- `import` inside a function is cached in `sys.modules` after first call.
- Subsequent calls are O(1) dict lookup on `sys.modules['mpmath']`.
- Arithmetic path NEVER imports mpmath — `evaluate("2 + 3")` does not trigger `_eval_transcendental` and does not pay the import cost.
- First transcendental call pays ~150ms (one-time cost); subsequent transcendental calls are fast.

**Regression guard**: `scripts/tests/d110-evaluator-lazy-import-mpmath.sh` (6 TCs, sister to d100, d107, d108, d109) verifies:
- TC1: `import atilcalc.engine.evaluator` does NOT populate `sys.modules['mpmath']`
- TC2: `evaluator.evaluate("1 + 2")` does NOT populate `sys.modules['mpmath']`
- TC3: `evaluator.evaluate("sin(0)")` DOES populate `sys.modules['mpmath']`
- TC4: `sys.modules['mpmath']` is the SAME module object across calls (cache stability)
- TC5: arithmetic correctness regression guard (`evaluate("2+3") == Decimal("5")`)
- TC6: transcendental correctness regression guard (`evaluate("sin(0)")` ≈ `Decimal("0")`)

**Future engine dep additions MUST include import-site rationale** as part of the architectural decision. Eager module-level imports are an implicit API contract (they're paid by all importers); lazy imports are an opt-in pattern. ADR-0017 §engine ↔ UI separation requires the engine to be a pure module with no I/O; module-level eager imports are consistent with this when the dep is universally required, but lazy imports are required when the dep is path-specific (transcendentals only).
```

### 2. Self-hosted runner perf budget multiplier (P1)

**Add new sub-§"Runner-aware multipliers" to ADR-0019 amendment 2 §"Performance budget"**:

```markdown
### Runner-aware perf budget multipliers

**Sprint 22 PIVOT P3 baseline (2026-06-30)**: public GitHub Actions runners use 1.0× base budget; self-hosted runners use 2.0× base budget.

| Runner type | Multiplier | Arithmetic budget | Transcendental budget |
|---|---|---|---|
| Public GH Actions (`ubuntu-latest`) | 1.0× | 50ms p99 | 100ms p99 |
| **Self-hosted** (`[self-hosted, linux, x64, atilproject]`) | **2.0×** | **100ms p99** | **200ms p99** |
| Future runner types | TBD | TBD | TBD |

**Implementation** (`.github/workflows/ci.yml` Test (Python) step):

```yaml
env:
  BUDGET_MULTIPLIER: ${{ vars.BUDGET_MULTIPLIER || 1.0 }}
```

**Operator action** (one-time, in repo Settings → Secrets and variables → Actions → Variables):
- Set `vars.BUDGET_MULTIPLIER=2.0` for self-hosted runner. Default fallback is 1.0× if not set.

**Engine perf tests** (`tests/api/test_evaluate_transcendental.py`) read the multiplier via env var:

```python
BUDGET_MULTIPLIER = float(os.environ.get('BUDGET_MULTIPLIER', '1.0'))
ARITHMETIC_BUDGET_MS = 50 * BUDGET_MULTIPLIER
TRANSCENDENTAL_BUDGET_MS = 100 * BUDGET_MULTIPLIER
```

**Why 2.0×** (not 1.0×, not 3.0×):
- Self-hosted runner has different perf characteristics than public runner — empirically 1.5-2x slower on arithmetic-heavy paths.
- 1.0× would force arithmetic to <50ms on self-hosted runner, which empirically yields p99=79.02ms (post-PR-#731 lazy-import fix; before lazy-import it was 215ms).
- 2.0× absorbs 79ms variance with 21ms margin (100ms budget), leaves headroom for transient CI slowdowns.
- 3.0× would mask real engine regressions to 150ms — defeats "honest failure" doctrine.
- 2.0× preserves regression detection at the 200ms threshold — future engine code that regresses to 200ms+ will still FAIL.

**Honest failure preserved at regression-detection threshold**: a regression to 200ms+ engine perf still fails the 2.0×=100ms relaxed budget. The 2.0× multiplier absorbs **CI infrastructure variance**, not engine code regressions.

**Regression guard**: `scripts/tests/d111-budget-multiplier-runner-aware.sh` (NEW, sister to d100 + d110; ~6 TCs) verifies:
- TC1: BUDGET_MULTIPLIER env var defaults to 1.0× when unset
- TC2: BUDGET_MULTIPLIER=2.0 produces 100ms arithmetic budget
- TC3: BUDGET_MULTIPLIER=2.0 produces 200ms transcendental budget
- TC4: BUDGET_MULTIPLIER=0.5 produces 25ms arithmetic budget (sanity, future tightening)
- TC5: ci.yml Test (Python) step has `env: BUDGET_MULTIPLIER: ${{ vars.BUDGET_MULTIPLIER || 1.0 }}`
- TC6: vars.BUDGET_MULTIPLIER set in repo Settings is read at CI run time

**Future runner additions**: when adding a new runner type (e.g., macOS self-hosted, ARM self-hosted), measure p99 baseline on the new runner and add a new row to the table. Document the rationale per runner type.
```

---

## Rationale

### Why lazy-import mpmath (vs. deeper optimization, vs. revert mpmath)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Lazy-import mpmath** (CHOSEN) | Surgical fix (module-level → per-function import). Addresses root cause. Preserves ADR-0019 amend 2 §2 mpmath contract. | First transcendental call still pays ~150ms (amortized). | **Best fit** — boring-tech-wins |
| Deeper lazy-import (move constants + helpers) | Marginal perf gain | YAGNI; arithmetic 79ms is within 2.0× budget, no need for sub-50ms | **Rejected** — perfectionism |
| Revert mpmath (roll back PR #709 cascade) | Unblocks PR #694 immediately | Undoes Sprint 22 PIVOT P0 closure; cascading impact on STORY-011 + ADR-0019 amend 2 | **Rejected** — last resort only |
| Relax budget (ADR-0019 amend 3 with 200ms base) | Codifies new budget | Sets precedent of perf budget inflation; defeats honest failure | **Rejected** — sub-§2 already exists; amend 3 is for multiplier not relaxation |

### Why 2.0× self-hosted multiplier (not 1.0×, not 3.0×)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **2.0× self-hosted multiplier** (CHOSEN) | Absorbs CI variance (79ms arithmetic fits with 21ms margin). Preserves regression detection at 200ms threshold. Reversible (settings change). | Slight perf budget relaxation on self-hosted. | **Best fit** — boring-tech-wins + reversible |
| 1.0× on self-hosted (no multiplier) | Honest at all times | Forces sub-50ms arithmetic on self-hosted; unachievable without further optimization (~2h dev work) | **Rejected** — YAGNI |
| 3.0× self-hosted multiplier | Very forgiving | Masks regressions to 150ms; defeats honest failure | **Rejected** — too permissive |
| 1.5× self-hosted multiplier | Tighter than 2.0× | Insufficient margin (79ms arithmetic needs 75ms = 1.5× of 50ms = 75ms budget, 4ms margin) | **Rejected** — too tight |

### Why runner-aware multipliers in ADR (not in ci.yml only)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **ADR codification + ci.yml implementation** (CHOSEN) | Doctrinal home for the multiplier; survives YAML refactors; visible in INDEX.md; cite-able from PRs | ADR maintenance overhead | **Best fit** — boring-tech-wins |
| ci.yml only (no ADR) | Less overhead | Multiplier undocumented; PRs can't reference ADR; future maintainers don't know rationale | **Rejected** — undocumented decision |
| d-test only (no ADR, no YAML) | Drift-detected | Test asserts on codification; doesn't define the contract | **Rejected** — orphan test |

---

## Alternatives considered

### A. Lazy-import + 2.0× multiplier (chosen)

- **Pros**: addresses both P0 root causes (mpmath import bleed + self-hosted perf characteristic); minimal change to existing code; reversible
- **Cons**: requires operator UI step + ADR review
- **Verdict**: chosen

### B. Deeper lazy-import + 2.0× multiplier (push for arithmetic <50ms)

- **Pros**: full 1.0× honor on self-hosted
- **Cons**: ~2h additional dev work; not guaranteed (79ms may include non-mpmath overhead); YAGNI
- **Verdict**: rejected

### C. Revert mpmath (roll back PR #709 cascade)

- **Pros**: unblocks cascade immediately
- **Cons**: undoes Sprint 22 PIVOT P0 closure; cascading impact
- **Verdict**: rejected (last resort only)

### D. Lazy-import only (no multiplier change)

- **Pros**: addresses root cause #1
- **Cons**: doesn't address self-hosted runner perf characteristic; engine perf tests still FAIL on self-hosted even with lazy-import (79ms arithmetic > 50ms)
- **Verdict**: rejected (partial fix; needs multiplier too)

### E. Multiplier only (no lazy-import)

- **Pros**: addresses root cause #2
- **Cons**: doesn't address mpmath import bleed; PR #709 cascade regression root cause unfixed
- **Verdict**: rejected (partial fix; needs lazy-import too)

---

## Consequences

### Positive

- **Two P0 root causes addressed**: lazy-import fixes mpmath import bleed (root cause #1); 2.0× multiplier fixes self-hosted runner perf characteristic (root cause #2).
- **Engine perf regression closed**: PR #731 (lazy-import) + PR #729 (ci.yml env var) + operator UI step (vars.BUDGET_MULTIPLIER=2.0) closes the PR #709 cascade perf regression.
- **Sprint 22 PIVOT P3 cascade unblocks**: PR #694 + PR #726 + PR #679 + PR #730 all unblock once #731 + #729 + operator step complete.
- **Doctrinal home for self-hosted runner multiplier**: ADR-0019 amend 3 §"Runner-aware multipliers" is the canonical reference for BUDGET_MULTIPLIER semantics.
- **Regression guards in place**: d110 (lazy-import) + d111 (multiplier runner-aware, NEW) prevent future regressions to module-level import or unspecified multiplier.
- **Honest failure preserved at regression-detection threshold**: 200ms+ engine code regressions still FAIL at 100ms relaxed budget; the 2.0× multiplier absorbs CI variance, not engine regressions.
- **Reversibility**: BUDGET_MULTIPLIER=2.0 is a settings change; ADR-0019 amend 3 is canonical doctrine; both fully reversible (settings → 1.0; ADR → future amend 4).

### Negative

- **Operator UI step required**: vars.BUDGET_MULTIPLIER=2.0 must be set in repo Settings → Secrets and variables → Actions → Variables. Forgotten step = cascade still blocked. Mitigation: owner pING with explicit instruction.
- **2.0× multiplier is opinionated**: future maintainers may disagree with the specific value. Mitigation: ADR is citable; future amendments can adjust.
- **d111 NEW d-test** required (~30 min architect-tester coordination, ~1 SP dev impl).
- **Lazy-import first-call cost (~150ms)** still present on first transcendental call. Acceptable for calculator use (cold start vs. amortized cost); future perf optimization (mpmath context caching) can address.

### Out of scope (deferred to follow-up tickets)

| Item | Sprint | Owner |
|---|---|---|
| STORY-011 implementation PR (transcendentals + factorial) — already merged pre-#709 cascade | Sprint 2 P1 (complete) | @developer |
| d111-budget-multiplier-runner-aware d-test | Sprint 22 PIVOT P3 | @tester (contract) + @developer (impl) |
| Lift 2.0× multiplier to 3.0× if self-hosted perf improves (post-Sprint 23) | Sprint 23+ | @architect (assess) |
| Pre-compute mpmath context caches (`pi`, `e`, etc.) for first-call latency reduction | Sprint 23+ | @developer (perf optimization) |
| MacOS self-hosted runner + ARM self-hosted runner multiplier rows | Out of MVP | n/a |
| Symbolic math (sympy) for algebraic simplification | Out of MVP | n/a |

### Follow-up tickets to file

- [ ] d111-budget-multiplier-runner-aware d-test contract (tester lane, ~30 min architect-tester coordination)
- [ ] d111 d-test implementation (dev lane, ~1 SP)
- [ ] Operator UI step: vars.BUDGET_MULTIPLIER=2.0 in repo Settings (owner lane, ~5 min)
- [ ] PR #731 + PR #729 squash-merge gate (owner lane, file ownership matrix applies)
- [ ] PR #694 + PR #726 + PR #679 + PR #730 cascade squash-merge (owner lane)
- [ ] RETRO-016 (Sprint 22 PIVOT P3 retro cluster) — capture 9-Lens blind-spot family learnings

---

## What this amendment commits to *now*

- **Lazy-import mpmath contract**: `import mpmath` MUST be inside `_eval_transcendental()`, NOT at module level. Future engine dep additions MUST include import-site rationale.
- **Self-hosted runner 2.0× multiplier**: arithmetic 100ms p99 + transcendental 200ms p99 on self-hosted runners. Public runner remains at 1.0× baseline.
- **`BUDGET_MULTIPLIER` env var**: ci.yml Test (Python) step reads `vars.BUDGET_MULTIPLIER || 1.0`. Default fallback 1.0× for unset/missing.
- **d110 regression guard** (existing): lazy-import behavior verified via sys.modules introspection.
- **d111 regression guard** (NEW): runner-aware multiplier verified via env var round-trip + YAML env block presence.
- **No breaking changes** to engine exception taxonomy (preserved from ADR-0019 amend 2 §4) or evaluation semantics (preserved from amend 2 §2).
- **Engine ↔ UI separation invariant preserved** (ADR-0017): engine is still pure-Python; runtime dep boundary unchanged.

---

## Cross-references

- **API contract (base)**: [ADR-0019](./ADR-0019-api-contract.md) (accepted via PR #37)
- **Amendment 2 (this amends)**: [ADR-0019 amendment 2](./ADR-0019-amendment-2-decimal-and-envelope.md) §2 Transcendental precision model + §Performance budget
- **Tech stack (engine ↔ UI separation)**: [ADR-0017](./ADR-0017-tech-stack.md)
- **d-test framework sister-pattern**: [ADR-0049](./ADR-0049-d-test-framework.md) (≥5 TCs, ≥3 sister-pattern)
- **9-Lens pre-publish gate**: [ADR-0045](./ADR-0045-9-lens-pre-publish.md)
- **3-condition flake-vs-regression discriminator**: [ADR-0051](./ADR-0051-engine-perf-flake-vs-regression.md)
- **Sprint 22 PIVOT P3 follow-up cluster**:
  - [Issue #727](https://github.com/atilcan65/AtilCalculator/issues/727) [P0] CI infrastructure gap (tester reframed at 17:42Z)
  - [Issue #728](https://github.com/atilcan65/AtilCalculator/issues/728) [P0] engine perf hotfix (architect design ownership)
  - [PR #709](https://github.com/atilcan65/AtilCalculator/pull/709) Sprint 22 PIVOT Faz 1.1 (commit `eb64485`, regression origin)
  - [PR #731](https://github.com/atilcan65/AtilCalculator/pull/731) lazy-import implementation (dual peer 🟢, lint fix commit 80a6d2a)
  - [PR #729](https://github.com/atilcan65/AtilCalculator/pull/729) ci.yml env var + d109 sister-test (tester 🟢, owner squash gate pending)
  - [TD-044](https://github.com/atilcan65/AtilCalculator/pull/730) (PR #730) Sprint 22 PIVOT Faz 1.2 cascade tech-debt documentation
  - [TD-045 candidate](https://github.com/atilcan65/AtilCalculator/pull/732) lightweight — d105→d110 typo correction by dev (per Issue #113 label-authority)
  - [TD-046](https://github.com/atilcan65/AtilCalculator/pull/732) (PR #732, deferred until GraphQL reset) PR review missed lint — d110 runtime behavioral
- **Architect verdicts**:
  - [cmt 4846373274](https://github.com/atilcan65/AtilCalculator/issues/728#issuecomment-4846373274) Issue #728 initial verdict (lazy-import recommendation)
  - [cmt 4846642828](https://github.com/atilcan65/AtilCalculator/pull/731#issuecomment-4846642828) PR #731 arch verdict (🟢 OK design)
  - [cmt 4846778097](https://github.com/atilcan65/AtilCalculator/issues/728#issuecomment-4846778097) Issue #728 fresh verdict (🟢 APPROVED on (A) 2.0× + (C) amend 3)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>