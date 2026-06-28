# Sprint 18 — Plan

> **Status:** 🟡 **DRAFT — PM lane (Sprint 18 Kickoff dispatch, Issue #602, TIER 2.2)**
> **Date drafted:** 2026-06-28 (Sprint 18 kickoff post-Sprint 17 close per owner directive)
> **Mode:** 🚀 **CONTINUOUS FLOW** (carry-over from Sprint 17, ADR-0031 owner override)
> **Refs:** [Sprint 18 backlog](./backlog.json) · [Sprint 17 close](../sprint-17/close.md) · [RETRO-012](../sprint-17/RETRO-012.md) · Issue #602 (TIER 2.2 dispatch)
> **Source-of-truth:** `docs/sprints/sprint-18/backlog.json` (on this branch `feat/sprint-18-kickoff-pm`, awaiting owner squash-merge)

---

## TL;DR

Sprint 18 absorbs the **post-cluster consolidation** phase after Sprint 17 P1's 8/8 SHIPPED+CLOSED cluster. Scope is **doctrine hardening + d-test family completion + script tuning** — small, surgical, no architectural risk. Total: **8 stories (3 P0 + 5 P1) ≈ 5.5 SP committed** within lane capacity, plus **3 P2 deferred** (≤1.75 SP reserve).

**Critical path (Sprint 18 P0)**:
1. **STORY-S18-001** — §AC mapping verification doctrine (arch lane, ~1.0 SP, needs_design=true). Sponsorship from PM (cycle 647 AC drift codification candidate, RETRO-012 §1). Codifies pre-citation cross-check + 30s timing window into architect.md.
2. **STORY-S18-002** — Cluster-lag-detector workflow YAML wiring (dev lane + owner-only workflow YAML approval, ~1.5 SP, needs_design=true). Wires `scripts/post-squash/cluster-lag-detector.sh` (SHIPPED Sprint 17) into `.github/workflows/post-squash.yml` for future cluster-squash events.
3. **STORY-S18-003** — Cluster-lag.log retrospective population (PM lane, 0.5 SP). PM curator step: invoke detector retroactively for Sprint 17 P1 cluster (7 PRs: #589, #590, #591, #593, #595, #596, #597) + Sprint 14 P1 #2 cluster historical baseline (Issue #508 LIVE INSTANCE, 4 PRs, 324s lag).

**Parallel tracks (Sprint 18 P1, all unblocked today)**:
- **STORY-S18-004** — d065 dual-channel-enforcement d-test (sister-pattern to d058/d059/d061/d062/d063/d064, ~0.5 SP, dev lane). Codifies PR #598 reviewer feedback (cmt 4826486795) into a regression gate.
- **STORY-S18-005** — §verdict-by:<ts> discipline codification (orchestrator.md amendment, ~0.5 SP, orchestrator self). Forward discipline per PICKUP-531.
- **STORY-S18-006** — WIP cap script miscounts fix (`scripts/wip-cap-check.sh`, ~0.5 SP, dev lane). Fixes status filter + owner-gated item exemption per RETRO-012 §6 + Sprint 17 P1 #582/#583 incident.
- **STORY-S18-007** — Proactive-scan wip_overflow false positive fix (`scripts/proactive-board-scan.sh`, ~0.5 SP, dev lane). Distinguishes OVERFLOW (count > cap) from AT-CAP (count == cap) per RETRO-012 §5.
- **STORY-S18-008** — d064 CI workflow integration (~0.5 SP, dev lane + owner-only workflow YAML approval). Sister-pattern to d015/d031/d058/d059 CI integration per ADR-0044.

---

## Sprint goal

> **Codify the 4 retro lessons from Sprint 17 P1 (RETRO-012 §1-§7) into enforceable, regression-tested doctrine + close the cluster-lag detection loop end-to-end (script → workflow → log → retro marker).**

Acceptance: (a) cluster-lag.log populated for Sprint 17 + historical baseline, (b) 4 doctrine codifications merged (AC mapping, verdict-by, WIP cap filter, proactive-scan), (c) d-test family 18-sister shipped (d065), (d) d064 CI-integrated.

---

## Capacity

| Lane | Capacity (post-RETRO-012 doctrine chain) | Allocated | Headroom |
|---|---|---|---|
| Architect | ~1.5 SP (1 amendment + 1 ADR) | 1.0 SP (STORY-001) | 0.5 SP |
| Developer | ~3.0 SP (sister-pattern work) | 2.5 SP (STORY-002 + 004 + 006 + 007) | 0.5 SP |
| Tester | ~1.0 SP (d-test reviews) | 0.5 SP (STORY-004 co) | 0.5 SP |
| Orchestrator | ~1.0 SP (1 amendment) | 0.5 SP (STORY-005 self) | 0.5 SP |
| Product Manager | ~1.5 SP (curator + commit) | 0.75 SP (STORY-003 + close) | 0.75 SP |
| **Total** | **~8.0 SP** | **5.25 SP** | **2.75 SP reserve** |

**Reserve uses**: PICKUP-nnnn remediation work, owner-gated items, or P2 promotion if owner prioritizes.

---

## Committed stories (8)

### P0 (3 stories, 3.0 SP)
1. **STORY-S18-001** — §AC mapping verification doctrine (architect) — `agent:architect` `cc:product-manager,developer,tester,human` — needs_design=true — 1.0 SP
2. **STORY-S18-002** — Cluster-lag-detector workflow YAML wiring (developer + owner YAML approval) — `agent:developer` `cc:architect,tester,product-manager,human` — needs_design=true — 1.5 SP
3. **STORY-S18-003** — Cluster-lag.log retrospective population (PM curator) — `agent:product-manager` `cc:architect,developer,human` — 0.5 SP

### P1 (5 stories, 2.25 SP)
4. **STORY-S18-004** — d065 dual-channel-enforcement d-test (developer) — `agent:developer` `cc:tester,architect,product-manager` — 0.5 SP
5. **STORY-S18-005** — §verdict-by:<ts> discipline codification (orchestrator) — `agent:orchestrator` `cc:product-manager,architect,developer,tester,human` — 0.5 SP
6. **STORY-S18-006** — WIP cap script miscounts fix (developer) — `agent:developer` `cc:product-manager,architect,tester,human` — 0.5 SP
7. **STORY-S18-007** — Proactive-scan wip_overflow false positive fix (developer) — `agent:developer` `cc:product-manager,tester,architect,human` — 0.5 SP
8. **STORY-S18-008** — d064 CI workflow integration (developer + owner YAML approval) — `agent:developer` `cc:tester,architect,product-manager,human` — 0.5 SP

### P2 deferred (3 candidates, ≤1.75 SP reserve)
- STORY-S18-DEFERRED-1 — §Cross-user GraphQL rate limit workaround codification (orchestrator.md) — 0.5 SP
- STORY-S18-DEFERRED-2 — d-test family 19-sister (d066 + d067) — 1.0 SP
- STORY-S18-DEFERRED-3 — §PM curator step cadence enforcement (product-manager.md) — 0.25 SP

---

## Dependencies

```
STORY-S18-001 (AC mapping doctrine, arch)
    └── blocks → STORY-S18-002 (cluster-lag YAML wiring may benefit from §AC verification)

STORY-S18-002 (cluster-lag YAML wiring, dev)
    └── blocks → STORY-S18-003 (detector must be wired to invoke on historical data)

RETRO-012 §1-§7 (closed via PR #598, on main @ bf1e237) → all stories
PR #597 (cluster-lag-detector.sh, SHIPPED Sprint 17) → STORY-S18-002
PR #598 (RETRO-012 + post-squash-cleanup, SHIPPED Sprint 17) → STORY-S18-004
PR #601 (close.md Sprint 17, SHIPPED) → all stories (Sprint 17 close-out prerequisite)
ADR-0038 (WIP cap) → STORY-S18-006 + STORY-S18-007
ADR-0044 (RED-first TDD) → STORY-S18-004 + STORY-S18-008
ADR-0059 (cluster-squash detection) → STORY-S18-002 + STORY-S18-003
```

**Critical unblock order**: STORY-S18-001 → STORY-S18-002 → STORY-S18-003 (P0 chain). P1 stories are independent and can parallelize across lanes.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Workflow YAML approval delay (STORY-002 + STORY-008) | Medium | Medium | Pre-stage YAML drafts in PM PR, owner can approve in 1 click per file ownership matrix |
| d-test 18-sister ID clash (STORY-004) | Low | Low | ADR-0055 §sub-pattern remediation — verify ID uniqueness in `scripts/tests/INDEX.md` before commit |
| Sprint 17 P1 cluster detection yield < 50% (STORY-003 retrospective) | Low | Low | 5/7 PRs already known cluster-squash (cmt 4826303998), high-confidence baseline |
| Owner distraction → no squash click on PM PR | Medium | Low | Plan.md here is the source-of-truth; backlog.json lives on branch; orchestrator can re-prompt owner if needed |
| PR #601 merge timing (close.md) | Low | Low | Already squashed (d8739d6) per backlog.json, this PR depends on it being on main |

---

## Metrics of success

- **Cluster-lag detection live**: 100% of Sprint 18+ cluster-squash events produce `cluster_lag_detected` entries in `cluster-lag.log`
- **Doctrine codification**: 4/4 RETRO-012 §1-§7 codifications merged (AC mapping, verdict-by, WIP cap filter, proactive-scan)
- **d-test family**: 18-sister shipped (d065), d064 CI-integrated (was last gap)
- **ProcessGap retro lineage**: RETRO-012 §1-§7 each produces a follow-up merge OR explicit deferral with owner acknowledgment
- **Sprint boundary discipline**: Sprint 18 close.md authored ≤24h after last P0 merge (vs Sprint 17's 1-day lag post-#597)

---

## Cross-references

- Issue #599 ([Sprint 17 Close Ceremony] PM curator trigger — CLOSED via PR #601)
- Issue #602 ([Sprint 18 Kickoff] — Coordinated Sprint 18 dispatch, TIER 2.2)
- Issue #508 (LIVE INSTANCE — Sprint 14 P1 #2 cluster, 4 PRs, 324s lag — historical baseline)
- Issue #582 + #583 (Sprint 17 P1 owner-gated WIP miscount incident)
- PR #597 (cluster-lag-detector.sh impl, SHIPPED)
- PR #598 (RETRO-012 + post-squash-cleanup runbook, SHIPPED)
- PR #601 (close.md Sprint 17 close-out, SHIPPED)
- RETRO-012 (Sprint 17 P1 ProcessGap retro, on main)
- ADR-0012 (4-cat invariant)
- ADR-0024 (verdict-by convention)
- ADR-0031 (owner override)
- ADR-0038 (per-role WIP cap)
- ADR-0044 (RED-first TDD)
- ADR-0055 (d-test ID uniqueness + sub-pattern remediation)
- ADR-0059 (cluster-squash batch-lag detection)

---

## Ratification path

PM lane commit (this file + backlog.json) → PM open PR `docs(sprint-18): plan.md + backlog.json (Sprint 18 kickoff)` → owner squash-merge → backlog.json on main → per-story Issues opened via `gh issue create` (8 issues, 4-cat invariant per ADR-0012) → orchestrator dispatches first P0 (`STORY-S18-001 §AC mapping doctrine`) to architect.

**PM WIP**: 1/2 (Issue #602 in-progress, under cap per ADR-0038).

---

— Product Manager, 2026-06-28 (Sprint 18 Kickoff dispatch, TIER 2.2)
