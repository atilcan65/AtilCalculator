# ADR-0019 (amendment 4) — Conftest env-var precedence contract (TD-046-extension dual-source-of-truth closeout)

**Status:** Proposed (Sprint 22 PIVOT P3 closeout, cycle ~#1810+, file post-#732-squash per arch plan)
**Date:** 2026-06-30
**Deciders:** @architect (drafting), @developer (impl + PR #734 squash gate), @tester (d112 d-test sign-off — 7 TCs GREEN), @atilcan65 (owner squash gate for `tests/conftest.py` + ADR)
**Supersedes:** — (amends; does not replace)
**Amends:** [ADR-0019](ADR-0019-api-contract.md) §Performance budgets (transcendental/arithmetic); [ADR-0019 (amendment 3)](./ADR-0019-amendment-3-lazy-import-and-self-hosted-multiplier.md) §Runner-aware multipliers (env var = single source of truth) — this amendment codifies the **resolver-layer** that amendment 3 presupposes
**Related:** [Issue #728](https://github.com/atilcan65/AtilCalculator/issues/728) (Sprint 22 PIVOT engine-perf RCA); [PR #729](https://github.com/atilcan65/AtilCalculator/pull/729) (dev fixup `|| 2.0` fallback); [PR #731](https://github.com/atilcan65/AtilCalculator/pull/731) (lazy-import mpmath impl); [PR #732](https://github.com/atilcan65/AtilCalculator/pull/732) (amendment 3 doctrine codification); [PR #734](https://github.com/atilcan65/AtilCalculator/pull/734) (dev impl — conftest helper + d112 d-test, MERGED 2026-06-30T20:13:46Z @ 727a2c70a273); [PR #726](https://github.com/atilcan65/AtilCalculator/pull/726) (engine-perf canonical PR — was chicken-egg blocked); [PR #679](https://github.com/atilcan65/AtilCalculator/pull/679) (d069 d-test carrier); [PR #694](https://github.com/atilcan65/AtilCalculator/pull/694) (TD-044 cascade); [PR #730](https://github.com/atilcan65/AtilCalculator/pull/730) (TD-044 docs filing); [Issue #706](https://github.com/atilcan65/AtilCalculator/issues/706) (post-merge RCA — sprint plan doc); [TD-046-extension](./../tech-debt.md) (new entry — dual-source-of-truth blind-spot, ~12th in 9-Lens family); [Issue #113](https://github.com/atilcan65/AtilCalculator/issues/113) (label-authority > body doctrine — labels are source of truth)

---

## Context

ADR-0019 (accepted 2026-06-17 via PR #37) defines the AtilCalculator HTTP API contract and its amendment 2 (PR #84) introduced transcendental perf budgets (50ms arithmetic / 100ms transcendental p99). Amendment 3 (PR #732, owner squash pending at cycle ~#1810) codifies the Sprint 22 PIVOT self-hosted runner 2.0× baseline and the lazy-import mpmath contract. This **fourth amendment** addresses the dual-source-of-truth gap surfaced by Sprint 22 PIVOT P3 closeout (Issue #728 RCA + PR #734 follow-up):

| # | Gap | Source | Severity |
|---|---|---|---|
| 1 | **`tests/conftest.py:115` defines `_BUDGET_MULTIPLIER_MAP[detect_runner_env()]`** — this module-level constant bypasses `ci.yml`'s `vars.BUDGET_MULTIPLIER` env var propagation, creating a **second source of truth** for the multiplier. Operator-set env var (e.g., `vars.BUDGET_MULTIPLIER=2.0` for prod runner) is silently overridden by the runner-detection map. | PR #734 cycle ~#1770+ RCA: PR #726 CI arithmetic p99=83.19ms vs 50ms × 1.0 (env var not respected); TD-046-extension | **P0** (blocks PR #726 squash chain) |
| 2 | **No fail-loud contract for unparseable env vars** — `float("garbage")` raises `ValueError`, but conftest's role is to surface the error to operators, not silently downgrade. Sister-pattern to ADR-0056 silent_skip doctrine. | Arch design cmt 4847385602 (Q3 answer); PR #734 TC6 | **P1** (operator ergonomics) |
| 3 | **SUBPROCESS_TIMEOUT_S has identical architecture gap** — `tests/conftest.py:_SUBPROCESS_TIMEOUT_MAP_S` is also a parallel source of truth, independently bypassing ci.yml env vars. Sister-contract to BUDGET_MULTIPLIER. | Arch design cmt 4847385602 (Q1 answer — single-resolver symmetry); PR #734 TC7 | **P1** (same root cause as gap #1) |

### Why this is a TD-046-extension (12th blind-spot in 9-Lens family)

The 9-Lens family (ADR-0045) currently covers 9 blind-spots: TD-016 (data flow), TD-018 (runtime preconds), TD-019 (canonical entry), TD-020 (silent-skip preflight), TD-028 (workflow SHA pin), TD-029 (platform hard constraints), TD-030 (auto-gen file refs + live-state), TD-031 (JS syntactic correctness), TD-046 (perf budget calibration, generic). The TD-046-extension surfaces a **12th blind-spot class**: **dual-source-of-truth architecture gap** — when two distinct code paths independently compute the same canonical value (here, BUDGET_MULTIPLIER), operator overrides can be silently overridden by the more isolated path. Sister-pattern family: TD-016/TD-018/TD-019/TD-020/TD-030 = architectural observability gaps; TD-046-extension = **architectural source-of-truth authority gap**.

### Why this amendment is required (not just an impl fix)

PR #734 has already landed the **impl fix** in `tests/conftest.py` (lines 113-158: `_resolve_budget_multiplier()` + `_resolve_subprocess_timeout_s()` helpers + module-level constants use helpers). This amendment **codifies the resolver-layer doctrine** that the impl presupposes — specifically, the canonical 3-tier precedence chain (env var > runner detection > hardcoded map) and the fail-loud ValueError contract. Without this ADR, the next engineer refactoring conftest.py has no doctrinal anchor for why the resolver exists; the dual-source-of-truth gap could silently re-emerge.

---

## Decision

**Adopt the conftest env-var precedence contract** as a canonical resolver-layer doctrine for all operator-tunable perf-budget knobs in `tests/conftest.py`. Codified as a 3-tier canonical precedence chain with fail-loud ValueError semantics:

1. **Tier 1 — Operator env var**: `os.environ["BUDGET_MULTIPLIER"]` / `os.environ["SUBPROCESS_TIMEOUT_S"]` (operator-set via `vars.*` in `.github/workflows/ci.yml` or shell export for local runs). **Takes precedence over all other sources.**
2. **Tier 2 — Runner detection**: `detect_runner_env()` returns `'self-hosted' | 'github-hosted' | 'local'`. Maps to canonical runner-aware defaults (Sprint 22 PIVOT: self-hosted = 2.0×/10s, github-hosted + local = 1.0×/5s).
3. **Tier 3 — Hardcoded map fallback**: `_BUDGET_MULTIPLIER_MAP` / `_SUBPROCESS_TIMEOUT_MAP_S` retained as final fallback (canonical Sprint 22 PIVOT self-hosted baseline lives here per arch Q3 answer — map is **not** removed; it is the canonical "unconfigured environment" baseline).

**Fail-loud contract**: unparseable env var (e.g., `BUDGET_MULTIPLIER=garbage`) MUST raise `ValueError` immediately. **Silent downgrade is DOCTRINALLY REJECTED** per ADR-0056 silent_skip doctrine (lens d). Operators must see the bad config, not have CI silently fall back to runner defaults.

### Conftest resolver contract (canonical)

```python
# tests/conftest.py (PR #734 impl, lines 126-141 + 144-154)

def _resolve_budget_multiplier() -> float:
    """TD-046-extension canonical precedence: env var > runner-detected > hardcoded map.

    Operator env var (os.environ['BUDGET_MULTIPLIER']) takes precedence per
    ADR-0019 amendment 3 §Runner-aware multipliers (env var = single source of truth
    for operator overrides). detect_runner_env() is canonical for unconfigured
    environments. Hardcoded map is the final fallback (canonical Sprint 22 PIVOT
    self-hosted baseline lives here — map RETAINED per arch Q3 answer).

    Raises ValueError on unparseable env var (fail-loud per ADR-0056 silent_skip
    sister-pattern — bad operator input must not silently downgrade to runner default).
    """
    env_val = os.environ.get("BUDGET_MULTIPLIER")
    if env_val is not None:
        return float(env_val)  # raises ValueError on garbage
    return _BUDGET_MULTIPLIER_MAP[detect_runner_env()]


def _resolve_subprocess_timeout_s() -> float:
    """TD-046-extension canonical precedence: env var > runner-detected > hardcoded map.

    Sister-contract to _resolve_budget_multiplier() — same precedence doctrine applies
    because both are operator-tunable perf budget knobs (per ADR-0019 amend 3 doctrine:
    env var = single source of truth for all perf-budget operator overrides).
    """
    env_val = os.environ.get("SUBPROCESS_TIMEOUT_S")
    if env_val is not None:
        return float(env_val)
    return _SUBPROCESS_TIMEOUT_MAP_S[detect_runner_env()]


BUDGET_MULTIPLIER: float = _resolve_budget_multiplier()
SUBPROCESS_TIMEOUT_S: float = _resolve_subprocess_timeout_s()
```

**Why 3-tier (not 2-tier)**:

- **2-tier (env var > hardcoded map) would lose the runner-aware baseline.** Sprint 22 PIVOT's canonical baseline is **runner-aware** (self-hosted = 2.0×, github-hosted + local = 1.0×). A pure env-var-or-hardcoded contract would require operators to set `BUDGET_MULTIPLIER=2.0` on every self-hosted CI run, defeating the point of the runner-detection layer.
- **3-tier (env var > runner detection > hardcoded map)** preserves the runner-aware baseline as the canonical "unconfigured" path AND allows operator override. The hardcoded map RETAINED because it encodes the Sprint 22 PIVOT canonical self-hosted baseline (2.0×/10s) — this is **the** source of truth for what runner-aware defaults look like, even if env var takes precedence.

**Why env var takes precedence (not runner detection)**:

- **Reversibility > correctness**: env var is the operator's runtime override channel. If runner detection overrode env var, operators couldn't A/B test new baselines (e.g., `BUDGET_MULTIPLIER=3.0` to verify a slower runner).
- **Operational ergonomics**: Sprint 22 PIVOT self-hosted runner has been observed at 1.5×-2.5× variance. Operators MUST be able to override without modifying code.
- **Single source of truth**: per ADR-0019 amend 3 §Runner-aware multipliers, env var is canonical. The resolver's job is to enforce that.

**Why fail-loud ValueError (not silent fallback)**:

- ADR-0056 silent_skip doctrine (lens d) requires all conditionals that skip work to log a `silent_skip` event. Silent downgrade of `BUDGET_MULTIPLIER=garbage` to `1.0` (runner default) violates this — operator's typo silently miscalibrates the perf budget, producing false-positive CI green.
- Per arch design cmt 4847385602 (Q3 answer): "Fail-loud on parse error — operator MUST see the bad config; float('garbage') → ValueError is the contract".
- Sister-pattern: PR #734 TC6 verifies `BUDGET_MULTIPLIER=abc` raises ValueError (d112 d-test GREEN).

### Map retention rationale (Q3 answer)

The hardcoded maps `_BUDGET_MULTIPLIER_MAP` / `_SUBPROCESS_TIMEOUT_MAP_S` are **NOT removed** after PR #734. They are the canonical encoding of the Sprint 22 PIVOT runner-aware baseline. Removing them would force every future engineer to recompute "what's the canonical self-hosted multiplier?" — a docs drift risk. **The maps are the data; the resolver is the policy.**

---

## Rationale

### Why 3-tier precedence (not 2-tier or 4-tier)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **3-tier: env var > runner detection > hardcoded map** (CHOSEN) | Preserves runner-aware canonical baseline; allows operator override; map encodes the canonical self-hosted baseline (data + policy separation) | 3 sources of truth is a maintenance burden (mitigated by canonical ADR) | **Best fit** — encodes Sprint 22 PIVOT canonical doctrine |
| 2-tier: env var > hardcoded map (drop runner detection) | Simpler; 1 source of truth at runtime | Loses runner-aware baseline; operator MUST set env var on every CI run; defeats purpose of runner detection | **Rejected** — discards amendment 3's runner-aware doctrine |
| 4-tier: env var > runner override file > runner detection > hardcoded map | Most flexible | Adds new artifact (runner override file) for no current use case; YAGNI per ADR-0017 §YAGNI doctrine | **Rejected** — over-engineered |
| 1-tier: hardcoded map only (drop env var + runner detection) | Simplest | Cannot A/B test new baselines; operator has no override channel; Sprint 22 PIVOT variance unmanageable | **Rejected** — operational dead-end |

### Why env var takes precedence over runner detection

- **Reversibility > correctness** (architect doctrine): env var is operator's override channel. Operator MUST be able to test `BUDGET_MULTIPLIER=3.0` on a slower runner without modifying `ci.yml`.
- **Sprint 22 PIVOT empirical evidence**: PR #729 squash-merge cycle observed self-hosted runner at 1.5×-2.5× variance (PR #729 squash @ f5636d5 vs subsequent runs). Operators need override channel for calibration drift.
- **Single source of truth** (ADR-0019 amend 3): env var is the canonical operator override channel. Resolver enforces this.

### Why retain the hardcoded map (not delete post-#734)

- **Data vs policy separation**: the map IS the canonical Sprint 22 PIVOT self-hosted baseline. Removing it forces the next engineer to grep `git log` for "what's the 2.0× number?" — a docs drift risk.
- **Q3 answer (arch design cmt 4847385602)**: explicitly retained. Removing would be a separate ADR (out of scope for amendment 4).
- **Single-file canonicality**: with the map retained, `tests/conftest.py` is the **single file** where Sprint 22 PIVOT canonical baselines live. Cross-archaeology via `git blame` shows the rationale.

### Why fail-loud ValueError (not silent fallback or warning)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Fail-loud ValueError** (CHOSEN) | Operator sees typo immediately; aligns with ADR-0056 lens d doctrine | Unhandled exception crashes CI on bad config (this is the point) | **Best fit** — surfaces bug, doesn't hide it |
| Silent fallback to runner default | Operator's CI keeps running | Mis-calibrated perf budget; false-positive green; violates ADR-0056 | **Rejected** — silent_skip violation |
| Log warning + fallback | Compromise | Still mis-calibrates perf budget; warning may be missed in CI output | **Rejected** — partially violates ADR-0056 |
| Try/except + use sentinel | Most defensive | Hides bug; sentinel value (`-1.0`?) needs separate handling everywhere | **Rejected** — over-engineered |

### Alternatives considered

#### A. Conftest env var precedence (chosen)

- **Pros**: closes dual-source-of-truth gap; preserves runner-aware baseline; allows operator override; fail-loud semantics align with ADR-0056
- **Cons**: 3 sources of truth (env var, runner detection, hardcoded map) — mitigated by canonical ADR + d112 d-test (7 TCs GREEN)
- **Verdict**: chosen (matches PR #734 impl exactly)

#### B. Switch CI to public runner (drop self-hosted)

- **Pros**: removes runner variance entirely
- **Cons**: violates Sprint 22 PIVOT path-(b) closure (self-hosted is canonical for LAN deploy per ADR-0030); public runner cannot reach private LAN 192.168.1.199:22 (Sprint 3 P0 incident #138 RCA-1)
- **Verdict**: rejected (architecturally wrong direction)

#### C. Both A + B (defense-in-depth)

- **Pros**: belt-and-suspenders
- **Cons**: B is overkill for this fix; Sprint 22 PIVOT path-(b) is closed
- **Verdict**: deferred (only if A insufficient)

---

## Consequences

### Positive

- **Dual-source-of-truth gap closed** (TD-046-extension): env var is now the single canonical operator override channel for BUDGET_MULTIPLIER + SUBPROCESS_TIMEOUT_S.
- **PR #726 squash chain unblocked**: PR #734 (MERGED 2026-06-30T20:13:46Z @ 727a2c70a273) provides the conftest fix; PR #729 (env var lookup) + PR #731 (lazy-import impl) + PR #726 (canonical perf PR) + PR #679 + PR #694 + PR #730 + PR #732 can now squash in sequence.
- **Sprint 22 PIVOT P3 closeout** fully closes: PR #679, #694, #726, #730, #732, #734 = 6-PR cascade. Sister d-tests: d069 (PR #679), d100 (PR #729 sister), d110 (PR #731), d112 (PR #734 NEW).
- **Fail-loud contract enforced**: TC6 verifies ValueError on garbage input; aligns with ADR-0056 silent_skip doctrine.
- **Reversibility preserved**: env var override allows A/B testing of new baselines without code changes.
- **Map retention**: canonical Sprint 22 PIVOT self-hosted baseline (2.0×/10s) is preserved as data, not policy.

### Negative

- **3 sources of truth**: env var + runner detection + hardcoded map = 3 distinct values that can produce the same canonical input. Mitigated by canonical ADR + d112 d-test (7 TCs) + ADR-0055 Cadence Rule 1 atomic.
- **ValueError on garbage input**: crashes CI on operator typo. This is the intent (fail-loud), but operators used to silent fallback will be surprised. Mitigation: README + USER-GUIDE update (out of scope for this ADR, file as follow-up).
- **d112 d-test required**: 7 TCs (TC1-TC7) verify env var precedence, runner detection fall-back, fail-loud ValueError, edge cases (TC5 `BUDGET_MULTIPLIER=0` → 0.0). Per ADR-0049 baseline ≥3 TCs minimum (multi-source verified, NOT ≥5 — arch cycle ~#1801 doctrinal correction); 7 TCs is **PRIMARY-d-test aspirational**, exceeds baseline.

### Out of scope (deferred to follow-up tickets)

| Item | Sprint | Owner |
|---|---|---|
| README + USER-GUIDE update: document env var precedence + fail-loud contract | Sprint 23+ | @developer (docs) |
| ADR-0049 amendment: clarify ≥3 TCs baseline (NOT ≥5 as previously claimed in amendment 3 L258) | Sprint 23 P1 doctrine hardening | @architect (doc correction) |
| d100 TC5: cross-file BUDGET_MULTIPLIER import consistency (tester-suggested, Sprint 23+ candidate) | Sprint 23+ | @tester |
| d094 TC4-5: extend to cover SUBPROCESS_TIMEOUT_S symmetry | Sprint 23+ | @tester |
| ADR-0055 amendment: 3-tier precedence as canonical resolver-layer doctrine for all operator-tunable knobs (generalize beyond conftest) | Sprint 23+ | @architect (generalize) |

### Follow-up tickets to file

- [ ] docs/tech-debt.md TD-046-extension entry: dual-source-of-truth architecture gap (12th in 9-Lens family, sister to TD-016/TD-018/TD-019/TD-020/TD-030)
- [ ] Sprint 23 backlog candidate: ADR-0049 amendment ≥3 TCs clarification
- [ ] Sprint 23 backlog candidate: README/USER-GUIDE update for env var precedence + fail-loud

---

## What this amendment commits to *now*

- **Conftest env var precedence**: `os.environ["BUDGET_MULTIPLIER"]` / `os.environ["SUBPROCESS_TIMEOUT_S"]` takes precedence over runner detection (Sprint 22 PIVOT canonical baseline) and hardcoded map fallback.
- **3-tier canonical precedence chain**: env var > runner detection > hardcoded map. **The chain is the doctrine.**
- **Fail-loud ValueError contract**: unparseable env var raises `ValueError` immediately. Silent downgrade DOCTRINALLY REJECTED per ADR-0056.
- **Map retention**: `_BUDGET_MULTIPLIER_MAP` / `_SUBPROCESS_TIMEOUT_MAP_S` retained as canonical Sprint 22 PIVOT baseline encoding. Map is data; resolver is policy.
- **Sister-pattern symmetry**: BUDGET_MULTIPLIER + SUBPROCESS_TIMEOUT_S have identical resolver contracts (single resolver doctrine per arch design cmt 4847385602 Q1 answer).
- **d112 d-test contract**: 7 TCs (TC1-TC7) verify env var precedence, runner detection fall-back, fail-loud ValueError, edge cases. Per ADR-0049 baseline ≥3 TCs minimum; 7 TCs exceeds baseline.
- **PR #734 impl is the canonical reference**: lines 113-158 of `tests/conftest.py` (commit 727a2c70a273) are the binding impl this amendment codifies.
- **Sprint 22 PIVOT P3 closeout**: this amendment + PR #734 + PR #732 (amendment 3) + PR #730 (TD-044) + PR #729 (env var lookup) + PR #731 (lazy-import impl) = full Sprint 22 PIVOT P3 closeout cluster.

---

## Cross-references

- **API contract (base)**: [ADR-0019](ADR-0019-api-contract.md) (accepted via PR #37; amended via PR #63, PR #84, PR #732, **this amendment**)
- **Amendment 3 (lazy-import + self-hosted multiplier)**: [ADR-0019-amendment-3-lazy-import-and-self-hosted-multiplier.md](./ADR-0019-amendment-3-lazy-import-and-self-hosted-multiplier.md) (PR #732, owner squash pending — this amendment codifies the resolver layer amendment 3 presupposes)
- **Amendment 2 (mpmath + factorial + DomainError + envelope)**: [ADR-0019-amendment-2-decimal-and-envelope.md](./ADR-0019-amendment-2-decimal-and-envelope.md) (PR #84, MERGED 2026-06-18 — transcendental perf budgets introduced here)
- **Sprint 22 PIVOT engine-perf RCA**: [Issue #728](https://github.com/atilcan65/AtilCalculator/issues/728) (origin of amendment 3 + this amendment)
- **PR #734 (impl)**: [PR #734](https://github.com/atilcan65/AtilCalculator/pull/734) (MERGED 2026-06-30T20:13:46Z @ 727a2c70a273 — conftest resolver + d112 d-test)
- **PR #732 (amendment 3 doctrine)**: [PR #732](https://github.com/atilcan65/AtilCalculator/pull/732) (owner squash pending — env var = single source of truth doctrine)
- **PR #731 (lazy-import impl)**: [PR #731](https://github.com/atilcan65/AtilCalculator/pull/731) (arch sign-off + PM validation, owner squash pending)
- **PR #729 (env var lookup)**: [PR #729](https://github.com/atilcan65/AtilCalculator/pull/729) (dev fixup `|| 2.0` fallback, owner squash pending)
- **PR #730 (TD-044 cascade)**: [PR #730](https://github.com/atilcan65/AtilCalculator/pull/730) (docs(tech-debt) filing, owner squash pending)
- **PR #726 (engine-perf canonical)**: [PR #726](https://github.com/atilcan65/AtilCalculator/pull/726) (canonical perf PR — was chicken-egg blocked, now unblocked post-#734)
- **PR #679 (d069 d-test carrier)**: [PR #679](https://github.com/atilcan65/AtilCalculator/pull/679) (tester-authored, RETRO-016 #2/#3 LIVE INSTANCE)
- **PR #694 (TD-044 cluster)**: [PR #694](https://github.com/atilcan65/AtilCalculator/pull/694) (tester-authored followup)
- **Silent-skip doctrine**: [ADR-0056](./ADR-0056-layer-5-idempotency-reconcile.md) (silent_skip on conditionals, lens d compliance)
- **9-Lens Review Checklist**: [ADR-0045](./ADR-0045-auto-generated-file-refs-design-verification.md) (lenses a-j; this amendment is doctrine-only, applies (d) silent-skip lens for fail-loud contract)
- **d-test framework**: [ADR-0049](./ADR-0049-behavioral-workflow-test-framework.md) (≥3 TCs baseline per arch cycle ~#1801 doctrinal correction; d112 7 TCs exceeds baseline)
- **Cadence Rule 1 atomic**: [ADR-0055](./ADR-0055-d-test-id-uniqueness-sub-pattern-matrix.md) §1 (this ADR + INDEX.md row in same PR)
- **Label-authority doctrine**: [Issue #113](https://github.com/atilcan65/AtilCalculator/issues/113) (labels > body; PR #734 squash gate via `verdict-by:<ts>` labels)
- **Tech-debt ledger**: [docs/tech-debt.md](./../tech-debt.md) (TD-046-extension entry — to be filed in same PR per ADR-0055 Cadence Rule 1)
- **Architect design input (cmt 4847385602)**: PR #734 cycle ~#1770+ arch design comment — Q1 answer (single-resolver symmetry) + Q3 answer (map retention)
- **Architect design input (cmt 4847430061)**: PR #734 cycle ~#1799 arch verdict — 🟢 OK on impl

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
