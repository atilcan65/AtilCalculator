# Sprint 4 — Proposed Scope (PM grooming, awaiting sizing ceremony)

> **Status:** 🟡 PM-groomed from Issue #176 (Sprint 4 kickoff) + RETRO-003 (Sprint 3 retro, merged via PR #174).
> **Source for backlog:** [`docs/sprints/sprint-04/backlog.json`](./backlog.json) (3 P0 + 5 P1 + 3 P2 = 11 stories).
> **Sprint window:** 2026-07-04 → 2026-07-17 (14 days; starts day after Sprint 3 close).
> **Capacity:** 5 agents × 14 days ≈ 35-45 SP (matching Sprint 1/2/3 template).
> **Proposed total:** **19.5 SP** (43-56% capacity utilization — comfortable buffer for unplanned work + Sprint 3 P0 DoD §4/§5 carry + Sprint 3 24h burn-in bugs + ceremony time).
> **Sprint 3 close-out context:** DoD §4 = 3/3 PASS verified via PR #169 (RCA-12 v8) + RCA-13 owner infra fix. DoD §5 = PENDING (RCA-14 v9 was merged to main via PR #174 owner-override, owner pre-req NOT yet applied — RCA-15). All 14 RCAs in chain closed; doctrine evolved via TD-015/016/018/019 family.

---

## Sprint goal (PM framing)

