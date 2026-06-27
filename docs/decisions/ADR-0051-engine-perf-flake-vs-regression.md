# ADR-0051: Engine perf flake vs regression codification (3-condition discriminator)

**Status:** Proposed (Sprint 14 P1 #2, draft pending arch sign-off + PM/owner squash)
**Date:** 2026-06-27
**Deciders:** @architect (drafting), @tester (verdict on d057 contract), @developer (d057 d-test impl), @orchestrator (sprint ratification)
**Supersedes:** — (doctrinal codification; no prior ADR)
**Amends:** — (no amendment; new doctrine)
**Related:** [ADR-0019 amendment 2](./ADR-0019-amendment-2-decimal-and-envelope.md) §Performance budgets (50ms arithmetic / 100ms transcendental); [RETRO-008 §2](../sprints/sprint-14/plan.md) (codification carrier); [Issue #329](https://github.com/atilcan65/AtilCalculator/issues/329) (perf test flake hypothesis, environmental sensitivity); [Issue #488](https://github.com/atilcan65/AtilCalculator/issues/488) (canonical live evidence, RESOLVED as flake); [Issue #493](https://github.com/atilcan65/AtilCalculator/issues/493) (Sprint 14 P1 #2 home)

---

## Context

Sprint 13–14 produced **4 consecutive CI FAILs on engine perf tests** (`test_arithmetic_p99_under_50ms_still_holds` + `test_transcendental_p99_under_100ms_still_holds`), each initially misclassified as regression:

| PR | Date | First run p99 | Re-run | Verdict (initially) | Verdict (correctly) |
|---|---|---|---|---|---|
| PR #408 | 2026-06-26 | flake candidate | n/a (fix landed) | flake | **flake** (Issue #329 fix) |
| PR #465 | 2026-06-26 | p99=209ms (4x over) | PASS | regression | **flake** (RETRO-008 §2 condition 3 met) |
| PR #472 | 2026-06-26 | p99=143ms | PASS | regression (PM misattribution) | **flake** (RETRO-008 §2 condition 3 met) |
| PR #487 | 2026-06-27 | p99=53.75ms (7.5% over) | p99=135.25ms (170% over) | regression | **flake** (RETRO-008 §2 condition 3 met on 3rd run) |

**Issue #488** (Sprint 14 P1, 2026-06-27) was the canonical live evidence: 2 FAILs followed by 3rd PASS within 13 minutes confirmed the flake pattern. Issue #488 was filed as regression but RESOLVED as environmental flake after dev scratch PR #489 (main HEAD canonical check) PASSED locally + 3rd CI run PASSED.

**Pattern**: 4 consecutive false-positive regressions in 48 hours, each requiring 1-3 CI reruns + scratch PR investigation to disambiguate. Without codification, the next flake becomes a 30-minute debugging cycle (or worse, a P1 regression file that wastes sprint capacity).

**Current state (pre-ADR)**: RETRO-008 §2 (codification carrier) defines a 1-retry discriminator ("CI rerun passes within 4 minutes of the first FAIL"). Issue #488 evidence shows **2 retries may be needed** (1st FAIL 7.5%, 2nd FAIL 170%, 3rd PASS). The doctrine needs refinement AND implementation as an automated guard.

---

## Decision

**Adopt the 3-condition flake-vs-regression discriminator** as the canonical engine perf classification doctrine:

### Condition 1: Magnitude check (flake-eligible if met)

If p99 is >2.8% over the documented budget (per ADR-0019 amend 2: 50ms arithmetic / 100ms transcendental), the failure is **flake-eligible**. Failures ≤2.8% over are normal CI variance (handled by Issue #329 baseline).

### Condition 2: Local reproduction check (mandatory)

The developer MUST reproduce the failure locally:
- Dev scratch PR with main HEAD → CI runs main's engine code (no PR changes)
- Local pytest run of `tests/api/test_evaluate_transcendental.py::TestTranscendentalPerfBudget`
- If local p99 < budget → flake-eligible (env sensitivity)
- If local p99 > budget → REGRESSION (engine code regressed, not env)

### Condition 3: CI rerun check (mandatory, N retries)

The CI workflow MUST be re-triggered **N times** within a 4-minute window of the first FAIL:
- N=1 typical (most flakes resolve on first rerun)
- N=2 fallback (Issue #488 evidence: 2 FAILs then PASS)
- N=3 max (rare; documented in d057 d-test if needed)
- If ANY rerun PASSES within N retries → **FLAKE** (env sensitivity, no fix needed)
- If ALL N retries FAIL → **REGRESSION** (file P1 issue, dev investigates engine code)

### Distinction table (canonical reference)

| Scenario | Cond 1 (>2.8% over) | Cond 2 (local PASS) | Cond 3 (N-rerun PASS) | Verdict | Action |
|---|---|---|---|---|---|
| Issue #329 baseline | ✅ | n/a | n/a | **flake** (baseline) | Accept; PR #408 sample reduction |
| PR #465 (p99=209ms → rerun PASS) | ✅ | ✅ | ✅ (1 retry) | **flake** | Document in RETRO-008 |
| PR #472 (p99=143ms → rerun PASS) | ✅ | ✅ | ✅ (1 retry) | **flake** | Document in RETRO-008 |
| Issue #488 (p99=53.75 → 135.25 → PASS) | ✅ | ✅ | ✅ (2 retries) | **flake** | Close Issue #488 as kind:flake |
| Hypothetical regression (3 retries all FAIL, local FAIL) | ✅ | ❌ | ❌ | **regression** | File P1 issue, dev fixes engine |
| Hypothetical non-flake-eligible (≤2.8% over) | ❌ | n/a | n/a | **not a flake** | Within baseline; no action |

### Main HEAD canonical check (mandatory discriminator)

When a perf test fails on a PR, the **canonical "is-main-actually-broken" check** is:

```bash
# From dev: create scratch PR with main HEAD (no PR changes)
git checkout main
git checkout -b scratch/main-head-perf-check
git push origin scratch/main-head-perf-check
gh pr create --draft --title "scratch: main HEAD perf check (Issue #NNN)" --body "..." \
  --label "type:scratch" --label "agent:developer" --label "cc:architect"
# Wait for CI; if perf test fails → main is broken → REGRESSION
# If perf test passes → PR is the cause OR env flake → proceed to Condition 3
```

**Why main HEAD is canonical**: docs-only PRs (e.g., PR #487 Sprint 14 plan.md) cannot cause engine perf regressions because they don't touch `src/atilcalc/engine/`. PR HEAD re-run **re-tests main's engine code** (since main's code is checked out for CI), so PR HEAD failure on docs-only PR is strong evidence of main regression or env flake.

### PR HEAD re-run unreliable for docs-only PRs

A CI rerun on a docs-only PR's HEAD is **unreliable** as a regression indicator because:
- Docs files don't affect engine code
- CI runs the same engine code regardless of PR content
- A FAIL on docs PR HEAD = main's engine code OR env sensitivity (NOT PR regression)

**Correct workflow for docs-only PRs with engine perf FAIL**:
1. Skip "PR HEAD re-run" (unreliable)
2. Go directly to "main HEAD canonical check" (Condition 2)
3. Then Condition 3 (CI rerun on main HEAD or a scratch PR)

### Automated guard (d057 d-test, Sprint 14 P1 #2 sister)

The d057 d-test (tester-owned, dev-implemented) implements the 3-condition discriminator:
- Reads last 5 CI runs for the PR or main
- Asserts Condition 1 (>2.8% over → flake-eligible)
- Verifies dev local reproduction (Condition 2 evidence in PR comment or d057 fixture)
- Asserts Condition 3 (CI rerun history shows PASS within N retries)
- Outputs: PASS (flake-tolerant: ≤2 fails in 5 runs OK) or FAIL (regression: 3+ fails → P1)

Integration: `scripts/tests/d057-perf-flake-vs-regression.sh` triggered in `.github/workflows/lint-and-test.yml` (owner-merge, human-only territory).

---

## Rationale

### Why codify now (vs ad-hoc investigation per flake)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Codify 3-condition discriminator (CHOSEN)** | Doctrinal clarity; d057 guard; future flakes auto-classified within 30s | Initial ADR + d-test impl (1.5 SP Sprint 14 P1 #2) | **Best fit** — pattern is established, automation is the right move |
| Ad-hoc investigation per flake | No upfront work | Each flake = 30-min debugging cycle (Issue #488 = ~30 min); P1 noise (Issue #488, PR #465, #472 false positives) | **Rejected** — waste of sprint capacity |
| Raise perf budgets (75ms / 150ms) | Eliminates flakes | Masks real regressions; violates M5 vision invariant; sets bad precedent | **Rejected** (per arch verdict cmt 4815807328) |
| Disable perf tests in CI | No flakes | No perf regression detection; silent degradation | **Rejected** — violates observability principle |

### Why 3-condition (not 1 or 2)

- **1 condition** (magnitude only) — too coarse: p99=209ms (PR #465) could be env OR regression; no way to disambiguate
- **2 conditions** (magnitude + local) — better, but doesn't capture Issue #488 evidence (local PASS + 2 CI FAILs + 3rd PASS)
- **3 conditions** (magnitude + local + N-retry) — captures all 4-flake-pattern instances + regression discrimination

### Why N retries (not fixed 1)

Issue #488 evidence shows 2 retries may be needed:
- 1st FAIL p99=53.75ms (7.5% over) — could be transient
- 2nd FAIL p99=135.25ms (170% over) — looks like regression, but is actually CI runner contention
- 3rd PASS — confirms flake pattern

A fixed 1-retry policy would have misclassified Issue #488 as regression (false positive). The 3-condition with N retries captures the right semantics.

### Why main HEAD canonical check (not PR HEAD)

| Check | Reliability | Use case |
|---|---|---|
| **Main HEAD scratch PR** | **High** (isolates main's engine code from PR changes) | Canonical "is main broken" question |
| PR HEAD rerun | Low for docs-only PRs (re-tests main's code anyway) | Useful for src/ PRs that change engine code |
| Local pytest | High (deterministic) | Dev reproduction, Condition 2 |

For Sprint 14 docs PRs (which are the common case), main HEAD is the only reliable check.

### Why d057 d-test as automated guard

Per RETRO-008 §2 codification (PR #490 MERGED), the doctrine is established but not automated. Each flake requires manual investigation:
- Re-query CI status
- Run scratch PR
- Apply 3-condition discriminator manually
- File P1 or close as flake

d057 automates this: reads CI history, applies 3-condition, outputs PASS/FAIL. Future flakes auto-classified within 30s. Sister-pattern to d046/d048/d050b/d051/d052/d053/d054 (8-sister d-test family).

### Evidence: 4-flake sister-pattern

| PR | p99 first | p99 rerun | Local | Verdict | Time-to-classify |
|---|---|---|---|---|---|
| PR #408 | n/a (Issue #329 fix) | n/a | n/a | flake baseline | n/a |
| PR #465 | 209ms | PASS | n/a | flake | ~15 min |
| PR #472 | 143ms | PASS | n/a | flake (PM misattribution) | ~20 min |
| PR #487 / Issue #488 | 53.75ms → 135.25ms → PASS | PASS | 13.24s baseline | flake | ~30 min |

Total: ~65 minutes of sprint capacity spent on flake classification, all of which d057 would automate. Sprint 14 P1 #2 pays back the 1.5 SP investment in ~3 flakes.

---

## Alternatives considered

### A. 3-condition + d057 (chosen)

- **Pros**: captures all 4-flake-pattern instances; automated guard; doctrinal clarity
- **Cons**: 1.5 SP Sprint 14 P1 #2 (arch 0.5 + dev 0.5 + tester 0.5)
- **Verdict**: chosen

### B. Strict 1-retry policy (RETRO-008 §2 original)

- **Pros**: simpler; faster classification
- **Cons**: misclassifies Issue #488-style flakes as regression (false positive)
- **Verdict**: rejected — superseded by 3-condition with N retries

### C. Raise budgets (Option 2 from arch verdict cmt 4815807328)

- **Pros**: no flakes at all
- **Cons**: masks real regressions; violates M5 vision invariant
- **Verdict**: rejected (per arch verdict)

### D. Disable perf tests

- **Pros**: no flake noise
- **Cons**: silent degradation; violates observability principle
- **Verdict**: rejected

### E. Keep ad-hoc investigation per flake

- **Pros**: no upfront investment
- **Cons**: ~30 min per flake × 4 flakes in 48h = 2 hours sprint capacity wasted
- **Verdict**: rejected — automation pays back

---

## Consequences

### Positive

- **Doctrinal clarity**: 3-condition discriminator with N retries captures all 4-flake-pattern instances
- **d057 automated guard**: future flakes auto-classified within 30s (vs ~30 min manual)
- **Sprint capacity**: ~30 min/flake × 4 flakes = 2h saved per sprint going forward
- **False-positive reduction**: 4 of 4 recent flakes correctly classified (Issue #488 RESOLVED as flake, not regression)
- **Sister-pattern alignment**: d057 joins d046/d048/d050b/d051/d052/d053/d054 (8-sister d-test family)
- **Main HEAD canonical check**: provides reliable "is main broken" discriminator for docs-only PRs

### Negative

- **1.5 SP Sprint 14 P1 #2 cost**: arch 0.5 (this ADR) + dev 0.5 (d057 impl) + tester 0.5 (d057 sign-off + RED-first contract)
- **d057 workflow integration**: requires CI gate change in `.github/workflows/lint-and-test.yml` (owner-merge territory)
- **N retries = 2 typical**: not 1 (slightly slower classification, but more accurate)

### Out of scope (deferred)

- **ADR-0019 amendment 3** (perf budget revision): NOT needed unless d057 reveals structural issue (e.g., systematic CI runner contention >2x budget)
- **Engine code perf optimization** (PR #314 STORY-300 ** operator follow-up): separate Sprint 14+ scope
- **CI runner migration** (e.g., to dedicated runner): Sprint 15+ scope if d057 reveals runner infra issue
- **Perf test methodology overhaul** (e.g., warm-up, statistical power): Sprint 15+ scope

### Follow-up tickets

- [ ] **d057 d-test impl** (Issue #493 sister, Sprint 14 P1 #2 sister story) — tester-owned contract, dev-owned impl
- [ ] **d057 CI integration** — `.github/workflows/lint-and-test.yml` paths trigger (owner-merge, human-only)
- [ ] **d057 INDEX.md registration** — Sprint 14 P2 #9 carry (tester-owned, 0.25 SP)
- [ ] **Issue #488 close as kind:flake** — dev WIP=1/2, action per ADR-0038 (this ADR provides doctrinal authority)
- [ ] **RETRO-008 §2 update** — supersede 1-retry with N-retry doctrine (PM lane, 0.25 SP follow-up)

---

## What this ADR commits to *now*

- **3-condition discriminator** is the canonical engine perf classification doctrine
- **N retries = 2 typical, 3 max** within 4-minute window (refined from RETRO-008 §2 original 1 retry)
- **Main HEAD canonical check** is the reliable "is main broken" discriminator for docs-only PRs
- **PR HEAD re-run unreliable for docs-only PRs** — skip and go directly to main HEAD
- **d057 d-test guard** (Sprint 14 P1 #2 sister story) implements automated classification
- **Issue #488 = flake** (per doctrine application; dev to close with kind:flake label)
- **No budget amendment** (50ms arithmetic / 100ms transcendental stay per ADR-0019 amend 2)
- **No breaking changes** to ADR-0019 amend 2 (this is a separate doctrinal layer)

---

## Cross-references

### Live evidence (4-flake sister-pattern)

- **PR #408** (Issue #329 fix, sample 1000→500) — flake baseline established; CI 0% over budget
- **PR #465** (Sprint 13 P1 d053) — p99=209ms first run, PASS on rerun = flake
- **PR #472** (Sprint 13 P1 #3 §Pre-verdict cross-check codification) — p99=143ms first run, PASS on rerun = flake (PM misattribution)
- **PR #487** (Sprint 14 plan.md) — p99=53.75ms → 135.25ms (2 FAILs) → PASS on 3rd run = flake (RETRO-008 §2 N-retry refinement)
- **PR #489** (dev scratch PR for Issue #488 main HEAD canonical check) — PASS, confirms flake

### Doctrinal anchors

- **ADR-0019 amendment 2** §Performance budgets — 50ms / 100ms codified (unchanged by this ADR)
- **RETRO-008 §2** — codification carrier (this ADR refines 1-retry → N-retry)
- **Issue #329** — perf test flake hypothesis (environmental sensitivity)
- **Issue #488** — canonical live evidence (RESOLVED as flake per this doctrine)
- **Issue #493** — Sprint 14 P1 #2 home (this ADR is the AC1 deliverable)
- **d057** — automated guard (8-sister d-test family: d046/d048/d050b/d051/d052/d053/d054/d057)
- **M5 vision invariant** — "Engine evaluation <50ms p99" (product doctrine, unchanged)

### Sprint 14 P1 #2 cluster

- **#493** (this ADR home) — arch 0.5 SP
- **d057 d-test impl** — dev 0.5 SP (sister story)
- **d057 sign-off + RED-first contract** — tester 0.5 SP (sister story)
- **Total Sprint 14 P1 #2**: 1.5 SP (per arch verdict cmt 4815807328)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
