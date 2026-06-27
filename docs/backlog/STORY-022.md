# STORY-022: d059 new d-test (RETRO-009 §6 SPLIT-resolved, d-test family 11-sister carrier)

## User Story
As a **P2 — Dev + Tester (operator of scripts/tests/d059-*.sh d-test, d-test family persistence carrier)**,
I want **a new d-test that codifies the d-test family persistence pattern (RETRO-009 §6) with ≥7 TCs per ADR-0049 d-test framework, sister-pattern to d058 (which has 9 TCs)**,
So that **the d-test family reaches 11-sister on main (10 existing + d059) per RETRO-009 §6 codification (on main via PR #513 squash @ ebf6bc8), and the family persistence pattern itself is regression-tested** (i.e., adding a new d-test always updates INDEX.md + follows the 9-Lens review checklist per ADR-0045).

## Why now

Sprint 14 P1 cluster brought d-test family to 10-sister on main (d046/d048/d050b/d051/d052/d053/d054/d055/d056/d058). RETRO-009 §6 codification proposes d-test family persistence as a Sprint 15 P2 candidate. Without d059, the family growth pattern itself is unenforced and any future d-test addition can drift from the 9-Lens + INDEX.md + sister-pattern conventions.

## Acceptance Criteria

- **AC1** — `scripts/tests/d059-dtest-family-persistence.sh` d-test impl with ≥7 TCs green per ADR-0044 RED-first (sister-pattern to d058 which has 9 TCs):
  - TC1: All 10 existing d-tests have INDEX.md entry (sister-pattern verification)
  - TC2: All 10 existing d-tests follow 9-Lens review checklist per ADR-0045
  - TC3: New d-test addition (simulated) → INDEX.md auto-update (sister-pattern to d058 INDEX.md update)
  - TC4: New d-test addition → 9-Lens review checklist applied
  - TC5: New d-test addition → sister-pattern doc reference (depends_on + cross-refs)
  - TC6: d-test naming convention: `dNNN-<short-name>.sh` (sister-pattern to d058 name)
  - TC7: d-test failure → exit non-zero (basic contract)
  - TC8: 11-sister count verified (10 existing + d059, sister-pattern count check)
  - TC9: d-test family coverage ≥90% on Layer 2 + Layer 5 surfaces (sister-pattern to ADR-0038 §Layer 2 coverage)
- **AC2** — d059 variant: TBD at Sprint 15 kickoff workshop (3 candidates per backlog.json notes):
  - **(a) chain dep pollution §1 companion** (RECOMMENDED by tester, highest priority per RETRO-009 §6, addresses LIVE INSTANCE #6 PR #509) — P1 §1 + d059a tight d-test pair
  - **(b) post-squash label hygiene §3 companion** (viable, addresses 3 LIVE INSTANCES #507/#508/#512) — Sprint 16 defer per tester recommendation
  - **(c) comment-based arch verdicts watcher ext** (deferred Sprint 16 per plan.md §Deferred)
  - **DECISION**: workshop selects (a) for Sprint 15 P2, (b) for Sprint 16
- **AC3** — Sister-pattern to d058:
  - d059 d-test file path: `scripts/tests/d059-<variant>.sh` (sister-pattern to d058 file path)
  - d059 d-test TC count: ≥7 per ADR-0049 (sister-pattern to d058 9 TCs)
  - d059 INDEX.md registration: updated per ADR-0049 (sister-pattern to d058 INDEX.md)
  - d059 9-Lens review checklist: applied per ADR-0045

## Out of scope

- d060 (§1 companion, dev+tester) — separate scope, STORY-016 sister-pattern
- d061 (§3 companion, dev+tester) — separate scope, STORY-017 sister-pattern
- d-test family beyond 11-sister (Sprint 16+ candidate, RETRO-009 §6 future)
- Cross-test harmonization tooling (Sprint 16 candidate)

## Open questions

- [ ] **Workshop (PM + dev + tester + arch)**: d059 variant selection — (a) chain dep pollution, (b) label hygiene, (c) comment-based arch verdicts. Tester recommends (a) for Sprint 15. → Sprint 15 kickoff workshop decision
- [ ] **Architect**: d-test naming — should d059 follow the `dNNN-<short-name>.sh` convention strictly, or allow longer descriptive names (e.g., `d059-chain-dep-pollution-companion.sh`)? Recommendation: strict convention per ADR-0049 → architect @ Sprint 15 kickoff
- [ ] **Developer**: TC count — ≥7 (per ADR-0049 minimum) or 9 (sister-pattern to d058)? Recommendation: 9 for parity → developer @ impl
- [ ] **Tester**: Cross-test verification — should d059 verify other d-tests' adherence to family pattern (TC1/TC2 above), or just verify its own? → tester @ AC1

## Mockups / references

- `scripts/tests/d058-claim-wip-workstream.sh` — sister-pattern (9 TCs)
- `scripts/tests/d031-claim-next-ready.sh` — sister-pattern (5+2=7 TCs base, +3 expansion = 10 TCs post-STORY-019)
- `scripts/tests/d046-k-lens-runtime.sh` — 9-Lens sister
- `scripts/tests/d048-layer5-reviewer-chain.sh` — Layer 5 sister
- `scripts/tests/d050b-closes-anchor-strict-format.sh` — C9 strict sister
- `scripts/tests/INDEX.md` — centralized registry (post-STORY-023 update)
- ADR-0049 (d-test framework)
- ADR-0045 (9-Lens Review Checklist)
- RETRO-009 §6 (d-test family persistence, on main via PR #513)
- RETRO-008 §11 (d-test persistence predecessor)

## Dependencies

- **Upstream**:
  - d058 d-test impl (PR #506 squash @ 226b546) ✅ DONE — sister-pattern template
  - d058 CI integration (PR #511 squash @ 70e33d7) ✅ DONE
  - RETRO-009 §6 codification (on main via PR #513) ✅ DONE
  - ADR-0049 d-test framework ✅ DONE
- **Downstream**:
  - d059 CI integration (HUMAN lane, sister-pattern to PR #511 d058 CI integration)
  - scripts/tests/INDEX.md registration update (P2 #23 carry, tester lane)
- **Sister-pattern**:
  - d058-claim-wip-workstream.sh (9 TCs, claim-next-ready)
  - d046 (k lens runtime), d048 (Layer 5 reviewer chain), d050b (closes anchor)
  - d051, d052, d053, d054, d055, d056 (6-sister on main)
  - 10-sister pattern → 11-sister post-d059

## Metrics of success

- d059 d-test ≥7 TCs green (leading)
- d-test family 11-sister on main (10 + d059) (leading)
- 9-Lens review checklist applied to d059 (leading)
- INDEX.md updated per ADR-0049 (lagging)
- d-test family growth pattern regression-tested (lagging)

## Cross-refs

- docs/sprints/sprint-15/plan.md §Committed stories #8 (Sprint 15 P2 #8 home)
- docs/sprints/sprint-15/backlog.json (STORY-022 entry, d-test ID d059)
- RETRO-009 §6 (d-test family persistence codification)
- RETRO-008 §11 (d-test persistence predecessor, on main)
- Issue #495 (Sprint 14 P1 #4, 9-Lens enforcement, d055 sister)
- PR #506 squash @ 226b546 (d058 d-test impl, sister-pattern template)
- PR #511 squash @ 70e33d7 (d058 CI integration, sister-pattern)
- ADR-0044 (RED-first TDD discipline)
- ADR-0045 (9-Lens Review Checklist, AC2 application)
- ADR-0049 (d-test framework, AC2 sister-pattern reference)
- PR #513 squash @ ebf6bc8 (RETRO-009 ceremony 4/4)

— @product-manager, 2026-06-27T17:58+03:00 = 14:58Z, Sprint 15 P2 #8 (d059 new d-test, d-test family 11-sister carrier)