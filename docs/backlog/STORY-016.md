# STORY-016: §1 pre-push branch-base check (RETRO-009 §1, chain dep pollution prevention tooling)

## User Story
As a **P1 — Dev (operator of git pre-push hooks, branch contamination prevention)**,
I want **a pre-push hook that checks `git merge-base HEAD origin/main` against expected base + scripts/tests/d060-branch-base-check.sh d-test with 9/9 TCs green per ADR-0044 RED-first**,
So that **chain dep pollution (Sprint 14 PR #509 LIVE INSTANCE, RETRO-009 §6 LIVE INSTANCE #6) is prevented at push time, before PR creation, per RETRO-009 §1 codification (on main via PR #513 squash @ ebf6bc8)**.

## Why now

Sprint 14 P1 cluster observed chain dep pollution in PR #509 (3 scripts/ files duplicated PR #506 squash @ 226b546). Manual fix required `git reset --hard origin/main` + `git cherry-pick` playbook. RETRO-009 §1 codification proposes tooling-level prevention. Without d060 d-test, the pre-push hook implementation is unenforced and the chain dep pollution can re-occur on next cluster cycle.

## Acceptance Criteria

- **AC1** — `scripts/pre-push/branch-base-check.sh` hook impl per RETRO-009 §1 doctrine:
  - GIVEN a local branch `feat/foo` based on `origin/main`@SHA-X WHEN the dev runs `git push` THEN the hook runs `git merge-base HEAD origin/main` and verifies the result equals SHA-X (current origin/main HEAD)
  - GIVEN a local branch `feat/foo` based on `origin/main`@SHA-X (stale, origin/main advanced to SHA-Y) WHEN dev runs `git push` THEN hook exits non-zero with message "Branch base stale: rebase onto origin/main first" (sister-pattern to direct-push-to-main prevention)
  - GIVEN a local branch with chain dep pollution (commit chain references PR #N's squash SHA) WHEN hook runs THEN hook detects and exits non-zero with message "Chain dep pollution detected: rebase onto origin/main"
- **AC2** — `scripts/tests/d060-branch-base-check.sh` d-test with 9/9 TCs green per ADR-0044 RED-first (sister-pattern to d058 which has 9 TCs):
  - TC1: branch base matches origin/main HEAD → exit 0 (core happy path)
  - TC2: branch base stale (origin/main advanced) → exit 1, message present
  - TC3: chain dep pollution detected → exit 1, message present (sister-pattern to PR #509 LIVE INSTANCE)
  - TC4: branch with merge commit → exit 0 (no false positive on merge commits)
  - TC5: branch with squash-merge referenced → exit 1 (chain dep detected)
  - TC6: branch from detached HEAD → exit 0
  - TC7: hook bypass flag (`--no-verify`) → exit 0 (bypass is explicit dev choice)
  - TC8: hook on detached HEAD with no origin/main → exit 2 (config error)
  - TC9: hook on non-git directory → exit 2 (config error)
- **AC3** — CI guard per ADR-0053 (Layer 5 race codification):
  - Pre-push hook registered via `.git/hooks/pre-push` symlink OR `core.hooksPath` config in `.git/config`
  - Hook execution verified in `lint-and-test.yml` CI workflow (sister-pattern to d058 CI integration via PR #511)
  - INDEX.md registration updated per ADR-0049 d-test framework

## Out of scope

- CI-side chain dep detection (orthogonal concern, separate tooling)
- `git fsck` chain dep detection (orthogonal, future sister-pattern)
- d031-claim-next-ready.sh update (sister-pattern, separate lane, STORY-019)
- d059 §6 family persistence carrier (separate scope, STORY-022)

## Open questions

- [ ] **Architect**: Should chain dep pollution detection inspect commit messages (looking for `Closes #N` patterns) or use git internals (`git cherry`)? → architect @ Sprint 15 kickoff workshop
- [ ] **Architect**: Bypass flag handling — should `--no-verify` be allowed for emergency squash fixes (like PR #509), or always enforced? → architect @ Sprint 15 kickoff workshop
- [ ] **Developer**: Hook installation — `.git/hooks/pre-push` (per-repo, dev-self install) OR `.gitconfig` `core.hooksPath` (cross-repo, setup script)? → developer @ impl
- [ ] **Tester**: d-test TC ordering — should chain dep detection (TC3/TC5) come before sanity checks (TC6/TC7/TC8) for readability? → tester @ AC2

## Mockups / references

- `scripts/tests/d058-claim-wip-workstream.sh` — sister-pattern (9 TCs, claim-next-ready work-stream awareness)
- `scripts/tests/d031-claim-next-ready.sh` — sister-pattern (5+2=7 TCs, base Layer 2)
- `scripts/pre-push/` (new directory) — impl home
- `.git/hooks/pre-push` — hook registration
- RETRO-009 §1 (chain dep pollution prevention doctrine, on main via PR #513 squash @ ebf6bc8)
- RETRO-009 §6 LIVE INSTANCE #6 (PR #509 chain dep pollution, fix applied)
- Issue #498 (Sprint 14 PM lane continuation, sister-pattern to Sprint 15 PM lane)

## Dependencies

- **Upstream**:
  - branch-base spec ADR (arch-owned, file before §1 impl, Sprint 15 P1 #6 sister per arch observation)
  - RETRO-009 §1 codification (on main via PR #513) ✅ DONE
  - PR #509 chain dep pollution LIVE INSTANCE ✅ DOCUMENTED
- **Downstream**:
  - d060 d-test CI integration (HUMAN lane, sister-pattern to PR #511 d058 CI integration)
  - scripts/tests/INDEX.md registration (P2 #23 carry, tester lane)
  - Sprint 15 P2 d059 §6 family persistence (sister-pattern)
- **Sister-pattern**:
  - d058-claim-wip-workstream.sh (9 TCs, claim-next-ready)
  - d054-closes-anchor-strict-format.sh (PR #499 sister)
  - PR #509 squash @ 097f1c2 (LIVE INSTANCE #6 origin)

## Metrics of success

- Chain dep pollution prevented in CI per RETRO-009 §1 (leading)
- d060 d-test 9/9 TCs green (leading)
- Pre-push hook registered in `.git/hooks/` for all dev workstations (lagging)
- d-test family coverage: 12-sister pattern (10 + d059 + d060) all merged (lagging)

## Cross-refs

- docs/sprints/sprint-15/plan.md §Committed stories #2 (Sprint 15 P1 #2 home)
- docs/sprints/sprint-15/backlog.json (STORY-016 entry, d-test ID d060)
- Issue #498 (Sprint 14 PM lane continuation, Sprint 15 P1 #4 sister)
- RETRO-009 §1 (chain dep pollution prevention codification)
- RETRO-009 §6 LIVE INSTANCE #6 (PR #509 chain dep pollution fix)
- PR #509 squash @ 097f1c2 (LIVE INSTANCE origin)
- PR #513 squash @ ebf6bc8 (RETRO-009 ceremony 4/4)
- ADR-0044 (RED-first TDD discipline)
- ADR-0049 (d-test framework)
- ADR-0053 (Layer 5 race codification, AC3 CI guard sister)
- Issue #238 (no self-justified pauses doctrine)

— @product-manager, 2026-06-27T17:58+03:00 = 14:58Z, Sprint 15 P1 #2 (chain dep pollution prevention tooling, d-test ID d060)