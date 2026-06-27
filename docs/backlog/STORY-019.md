# STORY-019: d031 TC5/6/7 update (Sprint 14 P1 #6 follow-on, work-stream awareness TC expansion)

## User Story
As a **P1 — Tester (operator of scripts/tests/d031-claim-next-ready.sh d-test, sister-pattern template maintainer)**,
I want **d031 d-test expanded with TC5 (priority/age work-stream), TC6 (ready=0 work-stream), TC7 (dep work-stream) bringing total TCs from 7 (5+2) to 10 (5+2+3=10) per ADR-0044 RED-first TDD discipline**,
So that **d031 covers the full Layer 2 work-stream awareness scope per ADR-0038 §Work-Stream Awareness amendment (PR #504 squash @ a45c613), sister-pattern to d058 which has 9 TCs (5+2+2=9)**.

## Why now

d031 was the sister-pattern template for d058 (PR #506 squash @ 226b546). Post-d058 implementation + d058 CI integration (PR #511 squash @ 70e33d7), d031 needs TC harmonization to cover the full Layer 2 work-stream awareness scope. Without TC5/6/7 expansion, d031's coverage is incomplete relative to d058's spec, and any future Layer 2 change risks drift between the two d-tests.

## Acceptance Criteria

- **AC1** — `scripts/tests/d031-claim-next-ready.sh` TC5 added (priority/age work-stream):
  - GIVEN 2 work-streams with same `status:ready` priority WHEN `claim-next-ready.sh developer` runs THEN claim oldest (age tie-break, work-stream=work-stream, sister-pattern to TC2 issue-based)
  - Sister-pattern to d058 TC2 (2 standalone issues same priority → claim oldest)
- **AC2** — d031 TC6 added (ready=0 work-stream):
  - GIVEN 0 work-streams with `status:ready` WHEN `claim-next-ready.sh developer` runs THEN exit 1, no claim (negative case, work-stream-aware)
  - Sister-pattern to d058 TC6 (0 ready items → exit 1)
- **AC3** — d031 TC7 added (dep work-stream):
  - GIVEN work-stream A with `depends on #N` where #N is OPEN WHEN `claim-next-ready.sh developer` runs THEN work-stream A is filtered out (dep filter, sister-pattern to d058 TC9 dep filter)
  - Sister-pattern to d058 TC9 (PR cluster with closed-dep)
- **AC4** — d031 TC count reaches 10/10 per ADR-0044 (RED-first TDD):
  - TC1-TC4 (existing 4 base claim rules): unchanged
  - TC5 (NEW): priority/age work-stream tie-break
  - TC6 (NEW): ready=0 work-stream negative
  - TC7 (NEW): dep work-stream filter
  - TC8-TC9 (existing 2 sanity checks: usage error + invalid role): unchanged
  - Total: 4 + 3 + 2 = 9... wait, original was 5+2=7. After expansion: 5+2+3=10. Verify by reading scripts/tests/d031-claim-next-ready.sh current TC count.

## Out of scope

- d058 TC expansion (separate scope, STORY-016/017 d060/d061 sister-pattern)
- d058 → d031 cross-test harmonization (separate tooling, Sprint 16 candidate)
- New work-stream types (orthogonal, future sister-pattern)

## Open questions

- [ ] **Tester**: TC count reconciliation — d031 was 5+2=7 originally. Expansion to 10 requires either TC5/6/7 (3 new = 10 total) OR different decomposition. Verify by reading scripts/tests/d031-claim-next-ready.sh → tester @ AC4
- [ ] **Developer**: TC ordering — should work-stream rules (TC5/TC6/TC7) come before sanity checks (TC8/TC9) for readability, or follow d058's 9-TC pattern? → developer @ impl
- [ ] **Architect**: Should d031 AC4 include a sister-pattern verification check (cross-test that d031 + d058 cover the same work-stream scope without overlap)? → architect @ Sprint 15 kickoff workshop

## Mockups / references

- `scripts/tests/d031-claim-next-ready.sh` (existing, 5+2=7 TCs)
- `scripts/tests/d058-claim-wip-workstream.sh` (sister-pattern, 9 TCs, PR #506 impl)
- `scripts/claim-next-ready.sh` (PR #271 implementation, Issue #276 STUB replacement)
- ADR-0038 §Work-Stream Awareness amendment (PR #504 squash @ a45c613, on main)
- ADR-0044 RED-first TDD discipline

## Dependencies

- **Upstream**:
  - d058 d-test impl (PR #506 squash @ 226b546) ✅ DONE
  - d058 CI integration (PR #511 squash @ 70e33d7) ✅ DONE
  - ADR-0038 §Work-Stream Awareness amendment (PR #504 squash) ✅ DONE
  - scripts/claim-next-ready.sh (PR #271 impl home) ✅ DONE
- **Downstream**:
  - scripts/tests/INDEX.md registration update (P2 #23 carry, tester lane)
  - d031 + d058 cross-test harmonization (Sprint 16 candidate)
- **Sister-pattern**:
  - d058-claim-wip-workstream.sh (9 TCs, claim-next-ready work-stream awareness)
  - d046, d048, d050b, d051, d052, d053, d054, d055, d056 (10-sister on main)

## Metrics of success

- d031 TC count reaches 10/10 per ADR-0044 (leading)
- d031 + d058 cover full Layer 2 work-stream awareness scope without gap (leading)
- d-test family coverage: 10-sister pattern preserved (lagging)
- Cross-test harmonization filed as Sprint 16 candidate (lagging)

## Cross-refs

- docs/sprints/sprint-15/plan.md §Committed stories #5 (Sprint 15 P1 #5 home)
- docs/sprints/sprint-15/backlog.json (STORY-019 entry)
- Issue #497 (Sprint 14 P1 #6, AC2 = d058 d-test impl, sister-pattern to STORY-019)
- PR #504 squash @ a45c613 (ADR-0038 amendment, doctrinal prerequisite)
- PR #506 squash @ 226b546 (d058 d-test impl, sister-pattern template)
- PR #511 squash @ 70e33d7 (d058 CI integration, AC5 follow-up)
- ADR-0038 §Work-Stream Awareness (PR #504 home)
- ADR-0044 RED-first TDD discipline
- ADR-0049 d-test framework
- RETRO-008 §3 (wip_overflow false positive origin)
- Issue #238 (no self-justified pauses doctrine, RETRO-008 §3 carrier)

— @product-manager, 2026-06-27T17:58+03:00 = 14:58Z, Sprint 15 P1 #5 (d031 TC5/6/7 update, work-stream awareness TC expansion)