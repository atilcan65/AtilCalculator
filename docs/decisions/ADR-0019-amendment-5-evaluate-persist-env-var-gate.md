# ADR-0019 — Amendment 5: ATILCALC_EVALUATE_PERSIST env-var precedence contract (Issue #728 perf-regression closeout)

- **Status:** Proposed (parallel to PR #742 cluster squash, Sprint 23 dev-lane closeout)
- **Date:** 2026-07-01
- **Deciders:** @architect (drafted 9-lens review cycle ~#1942), @owner (doubles PM — owner directive 2026-07-01 "olur beklerim ama kalıcı fix olsun"), @developer (impl PR #742), @tester (sign-off pending)
- **Supersedes:** (none — additive amendment)
- **Amends:** [ADR-0019-api-contract.md](./ADR-0019-api-contract.md) §Endpoint behaviour (`POST /api/evaluate` auto-persistence contract)
- **Closes:** Issue #728 (perf-regression follow-up, Sprint 23 dev-lane P0 unblocker)
- **Origin PR:** [#742 feat(api): ATILCALC_EVALUATE_PERSIST env-var gate](https://github.com/atilcan65/AtilCalculator/pull/742)

---

## Context

### Sprint 22 → Sprint 23 PIVOT — the perf-budget bleed cluster

The Sprint 22 → Sprint 23 PIVOT migrated CI to a self-hosted runner
(`192.168.1.197`, 8 vCPU / 16 GB RAM, mechanical disk) per
[ADR-0030](./ADR-0030-self-hosted-runner-lan-deploy.md). The PIVOT surfaced a
class of perf-budget bleed that had been hidden on `ubuntu-latest`-public:

- 7/8 PRs in the cluster squash (PR #679, #694, #704, #732, #736, #738, #741)
  regressed on `tests/api/test_evaluate_transcendental.py::test_arithmetic_p99_under_50ms_still_holds`.
- Local bench: p99 = **344–478 ms** vs the 250 ms budget (BUDGET_MULTIPLIER=5.0,
  i.e. CI expected to be ≤ 50 ms × 5.0).
- Cycle ~#1870 RCA ruled out the engine mpmath path (d110 / PR #731 already
  fixed lazy-import; arithmetic path verified mpmath-free at ~3.9 μs/call
  locally — well under any budget).
- **Root cause located:** per-request `persistence.insert_record(...)` in
  `src/atilcalc/api/routes.py:343` (the auto-persistence block in
  `evaluate_endpoint`). On slow self-hosted disk IO the per-call
  `INSERT + COMMIT` dominates request cost.

### The owner directive verbatim (2026-07-01)

> "olur beklerim ama **kalıcı fix olsun lütfen**" — "I'll wait, but make it a permanent fix."

This rejects a budget raise (option a) in favour of an actual perf fix
(option b — the option at hand). The cluster squash should not land without
the real fix, even if it costs cluster turnaround time.

---

## Decision

### The contract

Add the `ATILCALC_EVALUATE_PERSIST` environment variable to the
`POST /api/evaluate` handler as a state-mutating-side-effect gate, with the
following **3-tier precedence semantics**:

| Env-var value (post-`.strip().lower()`) | Effective state | Notes |
|---|---|---|
| **Unset** (canonical: `env -u ATILCALC_EVALUATE_PERSIST`) | `ENABLED` | Backward-compat preserved: `os.environ.get("ATILCALC_EVALUATE_PERSIST", "1")` defaults to `"1"`. |
| `"1"` / `"true"` / `"yes"` / `"on"` (or any value **not** in the falsy set) | `ENABLED` | Explicit-on parity. |
| `"0"` / `"false"` / `"no"` / `"off"` (case-insensitive) or `""` | `DISABLED` | Opt-out path. The SQLite INSERT+COMMIT is **skipped entirely** — no row written, no audit-trail row, no best-effort log entry. |

### Parsing implementation (must match the gate exactly)

```python
# src/atilcalc/api/routes.py — evaluate_endpoint
_persist_env = os.environ.get("ATILCALC_EVALUATE_PERSIST", "1").strip().lower()
_persist_enabled = _persist_env not in ("", "0", "false", "no", "off")
if _persist_enabled:
    ts_iso = _iso8601_now()
    try:
        persistence.insert_record(
            _get_db_path(), expr=req.expr, result=result_str,
            ts=ts_iso, idempotency_key=None,
        )
    except Exception as exc:
        log.warning(
            "history persist failed at /api/evaluate: %s", exc,
            extra={"path": "/api/evaluate", "request_id": request_id},
        )
```

The implementation in PR #742 matches this contract byte-for-byte.

### What stays unchanged

1. The HTTP contract for `POST /api/evaluate` is unchanged — the response
   payload (`{"result": <Decimal-as-string>}`) is identical regardless of
   persist state.
2. The default behaviour is `ENABLED`. Production deployments that do not
   set `ATILCALC_EVALUATE_PERSIST` will continue to auto-persist every
   evaluation, preserving the durable cross-device history.
3. `POST /api/history` (explicit-persist endpoint) is **out of scope**.
   This gate only wraps the **auto-persist** in `evaluate_endpoint`.
4. The `log.warning("history persist failed at /api/evaluate: %s", exc)`
   handler is preserved verbatim.

### Why opt-out (NOT opt-in)?

Reverse-of-default would force every test infrastructure / low-resource
deployment to opt-in explicitly, which is fragile (forget to set → SQLite
writes still fire → slow CI). Defaulting to `ENABLED` keeps production
auto-persist working **out of the box**; the gate's only effect is to
**make opt-out cheap and explicit**.

---

## Rationale

### Three ranked options considered

| Option | Description | Cost | Pros | Cons | Verdict |
|---|---|---|---|---|---|
| **(a) Budget raise** | Bump `BUDGET_MULTIPLIER` from 5.0 → 7.0 (or higher). | 1 line in `tests/conftest.py` | One-line fix; lands in 5 min. | **Hides the regression** — the user's real perf issue (slow per-request cost) remains. Owner directive explicitly rejects this. | **REJECTED** by owner directive ("kalıcı fix olsun"). |
| **(b) Real perf fix** *(chosen)* | Add the `ATILCALC_EVALUATE_PERSIST` opt-out gate; test infra + low-resource envs set `0`; production unchanged. | 26 lines net + 200-line d-test (`d113`) + this ADR + INDEX.md | (i) Real perf improvement on slow runners — local bench p50 6.13 ms → 3.67 ms (1.7×), p99 16.98 ms → 6.03 ms (2.8×); (ii) production behaviour unchanged (ADR-0022 §Cross-device sync model preserved); (iii) test infra opt-out is explicit + auditable; (iv) sister-pattern to d109/d110/d112 env-var precedence family (≥3 sister coverage per ADR-0049); (v) ≥5 TCs in d113 with RED-first per ADR-0044. | (i) Carries a **silent-skip risk** — see §Follow-up tickets; (ii) one more env-var to document in OPERATIONS.md. | **CHOSEN** |
| **(c) Async-batched persist** | Persist in batches via background worker, evaluate returns immediately. | ~80 LoC engine + 50 LoC bgtask/queue infra + AsyncResult migration | Removes synchronous write from hot path entirely; production keeps history. | (i) Bigger change surface; (ii) requires queue infra + retry policy + idempotency-key already supported; (iii) Sprint 23 PIVOT blocked. | **DEFERRED** to follow-up ticket. |

### Boring-tech-wins heuristic (ADR preamble)

The gate is **stdlib `os.environ.get` + `.strip().lower()` + `not in (tuple)`** —
no new dependency, no library, no async, no retry-policy machinery. **Reversibility**
is <1 day of refactor (delete the gate, remove the d-test, prune comment).

### Why this is "the" place to fix it (not the conftest)

The conftest `BUDGET_MULTIPLIER` (ADR-0019 amend-4 / PR #734) governs the
**test envelope**, not the **production hot path**. Lowering BUDGET_MULTIPLIER
would let the slow CI pass without fixing the underlying request cost.
The right boundary is: **the request cost itself** — measured on the
production-shaped code path, not on a test-only knob.

### Sister-pattern frame (ADR-0049 §Sister-pattern coverage ≥ 3)

| d-test | Sister-domain | Layer |
|---|---|---|
| `d100` (4 TCs) | Sprint 22 PIVOT self-hosted perf-budget envelope | performance envelope |
| `d109` (6 TCs) | ci.yml env-block precedence (Issue #727) | CI env-var propagation |
| `d110` (6 TCs) | Issue #728 lazy-import mpmath (PR #731) | engine-side perf |
| `d112` (7 TCs) | TD-046-extension conftest env-var precedence (PR #734 / ADR-0019 amend-4) | test-side env-var precedence |
| **`d113` (5 TCs, NEW)** | **THIS — /api/evaluate hot-path persist gate** | **runtime env-var precedence at the API boundary** |

= **≥ 3 sister-pattern coverage per ADR-0049.** The env-var precedence
family now forms a coherent unit: test-side (d100 / d112), CI-side (d109),
engine-side (d110), **runtime-side (d113)**.

---

## Consequences

### Positive

1. **Real perf improvement** — local bench p99 cut 2.8× (16.98 → 6.03 ms
   under `persist=0`).
2. **Production auto-persistence preserved** — ADR-0022 §Cross-device sync
   model maintains the durable history without an explicit
   `POST /api/history` call.
3. **Test infra opt-out is explicit + auditable** — `ATILCALC_EVALUATE_PERSIST=0`
   in ci.yml + the d113 d-test self-tests the gate.
4. **Sister-pattern env-var precedence family ≥ 3** — ADR-0049 coverage
   satisfied by d109 + d110 + d112 + d113.
5. **Reversibility**: the gate is a 4-line wrap + comment + 1 env-var
   contract. Rollback path: `git revert cbf4a25` (already documented in
   PR #742 §Rollback plan).

### Negative

1. **Silent-skip risk** — when the gate fires (DISABLED), no `log.info`
   or metric counter is emitted. Operators cannot distinguish
   "ATILCALC_EVALUATE_PERSIST=0 set" from "SQLite INSERT failed silently"
   without inspecting the env var. See §Follow-up tickets #A.
2. **d113's TC1 unset semantics subtlety** — bash `unset X; X=""` is a
   no-op for `os.environ.get('X', '1')` (returns `''`, not the default).
   The gate correctly maps `''` → DISABLED. The d113 TC1 uses
   `env -u ATILCALC_EVALUATE_PERSIST` for canonical unset semantics
   (process inherits no env-var → `os.environ.get` returns the default
   `"1"` → ENABLED). This is correct but **fragile against future
   refactors that read the env var via `os.environ["..."]` directly** —
   see §Follow-up tickets #B.
3. **One more env var to document in OPERATIONS.md** — see §Follow-up
   tickets #C.

### Follow-up tickets (deferred)

| ID | Description | Severity | Owner |
|---|---|---|---|
| **#A** | Add `log.info("evaluate persist opt-out, ATILCALC_EVALUATE_PERSIST=…", ...)` + metrics counter (`atilcalc_evaluate_persist_skipped_total`) for the DISABLED branch. **Closes lens d silent-skip risk per ADR-0045.** | M | @developer (Sprint 23 P2) |
| **#B** | Add `d113` TC6: verify `os.environ.get('ATILCALC_EVALUATE_PERSIST', '1')` is used (not `os.environ[...]` direct read). | L | @developer (Sprint 23 P2) |
| **#C** | Document `ATILCALC_EVALUATE_PERSIST` in `docs/OPERATIONS.md` (or `README.md` runtime section) — operator-visible flag + recommended values. | M | @developer (Sprint 23 P2) |
| #D | Async-batched persist (option c from §Rationale) for Sprint 24+ if perf continues to bleed at 2-3× the budget even with persist opt-out. Requires a queue infra + idempotency-key migration (the latter already supported per existing schema). | L | TBD (Sprint 24+) |
| #E | `ATILCALC_<ENDPOINT>_<STATE>_PERSIST` family — extend the precedence pattern to future state-mutating endpoints (if/when added). Follows from d113 framework. | L | TBD |

---

## Cross-references

- **PR #742** — the impl (this ADR's origin). Author @atilcan65 (owner doubles PM).
  Branch: `fix/issue-728-sprint-23-evaluate-persist-env-var-gate`.
  Commit: `cbf4a25`.
- **Issue #728** — perf-regression follow-up (owner directive verbatim source).
- **d113 d-test** — `scripts/tests/d113-evaluate-persist-env-var-gate.sh` (5/5 TCs GREEN).
- **ADR-0019 amend-4** — `[ADR-0019-amendment-4-conftest-env-var-precedence.md](./ADR-0019-amendment-4-conftest-env-var-precedence.md)` (TD-046-extension closeout, parallel sister-pattern).
- **ADR-0022 §Cross-device sync model** — production auto-persistence rationale preserved.
- **ADR-0030** — `[ADR-0030-self-hosted-runner-lan-deploy.md](./ADR-0030-self-hosted-runner-lan-deploy.md)` (self-hosted runner; the perf-budget bleed originator).
- **ADR-0044** — RED-first TDD (d113 is RED-first verified).
- **ADR-0045** — 9-Lens pre-publish gate (this ADR's review process).
- **ADR-0049** — d-test framework ≥5 TCs, sister-pattern coverage ≥3.
- **ADR-0055 §1** — Cadence Rule 1 atomic (ADR + INDEX.md same commit).
- **d100 / d109 / d110 / d112** — env-var precedence sister-pattern family.

---

*Drafted by @architect in parallel with PR #742 cluster squash. cycle ~#1942.
Cluster squash turn-around-cost compatible (single ADR, single d-test, single
impl PR — no cross-team coordination required).*
