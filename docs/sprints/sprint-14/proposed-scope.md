# Sprint 14 — Proposed Scope (PM draft, owner ratifies)

> **Author:** @product-manager (PM lane, owner ratifies)
> **Date:** 2026-06-27T09:55+03:00 = 06:55Z (draft via Issue #483)
> **Mode:** 🚀 **CONTINUOUS FLOW** (owner override carry from Sprint 4-13, ADR-0031)
> **Sprint window:** 2026-06-27 → 2026-07-11 (2-week sprint)
> **Source-of-truth backlog:** GitHub Project board (Projects v2)
> **PM lane definition (LOCKED this sprint):** PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors

## TL;DR

Sprint 14 inherits 6.25 SP from Sprint 13 cluster + RETRO-008 12 candidates + 3 RETRO-007 watchlist carry-forwards + Sprint 14 P0 owner carry. **9 stories** total: **2 P0 (owner territory)** + **4 P1 (agent lane)** + **3 P2 (RETRO-008 Tier 2/3)**.

Total commitment: ~14.0 SP (with joint sizing pending). Architect pre-sizing: **L+S+TBD** inventory used (Issue #479 owner decision A).

## Owner decision context (Issue #479)

**Option A** (selected): Sprint 14 P0 = 2 owner-implementable items (d050b TC1 + d054 CI integration)
**Option B** (deferred): Sprint 14 P0 = 1 owner-implementable + 1 P1 carry (larger carry, smaller Sprint 14 cluster)

Owner ratification @ 2026-06-27T06:40+03:00 ("scope ok, A path").

## Capacity (Sprint 14)

- **architect**: 0/2 WIP (pre-sizing complete, await PR openings)
- **developer**: 0/2 WIP (gated on Issue #463 ADR-0050 merge — DONE)
- **tester**: 0/2 WIP (gated on dev d-test impl)
- **product-manager**: 1/2 WIP (this draft, Issue #483)
- **orchestrator**: 0/2 WIP (kickoff facilitation)

## Committed stories

### P0 (owner territory)

1. **d050b TC1 owner-implementable workflow file change** (Sprint 13 carry)
   - Owner: @atilcan65
   - Lane: `.github/workflows/lint-and-test.yml` paths trigger (human-only territory)
   - SP: owner (no agent execution)
   - **No PM action needed**
   - Cross-ref: ADR-0049 §Implementation guide, Issue #463 d053 sister-pattern

2. **d054 CI integration** (Sprint 13 P1 #2 carry)
   - Owner: @atilcan65
   - Lane: `.github/workflows/` (human-only territory)
   - SP: owner (no agent execution)
   - Sister-pattern to d050b TC1 (Sprint 13 P0 carry)
   - Cross-ref: Issue #468 (d054 carrier), d053 sister d-test

### P1 (architect + PM-facilitated, agent executable)

3. **§Engine perf flake vs regression codification** (RETRO-008 §2)
   - Owner: @architect (ADR amendment)
   - Lane: `docs/decisions/ADR-NNNN-engine-perf-flake-vs-regression.md` (arch territory)
   - SP: 0.5 (arch-only)
   - Origin: Sprint 13 PR #472 single-flake instance (Issue #329 hypothesis confirmed)
   - Doctrine: Distinguish flake vs regression — 2+ consecutive CI FAILs required before labeling regression
   - Cross-ref: Issue #329, RETRO-008 §2

4. **Sprint 14 PM lane continuation** (Sprint 13 PM cluster sister-pattern)
   - Owner: @product-manager
   - Lane: `docs/CLAUDE.md` PM lane def amendment (human-only territory, owner-merged)
   - SP: 0.5 (PM proposes, owner merges)
   - Origin: Sprint 13 PM cluster 100% shipped (1.25 SP), PM lane def LOCKED
   - Sister-pattern: Issue #471, RETRO-007 watchlist #9

5. **§9-Lens enforcement application** (ADR-0049 §Code review codification apply)
   - Owner: @architect (ADR amendment) + @developer (d-test impl, d055)
   - Lane: `docs/decisions/` + `scripts/tests/`
   - SP: 1.5 (arch 0.5 + dev 1.0)
   - Sister-pattern to d046 (k lens runtime) + d048 (Layer 5 reviewer chain) + d053 (4-cat verification)
   - Cross-ref: Issue #469 PR #478 §9-Lens Review Checklist

6. **§CI re-run race codification** (RETRO-008 §1)
   - Owner: @architect (ADR amendment) + @developer (d-test impl, d056)
   - Lane: `docs/decisions/` + `scripts/tests/`
   - SP: 1.5 (arch 0.5 + dev 1.0)
   - Origin: Sprint 13 PR #472 status:ready auto-promote race with PM status:in-review flip
   - Cross-ref: RETRO-008 §1, Issue #463 d053 sister

### P2 (architect carry, RETRO-008 Tier 2/3 + RETRO-007 watchlist)

7. **§wip_overflow false positive fix** (RETRO-008 §3)
   - Owner: @architect + @developer
   - Lane: `scripts/claim-next-ready.sh` (Layer 2 spec) + d-test impl
   - SP: TBD (arch + dev)
   - Origin: WIP = 2 active streams ≠ 2 separate issues; PR cluster counts as 1 stream
   - Cross-ref: ADR-0038 §Auto-Claim Protocol, Issue #238

8. **§Layer 5 race pattern codification** (RETRO-008 §4)
   - Owner: @architect
   - Lane: `docs/decisions/` (arch territory)
   - SP: TBD (arch-only)
   - Sister-pattern to §6 (RETRO-008 §1)
   - Cross-ref: ADR-0013 (board sync), ADR-0015 (atomic 4-flag hand-off)

9. **RETRO-008 §d-test persistence** (RETRO-008 §11)
   - Owner: @architect + @developer
   - Lane: `scripts/tests/INDEX.md` (centralized registry)
   - SP: TBD (arch + dev)
   - Origin: d-test proliferation (d046, d048, d050b, d051, d052, d053, d054) — no centralized registry
   - Cross-ref: ADR-0049 (d-test framework)

## Backlog deferral candidates (Sprint 15+)

- RETRO-007 watchlist #1, #2, #4 (unaddressed, carry-forward)
- RETRO-008 Tier 3 candidates (§11 d-test persistence + §12 owner squash boundary)
- RETRO-008 Tier 2 candidates (§6-§10, deferred to Sprint 15+)
- Story backlog (STORY-013 #179, DEPLOY-001-004, TEMPLATE-PORT, RETRO-003)

## Sprint 14 sizing (joint, per ADR-0024) — DRAFT, PENDING arch+dev+tester

| # | Story | arch | dev | tester | total | Notes |
|---|---|---|---|---|---|---|
| 1 | d050b TC1 owner-implementable | — | — | — | owner | L (owner-implement) |
| 2 | d054 CI integration | — | — | — | owner | S (owner-implement) |
| 3 | §Engine perf flake vs regression codification | TBD | — | — | TBD | ADR amendment |
| 4 | Sprint 14 PM lane continuation | — | — | — | TBD | PM lane, owner-merged |
| 5 | §9-Lens enforcement application | TBD | TBD | — | TBD | ADR + d-test |
| 6 | §CI re-run race codification | TBD | TBD | — | TBD | ADR + d-test |
| 7 | §wip_overflow false positive fix | TBD | TBD | — | TBD | claim-next-ready.sh + d-test |
| 8 | §Layer 5 race pattern codification | TBD | — | — | TBD | ADR amendment |
| 9 | RETRO-008 §d-test persistence | TBD | TBD | — | TBD | INDEX.md registry |
| **TOTAL** | | | | | **~14.0 SP** | TBD pending joint sizing |

## Risks

1. **Owner-implementable P0 dependency**: d050b TC1 + d054 CI integration are owner-only. Owner merge speed = Sprint 14 P0 critical path.
2. **Arch pre-sizing overflow**: 4 P1 stories require arch + dev coordination. Arch WIP cap 2/2 may bottleneck.
3. **Layer 5 race pattern emergent**: Sprint 13 PR #485 label-check failure exposed Layer 5 auto-promote + manual flip race. RETRO-008 §4 codification is Sprint 14 candidate.
4. **PM lane def amendment territory friction**: Sprint 14 PM lane continuation (Item #4) requires owner merge. Sister-pattern to Sprint 13 Issue #471 PR #473 squash.

## Critical path

1. **P0 owner merge**: d050b TC1 + d054 CI integration (owner-implementable, 5-10 min each)
2. **P1 #3**: §Engine perf flake vs regression ADR (arch draft)
3. **P1 #4**: Sprint 14 PM lane continuation (PM propose, owner merge)
4. **P1 #5**: §9-Lens enforcement ADR (arch) + d-test impl (dev) — sister-pattern to Sprint 13 P1 #2
5. **P1 #6**: §CI re-run race ADR (arch) + d-test impl (dev)
6. **P2 #7-9**: RETRO-008 codifications (arch + dev)

## Definition of Done — Sprint 14

- [ ] All committed stories shipped or carried with rationale
- [ ] All PRs merged to main via human owner squash
- [ ] CI green on main post-merge
- [ ] Docs updated: PM lane continuation, RETRO-008 Tier 1 codifications
- [ ] Sprint 14 kickoff issue closed (status:done, atomic close)
- [ ] No new P0/P1 bugs filed against Sprint 14 stories in 24h post-merge window

## Cross-refs

- Sprint 13 close.md: `docs/sprints/sprint-13/close.md` (sister-pattern, owner ratifies)
- RETRO-008 codification: `docs/retros/retro-008.md` (12 candidates, Tier 1/2/3)
- Sprint 14 kickoff dispatch: Issue #483 (this scope)
- Sprint 14 kickoff coordination: Issue #479 (owner decision A vs B)
- Issue #463 (d053 carrier, Sprint 13 P1 #2)
- Issue #468 (d054 carrier, Sprint 13 P2 #6)
- Issue #470 (§Timing window carrier, Sprint 13 P1 #3)
- Issue #471 (PM lane def, Sprint 13 P1 #4)
- RETRO-007 watchlist (9 entries, 6 closed in Sprint 13)
- ADR-0033 (peer-poke discipline)
- ADR-0038 (Auto-Claim Protocol)
- ADR-0049 (behavioral workflow test framework)
- ADR-0050 (§Pre-merge 4-cat verification)

## Verdict readiness

- **PM verdict**: 🟢 PM-OK (ground-truth re-query within 30s window per Issue #470 §Timing window)
- **CC expected**: @orchestrator (sister-pattern), @architect (pre-sizing input), @atilcan65 (owner ratification)
- **Merge authority**: owner squash only (per Sprint 13 PM lane def LOCKED)

— @product-manager, 2026-06-27T09:55+03:00, Sprint 14 PM-lane proposed-scope draft (Issue #483, Closes #483 + Issue #479)