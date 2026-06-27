# Sprint 14 — Proposed Scope (PM draft)

> **Status:** PROPOSED (PM lane, owner ratifies)
> **Trigger:** Sprint 13 CLOSED (6.25 SP shipped, 8 PRs, RETRO-008 12 candidates surfaced). Owner decision A on Issue #479.
> **Sister-pattern:** [Sprint 13 proposed-scope](../sprint-13/proposed-scope.md) (precedent)
> **Mode:** 🚀 **CONTINUOUS FLOW** (ADR-0031 owner override carry from Sprint 4-13)

## Sprint Goal

Apply Sprint 13 RETRO-008 codifications + finish d050b/d054 CI integration (Sprint 13 P0 carry) + continue PM lane. **9 stories total** (2 P0 owner territory + 4 P1 + 3 P2), no feature work.

## Capacity

- **architect**: 1/2 WIP (P1 #5 + P1 #6 + P2 #9 carry)
- **developer**: 0/2 WIP (gated on P0 #1 + P2 #7)
- **tester**: 0/2 WIP (P2 #8 d-test carry)
- **product-manager**: 1/2 WIP (P1 #3 + P1 #4)
- **orchestrator**: 0/2 WIP (kickoff facilitation)
- **owner**: 1/1 WIP (P0 #1 + P0 #2 owner-merge)

## Committed Stories

### P0 (owner territory)

1. **d050b TC1 owner-implementable d-test extension** (Sprint 13 carry)
   - Owner: @atilcan65
   - Lane: `.github/workflows/` (human-only territory, agents propose via PR)
   - Sprint 13 P0 carry, no PM action needed

2. **d054 CI integration** (per ADR-0048)
   - Owner: @architect (propose) + @atilcan65 (squash merge)
   - Size: S (CI YAML path trigger)
   - Lane: `.github/workflows/lint-and-test.yml` paths update

### P1 (PM lane + arch lane)

3. **RETRO-008 codifications (top 5 of 12 candidates)** — Issue #480 carry
   - Owner: @product-manager
   - Lane: `docs/retros/retro-008.md` (human-only territory, owner ratifies)
   - Top 5 priority:
     - §1 CI re-run race condition (4 instances today)
     - §2 Engine perf flake vs regression distinction
     - §3 wip_overflow false positive
     - §4 Layer 5 race pattern
     - §5 Peer-poke CI timing gap
   - PR #482 squash pending (Sprint 13 close.md + RETRO-008 draft)

4. **Sprint 14 PM lane continuation** (carry from #473)
   - Owner: @product-manager
   - Lane: `docs/CLAUDE.md` + `.claude/CLAUDE.md` (PM lane def amendment in production)
   - Sister-pattern to Sprint 13 PM lane def amendment (PR #473 squash)

5. **§9-Lens enforcement** (Issue #469 P2 #7 sister)
   - Owner: @architect
   - Size: L (mechanism + 10 TCs + ADR amend)
   - Sister-pattern: ADR-0049 §9-Lens Review Checklist (PR #478 squash)

6. **RETRO-007 watchlist continuation** (new entries from RETRO-008)
   - Owner: @architect
   - Size: TBD (pending PM draft)
   - Lane: `docs/CLAUDE.md` + ADRs

### P2 (arch + dev + tester lanes)

7. **d054 Sprint 14 CI integration follow-up** (after P0 #2)
   - Owner: @developer
   - Size: S
   - Lane: `.github/workflows/` (human-only territory)

8. **d053/d054 carry + RETRO-008 §d-test persistence** (d-test carry)
   - Owner: @tester
   - Lane: `tests/` + d-test sister family
   - Sister-pattern: d046/d048/d050b/d051/d052/d053/d054 family

9. **ADR-0049 §9-Lens enforcement application** (after #478 codification)
   - Owner: @architect
   - Lane: `docs/decisions/ADR-0049` amendment
   - Sister-pattern: PR #478 codification

## Sizing (joint, per ADR-0024) — PENDING

Arch pre-sizing forwarded (saves one round):
- §9-Lens enforcement = L (mechanism + 10 TCs + ADR amend)
- d054 integration = S (CI YAML path trigger, owner-merge gate)
- RETRO-007 watchlist continuation = TBD pending PM draft

**Joint sizing verdict (PM-finalized per ADR-0024):**
- P0 #1: (owner territory, no SP)
- P0 #2: S (arch 0.5 + dev 0.5 + owner squash)
- P1 #3: (PM lane, owner ratifies) — TBD joint size
- P1 #4: (PM lane) — TBD joint size
- P1 #5: L (arch 1.0 + dev 1.0 + tester 0.5 + integration 0.5)
- P1 #6: TBD (arch 0.5+ pending)
- P2 #7: S (dev 0.5)
- P2 #8: (tester lane) — TBD
- P2 #9: (arch lane) — TBD

**Total estimated: ~3-4 SP (P0/P1 weighted)**

## Risks

1. **d050b/d054 owner-implementation slip** — owner territory, Sprint 13 carry, no agent self-execute. Owner blocked = Sprint 14 P0 carry stays unresolved (Sprint 13 risk realized).
2. **RETRO-008 codification scope creep** — 12 candidates, top 5 priority for Sprint 14, bottom 7 to Sprint 15+. Mitigations: arch pre-sizing (saves one round), cadence hint from #481 (batch new candidates into #480, no new issues).
3. **PM no-self-standby enforcement** — PM has demonstrable self-justified pause pattern (Sprint 13 close.md turn). Mitigations: peer-poke cadence enforcement; orchestrator ACK-reconcile check; Issue #238 §Valid pause (a/b/c) framework.
4. **CI re-run race recurrence** — 4+ instances in Sprint 13; codify in RETRO-008 + d-test (Sprint 14 P1 #3 candidate).
5. **Engine perf drift (Issue #329)** — P3→P1 candidate if pattern recurs; current status: single flake, no pattern.

## Critical Path

1. Owner squash PR #464 (already merged)
2. Owner squash PR #465 (already merged)
3. Owner squash PR #472 (already merged)
4. Owner squash PR #473 (already merged)
5. Owner squash PR #475 (already merged)
6. Owner squash PR #476 (already merged)
7. Owner squash PR #477 (already merged)
8. Owner squash PR #478 (already merged)
9. Owner squash PR #482 (Sprint 13 close.md + RETRO-008, pending)
10. P0 #1 d050b TC1 owner-implementable (Sprint 14 critical path, owner territory)
11. P0 #2 d054 CI integration (Sprint 14 critical path, owner squash)
12. P1 #3 RETRO-008 codifications top 5 (PM lane, owner ratifies)
13. P1 #4 PM lane continuation (PM lane)
14. P1 #5 §9-Lens enforcement (arch lane, L size)
15. P1 #6 RETRO-007 watchlist continuation (arch lane, TBD)
16. P2 #7-9 (arch + dev + tester lanes, after P0/P1 critical path)

## Definition of Done — Sprint 14

- [ ] All committed stories shipped (TBD SP after joint sizing) or carried with rationale
- [ ] All PRs merged to main via human owner squash
- [ ] CI green on main post-merge
- [ ] RETRO-008 codifications (top 5) ratified and merged
- [ ] Sprint 14 close.md drafted (PM lane, owner ratifies)
- [ ] Sprint 14 kickoff issue closed (status:done, atomic close)
- [ ] No new P0/P1 bugs filed against Sprint 14 stories in 24h post-merge window

## Cross-refs

- Sprint 13 close: `docs/sprints/sprint-13/close.md` (PM draft, owner ratifies)
- RETRO-008 codification: `docs/retros/retro-008.md` (PM draft, 12 candidates)
- Issue #479 (Sprint 14 kickoff coordination, parent, owner decision A)
- Issue #480 (RETRO-008, 12 candidates, top 5 priority for Sprint 14)
- Issue #481 (Sprint 13 close.md coordination, sibling)
- PR #482 (Sprint 13 close.md + RETRO-008 codification, owner squash pending)
- ADR-0049 (3-layer d-test defense, sister-pattern)
- ADR-0050 (Pre-merge 4-cat verification, sister-pattern)
- RETRO-007 watchlist (predecessor, 9 entries, 5 closed in Sprint 13)

— @product-manager, 2026-06-27T09:35+03:00, Sprint 14 proposed-scope (PM draft, owner ratifies)
