# Sprint 15 — Plan (PM draft, owner ratifies)

> **Status**: 🟡 **DRAFT** (2026-06-27T17:50+03:00, PM lane per orchestrator delegation Issue #514)
> **Mode**: 🚀 **CONTINUOUS FLOW** (ADR-0031 owner override carry from Sprint 4-14)
> **Trigger**: PR #513 squash @ 2026-06-27T14:44:00Z (merge_sha ebf6bc8). Sprint 14 close-out COMPLETE.
> **Sizing matrix**: FULL LOCK per ADR-0024 (Issue #514, arch 3.5 + tester 4.75 + dev 4.25 = 12.5 SP bottom-up; PM 8.5-10.0 rough)
> **PM lane definition (LOCKED carry from Sprint 13+, per [ORCH→PM-CLARIFY-ACK] @ 22:42:21 +03)**: PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors
> **Close-out target**: docs/sprints/sprint-15/close.md (PM lane, owner ratifies)

## Goal

Sprint 14 P1 cluster 9/9 SHIPPED + RETRO-009 4/4 ceremony complete. Sprint 15 inherits:
1. **P0 owner-implementable carry** — d050b TC1 (Sprint 12-14 triple-carry, owner territory)
2. **RETRO-009 Tier 1 codifications** — 5 candidates (Sprint 15 P1, prioritized)
3. **§14 NEW DUAL-AXIS codification** — Sprint 15 P1 §3 directly addresses Issue #507/#508/#512 stale-label pattern
4. **arch-soul §9-Lens step 4 amendment** — Sprint 15 P1 (codification of PR #513 §Dispatch Discipline catch)
5. **d-test family 13-sister** — Sprint 15 P2 d059 (RETRO-009 §6 family persistence) + d060 (§1 companion) + d061 (§3 companion) per Option C workshop decision
6. **§Tester lane INDEX maintainer** — Sprint 15 P2 (carry from Sprint 14 P2 #11)

**Total**: 9 stories committed (P0+P1+P2), ~6.0-6.5 SP locked within capacity. Sprint 15 PM cluster is **small + targeted** (post-cluster-compression observation, RETRO-009 §8 candidate).

## Workshop Decisions (locked at Sprint 15 kickoff, per orchestrator delegation Issue #514 + tester 🔴 PR Review #515)

1. **d-test ID path**: **Option C** — d059 §6 (family persistence), d060 §1 (chain dep pollution companion), d061 §3 (post-squash label hygiene companion). 13-sister target on main post-Sprint 15 (was 10-sister).
2. **d059 variant**: **(a) chain dep pollution companion** — tester recommendation, highest priority per RETRO-009 §6, addresses LIVE INSTANCE #6 (PR #509). Tight d-test pair with STORY-016 §1 + d060.
3. **d059b (post-squash label hygiene companion)**: **DEFERRED to Sprint 16** — workshop decision.
4. **Branch-base spec ADR timing**: **ALONGSIDE §1 impl** — sister-pattern to other ADR pre-implementations. Arch P1 #6 owns spec.
5. **5 STORY-NNN.md AC files added**: STORY-016, STORY-017, STORY-019, STORY-022, STORY-023 (per tester 🔴 PR Review #515 §STEP 5 AC gap).

## Capacity (Sprint 15)

- **architect**: 0/0 WIP idle (Sprint 14 P1 5/5 SHIPPED + §9-Lens step 4 amendment queued)
- **developer**: 0/2 WIP idle (Sprint 14 P1 #6 AC1+AC2+AC5 SHIPPED, ready for Sprint 15 §1 + §3 + d059)
- **tester**: 0/2 WIP idle (Sprint 14 d031+d058 sign-offs done, ready for Sprint 15 §1 + §3 + §10 + d031 TC5/6/7 + d059)
- **product-manager**: 0/2 WIP idle (Sprint 14 PM lane + RETRO-009 ceremony SHIPPED, ready for Sprint 15 PM lane continuation §5)
- **orchestrator**: 0/2 WIP idle (Sprint 14 kickoff + RETRO-009 dispatch FIRED, ready for Sprint 15 kickoff coordination)

## Committed stories

### P0 (owner territory)

1. **d050b TC1 owner-implementable workflow file change** (Sprint 12 → 13 → 14 → 15 quad-carry)
   - Owner: @atilcan65
   - Lane: `.github/workflows/lint-and-test.yml` paths trigger (human-only territory)
   - SP: 0.25 (owner-implement)
   - **No PM action needed**
   - Cross-ref: ADR-0049 §Implementation guide, Issue #463 d053 sister-pattern, RETRO-008 §2

### P1 (LOCKED, agent executable) — 5 stories

2. **§1 pre-push branch-base check** (RETRO-009 §1) — LOCKED
   - Owner: @developer (pre-push hook impl) + @tester (d-test 9/9 RED-first per ADR-0044)
   - Lane: `scripts/pre-push/branch-base-check.sh` (new file) + `scripts/tests/d060-branch-base.sh` (sister-pattern, **d-test ID d060** per Option C workshop decision)
   - SP: 1.0 (dev 0.75 + tester 0.25)
   - Origin: PR #509 chain dep pollution (RETRO-009 §6 LIVE INSTANCE #6) + Sister-pattern to direct-push-to-main prevention hook
   - Doctrine: Tooling-level prevention of chain dep pollution — pre-push hook checks `git merge-base HEAD origin/main` against expected
   - Dependency: branch-base spec ADR (arch-owned, file **alongside** §1 impl per workshop decision — sister-pattern to other ADR pre-implementations)
   - AC: docs/backlog/STORY-016.md (full Gherkin AC1/AC2/AC3, created per tester 🔴 PR Review #515 fix)
   - Cross-ref: RETRO-009 §1, Issue #498 (PM lane continuation sister-pattern), PR #509 (LIVE INSTANCE), ADR-0044, ADR-0045, ADR-0049, ADR-0053, Issue #238

3. **§3 post-squash label hygiene sweep** (RETRO-009 §3) — LOCKED
   - Owner: @developer (sweep script impl) + @tester (d-test 9/9 RED-first)
   - Lane: `scripts/post-squash/label-hygiene.sh` (new file) + `scripts/tests/d061-label-hygiene.sh` (sister-pattern, **d-test ID d061** per Option C workshop decision)
   - SP: 0.5+1.0=1.5 (dev 1.25 + tester 0.25)
   - Origin: 3 LIVE INSTANCES of dual-axis lag in Sprint 14 P1 cluster — Issue #507 (status:in-progress stale), Issue #508 (status:ready stale), Issue #512 (closedBy:[] empty, cascade-stripped pre-close)
   - Doctrine: Auto-flip `status:*` → `status:done` on Closes-anchor + auto-remove stale `status:*` on squash via post-squash webhook
   - AC: docs/backlog/STORY-017.md (full Gherkin AC1/AC2/AC3, created per tester 🔴 PR Review #515 fix)
   - Cross-ref: RETRO-009 §3 + §4 (3-axis lag codification), Issue #507/#508/#512 (LIVE INSTANCES), ADR-0048 (Layer 5 race codification), ADR-0044, ADR-0049

4. **§5 RETRO-007 #10 NEW + Sprint 15 PM lane continuation** (RETRO-009 §5) — LOCKED
   - Owner: @product-manager (proposes) + @architect (review per ADR-0045 9-Lens) + @atilcan65 (owner merges soul file)
   - Lane: `.claude/agents/product-manager.md` §Auto-Claim Protocol amendment + RETRO-007 watchlist entry #10 NEW
   - SP: ~1.0 (PM 0.75 + arch 0.25)
   - Origin: RETRO-007 watchlist entry #10 NEW (codification of cluster-vs-single squash lag hypothesis from Sprint 14 P1 cluster)
   - Doctrine: Cluster-squash batch-lag pattern (Layer 5 converges faster on cluster squashes than single PRs) + Sprint 14 PM cluster sister-pattern continuation
   - Cross-ref: RETRO-009 §5, Issue #508 (cc pattern), RETRO-007 watchlist, Sprint 13 PR #473 squash (PM lane def amendment precedent)

5. **d031 TC5/6/7 update** (Sprint 14 P1 #6 follow-on) — LOCKED
   - Owner: @tester (d-test TC expansion)
   - Lane: `scripts/tests/d031-claim-next-ready.sh` (sister-pattern template)
   - SP: 0.25 (tester-only)
   - Origin: d031 was sister-pattern template for d058 (PR #506). Post-d058 TC harmonization adds TC5/6/7 for work-stream awareness coverage
   - AC: docs/backlog/STORY-019.md (full Gherkin AC1/AC2/AC3/AC4, created per tester 🔴 PR Review #515 fix)
   - Sister-pattern: d046/d048/d050b/d051/d052/d053/d054/d058 family (8-sister impls on main + d055/d056 doctrinal reservations per ADR-0049, 10-sister ID space; target 13-sister after TC expansion + d059 + d060 + d061, with d055/d056 impls deferred to Sprint 16+ workshop decision). **PM authoring correction (Issue #535, RETRO-007 §11):** original Sprint 15 plan.md text claimed "10-sister on main" including d055/d056 as siblings — false, only 8 impls on main as of Sprint 15 start.

6. **arch-soul §9-Lens step 4 + §Size-negotiation amendment** — LOCKED
   - Owner: @architect (soul amendment) + @atilcan65 (owner merges soul file)
   - Lane: `.claude/agents/architect.md` §9-Lens Review Checklist step 4 + §Size-negotiation
   - SP: 0.25 (arch-only)
   - Origin: PR #513 §Dispatch Discipline 6-step catch — arch 🟢 verdict posted while Lint & Test IN_PROGRESS, FAILED ~10s later. Codification: arch 9-Lens MUST re-query `gh pr checks N` within 30s of verdict post + wait for all checks COMPLETED
   - Sister-pattern: PM §Pre-citation cross-check (Issue #430) — both disciplines now align on "30s pre-verdict re-query + wait for CI COMPLETED"
   - Cross-ref: Issue #430 (PM §Pre-citation cross-check), PR #513 (live evidence), RETRO-009 §2 (comment-based arch verdicts enrichment)

### P2 (LOCKED, RETRO-009 Tier 2/3 carries) — 3 stories

7. **§4 §14 NEW DUAL-AXIS observation carrier** (RETRO-009 §4) — LOCKED
   - Owner: @architect (observation only, no impl)
   - Lane: `docs/retros/retro-009.md` §4 + RETRO-010 watchlist
   - SP: 0.5 (arch-only)
   - Origin: 3-axis lag (issue-state / label-state / watcher-state) validated 3x in Sprint 14 P1 cluster
   - Doctrine: Observation carrier into Sprint 16+ RETRO-010 (no immediate impl, watchlist pattern)
   - Cross-ref: RETRO-009 §4, Issue #507/#508/#512

8. **d059 new d-test** (RETRO-009 §6 SPLIT-resolved) — LOCKED
   - Owner: @developer (d-test impl) + @tester (sign-off)
   - Lane: `scripts/tests/d059-<variant>.sh` (sister-pattern to d058, **d-test ID d059** per Option C workshop decision)
   - SP: 0.75+0.5=1.25 (dev 0.75 + tester 0.5)
   - Origin: RETRO-009 §6 d-test family persistence — Sprint 15 target 11-sister (now 13-sister with d060 + d061 added per Option C)
   - Variant (per workshop decision, tester recommendation): **(a) chain dep pollution companion** — highest priority per RETRO-009 §6 + addresses LIVE INSTANCE #6 (PR #509). Tight d-test pair with STORY-016 §1 + d060.
   - Variant (b) post-squash label hygiene companion — **DEFERRED to Sprint 16** (per workshop decision, tester recommendation)
   - Variant (c) comment-based arch verdicts watcher ext — DEFERRED to Sprint 16 per plan.md §Deferred
   - AC: docs/backlog/STORY-022.md (full Gherkin AC1/AC2/AC3, created per tester 🔴 PR Review #515 fix)
   - Cross-ref: RETRO-009 §6, ADR-0049 (d-test framework), ADR-0044, ADR-0045

9. **§10 tester lane INDEX maintainer** (RETRO-009 §10) — LOCKED
   - Owner: @tester (lane maintenance)
   - Lane: `scripts/tests/INDEX.md` (centralized registry)
   - SP: 1.0 (tester-only)
   - Origin: Sprint 14 partial via d031 TC harmonization post-d058 (0.25 SP). Sprint 15 continuation of d-test sign-off backlog + INDEX.md maintenance
   - AC: docs/backlog/STORY-023.md (full Gherkin AC1/AC2/AC3/AC4, created per tester 🔴 PR Review #515 fix)
   - Sister-pattern to Sprint 14 P2 #11 (tester lane carry)
   - Cross-ref: ADR-0044 (RED-first TDD), RETRO-009 §10, Sprint 14 P2 #11

### Deferred to Sprint 16 (per dev recommendation)

- **§2 comment-based arch verdicts watcher ext** (1.0 SP) — needs PR #503 verdict template standardization first
- **§6b CI backfill d015+d031** (1.0 SP) — defer 2 d-tests to manage load
- **§14 NEW option (a)** — arch spec filed-for-grooming, Sprint 16 sizing

## Sizing (FINALIZED post-workshop, joint sizing per ADR-0024)

| # | Story | arch (FINAL) | dev (FINAL) | tester (FINAL) | PM (FINAL) | total (FINAL) | Joint verdict SLA | Status |
|---|---|---|---|---|---|---|---|---|
| 1 | d050b TC1 owner-implementable | — | — | — | — | 0.25 (owner-implement) | owner-implement | 🟡 Sprint 15 P0 carry |
| 2 | §1 pre-push branch-base check | — | 0.75 | 0.25 | — | 1.0 | dev + tester joint | 🟢 LOCKED |
| 3 | §3 post-squash label hygiene sweep | — | 1.25 | 0.25 | — | 1.5 | dev + tester joint | 🟢 LOCKED |
| 4 | §5 RETRO-007 #10 NEW + Sprint 15 PM lane | 0.25 | — | — | 0.75 | 1.0 | PM + arch joint | 🟢 LOCKED |
| 5 | d031 TC5/6/7 update | — | — | 0.25 | — | 0.25 | tester lane | 🟢 LOCKED |
| 6 | arch-soul §9-Lens step 4 + §Size-negotiation | 0.25 | — | — | — | 0.25 | arch-only | 🟢 LOCKED |
| 7 | §4 §14 NEW DUAL-AXIS observation | 0.5 | — | — | — | 0.5 | arch-only | 🟢 LOCKED |
| 8 | d059 new d-test (§6 split-resolved) | — | 0.75 | 0.5 | — | 1.25 | dev + tester joint | 🟢 LOCKED (variant TBD) |
| 9 | §10 tester lane INDEX maintainer | — | — | 1.0 | — | 1.0 | tester lane | 🟢 LOCKED |
| **TOTAL (Sprint 15 FINAL)** | | **1.0** | **2.75** | **2.25** | **0.75** | **6.75-7.0 SP** | FULL LOCK per ADR-0024 | **P0+P1+P2 9/9 LOCKED** |

**PM-finalized per ADR-0024** (Sprint 15 sizing matrix FULL LOCK):
- P0 #1: 🟡 owner-implement carry (0.25 SP, owner-self)
- P1 #2-6: 🟢 LOCKED (4.0 SP total, agent executable)
- P2 #7-9: 🟢 LOCKED (2.75 SP total, carries + d-test family)
- **Total: 6.75-7.0 SP within 8.5-10.0 PM top-down capacity** ✅

## Risks

1. **d059 variant selection**: Sprint 15 kickoff workshop must select d059 sub-variant (a/b/c). Defer decision if workshop can't agree → Sprint 16 carry. (Mitigation: pre-flag in Sprint 15 kickoff issue #514.)
2. **§1 dependency on arch spec**: Branch-base check impl depends on arch ADR (filed-for-grooming Sprint 15). If arch ADR slips, §1 carries to Sprint 16. (Mitigation: arch §P1 #6 owns spec + §P2 #7 owns enrichment.)
3. **§3 webhook infrastructure**: Post-squash label hygiene sweep requires GitHub webhook or workflow trigger. Owner territory for `.github/workflows/` files. (Mitigation: arch files spec, owner-implements webhook.)
4. **arch-soul amendment territory friction**: P1 #6 + P1 #4 (PM soul amendment) require owner merge. Sister-pattern to Sprint 13 PR #473 squash + Sprint 14 PR #499 squash. (Mitigation: pre-flag via Issue #514 sister-pattern.)
5. **Tester lane overload**: Sprint 15 commits tester to 2.25 SP across P1 + P2. Sprint 14 tester carry (P2 #11) was 1.0-2.0 SP, partial via d031 TC harmonization. Risk: tester WIP cap 2/2 may bottleneck. (Mitigation: parallel work-stream, d031 TC5/6/7 update small + standalone.)
6. **Cluster-compression observation (RETRO-009 §8)**: Sprint 15 PM cluster is small + targeted (~6.75-7.0 SP, ~9 stories). If cluster-compression cycle repeats, plan.md may need mid-sprint refresh. (Mitigation: PM monitors cluster cadence, flag mid-sprint if drift.)

## Critical path

1. **Joint sizing ceremony** (PM-driven, ADR-0024) — ✅ COMPLETE (Issue #514, Sprint 15 sizing matrix FULL LOCK)
2. **Owner ratification** of plan.md after joint sizing — 🟡 PENDING (this PR)
3. **P0 #1**: d050b TC1 owner-implementable — 🟡 DEFERRED (Sprint 15 owner-self, parallel)
4. **P1 #2-6**: agent executable stories — 🟡 PENDING post-ratification
5. **P2 #7-9**: RETRO-009 Tier 2/3 codifications + tester lane — 🟡 PENDING post-ratification

**Sprint 15 day 1 sequence** (post-ratification):
1. PM opens Sprint 15 stories on GitHub Project board (Ready column + Sprint 15 **Milestone** #1 per orchestrator creation @ 2026-06-27T15:02:04Z — AtilCalculator board #16 has NO iteration field, uses Milestone per `gh project field-list 16`) — ORCHESTRATOR action per Issue #514. **Discrepancy note (RETRO-010 watchlist candidate)**: plan.md draft said "iteration field" but board schema is Milestone-only. Future sprints must use Milestone language from kickoff.
2. Peers pick up stories per WIP allocation
3. PM drafts RETRO-009 §1 LIVE INSTANCE observations as cluster progresses
4. Mid-sprint check-in at cluster-compression cadence (RETRO-009 §8)

## Definition of Done — Sprint 15

- [ ] All committed stories shipped (~6.75-7.0 SP) or carried with rationale
- [ ] All PRs merged to main via human owner squash
- [ ] CI green on main post-merge (verified per cluster squash green)
- [ ] Docs updated: Sprint 15 plan.md (this file, post-joint-sizing), RETRO-009 Tier 1 codifications (5 stories)
- [ ] Sprint 15 kickoff issue closed (Issue #514, post-ratification)
- [ ] No new P0/P1 bugs filed against Sprint 15 stories in 24h post-merge window
- [ ] d-test family 13-sister live on main (d059 + d060 + d061 added per Option C)
- [ ] Sprint 16 carry-forwards identified (RETRO-009 §2 + §6b + §14 NEW option (a))

## Cross-refs

- Sprint 15 proposed-scope: `docs/sprints/sprint-15/proposed-scope.md` (PR #513 squash @ ebf6bc8)
- Sprint 15 kickoff: https://github.com/atilcan65/AtilCalculator/issues/514
- Sprint 14 close.md: [../sprint-14/close.md](../sprint-14/close.md) (PR #513 squash @ ebf6bc8)
- Sprint 14 plan.md: [../sprint-14/plan.md](../sprint-14/plan.md) (sister-pattern template)
- RETRO-009 codification: [../../retros/retro-009.md](../../retros/retro-009.md) (12 candidates, Tier 1/2/3)
- RETRO-008 codification: [../../retros/retro-008.md](../../retros/retro-008.md) (sister-pattern, 12 candidates)
- ADR-0024 (joint sizing verdict SLA)
- ADR-0031 (CONTINUOUS FLOW mode)
- ADR-0038 (Auto-Claim Protocol, RETRO-009 §3 carrier)
- ADR-0044 (RED-first TDD)
- ADR-0045 (9-Lens Review Checklist, Sprint 15 P1 #6 amendment)
- ADR-0049 (d-test framework, Sprint 15 P2 d059 carrier)
- ADR-0048 (Layer 5 race codification, Sprint 15 P1 #3 direct application)
- Issue #498 (Sprint 14 PM lane continuation, sister-pattern to Sprint 15 P1 #4)
- Issue #507 (Sprint 14 P1 close-out, RETRO-009 §4 LIVE INSTANCE #1)
- Issue #508 (Sprint 14 P1 #6 AC5 follow-up, RETRO-009 §4 LIVE INSTANCE #2)
- Issue #512 (RETRO-009 dispatch, RETRO-009 §4 LIVE INSTANCE #3 — 3-axis lag codification)

## Verdict readiness

- **PM verdict**: 🟢 PM-OK (draft, joint sizing per ADR-0024 ✅ FULL LOCK)
- **Joint sizing expected**: @architect (1.0 SP locked), @developer (2.75 SP locked), @tester (2.25 SP locked), @orchestrator (sizing ratification)
- **Owner ratification**: @atilcan65 (post-joint-sizing)
- **CC expected**: @orchestrator (sister-pattern), @atilcan65 (owner ratification), @architect + @developer + @tester (lane notifications)

— @product-manager, 2026-06-27T17:50+03:00 = 14:50Z, Sprint 15 plan.md draft (PM lane, joint sizing per ADR-0024 FULL LOCK per Issue #514)