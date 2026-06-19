# Sprint 3 — Proposed Scope (PM grooming, awaiting sizing ceremony)

> **Status:** 🟡 PM-groomed from Issue #127 (owner directive) + ADR-0027 (deploy architecture).
> **Source for backlog:** [`docs/sprints/sprint-03/backlog.json`](./backlog.json) (4 deploy stories + 1 retro + 1 template port).
> **Sprint window:** 2026-06-20 → 2026-07-03 (14 days; starts day after Sprint 2 P1 ship).
> **Capacity:** 5 agents × 14 days ≈ 35-45 SP (matching Sprint 1/2 template).
> **Proposed total:** **13 SP** (29-37% capacity utilization — comfortable buffer for unplanned work + post-Sprint-2 bug fixes + ceremony time).
> **Already-accepted context (not in commit):** Sprint 2 P1 all DONE (PR #88/#111/#112/#117/#118/#122); ADR-0027 Accepted via PR #128; ADR-0023 implementation shipped via PR #122 (status flip Proposed→Accepted is a separate small follow-up).

---

## Sprint goal (PM framing)

**Close the prod-liveness gap + capture Sprint 2 lessons.** Sprint 2 P1 merged 6 of 6 P1 feature stories, but the production site doesn't auto-update — owner has been manually SSH-deploying since Sprint 1. Sprint 3 ships the GitHub Action deploy pipeline (per ADR-0027) so that any future `main` merge flows to prod automatically, AND writes the Sprint 2 retro so the lessons are durable, AND ports the Sprint 1+2 lessons to the dev-studio template (Issue #48 unblock).

Sprint 3 is **operational hardening + retro ceremony**, not feature work. All MVP-1 features are shipped; Sprint 3 makes the system trustworthy and the learnings reusable.

---

## Committed stories — PM proposed (Fibonacci, sizing-pending)

| Story | Title | Priority | PM SP | Type | Vision metric | ADR refs |
|---|---|---|---|---|---|---|
| **DEPLOY-002** | Secret wiring (SSH key + host + user repo secrets) | P0 | **2** | feature | M2 | ADR-0027 §2, ADR-0014 precedent |
| **DEPLOY-001** | Trigger pipeline (.github/workflows/deploy.yml + scripts/deploy-runner.sh) | P0 | **3** | feature | M2 + M4 | ADR-0027 §1+2+5+6 |
| **DEPLOY-003** | `GET /healthz` + smoke test + auto-rollback | P0 | **3** | feature | M2 | ADR-0027 §3, ADR-0019 amend |
| RETRO-003 | Sprint 2 retrospective (PM drafts, orchestrator publishes) | P1 | **1** | docs | — | — |
| TEMPLATE-PORT | Issue #48 — Sprint 1+2 lessons → dev-studio-template | P1 | **3** | chore | — | — |
| DEPLOY-004 (optional) | `scripts/deploy-status.sh` audit query | P2 | **1** | feature | — | ADR-0027 §6 |
| **Proposed total** | | | **13 SP** | | | |

**Sizing rule applied:** per `product-manager.md` §Hard Rules, all stories ≤5 SP. Largest 3-SP stories (DEPLOY-001, DEPLOY-003) are split-bounded — workflow-file + smoke-test scope can be cut along the "human-only workflow approval" line if sizing ceremony demands.

**Capacity buffer:** 22-32 SP remaining (35-45 - 13) for unplanned work + Sprint 3 ceremonies + on-call + post-Sprint-2 bug fixes (24h burn-in active until 2026-06-20T18:33:04Z — 6 P1 stories under observation).

---

## Vision traceability

| Metric (vision.md) | Sprint 1+2 status | Sprint 3 stories | Sprint 4+ deferred |
|---|---|---|---|
| **M1 — Accuracy** (0.1+0.2 = 0.3) | ✅ DONE (PR #26) | — | — |
| **M2 — Stickiness** (≥35 records/week) | ✅ DONE (STORY-007+008+011 shipped) | DEPLOY-001/002/003 (validate post-launch with real usage) | Real-data telemetry + polish |
| **M3 — Keyboard-only** | ✅ DONE (PR #49, extended in PR #122) | — | — |
| **M4 — Skin transition** (cross-device + persistent) | ✅ DONE (STORY-009+010 shipped) | DEPLOY-001 (skin system needs auto-deploy to validate cross-device clause in prod) | WCAG AAA audit |
| **M5 — History perf** | ✅ DONE (STORY-007+008 shipped) | DEPLOY-003 (healthz extends perf telemetry) | Real-data validation (1 week post-launch) |

**Sprint 3 outcome**: All MVP-1 metrics M1-M5 are at "shipped" status; Sprint 3 closes the **operational** gap (deploy) and **ceremonial** gap (retro + template port). Sprint 4+ is polish, telemetry, or persona expansion.

---

## Dependency DAG (Sprint 3 commit order)

```
DEPLOY-002 (secrets) ──► DEPLOY-001 (workflow) ──► DEPLOY-003 (smoke test)
                                                       │
                                                       ▼
                                                  DEPLOY-004 (audit query, optional)

RETRO-003 (PM drafts retro) ──► Issue #48 unblock (gate met) ──► TEMPLATE-PORT

ADR-0023 status flip (Proposed → Accepted) — small follow-up PR, parallel track
```

Sprint 3 sequencing:
1. **DEPLOY-002** starts (owner generates keypair — owner gate, ~1 hour of owner time)
2. **RETRO-003** starts in parallel (PM drafts, ~1 hour of PM time, no owner gate)
3. **DEPLOY-001** starts after DEPLOY-002 secrets exist (depends on owner keypair)
4. **DEPLOY-003** starts after DEPLOY-001 workflow exists (depends on workflow file)
5. **TEMPLATE-PORT** starts after RETRO-003 lands (depends on retro content)
6. **DEPLOY-004** deferred to Sprint 4 unless Sprint 3 capacity is comfortable

**Critical owner gates** (Sprint 3 has 2 owner-gated events — more than Sprint 1/2):
- **DEPLOY-002 owner gate**: generate ed25519 keypair on prod host + add public key to ~/.ssh/authorized_keys + store private key in repo secret DEPLOY_SSH_KEY
- **DEPLOY-001 owner gate**: approve `.github/workflows/deploy.yml` merge (per CLAUDE.md §File ownership matrix — workflows are human-only)

---

## Risks & mitigations

| Risk | Severity | Mitigation | Owner |
|---|---|---|---|
| Owner bandwidth on 2 gates (keypair + workflow approval) is the critical path | P0 | PM pings owner ahead of each gate; DEPLOY-002/001 docs are written so owner can execute in <30 min each | @human + PM |
| DEPLOY-003 GET /healthz is a new endpoint — may require ADR-0019 amendment | P1 | Architect drafts ADR-0019-amend-3 (or extends the existing amendment) at Sprint 3 sizing; tiny ADR | @architect |
| DEPLOY-001 workflow file may need iteration after first deploy fails | P1 | Sprint 3 has buffer (22-32 SP); allow 1-2 deploy retries before declaring story done | @developer + @human |
| Owner-impl pattern (Sprint 2) — owner may want to implement deploy stories themselves | P2 | Pattern validated 6x in Sprint 2; if owner implements, PM's role is spec only (no shift) | @human + PM |
| Sprint 2 retro not yet written (RETRO-003) blocks Issue #48 (TEMPLATE-PORT) | P2 | RETRO-003 is 1 SP — PM can draft in <1 hour; orchestrator publishes | @product-manager + @orchestrator |
| M2+M4+M5 metrics validation depends on real prod usage (24h+ post-deploy) | P1 | Sprint 3 itself is a self-validation: once DEPLOY-001+003 ship, owner's daily use generates the validation data | @human (self-report) |
| Branch contamination pattern (PR #122 mid-PR fix) recurs on DEPLOY-* PRs | P2 | PM specifies branch-from-main invariant in DEPLOY-001/002/003 story docs; developer pattern awareness from Sprint 2 retro | @developer |
| Sprint 2 P1 24h burn-in — P0/P1 bug filed after this proposed-scope writes | P1 | Sprint 3 capacity buffer (22-32 SP) absorbs bug fix work without re-planning | @developer + @tester |

---

## Definition of Done (sprint-level)

Sprint 3 is **DONE** when ALL of:

1. All committed stories merged to main with owner approval (workflow-file merge for DEPLOY-001 is owner-only per CLAUDE.md).
2. CI green on main post-merge.
3. `docs/sprints/sprint-03/retrospective.md` written.
4. **Real-data validation**: deploy pipeline has fired ≥3 times successfully (3 owner merges to main auto-deploy without intervention).
5. **Smoke test validated**: DEPLOY-003 auto-rollback path has been tested at least once (intentional bad merge → rollback verified).
6. No new P0/P1 bugs filed against Sprint 3 stories within 24h.
7. Sprint 4 backlog drafted (grooming-ready).

---

## Cross-cutting dependencies (Sprint 3, parallel to this PM backlog)

These are architect/developer-owned chore stories tracked in their own issues, NOT in this PM-authored feature backlog. They will be sized into the final Sprint 3 plan at the sizing ceremony:

- **Issue #46** (P0) — Stale-verdict watchdog TD-006 (already shipped via PR #108 — DONE; closed)
- **Issue #65** (chore) — fastapi/uvicorn reclassification (architect PR #66 — DONE per Sprint 2)
- **Issue #45** (chore) — STATUS block as action driver (developer-owned, separate flow)
- **ADR-0023 status flip** — Proposed → Accepted (small follow-up docs PR; PM can draft)
- **ADR-0029 (proposed)** — Deploy pipeline observability (if architect decides to formalize the deploy-marker file pattern)

---

## PM next actions (this PR's exit)

1. **This docs PR opens** with `docs/sprints/sprint-03/backlog.json` + `docs/sprints/sprint-03/proposed-scope.md`.
2. **Backlog.json hygiene PR** (separate PR): mark Sprint 2 stories `done` + add merged_pr URLs + add DEPLOY-001/002/003 entries + fix R-5 stale refs.
3. **Auto-ping orchestrator** with sizing ceremony signal (Sprint 3 kickoff).
4. **3 GitHub issues opened** (DEPLOY-001/002/003) with the 4-cat label invariant per ADR-0012 (and per `product-manager.md` §Handoff Discipline for new stories: `agent:tester cc:tester` so tester writes the test plan first).
5. **Atomic hand-off on Issue #127**: flip `agent:product-manager` → `agent:orchestrator` + `cc:orchestrator` (per ADR-0015). Orchestrator's turn: run sizing ceremony with @architect + @developer + @tester, then publish `docs/sprints/sprint-03/plan.md` (committed scope).
6. **PM stays in polling mode** for sizing comments on the DEPLOY-* issues + Issue #127 status updates + ADR-0023 status flip follow-up.

---

## Change log

- **2026-06-19T18:45Z** — Initial draft. PM-groomed from Issue #127 (owner directive) + ADR-0027 (deploy architecture, Accepted via PR #128). 4 deploy stories (8 SP) + 1 retro doc (1 SP) + 1 template port (3 SP) + 1 optional deploy audit query (1 SP) = 13 SP proposed. Comfortable capacity buffer (22-32 SP) for unplanned work + post-Sprint-2 bug fixes (24h burn-in active). Sprint 3 is operational hardening + retro ceremony, NOT feature work — all MVP-1 features shipped in Sprint 2 P1.