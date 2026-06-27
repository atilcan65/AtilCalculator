# STORY-023: §10 tester lane INDEX maintainer (RETRO-009 §10, d-test INDEX cadence doc + sign-off process)

## User Story
As a **P2 — Tester (operator of scripts/tests/INDEX.md centralized registry, d-test sign-off process owner)**,
I want **a cadence doc (when to update INDEX.md) + sign-off process (who reviews + approves d-test additions) + ≥3 new d-test entries registered in Sprint 15 (d059 + d060 + d061) per ADR-0049 d-test framework**,
So that **the d-test family persistence pattern (RETRO-009 §6 + §10) is operationalized with clear ownership, and any future d-test addition follows the same cadence per Sprint 15 P2 tester lane maintenance**.

## Why now

Sprint 14 P1 cluster added 4 d-tests (d054, d055, d056, d058) without a centralized INDEX.md update cadence. Per RETRO-009 §10 codification, this is a tester lane carry-forward. Without cadence doc + sign-off process, INDEX.md can drift from actual d-test files, and future d-test additions may not follow the established 9-Lens + sister-pattern conventions.

## Acceptance Criteria

- **AC1** — `docs/sprints/sprint-15/INDEX-cadence.md` cadence doc (or section in d-test framework doc) per ADR-0049:
  - **Cadence rule**: every d-test impl/add = INDEX.md update in same PR (sister-pattern to PR #511 d058 CI integration)
  - **Cadence rule**: every d-test removal = INDEX.md entry removal in same PR
  - **Cadence rule**: INDEX.md reviewed quarterly by tester lane (Sprint planning ceremony)
- **AC2** — Sign-off process per ADR-0044 RED-first TDD:
  - **Process step 1**: dev authors d-test, runs locally, gets 9/9 TCs green
  - **Process step 2**: tester reviews d-test via 9-Lens per ADR-0045 + RED-first verification
  - **Process step 3**: tester signs off via `tests-passed:<ts>` label (sister-pattern to ADR-0024 verdict-by:<ts> schema)
  - **Process step 4**: arch reviews via 9-Lens final approval (sister-pattern to Sprint 14 P1 arch reviews)
  - **Process step 5**: orchestrator merges + INDEX.md updated
- **AC3** — ≥3 new d-test entries registered in Sprint 15 per ADR-0049:
  - **d059** (§6 family persistence, STORY-022): INDEX.md entry added
  - **d060** (§1 chain dep pollution companion, STORY-016): INDEX.md entry added
  - **d061** (§3 label hygiene companion, STORY-017): INDEX.md entry added
  - Total: 10-sister + d059 + d060 + d061 = 13-sister on main post-Sprint 15 (was 10-sister post-Sprint 14)
- **AC4** — Existing d-test entries verified (no drift):
  - All 10 existing d-tests (d046, d048, d050b, d051, d052, d053, d054, d055, d056, d058) have INDEX.md entries
  - INDEX.md entries are accurate (file path, TC count, sign-off status)
  - Cross-refs to RETRO-008 + RETRO-009 + ADRs are current

## Out of scope

- New d-test authoring (separate scope, STORY-016/017/022 sister-pattern)
- d-test CI integration (separate scope, HUMAN lane, sister-pattern to PR #511)
- d-test framework ADR amendment (orthogonal, ADR-0049 stable)

## Open questions

- [ ] **Tester**: INDEX-cadence.md home — separate file in `docs/sprints/sprint-15/` or section in ADR-0049? Recommendation: separate file for Sprint 15, consider merge into ADR-0049 in Sprint 16 → tester @ AC1
- [ ] **Architect**: Sign-off process — does the 5-step process apply to ALL d-tests, or only those with new doctrine codification (sister-pattern to d058)? Recommendation: 5-step for doctrine codifiers, 3-step (skip arch) for routine sister-pattern → architect @ AC2
- [ ] **Developer**: INDEX.md format — should entries follow a strict template (YAML front matter + body), or free-form markdown? Recommendation: YAML front matter for machine-parseable + free-form body → developer @ AC3
- [ ] **Orchestrator**: Quarterly review cadence — Sprint planning ceremony (every 2 weeks) or quarterly literal (every 12 weeks)? Recommendation: Sprint planning ceremony → orchestrator @ AC1

## Mockups / references

- `scripts/tests/INDEX.md` (existing centralized registry)
- `scripts/tests/d058-claim-wip-workstream.sh` — sister-pattern (9 TCs, claim-next-ready, post-PR #506 + PR #511)
- `scripts/tests/d031-claim-next-ready.sh` — sister-pattern (5+2=7 TCs base, +3 expansion = 10 TCs post-STORY-019)
- ADR-0044 RED-first TDD discipline (process step 2 + 3)
- ADR-0045 9-Lens Review Checklist (process step 2 + 4)
- ADR-0049 d-test framework (cadence doc home)
- ADR-0024 verdict-by:<ts> schema (sign-off label sister-pattern)
- RETRO-009 §6 (d-test family persistence codification)
- RETRO-009 §10 (tester lane INDEX maintainer codification, on main via PR #513)

## Dependencies

- **Upstream**:
  - d058 d-test impl + CI integration (PR #506 + PR #511) ✅ DONE — sister-pattern reference
  - RETRO-009 §6 + §10 codifications (on main via PR #513) ✅ DONE
  - ADR-0044 + ADR-0045 + ADR-0049 framework ADRs ✅ DONE
- **Downstream**:
  - d059, d060, d061 d-test impl (STORY-022, STORY-016, STORY-017) — INDEX.md entries added
  - Sprint 16+ d-test additions follow same cadence + sign-off process
- **Sister-pattern**:
  - d-test family 10-sister on main → 13-sister post-Sprint 15
  - Sprint 14 P2 #11 (tester lane INDEX maintainer predecessor, 1.0-2.0 SP)
  - Sprint 14 P1 #2/3/4/5 d-test additions (4-sister cycle, INDEX.md drift observation)

## Metrics of success

- d-test INDEX.md entries ≥10 (10 existing) + ≥3 (Sprint 15 new) = 13-sister (leading)
- INDEX-cadence.md doc published (leading)
- Sign-off process documented + applied to ≥3 d-tests (leading)
- d-test family 13-sister on main post-Sprint 15 (lagging)
- Quarterly INDEX.md review maintained (lagging)

## Cross-refs

- docs/sprints/sprint-15/plan.md §Committed stories #9 (Sprint 15 P2 #9 home)
- docs/sprints/sprint-15/backlog.json (STORY-023 entry)
- RETRO-009 §6 (d-test family persistence codification)
- RETRO-009 §10 (tester lane INDEX maintainer codification, on main via PR #513)
- RETRO-008 §11 (d-test persistence predecessor)
- Sprint 14 P2 #11 (tester lane carry, sister-pattern)
- ADR-0044 RED-first TDD discipline (sign-off process)
- ADR-0045 9-Lens Review Checklist (sign-off process)
- ADR-0049 d-test framework (cadence doc home)
- ADR-0024 verdict-by:<ts> schema (sign-off label)
- PR #506 squash @ 226b546 (d058 impl)
- PR #511 squash @ 70e33d7 (d058 CI integration, INDEX.md update sister-pattern)
- PR #513 squash @ ebf6bc8 (RETRO-009 ceremony 4/4)

— @product-manager, 2026-06-27T17:58+03:00 = 14:58Z, Sprint 15 P2 #9 (tester lane INDEX maintainer, d-test cadence doc + sign-off process)