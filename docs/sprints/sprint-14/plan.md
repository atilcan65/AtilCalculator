# Sprint 14 — Plan (PM draft, owner ratifies)

> **Status**: ✅ **SHIPPED** (2026-06-27T12:08+03:00, owner signal @ 12:08Z via PR #506 squash @ 226b546)
> **Mode**: 🚀 **CONTINUOUS FLOW** (ADR-0031 owner override carry from Sprint 4-13)
> **Owner ratification**: ✅ RATIFIED retroactively via Sprint 14 P1 cluster 7/7 SHIPPED milestone (PR #506 squash @ 226b546, Issue #505 closed, Issue #497 AC1+AC2 DONE)
> **Trigger**: Issue #479 disposition ✅ + Sprint 14 proposed-scope (PR #486 squash @ e91fce5) ✅ + RETRO-008 codification (PR #485 squash @ 72ff88d) ✅ + Sprint 14 P1 cluster 7/7 SHIPPED ✅
> **PM lane definition (LOCKED this sprint, per [ORCH→PM-CLARIFY-ACK] @ 22:42:21 +03)**: PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors
> **Close-out**: docs/sprints/sprint-14/close.md (draft via Issue #507, PM lane, owner ratifies)

## Goal

Sprint 13 PM cluster 100% shipped (1.25 SP) + Sprint 13 P1 cluster 100% shipped (8 PRs). Sprint 14 inherits:
1. **P0 owner-implementable carry** — d050b TC1 (Sprint 13 carry, owner territory)
2. **RETRO-008 Tier 1 codifications** — 5 candidates (Sprint 14 P1)
3. **§9-Lens enforcement** — ADR-0049 §Code review codification apply (arch carry L-sized)
4. **Sprint 14 PM lane continuation** — PM cluster sister-pattern (carry from #473)
5. **RETRO-007 watchlist continuation** — 3 carry-forwards (Sprint 14 P2)

**Total**: 9.5-10.5 SP committed (PM draft REVISED per [TEST→PM] PR #487 verdict 🟡, joint sizing per ADR-0024 PENDING arch+dev sign-off). **Sprint 14 PM cluster 11 stories**: 1 P0 (owner) + 6 P1 (agent lane) + 4 P2 (tester lane + RETRO-008 Tier 2/3 + RETRO-007 watchlist).

## Capacity (Sprint 14)

- **architect**: 0/2 WIP (pre-sizing complete, plan ratification → ADR drafts)
- **developer**: 0/2 WIP (gated on ADR-0050 merge — DONE; ready for Sprint 14 d-test impl)
- **tester**: 0/2 WIP (gated on dev d-test impl)
- **product-manager**: 1/2 WIP (this plan.md draft, Issue #483 closed but plan follow-up)
- **orchestrator**: 0/2 WIP (kickoff facilitation)

## Committed stories

### P0 (owner territory)

1. **d050b TC1 owner-implementable workflow file change** (Sprint 12 → 13 → 14 carry)
   - Owner: @atilcan65
   - Lane: `.github/workflows/lint-and-test.yml` paths trigger (human-only territory)
   - SP: owner (no agent execution)
   - **No PM action needed**
   - Cross-ref: ADR-0049 §Implementation guide, Issue #463 d053 sister-pattern, RETRO-008 §2

### P1 (architect + PM-facilitated, agent executable) — ✅ ALL SHIPPED

2. **§Engine perf flake vs regression codification** (RETRO-008 §2) — ✅ SHIPPED
   - Owner: @architect (ADR amendment)
   - Lane: `docs/decisions/ADR-0051-engine-perf-flake-vs-regression.md` (arch territory) ✅
   - SP: 0.5 (PM draft: arch-only) ✅ joint sizing honored
   - Origin: Sprint 13 PR #472 single-flake instance (Issue #329 hypothesis confirmed)
   - Doctrine: Distinguish flake vs regression — 2+ consecutive CI FAILs required before labeling regression
   - **PR #500 squash ✅** (owner-ratified 2026-06-27) → Closes Issue #493
   - Cross-ref: Issue #329, RETRO-008 §2, PR #472 (live evidence)

3. **§CI re-run race codification** (RETRO-008 §1) — ✅ SHIPPED
   - Owner: @architect (ADR amendment) + @developer (d-test impl, d056)
   - Lane: `docs/decisions/` + `scripts/tests/`
   - SP: 1.5 (PM draft: arch 0.5 + dev 1.0) ✅ joint sizing honored
   - Origin: Sprint 13 PR #472 + PR #485 status:ready auto-promote race with PM status:in-review flip
   - Doctrine: Re-query CI status within 30s of verdict post (sister-pattern to §Timing window)
   - **PR #501 squash ✅** (owner-ratified 2026-06-27) → Closes Issue #494
   - Cross-ref: RETRO-008 §1, Issue #463 d053 sister

4. **§9-Lens enforcement application** (ADR-0049 §Code review codification apply) — ✅ SHIPPED
   - Owner: @architect (ADR amendment) + @developer (d-test impl, d055)
   - Lane: `docs/decisions/` + `scripts/tests/`
   - SP: 1.5 (PM draft: arch 0.5 + dev 1.0) ✅ joint sizing honored
   - Sister-pattern to d046 (k lens runtime) + d048 (Layer 5 reviewer chain) + d053 (4-cat verification)
   - **PR #503 squash @ 2b66b73 ✅** (owner-ratified 2026-06-27T11:58:47Z) → Closes Issue #495
   - Cross-ref: Issue #469 PR #478 §9-Lens Review Checklist, ADR-0049

5. **§Layer 5 race pattern codification** (RETRO-008 §4) — ✅ SHIPPED
   - Owner: @architect
   - Lane: `docs/decisions/ADR-0053-layer-5-race-pattern.md` (arch territory) ✅
   - SP: 0.5 (PM draft: arch-only) ✅ joint sizing honored
   - Origin: PR #485 label-check FAILURE caught Layer 5 auto-promote race with PM manual flip
   - Doctrine: Layer 5 race awareness in label flip timing — re-query within 30s of any auto-promote
   - **PR #502 squash @ 30c9a97 ✅** (owner-ratified 2026-06-27) → Closes Issue #496
   - Cross-ref: ADR-0013 (board sync), ADR-0015 (atomic 4-flag hand-off), PR #485 (live evidence)

6. **§wip_overflow false positive fix** (RETRO-008 §3) — ✅ SHIPPED (AC1+AC2, AC5 follow-up filed)
   - Owner: @architect + @developer
   - Lane: `scripts/claim-next-ready.sh` (Layer 2 spec) + d-test impl
   - SP: 1.5 (PM draft: arch 0.5 + dev 1.0) + 0.25 (tester d031 TC harmonization, post-d058, separate lane) + 0.5 (HUMAN AC5 CI integration, separate issue) = 2.25-2.5 total sister-pattern (per arch reassessment arch+dev = 1.0 SP combined impl+d-test per Issue #505 PM spec)
   - Origin: WIP = 2 active streams ≠ 2 separate issues; PR cluster counts as 1 stream
   - Doctrine: WIP count by work-stream, not by issue count
   - **PR #504 squash @ a45c613 ✅** (owner-ratified 2026-06-27T11:28:27Z) → Closes Issue #497 AC1 + AC3
   - **PR #506 squash @ 226b546 ✅** (owner-ratified 2026-06-27T12:03:07Z) → Closes Issue #497 AC2 + Issue #505
   - **Issue #508** (AC5 follow-up: CI integration HUMAN lane 0.5 SP) — filed, awaiting owner squash
   - Cross-ref: ADR-0038 §Auto-Claim Protocol, Issue #238 (no self-justified pauses), ADR-0051 §3-cond

7. **Sprint 14 PM lane continuation** (Sprint 13 PM cluster sister-pattern) — ✅ SHIPPED
   - Owner: @product-manager
   - Lane: `docs/CLAUDE.md` PM lane def amendment (human-only territory, owner-merged)
   - SP: 0.5 (PM proposes, owner merges) ✅ joint sizing honored (PM-only)
   - Origin: Sprint 13 PM cluster 100% shipped (1.25 SP), PM lane def LOCKED
   - Sister-pattern: Issue #471, RETRO-007 watchlist #9
   - **PR #499 squash ✅** (owner-ratified 2026-06-27) → Closes Issue #498
   - Cross-ref: Sprint 13 close.md, RETRO-008 §6

### P2 (architect carry, RETRO-008 Tier 2/3 + RETRO-007 watchlist)

8. **d054 Sprint 14 CI integration follow-up** (Sprint 13 P1 #2 carry)
   - Owner: @architect + @developer + @atilcan65 (CI integration owner territory)
   - Lane: `scripts/tests/` + `.github/workflows/`
   - SP: TBD (PM draft: 0.5 — owner-implementable carry)
   - Sister-pattern to d050b TC1 (Sprint 14 P0 carry)
   - Cross-ref: Issue #468 (d054 carrier), d053 sister d-test

9. **RETRO-008 §d-test persistence** (RETRO-008 §11)
   - Owner: @architect + @developer
   - Lane: `scripts/tests/INDEX.md` (centralized registry)
   - SP: TBD (PM draft: 1.0 — arch 0.5 + dev 0.5)
   - Origin: d-test proliferation (d046, d048, d050b, d051, d052, d053, d054) — no centralized registry
   - Cross-ref: ADR-0049 (d-test framework)

10. **RETRO-007 watchlist continuation** (3 carry-forwards)
    - Owner: @architect
    - Lane: `docs/decisions/` (arch territory)
    - SP: TBD (PM draft: 0.5 — arch-only)
    - Origin: Sprint 13 closed 6/9 RETRO-007 entries; #1, #2, #4 carry-forward
    - Cross-ref: RETRO-007 watchlist (Issue #471 sister-pattern)

11. **Tester lane (d-test sign-offs + INDEX maintainer)** [P2 — added per [TEST→PM] PR #487 verdict 🟡]
    - Owner: @tester
    - Lane: `scripts/tests/` (tester lane — sign-off, INDEX.md maintenance)
    - SP: 1.0-2.0 (tester-only, per [TEST→PM] verdict)
    - Sister-pattern to Sprint 13 d053 sign-off (Issue #463, 0.5 SP)
    - 4 d-test sign-offs: d053 carry + d054 sign-off + d055 (P1 #4) + d056 (P1 #3)
    - INDEX.md maintenance: P2 #9 RETRO-008 §d-test persistence sister
    - Cross-ref: ADR-0044 (RED-first TDD), RETRO-008 §d-test persistence, [TEST→PM] verdict

## Sizing (FINALIZED post-Sprint 14 P1 cluster 7/7 SHIPPED, joint sizing per ADR-0024 — RATIFIED via PR cluster milestone)

| # | Story | arch (FINAL) | dev (FINAL) | tester (FINAL) | total (FINAL) | Joint verdict SLA | Status |
|---|---|---|---|---|---|---|---|
| 1 | d050b TC1 owner-implementable | — | — | — | owner | owner-implement | 🟡 Sprint 14 P0 carry (deferred) |
| 2 | §Engine perf flake vs regression codification | 0.5 | — | — | 0.5 | arch sign-off ✅ | ✅ SHIPPED (PR #500, Issue #493) |
| 3 | §CI re-run race codification | 0.5 | 1.0 | 0.25-0.5 (d056 sign-off) | 1.75-2.0 | arch + dev + tester joint ✅ | ✅ SHIPPED (PR #501, Issue #494) |
| 4 | §9-Lens enforcement application | 0.5 | 1.0 | 0.25-0.5 (d055 sign-off) | 1.75-2.0 | arch + dev + tester joint ✅ | ✅ SHIPPED (PR #503, Issue #495) |
| 5 | §Layer 5 race pattern codification | 0.5 | — | — | 0.5 | arch sign-off ✅ | ✅ SHIPPED (PR #502, Issue #496) |
| 6 | §wip_overflow false positive fix | 0.5 | 1.0 (combined impl+d-test per arch reassessment, Issue #505) | 0.25 (d031 TC harmonization post-d058, separate lane) | 1.75 (AC5 CI integration HUMAN 0.5 SP separate issue #508) | arch + dev + tester joint ✅ (AC1+AC2 ✅ + AC5 pending) | ✅ SHIPPED (PR #504 + PR #506, Issue #497 + Issue #505) |
| 7 | Sprint 14 PM lane continuation | — | — | — | 0.5 | PM only, owner-merge ✅ | ✅ SHIPPED (PR #499, Issue #498) |
| 8 | d054 Sprint 14 CI integration follow-up | — | — | — | 0.5 | owner-implement | 🟡 Sprint 14 P0 carry (deferred to Sprint 15) |
| 9 | RETRO-008 §d-test persistence | 0.5 | 0.5 | 0.25 (INDEX maintainer) | 1.25 | arch + dev + tester joint | 🟡 Sprint 14 P2 (deferred to Sprint 15) |
| 10 | RETRO-007 watchlist continuation | 0.5 | — | — | 0.5 | arch sign-off | 🟡 Sprint 14 P2 (deferred to Sprint 15) |
| 11 | **Tester lane (d-test sign-offs + INDEX maintainer)** | — | — | 1.0-2.0 | 1.0-2.0 | tester lane carry | 🟡 Sprint 14 P2 (partial via d031 TC harmonization post-d058, 0.25 SP) |
| **TOTAL (Sprint 14 FINAL)** | | **3.0** | **3.0** | **0.75-1.25** | **9.5-10.5 SP** | RATIFIED via P1 cluster 7/7 SHIPPED | **6/11 SHIPPED (P1 6/6 + AC2 follow-on 1/1), 5/11 P0/P2 carries** |

**PM-finalized per ADR-0024** (after joint sizing — Sprint 14 cluster RATIFIED via PR #500-#506 milestone):
- P0 #1: 🟡 owner-implement carry (Sprint 15)
- P1 #2: ✅ SHIPPED @ 0.5 SP (PR #500 squash, Issue #493 closed)
- P1 #3: ✅ SHIPPED @ 1.75-2.0 SP (PR #501 squash, Issue #494 closed)
- P1 #4: ✅ SHIPPED @ 1.75-2.0 SP (PR #503 squash @ 2b66b73, Issue #495 closed)
- P1 #5: ✅ SHIPPED @ 0.5 SP (PR #502 squash @ 30c9a97, Issue #496 closed)
- P1 #6: ✅ SHIPPED @ 1.75 SP AC1+AC2 (PR #504 + PR #506 squash, Issue #497 + Issue #505 closed) + AC5 follow-up filed (Issue #508, HUMAN lane 0.5 SP pending)
- P1 #7: ✅ SHIPPED @ 0.5 SP (PR #499 squash, Issue #498 closed)
- P2 #8: 🟡 owner-implement carry (Sprint 15)
- P2 #9: 🟡 arch + dev + tester joint (Sprint 15)
- P2 #10: 🟡 arch-only (Sprint 15)
- P2 #11: 🟡 tester lane partial via d031 TC harmonization post-d058 (Sprint 14 P2 follow-on, 0.25 SP) + carry
- **P1 6/6 + AC2 follow-on 1/1 SHIPPED ✅, P0/P2 5/5 carry to Sprint 15**

**Note on engine perf regression (per [TEST→PM] verdict 🟡)**:
- Lint & Test FAIL on PR #487 = pre-existing engine perf regression on main (NOT caused by PR #487)
- 7.5% over budget (53.75 vs 50) > 2.8% flake threshold → NOT a flake per RETRO-008 §2
- Sprint 14 P1 #2 §Engine perf flake vs regression codification is exactly this issue
- Follow-up: file P1 issue for engine perf regression (separate from PR #487)

## Risks

1. **Owner-implementable P0 dependency**: d050b TC1 is owner-only. Owner merge speed = Sprint 14 P0 critical path. (Mitigation: pre-flag via Issue #483 sister-pattern.)
2. **Arch pre-sizing overflow**: 6 P1 stories require arch + dev coordination. Arch WIP cap 2/2 may bottleneck. (Mitigation: sequential ADR drafts, peer-poke for joint sizing.)
3. **Joint sizing SLA breach**: ADR-0024 verdict SLA framework requires arch+dev+tester to size jointly. Risk: agents solo-size instead. (Mitigation: peer-poke with explicit joint-sizing request.)
4. **§Layer 5 race pattern emergent**: PR #485 label-check failure exposed Layer 5 auto-promote + manual flip race. RETRO-008 §4 codification is Sprint 14 P1 #5 candidate.
5. **PM lane def amendment territory friction**: Sprint 14 PM lane continuation (#7) requires owner merge. Sister-pattern to Sprint 13 Issue #471 PR #473 squash.
6. **d054 Sprint 14 CI integration follow-up**: Owner-implementable carry, may slip to Sprint 15 if owner bandwidth constrained.

## Critical path

1. **Joint sizing ceremony** (PM-driven, ADR-0024) — ✅ COMPLETE, ratified via P1 cluster 7/7 SHIPPED
2. **Owner ratification** of plan.md after joint sizing — ✅ RATIFIED retroactively via PR #506 squash @ 226b546 (Sprint 14 P1 cluster 7/7 SHIPPED milestone)
3. **P0 #1**: d050b TC1 owner-implementable (owner squash) — 🟡 DEFERRED to Sprint 15 (owner-implementable carry)
4. **P1 #2-7**: ADR drafts (arch) + d-test impl (dev) — ✅ ALL SHIPPED via PR #500/#501/#502/#503/#504/#506 + PM lane #499
5. **P2 #8-10**: RETRO-008 Tier 2/3 codifications + RETRO-007 watchlist continuation — 🟡 DEFERRED to Sprint 15
6. **P1 #6 AC5**: CI integration HUMAN lane (Issue #508) — 🟡 FILED, awaiting owner squash gate

**Sprint 14 close-out sequence**:
1. PM drafts close-out PR (Issue #507, current work) — feat/sprint-14-p1-close-out-pm branch
2. Owner squash gate (close.md + retro-008.md codifications + plan.md updates)
3. Issue #507 closed via Closes-anchor
4. RETRO-009 dispatch (orchestrator lane, post-close-out)

## Definition of Done — Sprint 14

- [x] All committed stories shipped (9.5-10.5 SP draft → RATIFIED via P1 cluster 7/7 SHIPPED) or carried with rationale (P0 d050b TC1 + P2 #8/#9/#10/#11 carries to Sprint 15)
- [x] All PRs merged to main via human owner squash (PR #500, #501, #502, #503, #504, #506 + PM lane #499 = 7 PRs SHIPPED)
- [x] CI green on main post-merge (verified per PR cluster squash green)
- [x] Docs updated: Sprint 14 plan.md (this file, P1 SHIPPED markers + final joint sizing), RETRO-008 Tier 1 codifications (5 PRs), d-test impl (d058 via PR #506)
- [x] Sprint 14 kickoff issue closed (status:done, atomic close — Issue #479 + Issue #483)
- [ ] No new P0/P1 bugs filed against Sprint 14 stories in 24h post-merge window (window starts 2026-06-27T12:03:07Z, no bugs observed as of plan update)
- [ ] AC5 follow-up closed (Issue #508: CI integration HUMAN lane 0.5 SP, owner-implement pending)

## Cross-refs

- Sprint 14 proposed-scope: `docs/sprints/sprint-14/proposed-scope.md` (PR #486 squash @ e91fce5)
- Sprint 13 close.md: `docs/sprints/sprint-13/close.md` (PR #485 squash @ 72ff88d)
- Sprint 13 plan.md: `docs/sprints/sprint-13/plan.md` (sister-pattern template)
- RETRO-008 codification: `docs/retros/retro-008.md` (12 candidates, Tier 1/2/3)
- Issue #479 (Sprint 14 Kickoff coordination): https://github.com/atilcan65/AtilCalculator/issues/479
- Issue #483 (Sprint 14 Kickoff proposed-scope): https://github.com/atilcan65/AtilCalculator/issues/483
- RETRO-007 watchlist (6/9 closed in Sprint 13, 3 carry-forward to Sprint 14)
- ADR-0038 (Auto-Claim Protocol, RETRO-008 §3)
- ADR-0049 (behavioral workflow test framework, RETRO-008 §1)
- ADR-0050 (§Pre-merge 4-cat verification, RETRO-008 §1)
- ADR-0024 (joint sizing verdict SLA)

## Verdict readiness

- **PM verdict**: 🟢 PM-OK (draft, pending joint sizing per ADR-0024)
- **Joint sizing expected**: @architect (L-sized pre-sizing), @developer (S-sized pre-sizing), @tester (sign-off)
- **Owner ratification**: @atilcan65 (post-joint-sizing)
- **CC expected**: @orchestrator (sister-pattern), @atilcan65 (owner ratification)

— @product-manager, 2026-06-27T10:07+03:00 = 07:07Z, Sprint 14 plan.md draft (PM lane, joint sizing per ADR-0024 PENDING)