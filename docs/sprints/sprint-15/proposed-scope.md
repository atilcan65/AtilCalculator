# Sprint 15 — Proposed Scope (PM draft, pre-sizing)

> **Author:** @product-manager
> **Date:** 2026-06-27T14:30+03:00 = 11:30Z
> **Mode:** 🚀 **CONTINUOUS FLOW** (ADR-0031 owner override carry from Sprint 4-14)
> **Trigger:** Sprint 14 P1 cluster 9/9 SHIPPED (PR #500, #501, #499, #502, #504, #503, #506, #509, #511 — owner-squashed @ 70e33d7) + RETRO-009 ceremony (Issue #512)
> **Previous sprint close:** [../sprint-14/close.md](../sprint-14/close.md) (Issue #512 close-out FINAL)
> **PM lane definition (LOCKED carry, per [ORCH→PM-CLARIFY-ACK] @ 22:42:21 +03):** PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors

## TL;DR scope (proposed, sizing pending arch+dev+tester joint review)

- **P0 carry** (1 story): d050b TC1 owner-implementable workflow file change (Sprint 14 carry, owner-only territory)
- **P1 (PM-led joint sizing per ADR-0024)** (3 stories): RETRO-009 §1 + §5 + d031 TC5/6/7 update follow-on
- **P2 (Sprint 15 backlog carriers)** (9+ stories): RETRO-009 §2-§4 + §6-§10 + RETRO-008 §d-test persistence + RETRO-007 watchlist #1/#2/#4 + Tester lane INDEX maintainer

**Total proposed**: 12+ stories, ~7-9 SP (rough PM estimate pre-sizing, mostly small doc/d-test/tooling work)

**Sizing TBD** — PM requests joint sizing per ADR-0024 verdict SLA framework once orchestrator opens Sprint 15 kickoff issue (post-Sprint 14 close-out squash).

## Proposed story inventory

### P0 (carry-forward from Sprint 14, owner territory)

1. **d050b TC1 owner-implementable workflow file change** (Issue #492 carry, Sprint 12-14 triple-carry)
   - Owner: atil can (owner-implementable, no PM grooming needed)
   - Origin: RETRO-007 watchlist #1 — owner-only territory per `.github/workflows/` file ownership matrix
   - **No PM action needed** beyond Issue tracking

### P1 (PM-led joint sizing per ADR-0024)

2. **RETRO-009 §1 — Pre-push branch-base check** (chain dep pollution prevention tooling)
   - **Owner**: developer (pre-push hook impl) + tester (d-test 9/9 RED-first per ADR-0044)
   - **SP estimate**: ~1.0 SP (dev + tester joint)
   - **Origin**: PR #509 chain dep pollution (3 scripts/ files duplicated PR #506 squash) — §6 LIVE INSTANCE #6 in RETRO-009
   - **Doctrinal aim**: tooling-level prevention of chain dep pollution (sister-pattern to direct-push-to-main prevention)
   - **PM facilitates**: ADR candidate §Pre-push branch-base hook doctrine (PM-owned docs/doc)
   - Sister-pattern: existing pre-push hook (branch protection enforcement)

3. **RETRO-009 §5 — RETRO-007 #10 NEW + Sprint 15 PM lane continuation** (PM soul amendment + watchlist entry codification)
   - **Owner**: PM (proposes) + architect (review per ADR-0045 9-Lens) + owner (merges soul file)
   - **SP estimate**: ~1.0 SP (PM + arch joint)
   - **Origin**: RETRO-007 watchlist entry #10 NEW (codification of cluster-vs-single squash lag hypothesis, RETRO-009 §5 LIVE INSTANCE)
   - **Doctrinal aim**: codify the cluster-squash batch-lag observation into RETRO-007 watchlist + Sprint 15 PM lane continuation amendment
   - **PM owns**: `.claude/agents/product-manager.md` §Auto-Claim Protocol amendment + RETRO-007 watchlist entry #10

4. **d031 TC5/6/7 update (Sprint 14 P1 #6 follow-on)** (tester lane small carry)
   - **Owner**: tester (d-test TC expansion)
   - **SP estimate**: 0.25 SP
   - **Origin**: d031 was the sister-pattern template for d058 (PR #506). Post-d058 TC harmonization adds TC5/6/7 for work-stream awareness coverage
   - Sister-pattern: d046/d048/d050b/d051/d052/d053/d054/d055/d056/d058 family (10-sister on main, target 11-sister after TC expansion)

### P2 (Sprint 15 backlog carriers, 9+ stories)

5. **RETRO-009 §2 — Comment-based architect verdicts watcher extension** (option a, watcher extension)
   - **Owner**: architect (doctrine) + developer (agent-watch.sh extension)
   - **SP estimate**: ~1.0 SP (arch + dev joint)
   - **Origin**: PR #509 ARCH 🟢 APPROVED UNCONDITIONAL was posted via comment (not formal review), my polling missed it because `agent-watch pr_review_requested` only fires on formal review submissions. Periodic backlog scan caught it 22m later.
   - **Doctrinal aim**: extend agent-watch.sh to parse comment-based verdicts, not just formal review submissions

6. **RETRO-009 §3 — Post-squash label hygiene sweep script** (label-state auto-flip on squash)
   - **Owner**: orchestrator (hygiene script + cron)
   - **SP estimate**: ~0.5 SP
   - **Origin**: §14 NEW DUAL-AXIS codification — Issue #507 (closed with `status:in-progress`), Issue #508 (closed with `status:ready`), Issue #512 (predicted same pattern). 3 LIVE INSTANCES in Sprint 14 P1 cluster.
   - **Doctrinal aim**: auto-flip `status:*` → `status:done` when issue auto-closes via Closes-anchor in squash

7. **RETRO-009 §4 — §14 NEW DUAL-AXIS observation carrier** (3-axis lag pattern, observation only)
   - **Owner**: orchestrator (observation, no impl)
   - **SP estimate**: 0 SP (observation only, post-RETRO-009 codification)
   - **Origin**: 3-axis lag (issue-state / label-state / watcher-state) validated 3x in Sprint 14 P1 cluster
   - **Doctrinal aim**: observation carrier into Sprint 16+ RETRO-010 (no immediate impl, watchlist pattern)

8. **RETRO-009 §6 — d-test family persistence (11-sister pattern)** (arch + dev + tester joint)
   - **Owner**: architect (doctrine) + developer (d-test impl) + tester (sign-off)
   - **SP estimate**: ~1.25 SP (joint)
   - **Origin**: Sprint 14 P1 cluster brought d-test family to 10-sister on main. Sprint 15 target: 11-sister (one more d-test codifying §14 NEW or comment-based verdicts)

9. **RETRO-009 §7 — Layer 5 race pattern enrichment** (3-axis lag, arch carry)
   - **Owner**: architect (ADR-0053 amendment)
   - **SP estimate**: ~0.5 SP
   - **Origin**: ADR-0053 codified Layer 5 race. §14 NEW DUAL-AXIS observation adds 3-axis lag dimension. Enrichment via ADR amendment.

10. **RETRO-009 §8 — Sprint 14 P1 cluster cycle compression lesson** (orchestrator planning template)
    - **Owner**: orchestrator (planning template refinement)
    - **SP estimate**: ~0.5 SP
    - **Origin**: Sprint 14 P1 cluster compressed 6-7 P1 stories into 4h 22m window with parallel agent execution. Codify as planning template for future cluster cycles.

11. **RETRO-009 §9 — RETRO-007 watchlist continuation** (#1, #2, #4, arch-only carry)
    - **Owner**: architect (watchlist codifications)
    - **SP estimate**: ~0.5 SP
    - **Origin**: Sprint 13 carry, Sprint 14 deferred. 3 watchlist entries remaining (#1, #2, #4).

12. **RETRO-009 §10 — Tester lane d-test sign-offs + INDEX maintainer** (tester carry, ~1.0-2.0 SP)
    - **Owner**: tester (lane maintenance)
    - **SP estimate**: ~1.0-2.0 SP
    - **Origin**: Sprint 14 partial via d031 TC harmonization post-d058 (0.25 SP). Sprint 15 continuation of d-test sign-off backlog + scripts/tests/INDEX.md maintenance.

### P2 (Sprint 14 cross-refs, deferred carries)

13. **RETRO-008 §d-test persistence** (Sprint 14 carry, ~1.25 SP arch + dev + tester joint)
    - Sister-pattern to RETRO-009 §6 (consolidate in Sprint 15)

14. **Tester lane INDEX maintainer** (Sprint 14 carry, tester lane)
    - Sister-pattern to RETRO-009 §10 (consolidate)

## Joint sizing request (per ADR-0024)

PM requests orchestrator open Sprint 15 kickoff issue + size joint review for:
- **P1** items (3 stories): RETRO-009 §1 + §5 + d031 TC5/6/7
- **P0** carry (1 story): d050b TC1 owner-implementable

**P2 backlog refresh** is documented above for Sprint 15 mid-cycle grooming (not initial commitment).

## Sizing estimate (PM rough, awaiting joint validation)

| Story | Lane | PM estimate | Arch | Dev | Tester | Joint |
|---|---|---|---|---|---|---|
| d050b TC1 owner-impl | owner | 0.5 | n/a | n/a | n/a | 0.5 (owner-self) |
| RETRO-009 §1 pre-push hook | dev + tester | 1.0 | n/a | TBD | TBD | TBD |
| RETRO-009 §5 watchlist #10 + PM lane continuation | PM + arch | 1.0 | TBD | n/a | n/a | TBD |
| d031 TC5/6/7 update | tester | 0.25 | n/a | n/a | TBD | TBD |
| **P1 sub-total** | | **2.75** | | | | TBD |
| P2 sub-total (9+ stories) | | ~5.75-7.25 | | | | TBD |
| **Total Sprint 15 draft** | | **~8.5-10.0** | | | | TBD |

## Risks + mitigations

| Risk | Status | Mitigation |
|---|---|---|
| d050b TC1 owner-implementation slip | 🟡 DEFERRED | Sprint 15 P0 owner-scheduled (triple-carry Sprint 12-14) |
| Pre-push hook tooling gets too aggressive | 🟡 WATCH | Sprint 15 sizing review includes false-positive rate test (TCs) |
| Watcher extension (RETRO-009 §2) breaks existing wake loops | 🟡 WATCH | arch + dev joint sizing, opt-in roll-out behind feature flag |

## Cross-references

- **Sprint 14 close.md**: [../sprint-14/close.md](../sprint-14/close.md) (Issue #512, 9/9 P1 SHIPPED + RETRO-009 in progress)
- **RETRO-009 codification**: [../../retros/retro-009.md](../../retros/retro-009.md) (12 candidates, Tier 1/2/3)
- **RETRO-008 codification**: [../../retros/retro-008.md](../../retros/retro-008.md) (sister-pattern, 12 candidates)
- **Sprint 14 proposed-scope**: [../sprint-14/proposed-scope.md](../sprint-14/proposed-scope.md) (sister-pattern template)
- **Sprint 13 proposed-scope**: [../sprint-13/proposed-scope.md](../sprint-13/proposed-scope.md) (predecessor template)
- **RETRO-007 watchlist**: doctrinal concept referenced across retrospectives (7/9 closed in Sprint 13-14, 3 carry-forward + #10 NEW per RETRO-009 §5) — no consolidated `retro-007.md` home, cross-refs live in RETRO-008 §watchlist + RETRO-009 §5 + Issue #414 + Issue #430 + Issue #471
- ADR-0024 (joint sizing verdict SLA)
- ADR-0031 (CONTINUOUS FLOW mode)
- ADR-0038 (Auto-Claim Protocol)
- ADR-0044 (RED-first TDD)
- ADR-0045 (9-Lens Review Checklist)
- ADR-0049 (d-test framework)
- ADR-0053 (Layer 5 race codification)
- Issue #512 (Sprint 14 RETRO-009 dispatch — closed on owner squash of this PR)

— @product-manager, 2026-06-27T14:30+03:00, Sprint 15 PM-led proposed scope (work unit 3/4 of RETRO-009 ceremony, Issue #512)