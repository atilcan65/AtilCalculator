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
- **Doctrinal drift add (Sprint 7 P2, post-ADR-0044)**: #319 verdict-by enforcer refinement (1.0 SP = 0.5 SP script-touch orchestrator + 0.5 SP dev d-test) — added per pre-draft spec [../../peer-poke-spec.md](../../peer-poke-spec.md) §Sprint 7 scope-drift
- **Sprint 6 P2 carry deferred**: #193, #194, #198, #293 (3.5 SP total) → Sprint 7 P2 or Sprint 8 (PM recommendation)
- **Sprint 6 P0 carry**: #235 (orchestrator gap-scan duty) + #236 (dev gap-scan template port) — owner cron-blocked
- **Sprint 6 lead ADRs already on main**: ADR-0039 (wip-idle watchdog) + ADR-0040 (cross-repo PR auto-close) — both Accepted via PR #297

## Sprint 7 scope — RE-PLANNED (2026-06-25T19:08+03:00 post-REPRIME)

> ⚠️ **Ground-truth reconciliation 2026-06-25T19:08+03:00**: Sprint 7 P0 lead-track was ALREADY SHIPPED 2026-06-23 (PR #314 + #318 merged, #299/#300/#301 CLOSED) — 2 days BEFORE my Sprint 7 kickoff at 2026-06-25T18:25Z. This is iteration 2 of the #374 doctrine gap (orchestrator stale-state). Filed #378 for RETRO-005 day 7+.

### ✅ DONE pre-kickoff (no work remaining)

| ID | Title | Issue | PR | Merged | Notes |
|---|---|---|---|---|---|
| STORY-CLI-001 | Basic arithmetic via typer CLI (M1) | #299 | (pre-PR #314 chain) | 2026-06-22 (approx) | CLOSED COMPLETED |
| STORY-CLI-002 | Multi-op expressions + operator precedence | #300 | #314 | 2026-06-23T20:20:11Z | CLOSED COMPLETED, includes ** power op |
| STORY-CLI-003 | REPL mode interactive (M3) | #301 | #318 | 2026-06-23T21:15:25Z | CLOSED COMPLETED |
| Sprint 6 P2 carry | #198 template port | #198 | atilcan65/dev-studio-template#61 | 2026-06-25T15:42:46Z | CLOSED COMPLETED |
| Sprint 6 P2 carry | #293 cross-repo PR auto-close | #293 | (already in Sprint 6) | 2026-06-24T10:33:52Z | CLOSED COMPLETED |

### 🟡 Remaining Sprint 7 scope (PM verdict 2026-06-25T19:07Z — Option B+#316, awaiting owner approval)

| ID | Title | Issue | Owner | SP | Phase |
|---|---|---|---|---|---|
| **#316** | installable `atilcalc` binary in pyproject.toml (CLI polish, M1 close-out) | #316 | developer | 0.25 | Day 1-2 (dev, parallel to doctrine pair) |
| **#296** | Peer-poke discipline (scripts/peer-poke.sh helper + 5-soul amendment) | #296 | orchestrator (script) + owner (soul amendment) | 1.0 | Day 1-3 (orch script) + owner soul patch (gating) |
| **#319** | verdict-by:* enforcer refinement — exclude TDD RED contract PRs from SLA timer | #319 | orchestrator (script-touch on `scripts/agent-watch.sh` `query_stale_verdict`) + dev (d-test) | ~30 LoC | Day 2-4 (after #296 to prevent meta-meta-meta stack) |

**Total committed**: ~2.25 SP (PM verdict 2026-06-25T19:07Z, awaiting owner approval per CLAUDE.md §Auto-Ping Hard-Rule)

**PM rationale (per #376 PM verdict comment):**
1. #316 closes the user-facing CLI arc (CLI MVP shipped, polish = `atilcalc <expr>` post-`pip install`)
2. #296 + #319 doctrine pair addresses Sprint 6 Day 1-2 gap stack
3. Option A (doctrine-only) breaks user-facing momentum
4. Option B+#370 (meta-test) deferred to Sprint 8 P2
5. Option C (early close) commits Sprint 8 prematurely

**Sprint 8 proposal (PM, awaiting orch+owner confirmation):**
- STORY-HTTP-001 (FastAPI scaffold, 2.0 SP)
- STORY-HTTP-002 (HTTP REPL, 1.5 SP)
- STORY-HTTP-003 (front-end web shell revival, 1.5 SP)
- #370 (d043 lens-h carryover, 1.0 SP)
- Total: 6.0 SP. HTTP surface = M1+M3 web coverage.

**RETRO-005 ceremony**: Day 7+ = 2026-06-27 (Saturday, unchanged).

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

## Capacity planning (RE-PLANNED post-REPRIME)

| Role | Available | Committed (Sprint 7 remaining) | Done pre-kickoff | Free |
|---|---|---|---|---|
| developer | 8 SP | 0 (#296 + #319 are orch/dev mix, but dev share = #319 d-test only ≈ 0.5 SP) | 4.5 (CLI chain via PR #314+#318) + 1.5 (#198+#293 dev share) | ~6.0 SP available for Sprint 7 add or Sprint 8 start |
| architect | 4 SP | 0 (no arch in #296/#319 directly) | 0 (CLI engine-only) | 4.0 SP available |
| product-manager | 2 SP | 0 (plan landed + re-scope in flight) | 0 | 2.0 SP available |
| tester | 4 SP | 0.5 (#319 d-test) | 1.5 (CLI chain regression tests in PR #314/#318) | 2.0 SP available |
| owner | 0.5 SP | 0.5 (#296 soul patch — owner-only) | 0 | 0.0 (overcommitted) |
| orchestrator | continuous | 1.5 (#296 script + #319 script-touch) | 0 | continuous |

**Sprint 7 total capacity**: ~22 SP (continuous, no sprint end date)
**Sprint 7 remaining**: 2.0 SP (#296 + #319) + TBD dev polish (#316 or #370 if PM adds) + Sprint 6 carry P0 (#235 + #236 still owner-cron-blocked)

**Net:** Sprint 7 dev-lane is idle unless PM adds #316 or #370, or Sprint 8 starts early.

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

## Sprint 7 ceremony plan (RE-PLANNED)

1. **Day -2 (2026-06-23T20:20Z — pre-kickoff, retroactively):** Sprint 7 P0 lead track SHIPPED. PR #314 (STORY-300) MERGED.
2. **Day -2 (2026-06-23T21:15Z):** PR #318 (STORY-301 REPL) MERGED. Sprint 7 lead track COMPLETE 2 days before kickoff.
3. **Day 0 (2026-06-25T18:25Z — owner directive):** Sprint 7 kickoff issued, but plan.md stale (already-shipped lead track listed as ready).
4. **Day 0+1h (2026-06-25T19:08Z — REPRIME recovery):** Orchestrator re-plan: 2.0 SP remaining (#296 + #319). PM verdict pinged on Sprint 7 final scope.
5. **Day 1-3 (2026-06-25 → 2026-06-28):** Awaiting PM verdict on Sprint 7 final scope (A/B+316/B+370/C).
6. **Day 3-5 (parallel):** Orchestrator writes `scripts/peer-poke.sh` (#296 script-touch); orchestrator scripts `query_stale_verdict` scope-rule fix (#319); dev writes d-test for #319.
7. **Day 5+ (owner gating):** Owner soul amendment for #296 (5 files, ~5 min, blocks #296 Done).
8. **Day 7+ (2026-06-27 + 2026-07-02):** RETRO-005 ceremony (unchanged). Sprint 7 close. Sprint 8 kickoff (PM-groomed scope, CLI MVP post-launch polish).

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

## Sprint 7 board state (RE-CONCILED 2026-06-25T19:08+03:00 post-REPRIME)

| Column | Item | Owner | Notes |
|---|---|---|---|
| **Done** | #302 (Sprint 7 kickoff chore) | orchestrator | closed 2026-06-23T14:52Z |
| **Done** | #299 STORY-CLI-001 | developer | CLOSED COMPLETED pre-kickoff |
| **Done** | #300 STORY-CLI-002 | developer | CLOSED COMPLETED via PR #314 |
| **Done** | #301 STORY-CLI-003 | developer | CLOSED COMPLETED via PR #318 |
| **Done** | #198 (Sprint 6 P2 carry) | developer | CLOSED COMPLETED via PR #61 |
| **Done** | #293 (cross-repo PR auto-close) | architect+dev+owner+tester | CLOSED COMPLETED 2026-06-24 |
| **Backlog** | #296 peer-poke discipline | orchestrator + owner | sprint:current, awaiting orchestrator script start |
| **Backlog** | #319 verdict-by refinement | orchestrator + dev | sprint:current, awaiting orchestrator script-touch start |
| **Backlog** (proposed) | #316 atilcalc binary | developer | priority:P1, 44h stale — awaiting PM verdict |
| **Backlog** (proposed) | #370 d043 lens-h | developer | priority:P2, sprint:backlog, 19h stale — awaiting PM verdict |
| **In Progress** | #376 Sprint 7 kickoff issue | orchestrator | status:in-progress, cc:product-manager (PM verdict pending) |
| **Backlog** | #378 RETRO-005 #18 candidate | product-manager | status:backlog, sprint:backlog — for day 7+ ceremony |
| **Blocked** | #235, #236 (Sprint 4 P0 carry) | orchestrator / developer | owner-cron-blocked (unchanged) |

— Orchestrator, 2026-06-25T19:08+03:00 (Sprint 7 re-planned, PM verdict pending on final scope)
