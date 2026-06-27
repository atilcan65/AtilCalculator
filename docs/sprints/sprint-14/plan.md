# Sprint 14 — Plan (PM draft, owner ratifies)

> **Status**: ACTIVE (2026-06-27T10:05+03:00 = 07:05Z, owner signal @ 07:05Z per [ORCH→PM] Sprint 14 Kickoff dispatch)
> **Mode**: 🚀 **CONTINUOUS FLOW** (ADR-0031 owner override carry from Sprint 4-13)
> **Owner ratification**: pending (PM draft, owner ratifies after joint sizing per ADR-0024)
> **Trigger**: Issue #479 disposition ✅ + Sprint 14 proposed-scope (PR #486 squash @ e91fce5) ✅ + RETRO-008 codification (PR #485 squash @ 72ff88d) ✅
> **PM lane definition (LOCKED this sprint, per [ORCH→PM-CLARIFY-ACK] @ 22:42:21 +03)**: PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors

## Goal

Sprint 13 PM cluster 100% shipped (1.25 SP) + Sprint 13 P1 cluster 100% shipped (8 PRs). Sprint 14 inherits:
1. **P0 owner-implementable carry** — d050b TC1 (Sprint 13 carry, owner territory)
2. **RETRO-008 Tier 1 codifications** — 5 candidates (Sprint 14 P1)
3. **§9-Lens enforcement** — ADR-0049 §Code review codification apply (arch carry L-sized)
4. **Sprint 14 PM lane continuation** — PM cluster sister-pattern (carry from #473)
5. **RETRO-007 watchlist continuation** — 3 carry-forwards (Sprint 14 P2)

**Total**: 9.5-10.5 SP committed (PM draft REVISED per [TEST→PM] PR #487 verdict 🟡, joint sizing per ADR-0024 PENDING arch+dev sign-off). **Sprint 14 PM cluster 11 stories**: 1 P0 (owner) + 6 P1 (agent lane) + 4 P2 (tester lane + RETRO-008 Tier 2/3 + RETRO-007 watchlist).

**🚨 URGENT**: Issue #488 (P1 engine perf regression on main, p99=135ms vs 50ms budget, 170% over, 2 consecutive CI FAILs) is a **REAL REGRESSION** per RETRO-008 §2 (NOT a flake). Sprint 14 ratification BLOCKED until main is green. Tester (CI Gatekeeper doctrine) holds PR #487 squash. **P1 #12 engine perf regression fix** added below — MUST precede Sprint 14 ratification.

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

### P1 (architect + PM-facilitated, agent executable)

2. **§Engine perf flake vs regression codification** (RETRO-008 §2)
   - Owner: @architect (ADR amendment)
   - Lane: `docs/decisions/ADR-NNNN-engine-perf-flake-vs-regression.md` (arch territory)
   - SP: 0.5 (PM draft: arch-only)
   - Origin: Sprint 13 PR #472 single-flake instance (Issue #329 hypothesis confirmed)
   - Doctrine: Distinguish flake vs regression — 2+ consecutive CI FAILs required before labeling regression
   - Cross-ref: Issue #329, RETRO-008 §2, PR #472 (live evidence)

3. **§CI re-run race codification** (RETRO-008 §1)
   - Owner: @architect (ADR amendment) + @developer (d-test impl, d056)
   - Lane: `docs/decisions/` + `scripts/tests/`
   - SP: 1.5 (PM draft: arch 0.5 + dev 1.0)
   - Origin: Sprint 13 PR #472 + PR #485 status:ready auto-promote race with PM status:in-review flip
   - Doctrine: Re-query CI status within 30s of verdict post (sister-pattern to §Timing window)
   - Cross-ref: RETRO-008 §1, Issue #463 d053 sister

4. **§9-Lens enforcement application** (ADR-0049 §Code review codification apply)
   - Owner: @architect (ADR amendment) + @developer (d-test impl, d055)
   - Lane: `docs/decisions/` + `scripts/tests/`
   - SP: 1.5 (PM draft: arch 0.5 + dev 1.0)
   - Sister-pattern to d046 (k lens runtime) + d048 (Layer 5 reviewer chain) + d053 (4-cat verification)
   - Cross-ref: Issue #469 PR #478 §9-Lens Review Checklist, ADR-0049

5. **§Layer 5 race pattern codification** (RETRO-008 §4)
   - Owner: @architect
   - Lane: `docs/decisions/ADR-NNNN-layer-5-race-pattern.md` (arch territory)
   - SP: 0.5 (PM draft: arch-only)
   - Origin: PR #485 label-check FAILURE caught Layer 5 auto-promote race with PM manual flip
   - Doctrine: Layer 5 race awareness in label flip timing — re-query within 30s of any auto-promote
   - Cross-ref: ADR-0013 (board sync), ADR-0015 (atomic 4-flag hand-off), PR #485 (live evidence)

6. **§wip_overflow false positive fix** (RETRO-008 §3)
   - Owner: @architect + @developer
   - Lane: `scripts/claim-next-ready.sh` (Layer 2 spec) + d-test impl
   - SP: 1.5 (PM draft: arch 0.5 + dev 1.0)
   - Origin: WIP = 2 active streams ≠ 2 separate issues; PR cluster counts as 1 stream
   - Doctrine: WIP count by work-stream, not by issue count
   - Cross-ref: ADR-0038 §Auto-Claim Protocol, Issue #238 (no self-justified pauses)

7. **Sprint 14 PM lane continuation** (Sprint 13 PM cluster sister-pattern)
   - Owner: @product-manager
   - Lane: `docs/CLAUDE.md` PM lane def amendment (human-only territory, owner-merged)
   - SP: 0.5 (PM proposes, owner merges)
   - Origin: Sprint 13 PM cluster 100% shipped (1.25 SP), PM lane def LOCKED
   - Sister-pattern: Issue #471, RETRO-007 watchlist #9
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

12. **🚨 Engine perf regression fix** [P1 — added per Issue #488 (tester P1 filing), MANDATORY before Sprint 14 ratification]
    - Owner: @developer
    - Lane: `src/atilcalc/engine/` (engine code, dev lane)
    - SP: PM draft L (engine code regression fix, multi-file investigation) — pending dev+arch joint sizing per ADR-0024
    - **REAL REGRESSION, NOT flake** per RETRO-008 §2:
      - First run (07:10:02Z): p99=53.75ms (7.5% over 50ms budget)
      - Re-run (07:13:49Z): p99=135.25ms (170% over, 2.5x WORSE)
      - Both `test_arithmetic_p99_under_50ms_still_holds` AND `test_transcendental_p99_under_100ms_still_holds` failing
      - 2 consecutive FAILs with 2.5x delta → DETERMINISTIC REGRESSION (NOT flake)
    - **Blocks**: PR #487 squash (tester CI Gatekeeper doctrine), Sprint 14 ratification, all subsequent merges
    - Hypothesis: mpmath integration overhead (ADR-0019 amendment 2 context), recent engine code change
    - Cross-ref: Issue #488, RETRO-008 §2, ADR-0019 §Performance budgets, Issue #329, PR #487 (held)

## Sizing (PM draft REVISED per [TEST→PM] verdict 🟡, joint sizing per ADR-0024 — PENDING arch+dev)

| # | Story | arch (PM draft) | dev (PM draft) | tester (PM draft REVISED) | total (PM draft REVISED) | Joint verdict SLA |
|---|---|---|---|---|---|---|
| 1 | d050b TC1 owner-implementable | — | — | — | owner | owner-implement |
| 2 | §Engine perf flake vs regression codification | 0.5 | — | — | 0.5 | arch sign-off |
| 3 | §CI re-run race codification | 0.5 | 1.0 | 0.25-0.5 (d056 sign-off) | 1.75-2.0 | arch + dev + tester joint |
| 4 | §9-Lens enforcement application | 0.5 | 1.0 | 0.25-0.5 (d055 sign-off) | 1.75-2.0 | arch + dev + tester joint |
| 5 | §Layer 5 race pattern codification | 0.5 | — | — | 0.5 | arch sign-off |
| 6 | §wip_overflow false positive fix | 0.5 | 1.0 | 0.25-0.5 (claim-next-ready d-test sign-off) | 1.75-2.0 | arch + dev + tester joint |
| 7 | Sprint 14 PM lane continuation | — | — | — | 0.5 | PM only, owner-merge |
| 8 | d054 Sprint 14 CI integration follow-up | — | — | — | 0.5 | owner-implement |
| 9 | RETRO-008 §d-test persistence | 0.5 | 0.5 | 0.25 (INDEX maintainer) | 1.25 | arch + dev + tester joint |
| 10 | RETRO-007 watchlist continuation | 0.5 | — | — | 0.5 | arch sign-off |
| 11 | **Tester lane (d-test sign-offs + INDEX maintainer)** | — | — | 1.0-2.0 | 1.0-2.0 | tester lane carry |
| 12 | **🚨 Engine perf regression fix** (Issue #488) | TBD | TBD (L draft) | — | TBD (L draft) | dev + arch joint |
| **TOTAL (PM draft REVISED)** | | **3.5+** | **3.5+L** | **1.0-2.0** | **9.5-10.5+ L SP** | TBD arch+dev sign-off |

**PM-finalized per ADR-0024** (after joint sizing):
- P0 #1: owner (no agent sizing)
- P1 #2: TBD (PM draft 0.5, arch-only)
- P1 #3: TBD (PM draft 1.75-2.0, arch + dev + tester joint)
- P1 #4: TBD (PM draft 1.75-2.0, arch + dev + tester joint)
- P1 #5: TBD (PM draft 0.5, arch-only)
- P1 #6: TBD (PM draft 1.75-2.0, arch + dev + tester joint)
- P1 #7: TBD (PM draft 0.5, PM-only, owner-merge)
- P2 #8: TBD (PM draft 0.5, owner-implement)
- P2 #9: TBD (PM draft 1.25, arch + dev + tester joint)
- P2 #10: TBD (PM draft 0.5, arch-only)
- P2 #11: TBD (PM draft 1.0-2.0, tester lane — added per [TEST→PM] verdict)
- **9.5-10.5 SP total** (PM draft REVISED per [TEST→PM] verdict 🟡)

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

1. **Joint sizing ceremony** (PM-driven, ADR-0024) — peer-poke arch + dev + tester for sizing verdicts on PM draft
2. **Owner ratification** of plan.md after joint sizing
3. **P0 #1**: d050b TC1 owner-implementable (owner squash)
4. **P1 #2-7**: ADR drafts (arch) + d-test impl (dev) — sister-pattern to Sprint 13 cluster
5. **P2 #8-10**: RETRO-008 Tier 2/3 codifications + RETRO-007 watchlist continuation

## Definition of Done — Sprint 14

- [ ] All committed stories shipped (8.5 SP draft → TBD joint sizing) or carried with rationale
- [ ] All PRs merged to main via human owner squash
- [ ] CI green on main post-merge
- [ ] Docs updated: Sprint 14 plan.md, RETRO-008 Tier 1 codifications, d-test impl
- [ ] Sprint 14 kickoff issue closed (status:done, atomic close)
- [ ] No new P0/P1 bugs filed against Sprint 14 stories in 24h post-merge window

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