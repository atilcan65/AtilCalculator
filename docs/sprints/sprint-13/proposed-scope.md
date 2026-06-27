# Sprint 13 — Proposed Scope (PM draft, pre-sizing)

> **Author:** @product-manager
> **Date:** 2026-06-26T22:44+03:00 = 19:44Z
> **Mode:** 🚀 **CONTINUOUS FLOW** (ADR-0031 owner override carry from Sprint 4-12)
> **Trigger:** PR #458 SQUASH MERGED @ 19:21:43Z (commit fbf92be, §Dispatch Discipline 5-soul amend) + PR #460 SQUASH MERGED @ 19:32:07Z (commit b3bc032, d051 d-test + Issue #459 amend) + PR #462 SQUASH MERGED @ 19:40:05Z (commit c0900c7, d052 hardening) — **Sprint 12 fully closed** (7.5 SP shipped 100%)
> **Previous sprint close:** [../sprint-12/close.md](../sprint-12/close.md)
> **PM lane definition (LOCKED this sprint):** PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors (per [ORCH→PM-CLARIFY-ACK] @ 22:42:21 +03)

## TL;DR scope (proposed, sizing pending arch+dev+tester joint review)

- **P0 carry** (1 story): d050b TC1 owner territory (Sprint 12 carry-forward, owner-implementable, no PM grooming needed)
- **P1 (arch + PM-facilitated)** (3 stories): RETRO-007 watchlist entries + PM lane definition amendment
- **P2 (arch carry)** (3 stories): RETRO-007 watchlist codifications + ADR-0049 (k) text apply
- **Old backlog deferral candidates**: STORY-013, DEPLOY-001-004, RETRO-003, TEMPLATE-PORT (stale, recommend defer to Sprint 14+)

**Sizing TBD** — PM requests joint sizing per ADR-0024 verdict SLA framework once orchestrator opens Sprint 13 kickoff issue.

## Proposed story inventory

### P0 (carry-forward from Sprint 12, owner territory)

