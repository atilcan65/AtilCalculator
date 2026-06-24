# Sprint 6 — Plan (PM-refined, post-ORCH carryover update)

> **Author:** @product-manager (PM-led grooming cycle, Sprint 6 day 0 = 2026-06-24)
> **Date:** 2026-06-24T16:14Z (initial PM draft, post-PR #356 ADR-0043)
> **Mode:** 🚀 **CONTINUOUS FLOW** (owner directive 2026-06-23T11:08Z chat) — same as Sprint 4+5
> **Window:** **2-week default** (2026-06-24 → 2026-07-08), owner-decision per CLAUDE.md §Sprint duration doctrine
> **Sprint 5 close shipped:** PR #292 (commit 345c25c, 2026-06-23T11:06:13Z)
> **Refs:** [Sprint 5 close](../sprint-05/close.md), [Sprint 4 retro](../sprint-04/retro.md), [Issue #355 (Sprint 6 kickoff)](https://github.com/atilcan65/AtilCalculator/issues/355), [Issue #289 (CLOSED)](https://github.com/atilcan65/AtilCalculator/issues/289), [PR #356 (ADR-0043, status:ready)](https://github.com/atilcan65/AtilCalculator/pull/356)

## Sprint goal

**Close the Sprint 4 P2 RCA-17 redesign with GA-aware architecture (ADR-0043 lens i applied) + RETRO-005 lead (13-item backlog) + ADR-0043 soul amendment follow-up (owner-only).**

Sprint 5 closed the doctrine chain (§Doctrine Reminder + §Auto-Claim in 4/4 souls). Sprint 6 lands the architectural remediation triggered by P0 #351: redesign #193/#194 with the new 8-Lens checklist (ADR-0043, just MERGEABLE per PR #356 status:ready), and runs RETRO-005 to capture 13 process lessons into actionable backlog.

**Sprint 6 is recovery + retro, not new architecture.** All Sprint 5 doctrine items resolved; Sprint 6 closes the architectural debt surfaced by P0 #351 + captures retro lessons for Sprint 7 hardening.

## Capacity

- **Window**: 2-week (default per CLAUDE.md §Sprint duration doctrine)
- **Active agents**: 4 (orchestrator, PM, architect, developer + tester on call)
- **Capacity estimate**: 22 SP (2-week × ~5.5 SP/week × 4 agents)
- **Committed total**: **5.25 SP** (2 P1 redesign + 1 P1 port + 1 P3 template + 1 P3 retro + 1 P1 soul amendment + 1 P2 optional linter)
- **Headroom**: **16.75 SP** (76% free for Sprint 6 mid-sprint pickups + Sprint 7 prep)

## Committed scope

### P1 — Sprint 4 P2 redesign (architect-owned, ADR-0043 lens i applied)

| ID | Title | SP | Owner | Day | Notes |
|---|---|---|---|---|---|
| **RCA17-REDESIGN** (#193) | ADR-0030 deviation redesign — runner uid + GA-aware `path:` override | 1.5 | architect | Day 1-3 | P2→P1 bumped post-ADR-0043 |
| **SYMNK-CLEANUP** (#194) | Symlink cleanup (paired #193) | 1.0 | architect | Day 3-4 | Unblocks after #193 redesign |
| **ADR-0043-SOUL-FOLLOWUP** (owner-only) | architect.md §Standard Workflows add lens (h)+(i) | 0.25 | human | Day 1 | Owner-only per file ownership matrix |

**P1 subtotal**: 2.75 SP

### P1 — Template port (developer-owned)

| ID | Title | SP | Owner | Day | Notes |
|---|---|---|---|---|---|
| **TPL-PORT-WIP-IDLE** (#290) | Proactive WIP>0 idle detection — template port | 0.5 | developer | Day 2-3 | Sister to closed #289 |

### P3 — RETRO-005 lead (PM-owned)

| ID | Title | SP | Owner | Day | Notes |
|---|---|---|---|---|---|
| **RETRO-005-LEAD** (#327) | RETRO-005 lead — 13-item candidate backlog, Day 7+ = 2026-06-27 | 1.0 | product-manager | Day 7+ | 13 candidates documented |

### P3 — Template port backlog

| ID | Title | SP | Owner | Day | Notes |
|---|---|---|---|---|---|
| **TPL-PORT-481** (#198) | #48.1 template port (Sprint 2/3 candidate) | 1.0 | developer | Day 5-7 | status:blocked currently |

### Optional — Sprint 6 P2 platform linter

| ID | Title | SP | Owner | Day | Notes |
|---|---|---|---|---|---|
| **D041-PLATFORM-LINTER** (optional) | d041 platform-constraint linter — extends d040 to cover lens (i) 8 sub-categories | 1.0 | developer | Day 8+ | Optional, dev lane cycles |

**Total committed**: 5.25 SP (with 16.75 SP headroom for Sprint 6 mid-sprint pickups)

## Sprint 6 retro agenda (RETRO-005 #13 + backlog)

13-item candidate backlog (PM-owned, Day 7+ = 2026-06-27):

1. Cherry-pick body checklist (`Closes #N` precision)
2. Label-hygiene sweep (closed-but-status:in-progress)
3. AC-by-AC + PR-by-coherence pattern (validated on PR #314)
4. PM status:ready flip discipline — do NOT flip if `needs-tester-signoff` is set
5. Sister-incident class: #315 + #327
6. PM retroactive `verdict-by:<ts>` discipline (pattern established)
7. PM proactive `cc:*` removal after verdict delivery (lesson from PR #334 stale_cc deadlock)
8. Silent wake-up gap → RCA → ADR → fix chain (#312 RCA → ADR-0041 v8 → PR #323 → PR #330)
9. PM-vs-architect option preferences on owner-only doctrine changes (owner re-ask as resolution tool)
10. (reserved for architecture lessons from Sprint 4 P2)
11. **Closing-keyword syntax ambiguity** (`+` not recognized; PM filed on #350 ACK)
12. **RETIRED — replaced by ADR-0043 codification** (GA hard constraints pre-publish gate)
13. **Revert-doesn't-reopen-issues workflow gap** (PM filed on #352 ACK)

**Path**: `docs/sprints/sprint-04/RETRO-005.md` (matches Sprint 4 retro file convention)

## Risks

- **Combined CI blast radius**: Sprint 6 has 2 deploy.yml-touching items (#193 + #194 redesign + ADR-0043 soul amendment owner-only). Coordinate with architect: one at a time, with live deploy verification between each.
- **Owner saturation**: Sprint 5 owner shipped 6+ PRs. Sprint 6 owner-only items (#235 cron registration + ADR-0043 soul amendment) need buffer time. Recommend: owner pick-up by Day 3-5.
- **GA constraint unknowns**: Sprint 6 P1 redesign requires full GA awareness. Lens (i) is the formal gate but design itself may surface new unknowns. Mitigation: architect applies 8-lens checklist, regression test 3/3 deploy + /healthz.
- **RETRO-005 timing**: Day 7+ = 2026-06-27 (Saturday) — owner availability may be limited. Recommend: PM drafts RETRO-005 skeleton Day 5 (2026-06-26) for owner review before Day 7.

## Owner-only carryover

- **#235 cron registration** (P0, Sprint 6 setup, owner-decision pending — was Sprint 5 carryover)
- **ADR-0043 soul amendment** (P1, 0.25 SP, see ADR-0043-SOUL-FOLLOWUP above) — owner applies after PR #356 merge

## Auto-ping

- **agent-watch.sh product-manager** (180s polling per ADR-0002)
- **scripts/ping.sh orchestrator** (back-channel for Sprint 6 ceremony coordination)
- **Sprint 6 standup** auto-triggered daily 09:00 Europe/Istanbul (per CLAUDE.md §Process — no work-hours gate, agents operate 24/7)
- **Mid-sprint reflection** at Day 7 (2026-07-01) per Sprint 5 close.md pattern

## Done definition

Sprint 6 done when:
- ✅ Sprint 6 backlog.json + plan.md committed to main (this PR)
- ✅ #193 + #194 redesigned with 8-Lens (ADR-0043) applied + landed in main
- ✅ #290 template port landed in template repo (cross-repo-close workflow)
- ✅ ADR-0043 soul amendment merged (owner-only PR)
- ✅ RETRO-005.md committed with 13 candidates dispositioned
- ✅ Optional d041 platform-constraint linter (if Sprint 6 cycles allow)
- ✅ Sprint 6 close.md drafted (orchestrator-led, Day 14)

## Acceptance criteria (per Issue #355)

- [x] backlog.json follows Sprint 5 schema (id, issue, title, priority, sp, type, status, agent, cc, depends_on, blocks, adr_refs, scope_includes, acceptance_criteria)
- [x] plan.md has §Sprint goal, §Capacity, §Committed scope, §Risks, §Carryover, §Auto-ping sections
- [x] Sprint 6 issue links present (#355, #356, #290, #198, #193, #194, #327, #289)
- [x] Carryover items relabeled (sprint:backlog → sprint:current for #290, #198, #193; #194 was already sprint:current)
- [x] Priority bump applied (#193 + #194 P2 → P1 per ORCH unblock directive 2026-06-24T19:13Z)
- [x] New stories have 4-cat label invariant per ADR-0012 (verified on PR #356 + issue labels)

— @product-manager, 2026-06-24T19:14Z, Sprint 6 plan.md + backlog.json drafted post-ADR-0043 unblock.
