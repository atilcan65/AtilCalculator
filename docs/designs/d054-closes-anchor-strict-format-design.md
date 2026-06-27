# Design: d054 — §Closes-anchor strict format d-test (Issue #468)

- **Story ID**: d054 (Issue #468, Sprint 13 P2 #6)
- **Author**: @architect
- **Date**: 2026-06-27
- **Sprint**: 13 (P2 cluster, RETRO-007 watchlist entry #5 codification)
- **Priority**: P2
- **Closes**: RETRO-007 watchlist entry #5 (§Closes-anchor strict format), TD candidate for C9 enforcement depth
- **Refs**: Issue #468, ADR-0050 §C9, d053 (sister d-test, Issue #463 MERGED), PR #462 (closes-anchor strict format L1 catch precedent, cmt 4813352612), RETRO-007 watchlist entry #5

## Context

ADR-0050 §C9 specifies the rule:

> **Closes-anchor strict format**: L1 of PR body MUST match `^Closes #[0-9]+$` — uppercase C + line 1 + NO trailing text.

d053 (Issue #463, MERGED via PR #464+#465 at 2026-06-27T05:24:27Z + 05:25:26Z) implements C9 as **one of 9 doctrinal checks** in a broad sweep (C1-C9, shallow depth per check).

**Problem**: C9 in d053 is **broad-shallow**. It only checks the regex match on L1. Sister-pattern d-tests in the family (d046 jq-filter guard, d048 Layer 5 reviewer chain) are **deep-narrow** — single-purpose, exhaustive coverage. C9 lacks this depth.

**Real-world failures observed**:
- **PR #462 v1**: Closes-anchor mid-paragraph (not L1). d053 C9 would catch this (regex fail), but **trailing space**, **trailing period**, **embedded extras** like `Closes #N. See #M` need explicit TC coverage.
- **Sprint 13 cycle**: PR #472 + #473 opened with C9 violations (trailing text on L1). Manual arch review caught them via 🟡 suggestion; PM amended before merge. **Manual catches don't scale**.

**Solution**: **d054** — dedicated single-purpose d-test for Closes-anchor strict format, deep coverage, 8 explicit TCs. Sister-pattern to d046 (single-purpose jq-filter), d048 (single-purpose reviewer chain).

## Goals & non-goals

### Goals

- **Deep coverage**: 8 explicit TCs covering all observed + anticipated Closes-anchor format variants
- **Self-test mode**: RED-first per ADR-0044, 7-8 FAIL + 1 PASS expected (one PASS for the canonical valid case)
- **Live mode**: `bash scripts/tests/d054-closes-anchor-strict-format.sh <PR_NUMBER>` exits 0/1
- **Sister-pattern parity with d053 C9**: no contradiction, d054 is deeper, d053 C9 can remain as fast-path
- **CI integration ready**: output machine-parseable, exit code 0/1/2 (0=PASS, 1=FAIL, 2=preflight)
- **Pre-merge gate (future)**: d054 trigger path = `paths: scripts/tests/d054-*, .github/workflows/**` (Sprint 13 P0 #1 d050b TC1 owner territory)

### Non-goals

- ❌ **No removal of d053 C9** — d053 stays as broad-shallow sweep, d054 is deep-narrow sister
- ❌ **No changes to ADR-0050** — d054 implements within ADR-0050 §C9 spec, no spec change
- ❌ **No retroactive PR re-validation** — d054 applies to future PRs only (post-merge activation)
- ❌ **No Closes-anchor auto-fix** — d054 reports, doesn't amend (PM/dev/arch judgement to fix)

## High-level diagram

```mermaid
flowchart LR
    A[PR opened/updated] --> B[gh api repos/.../pulls/N<br/>fetch body]
    B --> C[Extract L1<br/>first non-empty line]
    C --> D{Regex match<br/>^Closes #[0-9]+$?}
    D -- yes --> E[PASS exit 0]
    D -- no --> F{Classify violation<br/>8 TC categories}
    F --> G[Report specific TC + remediation]
    G --> H[FAIL exit 1]

    style D fill:#cfc,stroke:#393
    style E fill:#cfc,stroke:#393
    style F fill:#fdc,stroke:#a83
    style H fill:#fdc,stroke:#a83
```

## Components

| Component | Responsibility | Owner | Tech |
|---|---|---|---|
| `docs/designs/d054-closes-anchor-strict-format-design.md` | This design doc | @architect | Markdown |
| `scripts/tests/d054-closes-anchor-strict-format.sh` | d-test impl (live + self-test modes) | @developer (per ADR-0044 RED-first) | Bash + gh CLI + jq |
| `scripts/tests/d053-pre-merge-4-cat-verification.sh` | Sister d-test (broad sweep, includes C9 shallow) | @developer (MERGED via PR #465) | Bash + gh CLI + jq |
| ADR-0050 §C9 | Doctrinal source of the rule | @architect (MERGED via PR #464) | Markdown |
| `.github/workflows/lint-and-test.yml` | CI integration trigger (Sprint 13 P0 #1 owner territory) | @human (owner-implementable workflow file) | YAML |

## API contract

### Self-test mode

```bash
bash scripts/tests/d054-closes-anchor-strict-format.sh --self-test
```

**Input**: None (inline fixture with 8 violation TCs + 1 valid TC).

**Output**: TC-by-TC PASS/FAIL report. Expected: 7-8 FAIL + 1 PASS (or 8 FAIL + 1 PASS depending on TC1 canonical case).

**Exit codes**:
- 0 — self-test green (expected FAIL/PASS counts match)
- 1 — self-test RED (counts mismatch = impl bug)

### Live mode

```bash
bash scripts/tests/d054-closes-anchor-strict-format.sh <PR_NUMBER>
# OR
PR_NUMBER=N bash scripts/tests/d054-closes-anchor-strict-format.sh
```

**Input**: PR number (positional or env var).

**Output**:
- `PASS — L1 = 'Closes #N' (strict format, ADR-0050 §C9 compliant)`
- `FAIL — <TC-id> <violation description>. L1='<actual-L1>'`
- `INFO — d054 deep-narrow sister to d053 C9 broad-shallow`

**Exit codes**:
- 0 — C9 strict format satisfied
- 1 — violation detected (with TC id + remediation hint)
- 2 — preflight failure (missing gh/jq, PR not found, etc.)

## 8 Test Cases (TC1-TC8)

| TC | L1 input | Expected | Sister-pattern / origin |
|----|----------|----------|--------------------------|
| TC1 | `Closes #N` (canonical, no trailing) | ✅ PASS | d053 C9 strict format (canonical) |
| TC2 | `closes #N` (lowercase c) | ❌ FAIL | d053 C9 regex fail (case-sensitive C) |
| TC3 | `closes #N` (no anchor at all, lowercase) | ❌ FAIL | d053 C9 regex fail |
| TC4 | `## Why\nCloses #N` (mid-paragraph, L1 is header) | ❌ FAIL | PR #462 v1 catch (anchor not on L1) |
| TC5 | `Closes #N ` (trailing space) | ❌ FAIL | d053 C9 regex fail (regex anchored to EOL) |
| TC6 | `Closes #N. See #M` (trailing sentence on L1) | ❌ FAIL | PR #472+#473 cycle (Sprint 13 observed) |
| TC7 | `` (empty body) | ❌ FAIL | d053 C9 empty body fail |
| TC8 | `## Why` (no Closes anchor anywhere on L1) | ❌ FAIL | d053 C9 no-anchor fail |

**Self-test expected outcome**: TC1 PASS, TC2-TC8 FAIL = 1 PASS + 7 FAIL (green).

## Alternatives considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **A: Extend d053 C9 with deeper checks** | Single d-test, less code | Bloats d053 (broad sweep loses focus); C9 becomes 30+ lines | ❌ Rejected — violates single-purpose sister-pattern |
| **B: d054 dedicated sister (this design)** | Single-purpose, deep coverage, sister to d046/d048 | New d-test to maintain | ✅ **Selected** — sister-pattern parity |
| **C: No d054, rely on d053 C9 + manual arch review** | Zero new code | Manual review doesn't scale; observed 2 manual catches in Sprint 13 | ❌ Rejected — manual catches don't prevent future violations |
| **D: d054 + replace d053 C9 with delegation** | One source of truth | Removes d053 broad-sweep speed; d053 is canonical 9-check framework | ❌ Rejected — d053 C9 is part of canonical 9-check sweep |

## Risks

| Risk | Lens | Mitigation |
|------|------|------------|
| **R1: d054 + d053 C9 duplication drift** | (a) Data flow, (f) Observability | Sister-pattern parity test: d054 self-test verifies d053 C9 same regex used; both share `^Closes #[0-9]+$` |
| **R2: d054 self-test false-green** | (d) Silent-skip risk | RED-first per ADR-0044: 7 FAIL expected in self-test, any false-green = impl bug |
| **R3: d054 live mode flaky on PR amend** | (e) Idempotency | Re-fetch PR body on each invocation; no caching; idempotent re-runs |
| **R4: gh API rate limit on live mode** | (b) Runtime preconditions | Preflight check `command -v gh` + `gh auth status`; exit 2 with clear error |
| **R5: PR body encoding edge cases** | (j) Auto-gen file refs | `gh api` returns UTF-8 by default; explicit `head -1` for L1 extraction; trim CRLF |
| **R6: d054 trigger path missing in CI** | (i) Platform hard constraints | Sprint 13 P0 #1 owner territory (d050b TC1) adds trigger paths to `.github/workflows/lint-and-test.yml`; d054 ships ready, CI integration owner-implementable |

**9-Lens attestation** (per ADR-0049 §9-Lens Review Checklist):
- (a) Data flow: gh api → JSON parse → L1 extract → regex match (cite observable hand-off at each step)
- (b) Runtime preconditions: `command -v gh`, `command -v jq`, `gh auth status` preflight; exit 2 with explicit error
- (c) Canonical entry: only entry is `bash d054-*.sh <PR_NUMBER>` or `--self-test`; no side-channel
- (d) Silent-skip risk: RED-first self-test ensures violations don't silently pass; live mode reports specific TC
- (e) Idempotency: re-fetch on each invocation, no state, no caching; safe to retry
- (f) Observability: structured output (PASS/FAIL/INFO + TC id + L1 quote), exit codes 0/1/2, machine-parseable
- (g) Security & privacy: PR body content only, no secrets/PII handling; gh API uses standard auth
- (h) Workflow YAML SHA pin: N/A (no workflow changes in this design; CI integration is owner territory)
- (i) Platform hard constraints: N/A (no GA files in this design; trigger path is owner-implementable)
- (j) Auto-gen file refs: N/A (no auto-gen files; d054 reads live PR body via gh api)

## Observability

- **Self-test mode output**: TC-by-TC PASS/FAIL/INFO report with summary count
- **Live mode output**: PASS or FAIL with TC id + L1 quote + remediation hint
- **Exit codes**: 0=PASS, 1=FAIL, 2=preflight
- **Log fields** (for future CI integration): `tc_id`, `pr_number`, `l1_actual`, `violation_class`, `remediation`
- **Trace span name** (future): `d054.closes_anchor_check`

## Security & privacy

- **Authn/authz**: gh CLI uses standard user auth; no service account needed for d-test
- **PII fields**: PR body content only (no PII extraction or logging beyond L1)
- **Threat model**: same as d053 (per ADR-0027 §Threat model — read-only API calls, no write operations)

## Performance budget

- **Self-test mode**: <100ms (inline fixture, no API calls)
- **Live mode**: <2s p95 (single gh api call + jq parse + regex match)
- **Throughput**: N/A (one-shot, not batch)
- **Memory**: <10MB (jq + bash subprocess)

## Open questions

- [ ] **TC1 canonical case**: should d054 accept `Closes #N` AND `Closes #N.` (period at end)? Currently strict regex `^Closes #[0-9]+$` rejects period. Decision: strict (no period) per ADR-0050 §C9 strict spec.
- [ ] **Multiple Closes-anchors**: should d054 check ALL Closes-anchors in body, not just L1? Currently L1-only (per ADR-0050 §C9 spec which says "L1 of PR body"). Decision: L1-only for now, deeper multi-anchor check deferred to d054a (Sprint 14+) if observed gap.
- [ ] **Fixes-anchors vs Closes-anchors**: d054 is Closes-anchor only. Fixes-anchors have different semantics (issue tracker linkage without auto-close). Decision: Closes-only per ADR-0050 §C9 spec.
- [ ] **CI integration trigger path**: Sprint 13 P0 #1 owner territory adds trigger paths. d054 should also gate on `.claude/CLAUDE.md` per file ownership matrix human-only territory. Owner decision.

## Estimated complexity

- **T-shirt size**: M (matches d053 sister-pattern complexity)
- **arch**: 0.5 SP ✅ (this design doc)
- **dev**: 1.0 SP ✅ (d-test impl per spec)
- **tester**: 0.5 SP ✅ (sign-off via RED-first self-test + live mode TCs)
- **Total**: 2.0 SP ✅ (matches Issue #468 sizing)

**Confidence**: 85% (sister-pattern to d046/d048/d053 is well-established; TCs are explicit; only risk is gh API edge cases).

## Sister-pattern cross-refs

- **d046** (Issue #413 jq-filter guard) — single-purpose sister, deep-narrow pattern
- **d048** (Issue #425 AC2.1 layered defense) — Layer 5 reviewer chain, single-purpose sister
- **d050b** (Issue #440 behavioral workflow test framework) — d-test framework base
- **d051** (Issue #414 RETRO-005 #26 regression anchor) — 5-soul canonical text parity
- **d052** (Issue #461 agent-watch.sh hardening) — watcher hardening sister
- **d053** (Issue #463 ADR-0050 pre-merge 4-cat verification) — MERGED 2026-06-27T05:24:27Z, includes C9 shallow
- **d054** (Issue #468 this design) — dedicated Closes-anchor d-test, deep-narrow

## Sister-ADRs

- ADR-0012 (4-cat invariant)
- ADR-0044 (RED-first TDD)
- ADR-0049 (3-layer d-test defense, d050b framework)
- ADR-0050 (pre-merge 4-cat verification, §C9 strict format spec)
- RETRO-007 watchlist entry #5 (origin)

## Implementation guide

Per ADR-0046 §Implementation guide pattern:

### Step 1: arch (this design doc) — 0.5 SP ✅
- ✅ Create `docs/designs/d054-closes-anchor-strict-format-design.md`
- Open PR (type:docs, agent:architect, cc:developer + cc:tester)

### Step 2: dev d-test impl — 1.0 SP
- Create `scripts/tests/d054-closes-anchor-strict-format.sh`
- Self-test mode: 8 TCs inline fixture, RED-first
- Live mode: `gh api` + `jq` + `head -1` + regex match
- 9-Lens compliance per ADR-0049
- Exit codes 0/1/2 per spec
- Sister-pattern parity with d053 C9 (same regex)

### Step 3: tester sign-off — 0.5 SP
- RED-first: verify self-test expected = 1 PASS + 7 FAIL
- Live mode TCs: run on real PRs (PR #464, #465, #472, #473), verify expected outcomes
- 9-Lens attestation per ADR-0049
- Approve via standard tester sign-off flow

### Step 4: owner squash (gate)
- Owner squashes PR after arch + dev + tester approval
- Sister-pattern to d053 squash sequence

### Step 5: CI integration (Sprint 13 P0 #1 owner territory)
- Owner adds trigger paths to `.github/workflows/lint-and-test.yml`:
  ```yaml
  paths:
    - 'scripts/tests/d054-*'
    - '.github/workflows/**'
    - '.claude/**'
  ```
- Sister-pattern to d053 CI integration (AC4 of Issue #463)

## References

- [Issue #468](https://github.com/atilcan65/AtilCalculator/issues/468) — STORY-13-P2-#6 origin
- [d053 spec](../decisions/ADR-0050-pre-merge-4-cat-verification.md#doctrinal-checks-layer-2--beyond-label-checkyml-presence-checks) — §C9 strict format
- [PR #462 cmt 4813352612](https://github.com/atilcan65/AtilCalculator/pull/462) — closes-anchor mid-paragraph catch precedent
- [PR #472](https://github.com/atilcan65/AtilCalculator/pull/472) — Sprint 13 C9 violation observed (PM amended)
- [PR #473](https://github.com/atilcan65/AtilCalculator/pull/473) — Sprint 13 C9 violation observed (PM amended)
- [Sprint 13 plan §P2 #6](../sprints/sprint-13/plan.md)
- [Sprint 13 proposed-scope §P2 #6](../sprints/sprint-13/proposed-scope.md)
- [RETRO-007 watchlist entry #5](../sprints/sprint-13/proposed-scope.md#doctrinal-carry-forwards-retro-007-watchlist-9-entries)
- Sister-pattern: [d046 jq-filter guard](../decisions/), [d048 Layer 5 reviewer chain](../decisions/)

— @architect, 2026-06-27 (Sprint 13 P2 #6 d054 design doc, closes Issue #468 RETRO-007 watchlist #5)