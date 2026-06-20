# Sprint 4 — Plan (committed, awaiting owner approval)

> **Status:** 🟡 Plan written by orchestrator after PM grooming (PR #177) + 3 peer verdicts (tester 🟢, developer 🟢, architect 🟢).
> **Source:** [`proposed-scope.md`](./proposed-scope.md) + [`backlog.json`](./backlog.json) (PM-groomed) + RETRO-003 (PR #174, merged).
> **Tracking issue:** [Issue #176](https://github.com/atilcan65/AtilCalculator/issues/176) (agent:orchestrator, status:ready, sprint:next).
> **Sprint window:** 2026-07-04 → 2026-07-17 (14 days; starts day after Sprint 3 close).
> **Capacity:** 5 agents × 14 days ≈ 35-45 SP.
> **Committed total:** **18.5 SP** (corrected from PM's claimed 19.5 — see ⚠️ Note 1 below). 56-67% capacity buffer for unplanned + Sprint 3 P0 DoD §4/§5 carry + Sprint 3 24h burn-in + ceremony time.
> **Owner approval:** ⏳ pending (this plan → Issue #176 comment → atilcan ping).

---

## Sprint goal

**Stabilize the Sprint 3 P0 deploy automation + close the doctrine gaps surfaced by the RCA-1 → RCA-15 chain.**

Sprint 3 was operational hardening (deploy pipeline, self-hosted runner, RCA fix chain). Sprint 4 closes the residual deploy-verify gap (E2E harness + RCA-15 pre-req race), the auto-revert bug (#125), and consolidates 5 P1 doctrine/tooling follow-ups the chain exposed.

**Sprint 4 is stabilization + doctrine consolidation, not new features.** All MVP-1 metrics M1-M5 remain shipped; Sprint 4 makes the system stable (RCA-15) and the doctrine durable (TD-015/016/018/019 promotion, watcher loop fix, template port, dev-idle Katman 3).

---

## Committed scope (3 P0 + 4 P1 + 3 P2 = 10 stories, 18.5 SP)

### P0 — Sprint 4 critical path (6 SP, 3 stories)

| ID | Title | SP | Owner | Test contract | Sprint 4 day |
|---|---|---|---|---|---|
| **RCA-15-CLOSE** | RCA-15 close — owner pre-req + v9 deploy verified + PR #172 close | 1 | owner (human) | 5-step contract from Issue #175 cmt | **Day 1 BLOCKING** |
| **AUTO-REVERT-FIX** | #125 auto-revert bug fix (architect RC + dev impl) | 2 | architect (RC) + dev (impl) | regression: 3 PRs no-revert within 90s | Day 1-2 |
| **E2E-DEPLOY-VERIFY** | E2E deploy verification harness (RCA-15 service persistence) | 3 | dev (harness impl) + tester (d019 RED) | d019 + 3+ deploys + 5+min service alive + `systemctl --user is-active` | Day 3-5 |

### P1 — Parallel tracks (9 SP, 4 stories) ⚠️ Note 1

| ID | Title | SP | Owner | Sprint 4 day |
|---|---|---|---|---|
| **DOCTRINE-A11-EXT** | #102 doctrine gap A11-ext — owner-override PR merge design drift consolidation | 2 | architect (with dev input) | Day 2-4 |
| **WATCHER-FIX** | #94 watcher stale-cc loop fix (architect-owned script patch) | 1 | architect + tester (d020) | Day 1-2 |
| **TEMPLATE-PORT** | #48 template port — Sprint 1+2+3 lessons → dev-studio-template | 5 | developer (primary) | Day 1-14 (long-pole) |
| **DEV-IDLE-K3** | #119 dev-idle fix Katman 3 — owner-applied soul amendment (5 soul files) | 1 | owner (human, .claude/ human-only) | Day 5-7 |

### P2 — Backlog overflow (3.5 SP, 3 stories)

| ID | Title | SP | Owner | Sprint 4 day |
|---|---|---|---|---|
| **PM-EVENT-EXT** | agent-watch PM event extension (Sprint 1 retro A5 carry) | 1 | architect + dev | Day 7-10 |
| **SELF-POSTMORTEM-REPL** | Replicate architect self-post-mortem pattern for other agents | 2 | orchestrator (PM/dev/tester sub-impls) | Day 10-12 |
| **ADR-0023-FLIP** | ADR-0023 status flip (Proposed → Accepted) | 0.5 | PM | Day 12-14 |

---

## ⚠️ Note 1 — PM grooming count inconsistency (resolved here)

PM's `proposed-scope.md` claims "5 P1 = 10 SP" and total "19.5 SP". The JSON file `backlog.json` contains only **4 P1 stories** with 2+1+5+1 = **9 SP**. PM-EVENT-EXT is P2 in both the JSON and the table. **Total SP from JSON stories = 6 + 9 + 3.5 = 18.5 SP**, not 19.5.

**This plan commits to 18.5 SP** (truth from JSON). The 0.5 SP delta is in PM's `totals.p1_sp_proposed` field (10 vs 9). Likely a transcription error from PM during grooming — not material to Sprint 4 capacity. Flagged here so the discrepancy is durable in our record.

**Auto-ping**: `[ORCH→PM] backlog.json count: p1_count=5 in totals but array has 4 stories. Please amend on next PM grooming or accept 18.5 SP as ground truth.`

---

## Capacity & utilization

| Bucket | SP | % of target (35-45) |
|---|---|---|
| **P0 critical path** | 6 | 13-17% |
| **P1 parallel tracks** | 9 | 20-26% |
| **P2 backlog overflow** | 3.5 | 8-10% |
| **Committed total** | **18.5** | **41-53%** |
| **Buffer (unplanned + burn-in + ceremony)** | 16.5-26.5 | 47-76% |
| **Effective capacity available** | **35-45** | **100%** |

**Buffer rationale**: Sprint 3 was incident-mode (14 RCAs in 4 days). Sprint 4 capacity buffer absorbs:
- Sprint 3 24h burn-in bugs (active until 2026-07-04)
- 2 owner-gated events (RCA-15-CLOSE + DEV-IDLE-K3 — same validated pattern)
- E2E deploy verification reveals deeper prod stability issue (P1 risk)
- Sprint 4 P0 chain dependency (RCA-15 → AUTO-REVERT-FIX → E2E-DEPLOY-VERIFY)
- Sprint 5 backlog grooming + Sprint 4 retrospective ceremony time

**Buffer is generous but justified** given Sprint 3 incident rate. If buffer is not consumed, Sprint 5 carries less Sprint 4 spillover.

---

## Dependency DAG (Sprint 4 commit order)

```
RCA-15-CLOSE (owner pre-req, 5-10min) ─┐
                                        ├──► E2E-DEPLOY-VERIFY (3 SP) ──► DoD §4/§5 close
AUTO-REVERT-FIX (architect RC, 2 SP) ──┤
                                        │
DOCTRINE-A11-EXT (architect, 2 SP) ────┤
WATCHER-FIX (architect, 1 SP) ─────────┤
                                        ├──► TEMPLATE-PORT (developer, 5 SP)
DEV-IDLE-K3 (owner, 1 SP) ─────────────┤
                                        │
PM-EVENT-EXT (architect, 1 SP) ────────┤
SELF-POSTMORTEM-REPL (orchestrator, 2 SP) ┤
                                        │
ADR-0023-FLIP (PM, 0.5 SP) ────────────┘ (parallel, no deps)
```

### Critical path (Sprint 4 day-by-day)

| Day | Action | Owner | Output |
|---|---|---|---|
| **Day 1 (2026-07-04)** | RCA-15-CLOSE owner pre-req applied (4-step systemd setup) | owner | Service persists, v9 deploy verified |
| **Day 1-2** | AUTO-REVERT-FIX architect RC | architect | RC report → issue #125 options a/b/c |
| **Day 1-2** | WATCHER-FIX (parallel) | architect + tester | scripts/agent-watch.sh patched + d020 regression |
| **Day 1-14** | TEMPLATE-PORT (long-pole, parallel) | developer | Sprint 1+2+3 lessons → dev-studio-template repo |
| **Day 2-4** | AUTO-REVERT-FIX dev impl + tester sign-off | dev + tester | Regression test PASS (3 PRs no-revert) |
| **Day 2-4** | DOCTRINE-A11-EXT (parallel with #125) | architect | PR #174 + #81 + #122 + #125 post-mortem → ADR-0033 |
| **Day 3-5** | E2E-DEPLOY-VERIFY harness impl + d019 RED → GREEN | dev + tester | 3+ deploys + 5+min service persistence + systemctl active |
| **Day 5-7** | DEV-IDLE-K3 owner-applied soul amendment | owner | 5 soul files patched, d015 still 9/9 PASS |
| **Day 5-7** | PR #172 close (superseded by v9 on main via PR #174) | owner + dev | Sprint 3 P0 carry closed |
| **Day 7-10** | PM-EVENT-EXT | architect + dev | agent-watch.sh emits PM events + d021 regression |
| **Day 10-12** | SELF-POSTMORTEM-REPL | orchestrator | 5-min self-post-mortem timer for PM/dev/tester + pilot on #171 |
| **Day 12-14** | ADR-0023-FLIP + retrospective + Sprint 5 grooming | PM + orchestrator | ADR-0023 Accepted + retro doc + Sprint 5 backlog drafted |

### Owner gates (2 events, 5-10 min each)

| Event | Owner action | Sprint 4 day | Pattern |
|---|---|---|---|
| **RCA-15-CLOSE pre-req** | (1) install unit file, (2) `loginctl enable-linger atilcan`, (3) `daemon-reload`, (4) `enable atilcalc-web.service` | Day 1 | Sprint 1+2+3 owner-impl pattern (8+ times) |
| **DEV-IDLE-K3 soul amendment** | Apply `.claude/agents/*.md` patch (5 files) from PR body | Day 5-7 | `.claude/` human-only per CLAUDE.md §File ownership matrix |

Both gates are **small, validated, well-documented**. Same pattern as Sprint 1+2+3 (DEPLOY-002, DEPLOY-003, RCA-13 owner infra fix, RCA-14 v9 systemd, RETRO-003). No Sprint 4 surprise owner work.

---

## Risks & mitigations

| Risk | Severity | Mitigation | Owner |
|---|---|---|---|
| RCA-15 owner pre-req applied late, blocks E2E-DEPLOY-VERIFY | P0 | PM pings owner ahead of Sprint 4 day 1; pre-req doc (Issue #175) is 5-10 min step-by-step | owner + PM |
| AUTO-REVERT-FIX architect RC identifies multi-watcher interaction | P1 | Architect extends RC window to 2 SP max; if root cause is multi-component, scope to highest-impact watcher | architect |
| TEMPLATE-PORT is the long-pole (5 SP) — Sprint 4 critical path | P1 | Split-bounded (process / doctrine / tooling axis); can trim tooling if sizing ceremony demands | developer |
| Sprint 3 P0 DoD §4/§5 carry into Sprint 4 (overlap with Sprint 3 close) | P1 | Sprint 3 close (Issue #176) is the gate; Sprint 4 plan commits AFTER Sprint 3 close | orchestrator |
| 5 owner-impl events in Sprint 4 (RCA-15 + DEV-IDLE-K3 + PM-EVENT-EXT owner review + SELF-POSTMORTEM-REPL orchestrator + ADR-0023-FLIP PM) | P2 | Pattern validated 8+ times Sprint 1+2+3; PM keeps owner gates small (5-10 min each) | owner + PM |
| E2E deploy verification reveals deeper prod stability issue | P1 | Sprint 4 capacity buffer (16.5-26.5 SP) absorbs re-scoping | developer + owner |
| Sprint 3 24h burn-in bug filed after Sprint 4 plan commits | P1 | Sprint 4 capacity buffer absorbs bug fix without re-planning | developer + tester |
| Sprint 3 P0 recovery consumes Sprint 4 day 1-2 capacity | P2 | Sprint 4 has 2-week window; recovery is built into the first 2 days | orchestrator |
| RCA-15 PR #172 close sequence (close AFTER v9 deploy verified, not before) | P1 | Sprint 4 dependency DAG makes RCA-15-CLOSE → E2E-DEPLOY-VERIFY → close PR #172 explicit | developer |
| AUTO-REVERT-FIX touches label-check workflow (CLAUDE.md §File ownership matrix) | P1 | Architect reviews workflow change; owner approval required per CLAUDE.md | architect + owner |

---

## Definition of Done (sprint-level)

Sprint 4 is **DONE** when ALL of:

1. **All committed stories merged to main with owner approval**
   - Workflow-file merges for AUTO-REVERT-FIX are owner-only per CLAUDE.md §File ownership matrix
   - `.claude/` soul files for DEV-IDLE-K3 are owner-only
   - All other stories follow standard PR + tester signoff + owner merge flow
2. **CI green on main post-merge** (every story's PR shows green at merge time)
3. **Sprint 3 P0 DoD §4/§5 close** — minimum 3 consecutive auto-deploys each showing service alive 5+ min post-deploy, with `systemctl --user is-active atilcalc-web.service` returning `active` between deploys. Re-validation with v9 code from PR #174.
4. **`docs/sprints/sprint-04/retrospective.md` written** — RETRO-004 with Sprint 4 lessons, RCA-16+ if any, doctrine amendments
5. **Template port complete** — atilcan65/dev-studio-template repo has Sprint 1+2+3 lessons ported (5 files, ~50 lines per layer); cross-repo PR merged or owner-acknowledged
6. **No new P0/P1 bugs filed against Sprint 4 stories within 24h**
7. **Sprint 5 backlog drafted** (grooming-ready) — PM-owned

---

## Sprint 4 owners & responsibilities

| Role | Sprint 4 primary | Sprint 4 cc |
|---|---|---|
| **owner (human)** | RCA-15-CLOSE (1 SP), DEV-IDLE-K3 (1 SP) | All merges, all workflow-file changes |
| **@orchestrator** | SELF-POSTMORTEM-REPL (2 SP), Sprint 4 coordination, Issue #176 close, Sprint 5 grooming prep | Plan review, sprint ceremony |
| **@product-manager** | ADR-0023-FLIP (0.5 SP), Sprint 5 backlog grooming, retro | All P0/P1 sizing, owner ping coordination |
| **@architect** | AUTO-REVERT-FIX RC (2 SP), DOCTRINE-A11-EXT (2 SP), WATCHER-FIX (1 SP), PM-EVENT-EXT (1 SP) | All P0/P1 design, RCA work |
| **@developer** | E2E-DEPLOY-VERIFY (3 SP), TEMPLATE-PORT (5 SP), AUTO-REVERT-FIX impl (2 SP) | All P0/P1 impl, PR work |
| **@tester** | d019 RED + d020 RED + d021 RED (regression contracts), AUTO-REVERT-FIX sign-off | All P0/P1 testing |

**Capacity per agent** (Sprint 4):
- owner: 2 SP owner-gated + ~30 min review (5-6 PR merges)
- orchestrator: 2 SP + sprint coordination (~3-4 h/day)
- PM: 0.5 SP + retro + Sprint 5 grooming (~2 h/day)
- architect: 6 SP P0/P1 (~5-6 h/day)
- developer: 8-10 SP P0/P1 (~6-8 h/day — long-pole owner)
- tester: regression contracts + sign-offs (~3-4 h/day)

All within Sprint 1+2+3 capacity bands. No agent overcommitment.

---

## Sprint 4 cadence (recurring)

| Cadence | Trigger | Action | Owner |
|---|---|---|---|
| **Daily standup** | 09:00 Europe/Istanbul (auto or human) | Post on `[Sprint 4] Daily Standup` issue (threaded comments per day) | orchestrator |
| **WIP check** | Every 60s (`scripts/agent-watch.sh orchestrator`) | Verify WIP ≤ 2 P0 + 4 P1 max; ping if exceeded | orchestrator |
| **Stale check** | Every 4h in same status | Ping owner with `[ORCH→<ROLE>] STORY-NNN stalled, ETA?` | orchestrator |
| **Sprint mid-check** | Day 7 (2026-07-10) | Re-evaluate buffer consumption; adjust if burn rate > 50% | orchestrator |
| **Sprint retro** | Day 14 (2026-07-17) | RETRO-004 + Sprint 5 backlog draft | orchestrator + PM |

**Heartbeat**: every 10 min per agent (already enforced by ADR-0002).

---

## Cross-cutting dependencies (orchestrator-managed)

These are tracked in their own issues, NOT in this PM-authored feature backlog:

- **Issue #176** (P0, this kickoff issue) — closes after Sprint 4 plan committed + Issue #173 acceptance #4 done
- **Issue #173** (P0) — RETRO-003 PM draft done via PR #174; closes after Sprint 4 plan committed
- **Sprint 3 24h burn-in** — active until 2026-07-04; P0/P1 bug filed absorbs into Sprint 4 capacity buffer
- **PR #172 close** (superseded by PR #174) — sequential after RCA-15-CLOSE pre-req applied (Sprint 4 day 5-7)
- **ADR-0023 status flip** (Proposed → Accepted) — Sprint 4 P2 (PM-owned, 0.5 SP)

---

## Owner approval gate

This plan is **DRAFT** until atilcan approves. Decision options for owner:

- **(A) Approve as-is** (18.5 SP, 10 stories, 14-day window, 2 owner gates) → Sprint 4 starts 2026-07-04
- **(B) Modify scope** (add/remove stories, adjust SP) → orchestrator revises plan.md
- **(C) Defer Sprint 4 start** (owner unavailable) → default Sprint 3 P0 DoD §4 stays pending; Sprint 4 starts when owner approves

**Default if no response by 2026-06-25T00:00Z** (T-9 days to Sprint 4 start): orchestrator applies Default karar (B-equivalent) — Sprint 4 starts 2026-07-04 as planned; owner-impl events remain owner gates (don't auto-apply).

---

## Auto-ping on this plan

- **To atilcan**: `[ORCH→HUMAN] Sprint 4 plan ready for your approval — Issue #176`
- **To PM**: `[ORCH→PM] Sprint 4 plan ready, backlog count inconsistency flagged (4 P1 in JSON vs 5 P1 in totals)`
- **To architect**: `[ORCH→ARCH] Sprint 4 plan ready, 6 SP architect-owned (AUTO-REVERT-FIX + DOCTRINE-A11-EXT + WATCHER-FIX + PM-EVENT-EXT)`
- **To developer**: `[ORCH→DEV] Sprint 4 plan ready, 8-10 SP dev-owned (E2E-DEPLOY-VERIFY + TEMPLATE-PORT long-pole + AUTO-REVERT-FIX impl)`
- **To tester**: `[ORCH→TEST] Sprint 4 plan ready, 3 regression contracts expected (d019 + d020 + d021)`

---

## Change log

- **2026-06-20T14:25:00Z** — Initial plan written by @orchestrator after PM grooming (PR #177) + 3 peer verdicts (tester 🟢, developer 🟢, architect 🟢). Sprint 4 stabilization + doctrine consolidation scope. 18.5 SP committed (corrected from PM's 19.5 — see ⚠️ Note 1). 41-53% capacity utilization, generous buffer for Sprint 3 burn-in carry.

— @orchestrator, 2026-06-20T14:25:00Z