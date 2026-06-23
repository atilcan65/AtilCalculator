# Sprint 7 — Plan

> **Author:** @orchestrator
> **Date:** 2026-06-23T17:52+03:00 = 14:52Z
> **Mode:** 🚀 **CONTINUOUS FLOW** (owner directive 2026-06-23T13:28Z chat, carry from Sprint 4-6)
> **Window:** No fixed end — stories ship when ready, merges when green
> **PM proposed scope shipped:** PR #298 (merged 2026-06-23T14:48:41Z, commit 12306b3)
> **Source-of-truth backlog:** [./backlog.json](./backlog.json)
> **PM rationale:** [./proposed-scope.md](./proposed-scope.md) (148L, merged via PR #298)
> **Refs:** [Sprint 6 plan](../sprint-06/plan.md), [Issue #302 (kickoff, closed)](https://github.com/atilcan65/AtilCalculator/issues/302)

## TL;DR

- **Mode**: CONTINUOUS FLOW (owner directive carry)
- **Lead track**: STORY-CLI-001 (#299, 2.0 SP, dev) → STORY-CLI-002 (#300, 1.5 SP) → STORY-CLI-003 (#301, 1.0 SP) — sequential dependency chain
- **Companion doctrine**: #296 peer-poke discipline (1.0 SP, orchestrator + owner) — Sprint 7 P1, owner-only territory for soul amendment
- **Sprint 6 P2 carry deferred**: #193, #194, #198, #293 (3.5 SP total) → Sprint 7 P2 or Sprint 8 (PM recommendation)
- **Sprint 6 P0 carry**: #235 (orchestrator gap-scan duty) + #236 (dev gap-scan template port) — owner cron-blocked
- **Sprint 6 lead ADRs already on main**: ADR-0039 (wip-idle watchdog) + ADR-0040 (cross-repo PR auto-close) — both Accepted via PR #297

## Sprint 7 scope (committed)

### User-facing re-entry (P0, 4.5 SP, dev owner)

| ID | Title | Issue | Owner | SP | Phase | Depends on |
|---|---|---|---|---|---|---|
| **STORY-CLI-001** | Basic arithmetic via typer CLI (M1 acceptance) | #299 | developer | 2.0 | Phase 1 (Day 0-2) | Sprint 1 engine (PR #26) |
| **STORY-CLI-002** | Multi-op expressions with operator precedence | #300 | developer | 1.5 | Phase 2 (Day 2-4) | STORY-CLI-001 |
| **STORY-CLI-003** | REPL mode interactive (M3 spirit) | #301 | developer | 1.0 | Phase 3 (Day 4-6) | STORY-CLI-001, STORY-CLI-002 |

**CLI scope total**: 4.5 SP (sequential chain, dev WIP=1 cap means one-at-a-time)

### Doctrine companion (P1, 1.0 SP, owner-only territory)

| ID | Title | Issue | Owner | SP | Phase |
|---|---|---|---|---|---|
| **#296** | Peer-poke discipline (scripts/peer-poke.sh helper + 5-soul amendment) | #296 | orchestrator (script) + owner (soul amendment) | 1.0 | Parallel to CLI dev |

**Why this is in Sprint 7**: owner doctrine 2026-06-23T12:55Z ("adam gibi poke etmeyi öğrenmelisin"). The Sprint 6 12:50Z Telegram-only poke miss exposed the gap. ADR-0033 dual-channel (notify.sh -w -r) already exists; gap is discipline (5-soul enforcement). Sprint 7 P1 to prevent Sprint 8+ agent productivity loss.

**Total committed**: 5.5 SP

## Carryover

### Sprint 6 P0 (blocked on owner cron)

| ID | Title | Owner | Unblock |
|---|---|---|---|
| #235 | Orchestrator proactive-gap-scan duty (P0) | orchestrator | owner cron registration |
| #236 | Sprint 4 P0 gap-scan template port | developer | #235 unblock + owner cron |

### Sprint 6 P2 (deferred — PM recommends Sprint 7 P2 or Sprint 8)

| ID | Title | Owner | SP |
|---|---|---|---|
| #193 | ADR-0030 deviation — runner user | architect | 0.5 |
| #194 | Symlink cleanup (RCA-17) | architect | 0.5 |
| #198 | #48.1 template port | developer | 1.0 |
| #293 | Cross-repo PR auto-close (ADR-0040 design ✅) | architect+dev+owner+tester | 1.5 |

**Sprint 6 P2 carry total**: 3.5 SP

## Capacity planning (continuous flow — no hard sprint cap)

| Role | Available | Committed (Sprint 7) | Sprint 6 carry | Free |
|---|---|---|---|---|
| developer | 8 SP | 4.5 (CLI chain) | 3.0 (#198 + #236 + #293 dev share) | 0.5 |
| architect | 4 SP | 0 (CLI engine-only, no arch) | 2.5 (#193 + #194 + #293 arch share) | 1.5 |
| product-manager | 2 SP | 0 (Sprint 7 plan landed) | (grooming) | 2.0 |
| tester | 4 SP | 1.5 (d036 CLI TDD RED + green) | 0.5 (#293 d035) | 2.0 |
| owner | 0.5 SP | 0.5 (#296 soul patch — owner-only) | 0.25 (#293 CI wiring) | (overcommitted) |
| orchestrator | continuous | 1.0 (#296 helper script) | 1.0 (#235 cron setup) | continuous |

**Sprint 7 total capacity**: ~22 SP (continuous, no sprint end date)
**Sprint 7 committed**: 5.5 SP + 4.0 SP Sprint 6 carry (unblocked) = 9.5 SP / 43% utilization (healthy headroom for #296 owner patch + carry P0)

## Risks

1. **Dev WIP=1 cap vs CLI chain length** (3 stories, 4.5 SP, sequential) — chain is the critical path. If CLI-001 takes 3+ days, 002/003 slip. Mitigation: dev can ship CLI-001 at 80% with CLI-002 TDD-RED in parallel if interfaces are stable.
2. **#296 owner soul patch** (5 files, ~5 min) — depends on owner availability. Sprint 7 P1; blocks Sprint 8+ agent productivity if deferred.
3. **CLI architecture**: parser approach (stdlib `re` + recursive descent, per architect PR #298 review 🟡) — boring-tech-wins, but unproven at Sprint scale. Mitigation: d036 TDD RED ready (PR #303 pending merge).
4. **PR #303 owner merge dependency**: Sprint 7 test plans must land BEFORE dev claims CLI-001, otherwise d036 has no spec. Owner merge is in the critical path.

## Out-of-scope (Sprint 8+ candidates)

- HTTP API surface (ADR-0017 deferred)
- WASM surface (ADR-0017 deferred)
- Multi-platform distribution (PyInstaller vs PyPI)
- Persistence layer
- Sprint 6 P2 carry (#193/#194/#198/#293) — deferred to Sprint 7 P2 or Sprint 8

## Sprint 7 ceremony plan

1. **Day 0 (now, 2026-06-23T14:52Z)**: Sprint 7 active. PR #298 merged, #302 closed.
2. **Day 0+1**: PR #303 owner merge (CLI test plans land). Dev auto-claims STORY-CLI-001 (~5 min via agent-watch).
3. **Day 1-3**: Dev implements STORY-CLI-001 (basic arithmetic via typer). Tester parallel-writes d036 TDD RED if not already from PR #303.
4. **Day 3-5**: STORY-CLI-002 (multi-op with precedence). Depends on STORY-CLI-001 merged.
5. **Day 5-7**: STORY-CLI-003 (REPL mode). Depends on STORY-CLI-002 merged.
6. **Day 1-7 (parallel)**: #296 owner soul patch + orchestrator peer-poke helper script.
7. **Day 7+**: All 4 items shipped. Sprint 7 close + RETRO-005.

## Open questions for owner

1. **PR #303 merge**: ~30 sec, unblocks dev TDD RED on STORY-CLI-001.
2. **#235 cron registration**: 5 min, unblocks #236 P0 carry. (Sprint 4 P0 carry from June 20.)
3. **#296 soul patch timing**: 5 min owner-only territory; Sprint 7 P1 or defer to Sprint 7 P2?
4. **Sprint 6 P2 carry**: Sprint 7 P2 or Sprint 8? (PM recommends Sprint 7 P2 to clear backlog before Sprint 8 user-facing features.)

## Resolved (owner directives + agent decisions)

- ✅ **Sprint 7 mode = CONTINUOUS FLOW** (owner directive 2026-06-23T13:28Z chat, "sprint 7 yi de aç başlat")
- ✅ **PR #298 merge** (Sprint 7 PM scope shipped 2026-06-23T14:48:41Z)
- ✅ **#302 Sprint 7 kickoff chore closed** (terminal hand-off per ADR-0015, 2026-06-23T14:52Z)
- ✅ **CLI architecture review** (architect PR #298 review, 🟢 OK + 12 🟡 suggestions — stdlib `re` + recursive descent, stdlib `input()` REPL, hardcode 28-digit Decimal precision)
- ⏳ **PR #303 merge** (awaiting owner, ~30 sec — Sprint 7 test plans)

## Sprint 7 board state (as of 2026-06-23T14:52Z)

| Column | Item | Owner |
|---|---|---|
| **Done** | #302 (Sprint 7 kickoff) | orchestrator |
| **Ready** | #299 STORY-CLI-001 | developer (auto-claim pending PR #303 merge) |
| **Ready** | #300 STORY-CLI-002 | developer (sequential, after #299) |
| **Ready** | #301 STORY-CLI-003 | developer (sequential, after #300) |
| **Backlog** | #296 peer-poke discipline | orchestrator + owner |
| **Backlog** | #193, #194, #198, #293 (Sprint 6 P2 carry) | architect / developer |
| **Blocked** | #235, #236 (Sprint 4 P0, owner cron-blocked) | orchestrator / developer |

— Orchestrator, 2026-06-23T17:52+03:00 (Sprint 7 active, awaiting PR #303 owner merge + dev auto-claim)
