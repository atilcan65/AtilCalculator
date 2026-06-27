# Sprint 12 — Plan

> **Author:** @orchestrator
> **Date:** 2026-06-26T20:12+03:00 = 17:12Z
> **Mode:** 🚀 **CONTINUOUS FLOW** (owner override carry from Sprint 4-11, ADR-0031)
> **Trigger:** PR #435 SQUASH MERGED @ 17:03:42Z (commit 1fb42bd) — Sprint 11 ATOMIC CLOSE complete
> **Kickoff issue:** #451 (`status:in-progress`, `sprint:current`, `agent:product-manager`)
> **Close ledger (Sprint 11):** [../sprint-11/close.md](../sprint-11/close.md)

## TL;DR scope

- **P0+P1 committed**: **7.0 SP** across **3 stories** (Issue #448 1.0 + Issue #450 0.5 [test] + Issue #440 3.0 + Issue #414 2.5)
- **Optional**: +0.5 SP (Issue #447 ADR-0048 §Live validation, owner squash pending)
- **Sprint capacity**: ~22 SP cap → 7.0 SP well within (32% allocation, leaves 15 SP for hotfixes/discovered work)
- **3 parallel lanes**: dev+owner (P0 workflow fix) + tester (P0 d-test + P1 d050b d-test) + PM-facilitated (P1 5-soul amend)

## SP delivery matrix (per PM framing, Issue #451)

| P-tier | Story | SP | Issue | PR | Owner(s) | Status |
|---|---|---|---|---|---|---|
| **P0** | Layer 5 addLabel TypeError fix | 1.0 | #448 | (workflow fix PR pending owner ACK) | @developer + @owner (workflow territory) | status:blocked + sprint:next → awaiting owner decision |
| **P0** | d048 TC8 d-test (companion to #448) | 0.5 | (PR #450) | PR #450 | @tester | CI-blocked on Issue #448 fix OR owner admin-merge |
| **P1** | d050b behavioral workflow test framework (ADR-0049 + d-test + impl) | 3.0 | #440 | PR #443 (ADR-0049, owner squash pending) | @architect (ADR) + @tester (d-test RED) + @developer (impl) | status:ready + agent:tester |
| **P1** | 5-soul §Dispatch Discipline amend (RETRO-005 #26) | 2.5 | #414 | (combined PR, owner-merge-only) | @product-manager (facilitated) + all 5 souls | status:in-progress + sprint:current |
| **P1 (optional)** | ADR-0048 §Live validation amendment | 0.5 | #425 AC #2 | PR #447 (owner squash pending) | @architect (already authored) | status:ready + cc:human |
| (folded) | Issue #444 9-Lens sub-check (k) | 0.0 | (folded into ADR-0049 §Implementation guide step 4) | n/a | n/a | closed as duplicate of ADR-0049 step 4 |

**Total**: 7.0 SP committed (5.5 SP P1 + 1.5 SP P0 carry-forwards) + 0.5 SP optional = 7.5 SP

## Critical path (Sprint 12 P0 dependency chain)

1. **Owner decision on #448** (workflow fix path, owner territory) — gates P0 unblock
2. **PR #450 admin-merge OR Issue #448 fix** (P0 d-test companion) — gates CI green
3. **Owner squash sequence on PR #443 + #446 + #447** (Sprint 11 cascade carryover + Issue #447 optional)
4. **PM Sprint 12 capacity allocation broadcast** (THIS DOCUMENT) — fires NOW
5. **@tester dispatch on Issue #440** (P1 d-test RED-first per ADR-0044) — depends on PR #443 owner squash
6. **@architect ADR-0049 §Implementation guide step 4** (AC6+AC7 from Issue #444 folding) — depends on PR #443 owner squash
7. **@developer d050b framework impl** — depends on @tester d-test RED + @architect ADR Accepted
8. **PM-facilitated 5-soul amend PR** (Issue #414) — depends on 5-soul consultation cycle

## Parallel tracks (Sprint 12, all unblocked today)

- **P0 dev+owner lane**: Issue #448 fix (workflow file, owner territory per CLAUDE.md §File ownership matrix)
- **P0 tester lane**: PR #450 d-test TC8 (admin-merge OR Sprint 12 P0 with #448 fix)
- **P1 tester+arch+dev lane**: Issue #440 d050b (architect ADR + tester d-test + dev impl, sequential per ADR-0044 TDD RED)
- **P1 PM-facilitated lane**: Issue #414 5-soul §Dispatch Discipline amend (cross-role, owner-merge-only)

## Sprint 11 close-cascade carry-over (atomic close complete)

- ✅ PR #435 SQUASH MERGED @ 17:03:42Z (commit 1fb42bd, Sprint 11 close.md ledger)
- ✅ Issue #425 CLOSED (manual close @ 16:13:42Z, PR #434 attribution)
- ✅ 4 P0 hotfixes caught + resolved (#436/#439/#441/#448)
- 🟡 Owner squash queue: PR #443 + #446 + #447 (Sprint 11 docs cascade) + PR #450 (Sprint 12 P0 admin-merge pending)

## Doctrinal carry-forwards (from RETRO-006/007)

1. **§Pull-request-target self-test limitation** — workflow self-fix cannot fully validate; owner admin-merge required
2. **§Workflow self-fix canonical close path: Option B** — owner squash with admin override despite UNSTABLE
3. **§Closes #N format strict requirements** — uppercase C + line 1 + NO trailing text
4. **§Layer 5 silent-skip observability** — works as designed, docs-path vs non-docs-path differentiation
5. **§Sprint boundary discipline** — hotfix = bug fix + minimal regression test only
6. **§d-test framework scope discipline** — framework additions = planned story
7. **§Auto-Claim Protocol** (ADR-0038) — production-tested on Issue #425
8. **§Pre-merge 4-cat verification** (NEW from RETRO-007) — mandatory pre-flight check after 6 arch-related workflow regressions in 24h
9. **§d-test behavioral vs content-anchor** — d050b framework distinguishes runtime vs static
10. **§P0 hotfix branch-from-main discipline** — branch from main unless explicit owner override
11. **§Layer 4 sister-pattern at L337** — follow-up issue deferred (TC7 d-test covers)
12. **§Close-out anchor pattern** (NEW from PR #446) — closure traceability artifacts via docs PR
13. **§RETRO-007 watchlist** — 6 arch-related workflow regressions, pre-merge 4-cat verification mandatory

## Open items for owner

1. **PR #443 + #446 + #447 owner squash** (Sprint 11 cascade carry-over)
2. **PR #450 disposition**: admin-merge NOW OR Sprint 12 P0 with #448 fix
3. **Issue #448 fix path**: 1-line addLabel → addLabels on label-check.yml L507, owner-gated per file ownership matrix
4. **Issue #447 fold into Sprint 12 P1** (optional +0.5 SP) OR defer to Sprint 12 P2 cleanup follow-up

## Definition of Done — Sprint 12

- [ ] All committed stories shipped (7.0 SP, 100%) or carried with rationale
- [ ] All PRs merged to main via human owner squash
- [ ] CI green on main post-merge
- [ ] Docs updated: ADR-0049 (d050b), 5-soul §Dispatch Discipline amend, close.md (this sprint)
- [ ] Issue #451 closed (status:done, atomic close on final commit)
- [ ] No new P0/P1 bugs filed against Sprint 12 stories in 24h post-merge window
- [ ] Sprint 12 retrospective (Day 14 or as scheduled)

## Already shipped (Sprint 11 reference)

- ✅ PR #435 SQUASH MERGED @ 17:03:42Z — Sprint 11 close.md ledger
- ✅ Issue #425 CLOSED @ 16:13:42Z — manual close path (PR #434 attribution)
- ✅ ADR-0047 cross-repo watcher architecture (PR #420)
- ✅ ADR-0048 Layer 5 status:ready auto-add gating (PR #434)
- ✅ PR #438 + PR #445 (Issue #436/#441 hotfixes)
- ✅ 4 P0 hotfixes resolved in 24h cascade

— Orchestrator, 2026-06-26T17:12Z (Sprint 12 plan, post-Sprint 11 ATOMIC CLOSE)