1. **d050b TC1 owner carry** (Issue #440 AC follow-up)
   - Owner-implementable per ADR-0049 §Implementation guide
   - Sprint 12 close.md "Sprint 13 P0 carry: d050b TC1 owner territory"
   - **No PM action needed**

### P1 (architect-authored, PM-facilitated docs/sprint amendments)

2. **§Pre-merge 4-cat verification d-test** (RETRO-007 watchlist entry #3)
   - Owner: architect (ADR) + developer (d-test impl) + tester (sign-off)
   - Origin: 6 arch-related workflow regressions in 24h (Sprint 12 cascade)
   - Sister-pattern to d048 (Issue #425) + d050b (Issue #440)
   - **PM facilitates**: docs/CLAUDE.md or per-soul clarification if doctrine change

3. **§Pre-verdict cross-check timing window codification** (RETRO-007 watchlist entry, PM-captured this session)
   - Owner: PM proposes doc amendment, arch review
   - Origin: PR #460 PM-AC-VERIFY missed arch verdict due to GitHub GraphQL comment-propagation delay (30-60s window)
   - Discipline refinement: re-query within 30s of posting verdict, not 1+ min before
   - **PM owns**: docs/CLAUDE.md §Dispatch Discipline refinement + RETRO-007 watchlist entry

4. **Sprint 13 PM lane definition amendment** (per [ORCH→PM-CLARIFY-ACK] @ 22:42:21 +03)
   - Owner: PM proposes, owner merges (.claude/CLAUDE.md human-only territory)
   - Lane: PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors
   - Sister-pattern to RETRO-007 watchlist §PM-cc gap orchestrator signaling entry
   - **PM owns**: .claude/CLAUDE.md §PM lane definition addition + RETRO-007 watchlist entry

### P2 (architect carry, RETRO-007 watchlist codifications + ADR amendments)

5. **§Dispatch Discipline in-flight body amend** (RETRO-007 watchlist 8th entry)
   - Owner: architect (PR #462 body amend Closes #461 → L1 was the trigger)
   - Sister-pattern to PM's PM-AC-VERIFY timing window entry (cross-pollination)
   - **PM facilitates**: docs/CLAUDE.md §Dispatch Discipline refinement note

6. **§Closes-anchor strict format d-test** (RETRO-007 watchlist entry #5)
   - Owner: architect (doc) + developer (d-test impl) + tester (sign-off)
   - Codification: uppercase C + line 1 + NO trailing text on line 1
   - Sister-pattern to d046 (jq-filter guard) + d048 (Layer 5 reviewer chain)
   - **PM facilitates**: none (arch doc territory)

7. **ADR-0049 (k) text apply** (Sprint 12 close.md line 124-125)
   - Owner: architect
   - Status: parked since Sprint 12, parked-to-P2 in Sprint 13
   - **PM facilitates**: none

### Backlog candidates (stale, recommend DEFER to Sprint 14+)

- **STORY-013** (Implicit first operand from history, P1, issue #179) — product feature, no recent activity, recommend defer pending customer feedback
- **DEPLOY-001** (Trigger pipeline, P0) — deferred per ADR-0017 (no HTTP surface decided)
- **DEPLOY-002** (Secret wiring, P0) — deferred per ADR-0017
- **DEPLOY-003** (GET /healthz, P0) — deferred per ADR-0017
- **DEPLOY-004** (deploy-status.sh, P2) — deferred per ADR-0017
- **RETRO-003** (Sprint 2 retrospective, P1) — stale retro, recommend close-as-superseded
- **TEMPLATE-PORT** (Issue #48, P1) — stale template work, recommend close-as-superseded

## Sizing request (per ADR-0024 verdict SLA framework)

PM requests arch+dev+tester joint sizing on:
- Item #2 (§Pre-merge 4-cat verification d-test) — arch ADR estimate + dev impl estimate + tester d-test estimate
- Item #3 (§Pre-verdict cross-check timing window codification) — PM doc amendment estimate (small, ~0.5 SP)
- Item #4 (Sprint 13 PM lane definition amendment) — PM .claude/CLAUDE.md amendment estimate (small, ~0.5 SP)
- Item #5 (§Dispatch Discipline in-flight body amend) — arch codification estimate
- Item #6 (§Closes-anchor strict format d-test) — arch+dev+tester joint estimate
- Item #7 (ADR-0049 (k) text apply) — arch ADR amendment estimate (small, ~0.5 SP)

**PM does not estimate alone** (per soul doctrine). Sizing requires arch+dev+tester per ADR-0024.

## Critical path (proposed)

1. **Owner d050b TC1** (P0, owner territory) — gates nothing else, owner-implementable
2. **arch §Pre-merge 4-cat verification ADR** (P1) — gates dev d-test impl
3. **dev §Pre-merge 4-cat verification d-test** — depends on arch ADR Accepted
4. **PM lane definition amendment** (P1) — docs/CLAUDE.md or per-soul, owner-merge-only
5. **Sister-pair cluster close**: d050b TC1 + §Pre-merge 4-cat verification (sister-pair to d051+d052 Sprint 12 P2 cluster)

## Doctrinal carry-forwards (RETRO-007 watchlist, 9 entries)

| # | Entry | Status | Sprint 13 lane |
|---|---|---|---|
| 1 | §Dispatch Discipline (5-soul amend) | DONE (PR #458 merged fbf92be) | — |
| 2 | §Closes-anchor 3-state check | DONE (codified Sprint 12) | — |
| 3 | §Pre-merge 4-cat verification | P1 Sprint 13 candidate | arch+dev+tester |
| 4 | §d-test behavioral vs content-anchor | DONE (d050b framework) | — |
| 5 | §Closes-anchor strict format | DONE (codified) | P2 d-test candidate |
| 6 | §Pre-verdict cross-check timing window | NEW (PM captured) | P1 doc amendment candidate |
| 7 | (reserved, per arch discretion) | TBD | TBD |
| 8 | §Dispatch Discipline in-flight body amend | NEW (arch captured) | P2 arch codification candidate |
| 9 | §PM-cc gap orchestrator signaling | NEW (orch captured) | P1 process improvement candidate (sister to PM lane def) |

## Open items for owner

1. **Sprint 13 d050b TC1 disposition** (owner carry from Sprint 12, owner territory)
2. **Sprint 13 scope ratification** (proposed-scope.md → plan.md via orchestrator)
3. **Sprint 13 kickoff issue open** (orchestrator opens per /sprint-start workflow)
4. **PM lane definition amendment owner-merge** (.claude/CLAUDE.md human-only territory)

## Definition of Done — Sprint 13

- [ ] All committed stories shipped (TBD SP after joint sizing) or carried with rationale
- [ ] All PRs merged to main via human owner squash
- [ ] CI green on main post-merge
- [ ] Docs updated: PM lane definition amendment, RETRO-007 watchlist additions (entries 6, 8, 9), close.md
- [ ] Sprint 13 kickoff issue closed (status:done, atomic close)
- [ ] No new P0/P1 bugs filed against Sprint 13 stories in 24h post-merge window

— PM, 2026-06-26T19:44Z (Sprint 13 proposed scope, pre-sizing per ADR-0024)