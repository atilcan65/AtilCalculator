# Sprint 23 — Plan

> **Cycle**: ~#1786, owner ASAP verdict (Issue #733 Q2)
> **Goal**: Close Sprint 22 PIVOT P3 cluster + restart delivery cadence post-PIVOT
> **Capacity**: ~25-30sp (owner-approved ASAP, no Monday kickoff ceremony)
> **Predecessor**: [Sprint 22 PIVOT](../sprint-22/plan.md) (self-hosted runner migration + 3-repo org migration + template visibility)

## Sprint goal (one paragraph)

Close the Sprint 22 PIVOT P3 close cluster (PR #732 ADR-0019 amend 3 + ADR-0019 amend 4 + cascade PRs #679/#704/#694) and execute Sprint 21 carry-over stories (sub-stories of #689/#690 closed by Issue #733 owner verdict Q1). Restart delivery cadence post-PIVOT. Primary technical debt: conftest env-var precedence (SOLVED by PR #734 + repo vars). Secondary debt: cascade PRs need re-verdict cycle to clear Sprint 22 PIVOT P3 cluster.

## Committed stories (Sprint 23 backlog seed per Issue #733 + owner ASAP verdict)

| Story | Source | sp | Lane | Pre-condition |
|---|---|---|---|---|
| **#633** (S21-019 ONBOARDING.md) | Sprint 21 Wave 1 leftover | 3sp | dev | d093 d-test shipped (PR #694 d093 sister-pattern, 3/3 RED→GREEN on rebased 3a4cf3b, currently in tester re-verdict cycle) |
| **#636** (S21-003a) | Sprint 21 Wave 2 leftover | 3sp | dev | d070a extends d070 (PR #704 d070) |
| **#693** (S21-003b) | Sprint 21 Wave 2 leftover | 2sp | dev | d070b extends d070a (cascade from #636) |
| **#651** (S21-004) | Sprint 21 Wave 2 leftover | 3sp | dev + owner cross-lane | d080 (5 TCs sister-pattern d004); partial ci.yml step = owner |
| **#635** (S21-005) | Sprint 21 Wave 2 leftover | 3sp | dev | d091 (renamed cycle ~#1222 from d081 per Issue #113); sister-pattern d070 |
| **#638** (S21-006) | Sprint 21 Wave 2 leftover | 3sp | dev + owner pre-approval | d082 sister-pattern d075; AC4 owner pre-approval `.claude/` human-only |
| **#639** (S21-007) | Sprint 21 Wave 2 leftover | 2sp | dev | d083 sister-pattern d090 |
| **#724** (d094 slot collision) | Sprint 23 hygiene | 1sp | dev | Option A: rename PR #709's d094 to d097 (per Issue #113 precedent, arch endorsed cmt 4847637068) |
| **#652** (S21-020 ONBOARDING.md content) | Sprint 21 deferred (Wave 5) | 6sp | PM | fast-track Sprint 23, S21-020a (3sp) PR #736 opened (PM lane active) |

**Total Sprint 23 committed**: 26sp dev lane + 6sp PM lane = **~32sp**

PM seed analysis: 25-30sp 2-week target, 32sp slightly over but owner chose ASAP start. Cluster close is primary path.

## Active cascade (in flight at Sprint 23 start)

| Item | Owner | Status | ETA |
|---|---|---|---|
| PR #732 (ADR-0019 amend 3) | dev (markdown link fix) + owner squash | status:in-progress + agent:developer | ~5dk (dev 1-line fix + CI re-run) |
| PR #679 (d069 v2) | dev (rebased 58f2b5e) + tester re-🟢 + owner squash | status:in-review + needs-tester-signoff | ~10dk |
| PR #704 (d070) | dev (rebased d700e05) + tester re-🟢 + owner squash | status:in-review + needs-tester-signoff | ~10dk |
| PR #694 (d093) | dev (rebased 3a4cf3b) + tester re-🟢 + owner squash | status:in-review + needs-tester-signoff | ~10dk |
| ADR-0019 amend 4 PR | arch (post-#732-squash) + tester 🟢 + owner squash | not yet filed (drafted in working tree as ADR-0019-amendment-4-conftest-env-var-precedence.md) | ~15dk (after #732 squash) |

## Risks (8)

1. **Cluster close cascade dependency**: PR #732 markdown fix → squash → ADR-0019 amend 4 → #679/#704/#694 owner squash. Any dev delay propagates.
2. **Sprint 21 carry-over batch size**: 9 stories committed = high WIP risk. WIP cap monitoring critical.
3. **Cross-lane dependencies**: #651 (ci.yml step = owner), #638 (AC4 owner pre-approval). Owner bandwidth constraint.
4. **Self-hosted runner perf discovery** (BUDGET_MULTIPLIER=5): may need future tuning if more perf tests added.
5. **d094 slot collision** (#724): cascade effect on PR #709's existing d094 numbering — needs careful rename to avoid re-numbering cascade. Arch endorsed Option A d094→d097 per Issue #113.
6. **PM bandwidth on #652** (S21-020 ONBOARDING.md): S21-020a 3sp shipped via PR #736 (PM lane active, 2026-06-30T23:31Z). S21-020b/c 3sp remaining.
7. **CI lint discoveries**: PR #732 markdown link lint revealed d110 d-test gap (now in regression guard inventory). May surface more lint issues in carry-over docs.
8. **Owner merge gate bottleneck**: 4-PR squash cluster pending owner bandwidth. Sprint 23 success depends on owner squash cadence.

## DoD criteria (per CLAUDE.md Definition of Done + Sprint 22 retro carry)

1. All Sprint 23 stories ship per AC
2. PR cluster closes cleanly (#732 → ADR-0019 amend 4 → #679/#704/#694)
3. PM coordination body well-tracked (Issue #733 + #724 + #652 + #735)
4. No new P0/P1 bugs filed against cluster PRs within 24h
5. Repo vars BUDGET_MULTIPLIER=5 + SUBPROCESS_TIMEOUT_S=10 documented in README + CHANGELOG.md
6. Sprint 22 close-out documented in docs/sprints/sprint-22/close.md (pending)

## Open questions (post-ceremony, to resolve in Sprint 23)

- **Q1**: Sprint 23 mid-sprint retro trigger? (cluster close + cascade health)
- **Q2**: ADR-0019 amend 4 PR file timing? (after #732 squash only, parallel lane OK?)
- **Q3**: #724 d094 → d097 rename scope? (per Issue #113 precedent, but is Issue #113 itself the right precedent?)

## Lane posture at Sprint 23 start

- **dev**: WIP=2/2 (PR #679 + PR #732 in flight); #704 + #694 cluster lane; PM-lane WIP not counted
- **tester**: 3 PRs in re-verdict cycle (cluster); 1 d-test gap (d110 markdown link lint) — add to regression guard inventory
- **arch**: ADR-0019 amend 4 PR pending #732 squash; #724 d094→d097 design endorsed (cmt 4847637068); design lane clear
- **PM**: #652 S21-020a 3sp PR #736 OPEN (status:ready, owner squash gate after tester 🟢); backlog seed provided in Issue #733
- **orchestrator**: Sprint 23 ceremony authored (this PR); cascade coordination active

## Ceremony timeline (cycle ~#1786-#1787)

- Issue #733 owner verdict captured (Q1: ok, Q2: ASAP, Q3: defer to ORCH/PM)
- Sprint 21 cleanup executed (#689 + #690 closed as carry-over)
- docs/sprints/sprint-23/plan.md authored (this file)
- docs/sprints/current/plan.md pointer updated (Sprint 22 → Sprint 23)
- Issue #735 [Sprint 23 Kickoff] tracking issue opened
- All 4 lane peers + owner peer-poked for Sprint 23 EXECUTION start
- arch design on #724 (Option A d094→d097) endorsed
- 9 stories committed, ~32sp, 8 risks, 6 DoD

— @orchestrator, cycle ~#1787, owner ASAP verdict on Issue #733 Q2 (2026-06-30T20:25Z)
