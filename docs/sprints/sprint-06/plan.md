# Sprint 6 — Plan

> **Author:** @orchestrator
> **Date:** 2026-06-23T11:10Z (initial draft) → 2026-06-23T11:08Z (mode confirmed)
> **Mode:** 🚀 **CONTINUOUS FLOW** (owner directive 2026-06-23T11:08Z chat) — same as Sprint 4+5
> **Window:** No fixed window — stories ship when ready, merges when green
> **Sprint 5 close shipped:** PR #292 (commit 345c25c, 2026-06-23T11:06:13Z)
> **Refs:** [Sprint 5 close](../sprint-05/close.md), [Sprint 4 retro](../sprint-04/retro.md), [Issue #289](https://github.com/atilcan65/AtilCalculator/issues/289)

## TL;DR

- **Mode**: CONTINUOUS FLOW (owner directive 2026-06-23T11:08Z) — no sprint boundary waiting
- **Lead item**: Issue #289 — proactive WIP>0 idle detection (orchestrator + dev + tester, 3.25 SP)
- **Carry from Sprint 5**: #289, #290, #291 (P1 trio for #289 design + impl + port)
- **P0 carry from Sprint 4**: #235, #236 (orchestrator gap-scan, blocked on owner cron)
- **P2 carry**: #193, #194, #198, #293 (cleanup + template ports)
- **PR #292**: MERGED (close summary shipped to main, 2026-06-23T11:06:13Z)

## Sprint 6 proposed scope (orchestrator draft, PM to refine)

### Lead track (P1, #289 family)

| ID | Title | Owner | SP | Phase |
|---|---|---|---|---|
| #289 | §Proactive WIP>0 idle detection — design | orchestrator | 0.25 | Phase 1 (doctrine close) |
| #291 | WIP-IDLE-IMPL — dev implementation | developer | 1.5 | Phase 2 (after #289 approved) |
| #290 | WIP-IDLE — template port | developer | 0.5 | Phase 3 |
| #289-d034 | d034 regression (3 TCs) | tester | 0.5 | Phase 4 |

**Lead total**: 2.75 SP

### P0 carry (Sprint 4, blocked)

| ID | Title | Owner | Status | Unblock |
|---|---|---|---|---|
| #235 | Orchestrator proactive-gap-scan duty (P0) | orchestrator | blocked | owner cron registration |
| #236 | Sprint 4 P0 gap-scan — template port | developer | blocked | #235 unblock + owner cron |

**Carry total**: ~3 SP (unblocked when owner acts)

### P2 carry (cleanup + ports)

| ID | Title | Owner | SP |
|---|---|---|---|
| #193 | ADR-0030 deviation — runner user | architect | 0.5 |
| #194 | Symlink cleanup (RCA-17) | architect | 0.5 |
| #198 | #48.1 template port | developer | 1.0 |
| #293 | Cross-repo PR auto-close pattern | architect+dev | 1.0 |

**Cleanup total**: 3 SP

## Capacity planning (continuous flow — no hard sprint cap)

| Role | Available | Committed (active) | Free |
|---|---|---|---|
| orchestrator | continuous | 0.25 (#289 doctrine close) | continuous |
| developer | 8 SP | 1.5 (#291) + 0.5 (#290) + 1.0 (#198) + 3 (#236) + 0.5 (#293 impl) = **6.5** | **1.5** |
| architect | 4 SP | 0.5 (#193) + 0.5 (#194) + 0.25 (#289 ADR draft) + 0.25 (#293 ADR draft) = **2.5** | **1.5** |
| owner | 0.25 SP (CI wiring only) | 0.25 (#293 CI wiring, owner-only territory) | 0 |
| product-manager | 2 SP | (grooming) | 2.0 |
| tester | 4 SP | 0.5 (#289-d034) + 0.25 (#293 d035) = **0.75** | **3.25** |

**Sprint 6 total capacity**: ~22 SP (continuous, no sprint end date)
**Sprint 6 committed (active)**: **~12.75 SP** (58% utilization, healthy headroom) — *corrected per architect #293 review (Option B with 5 caveats, d035 plan, refined phasing 1.5 SP total: arch 0.25 ✅ + arch 0.25 ADR + dev 0.5 + owner 0.25 + tester 0.25)*

## Risks

1. **#289 doctrine owner approval** — blocks #291 dev impl. Owner can act within 30m of design comment.
2. **Owner cron registration** — blocks #235/#236 P0 carry. Separate from #289.
3. **Multi-repo monitoring** (#289 scope) — extends `scripts/agent-watch.sh`; needs both repos in `REPO_LIST`.
4. **Cross-repo PR auto-close** — issue from Sprint 5 (template PRs can't auto-close AtilCalc issues). Design needed.

## Out-of-scope (Sprint 7+ candidates)

- TD-011 (PM issue-level events)
- TD-023 (multi-repo watcher beyond idle detection)
- d033 regression (4-soul §Doctrine Reminder coverage test) — Sprint 6 sub-task of #287 retro
- RETRO-005 (Sprint 5 retro) — Sprint 6 day 1+

## Sprint 6 ceremony plan

- **Day 1 (kickoff)**: PM grooming → ready-flip #291, #290, #235 → orchestrator pings
- **Day 2-3**: Dev impl #291 (depends on #289 doctrine close)
- **Day 4-5**: Tester d034 sign-off
- **Day 6-7**: Template port #290 + Sprint 5 retro
- **Day 8-9**: P0 carry #235/#236 (if owner cron ready)
- **Day 10**: Sprint 6 close + retro

## Open questions for owner

1. **Owner cron registration**: timing for #235/#236 unblock? (P0 carry blocked)
2. **Cross-repo PR close pattern** (#293): formal design or accept manual close? (architect reviewing)
3. **Mode cadence check**: continuous flow OK, or want periodic boundary checks? (e.g., weekly retro)

## Resolved (owner directives)

- ✅ **Sprint 6 mode = continuous flow** (2026-06-23T11:08Z chat)
- ✅ **PR #292 merge** (close summary shipped 2026-06-23T11:06:13Z)

— Orchestrator, 2026-06-23T11:10:00+03:00 (continuous flow mode, awaiting PM grooming + owner cron)