**Stabilize the Sprint 3 P0 deploy automation + close the doctrine gaps surfaced by the RCA-1 → RCA-15 chain.** Sprint 3 was operational hardening (deploy pipeline, self-hosted runner, RCA fix chain). Sprint 4 closes the residual deploy-verify gap (E2E harness + RCA-15 pre-req race), the auto-revert bug (#125), and consolidates 5 P1 doctrine/tooling follow-ups that the chain exposed.

Sprint 4 is **stabilization + doctrine consolidation**, not new features. All MVP-1 features are shipped; Sprint 4 makes the system **stable** (RCA-15) and the **doctrine durable** (TD-015/016/018/019 promotion, watcher loop fix, template port, dev-idle Katman 3).

---

## Committed stories — PM proposed (Fibonacci, sizing-pending)

| Story | Title | Priority | PM SP | Type | Vision metric | Issue ref |
|---|---|---|---|---|---|---|
| **E2E-DEPLOY-VERIFY** | E2E deploy verification harness (RCA-15 service persistence) | P0 | **3** | feature | M2 | #172 |
| **AUTO-REVERT-FIX** | #125 auto-revert bug fix (architect RC + dev impl) | P0 | **2** | bug | — | #125 |
| **RCA-15-CLOSE** | RCA-15 close — owner pre-req + v9 deploy verified + PR #172 close | P0 | **1** | chore | M2 | #175 |
| **DOCTRINE-A11-EXT** | #102 doctrine gap A11-ext — owner-override PR merge design drift consolidation | P1 | **2** | chore | — | #102 |
| **WATCHER-FIX** | #94 watcher stale-cc loop fix (architect-owned script patch) | P1 | **1** | chore | — | #94 |
| **TEMPLATE-PORT** | #48 template port — Sprint 1+2+3 lessons → dev-studio-template | P1 | **5** | chore | — | #48 |
| **DEV-IDLE-K3** | #119 dev-idle fix Katman 3 — owner-applied soul amendment (5 soul files) | P1 | **1** | chore | — | #119 |
| **PM-EVENT-EXT** | agent-watch PM event extension (Sprint 1 retro A5 carry) | P2 | **1** | chore | — | (new) |
| **SELF-POSTMORTEM-REPL** | Replicate architect self-post-mortem pattern for other agents | P2 | **2** | chore | — | (new) |
| **ADR-0023-FLIP** | ADR-0023 status flip (Proposed → Accepted) | P2 | **0.5** | docs | — | (new) |
| **Proposed total** | | | **19.5 SP** | | | |

**Sizing rule applied:** per `product-manager.md` §Hard Rules, all stories ≤5 SP. Largest 5-SP story (TEMPLATE-PORT) is split-bounded — can be cut along the (process | doctrine | tooling) axis if sizing ceremony demands.

**Capacity buffer:** 15.5-25.5 SP remaining (35-45 - 19.5) for unplanned work + Sprint 3 P0 DoD §4/§5 carry (already in P0 #1+2) + Sprint 3 24h burn-in bugs (active until 2026-07-04) + ceremonies + on-call.

---

## Vision traceability

| Metric (vision.md) | Sprint 1+2+3 status | Sprint 4 stories | Sprint 5+ deferred |
|---|---|---|---|
| **M1 — Accuracy** (0.1+0.2 = 0.3) | ✅ DONE (PR #26, Sprint 1) | — | — |
| **M2 — Stickiness** (≥35 records/week) | ✅ DONE (Sprint 2) | E2E-DEPLOY-VERIFY + RCA-15-CLOSE (operational — service persistence) | Real-data telemetry + polish |
| **M3 — Keyboard-only** | ✅ DONE (PR #49, Sprint 1; extended PR #122, Sprint 2) | — | — |
| **M4 — Skin transition** (cross-device + persistent) | ✅ DONE (Sprint 2) | E2E-DEPLOY-VERIFY (skin system needs stable auto-deploy) | WCAG AAA audit |
| **M5 — History perf** | ✅ DONE (Sprint 2) | — | Real-data validation (1 week post-launch) |

**Sprint 4 outcome**: All MVP-1 metrics M1-M5 remain "shipped"; Sprint 4 closes the **operational** residual (E2E deploy verification + RCA-15) and the **doctrinal** gaps (5 P1 follow-ups). Sprint 5+ is polish, telemetry, or persona expansion.

---

## Dependency DAG (Sprint 4 commit order)

```
RCA-15-CLOSE (owner pre-req applied) ─┐
                                       ├──► E2E-DEPLOY-VERIFY (3 SP) ──► DoD §4/§5 close
AUTO-REVERT-FIX (architect RC, 2 SP) ─┤
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

**Critical sequencing:**
1. **RCA-15-CLOSE** (owner pre-req) must happen FIRST — owner-impl, 5-10min, blocks E2E-DEPLOY-VERIFY
2. **AUTO-REVERT-FIX** architect RC closes Day 1-2 (2 SP) — unblocks all P1 PR work
3. **E2E-DEPLOY-VERIFY** starts after RCA-15-CLOSE pre-req applied (3 SP) — Sprint 4 P0 critical path
4. **WATCHER-FIX + DEV-IDLE-K3** run in parallel (both small, different agents)
5. **TEMPLATE-PORT** is the long-pole (5 SP) — developer-owned, can start after WATCHER-FIX (uses same scripts/agent-watch.sh pattern)
6. **DOCTRINE-A11-EXT + PM-EVENT-EXT + SELF-POSTMORTEM-REPL + ADR-0023-FLIP** are independent parallel tracks

**Critical owner gates** (Sprint 4 has 2 owner-gated events — same as Sprint 3):
- **RCA-15-CLOSE owner gate**: apply 4-step systemd pre-req + verify v9 deploy + close PR #172 (5-10 min owner time)
- **DEV-IDLE-K3 owner gate**: apply soul amendment to 5 soul files (5-10 min owner time, .claude/ is human-only)

---

## Risks & mitigations

| Risk | Severity | Mitigation | Owner |
|---|---|---|---|
| RCA-15 owner pre-req applied late, blocks E2E-DEPLOY-VERIFY | P0 | PM pings owner ahead of Sprint 4 day 1; pre-req doc (Issue #175) is 5-10 min step-by-step | @human + PM |
| AUTO-REVERT-FIX architect RC identifies multi-watcher interaction (Issue #125 hypothesis list) | P1 | Architect extends RC window to 2 SP max; if root cause is multi-component, scope to highest-impact watcher | @architect |
| TEMPLATE-PORT is the long-pole (5 SP) — Sprint 4 critical path | P1 | Split-bounded (process | doctrine | tooling); can trim tooling if sizing ceremony demands | @developer |
| Sprint 3 P0 DoD §4/§5 carry into Sprint 4 means Sprint 4 P0 has overlap with Sprint 3 close | P1 | Sprint 3 close (Issue #176) is the gate; Sprint 4 plan commits AFTER Sprint 3 close; no actual conflict | @orchestrator |
| 5 owner-impl pattern in Sprint 4 (RCA-15 pre-req + DEV-IDLE-K3 + PM-EVENT-EXT owner review + SELF-POSTMORTEM-REPL orchestrator + ADR-0023-FLIP PM) | P2 | Pattern validated 8+ times Sprint 1+2+3; PM keeps owner gates small (5-10 min each) | @human + PM |
| E2E deploy verification reveals deeper prod stability issue | P1 | Sprint 4 capacity buffer (15.5-25.5 SP) absorbs re-scoping | @developer + @human |
| Sprint 3 24h burn-in bug filed after Sprint 4 plan commits | P1 | Sprint 4 capacity buffer absorbs bug fix work without re-planning | @developer + @tester |
| Architect + PM + tester sprint capacity consumed by Sprint 3 P0 close (1-2 days recovery) | P2 | Sprint 4 has 2-week window; recovery is built into the first 2 days | @orchestrator |
| RCA-15 PR #172 close sequence (close AFTER v9 deploy verified, not before) | P1 | Sprint 4 dependency DAG makes RCA-15-CLOSE → E2E-DEPLOY-VERIFY → close PR #172 explicit | @developer |
| AUTO-REVERT-FIX touches label-check workflow (CLAUDE.md §File ownership matrix) | P1 | Architect reviews workflow change; owner approval required per CLAUDE.md | @architect + @human |

---

## Definition of Done (sprint-level)

Sprint 4 is **DONE** when ALL of:

1. All committed stories merged to main with owner approval (workflow-file merge for AUTO-REVERT-FIX is owner-only per CLAUDE.md; .claude/ soul files for DEV-IDLE-K3 is owner-only).
2. CI green on main post-merge.
3. **Sprint 3 P0 DoD §4/§5 close**: 3+ successful self-hosted-runner auto-deploys (DoD §4) + 1 verified rollback path (DoD §5) — re-validation with v9 code from PR #174.
4. `docs/sprints/sprint-04/retrospective.md` written.
5. **Template port complete**: atilcan65/dev-studio-template repo has Sprint 1+2+3 lessons ported.
6. No new P0/P1 bugs filed against Sprint 4 stories within 24h.
7. Sprint 5 backlog drafted (grooming-ready).

---

## Cross-cutting dependencies (Sprint 4, parallel to this PM backlog)

These are orchestrator/architect/developer-owned chore stories tracked in their own issues, NOT in this PM-authored feature backlog. They will be sized into the final Sprint 4 plan at the sizing ceremony:

- **Issue #176** (P0, this kickoff issue) — closes after Sprint 4 plan committed + Issue #173 acceptance #4 (Issue #173 done)
- **Issue #173** (P0) — RETRO-003 PM draft done via PR #174; closes after Sprint 4 plan committed
- **Sprint 3 24h burn-in** — active until 2026-07-04; P0/P1 bug filed absorbs into Sprint 4 capacity buffer
- **PR #172 close** (superseded by PR #174) — sequential after RCA-15-CLOSE pre-req applied
- **ADR-0023 status flip** (Proposed → Accepted) — Sprint 4 P2 (PM-owned, 0.5 SP)

---

## PM next actions (this PR's exit)

1. **This docs PR opens** with `docs/sprints/sprint-04/backlog.json` + `docs/sprints/sprint-04/proposed-scope.md` + Sprint 4 iteration field configured (Sprint 4 iteration id `702fe15a` on project #1, field `PVTIF_lAHOEBQhpc4BaJ7VzhVDhLY`).
2. **Sprint 4 plan PR** (orchestrator-owned) — publishes `docs/sprints/sprint-04/plan.md` (committed scope after sizing ceremony).
3. **Auto-ping orchestrator + architect + developer + tester** with sizing ceremony signal (Sprint 4 kickoff).
4. **Atomic hand-off on Issue #176**: flip `agent:product-manager` → `agent:orchestrator` + `cc:orchestrator` (per ADR-0015). Orchestrator's turn: run sizing ceremony, publish plan, get owner approval, then move Issue #176 to `status:done` and Issue #173 to `status:done`.
5. **PM stays in polling mode** for sizing comments + plan review + Sprint 4 P2 work (PM-EVENT-EXT advisory, ADR-0023-FLIP lead).

---

## Change log

- **2026-06-20T14:15:00Z** — Initial draft. PM-groomed from Issue #176 (Sprint 4 kickoff) + RETRO-003 (Sprint 3 retro, merged via PR #174). 3 P0 + 5 P1 + 3 P2 = 11 stories = 19.5 SP proposed. 43-56% capacity utilization (15.5-25.5 SP buffer for Sprint 3 P0 DoD §4/§5 carry + 24h burn-in bugs + unplanned). Sprint 4 is stabilization + doctrine consolidation, NOT feature work.

— @product-manager, 2026-06-20T14:15:00Z
