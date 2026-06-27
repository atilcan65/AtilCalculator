# STORY-017: §3 post-squash label hygiene sweep (RETRO-009 §3, dual-axis lag fix)

## User Story
As a **P1 — Dev (operator of post-squash hygiene tooling, dual-axis lag fix)**,
I want **a post-squash webhook + scripts/post-squash/label-hygiene.sh that auto-flips `status:*` → `status:done` on Closes-anchor + auto-removes stale `status:*` on squash + scripts/tests/d061-label-hygiene.sh d-test with 9/9 TCs green per ADR-0044 RED-first**,
So that **the dual-axis lag pattern (RETRO-009 §4 §14 NEW, 3 LIVE INSTANCES #507/#508/#512) is eliminated in CI per RETRO-009 §3 codification (on main via PR #513 squash @ ebf6bc8), per ADR-0048 Layer 5 race codification (Sprint 14 P1 #5)**.

## Why now

Sprint 14 P1 cluster observed 3 LIVE INSTANCES of dual-axis lag:
- Issue #507 closed with `status:in-progress` not flipped (Layer 5 race)
- Issue #508 closed with `status:ready` not flipped
- Issue #512 closed with NO status label (cascade-stripped pre-close, closedBy:[] empty)

Without d061 d-test, the post-squash sweep script is unenforced and the dual-axis lag can re-occur on next cluster cycle. Owner-implementable territory for `.github/workflows/` webhook.

## Acceptance Criteria

- **AC1** — `scripts/post-squash/label-hygiene.sh` sweep script impl per RETRO-009 §3 doctrine:
  - GIVEN an issue is auto-closed via Closes-anchor in a squash PR WHEN the squash fires THEN the script auto-flips `status:*` → `status:done` (e.g., `status:in-progress` → `status:done`)
  - GIVEN an issue is auto-closed via Closes-anchor AND has stale `status:ready` WHEN the squash fires THEN the script auto-removes `status:ready` and adds `status:done` (Layer 5 race fix)
  - GIVEN an issue auto-closed with cascade-stripped labels (no `status:*`) WHEN the squash fires THEN the script adds `status:done` (3rd LIVE INSTANCE fix, sister-pattern to Issue #512 closedBy:[] empty pattern)
- **AC2** — `scripts/tests/d061-label-hygiene.sh` d-test with 9/9 TCs green per ADR-0044 RED-first (sister-pattern to d058 which has 9 TCs):
  - TC1: issue with `status:in-progress` auto-closed → `status:done` flipped (core, LIVE INSTANCE #1 regression test)
  - TC2: issue with `status:ready` auto-closed → `status:ready` removed, `status:done` added (LIVE INSTANCE #2 regression test)
  - TC3: issue with no `status:*` auto-closed → `status:done` added (LIVE INSTANCE #3 regression test, sister-pattern to Issue #512 closedBy:[] empty)
  - TC4: issue manually closed (no squash) → no label change (sweep only fires on squash)
  - TC5: multiple issues in single squash → all auto-flipped (cluster case)
  - TC6: PR with no Closes-anchor → sweep exits 0, no change (negative case)
  - TC7: stale `status:in-review` auto-closed → `status:done` (extended coverage, not just status:in-progress + status:ready)
  - TC8: stale `status:blocked` auto-closed → `status:done` (extended coverage)
  - TC9: webhook signature invalid → exit 2 (config error)
- **AC3** — Webhook integration per ADR-0048 (Layer 5 race codification):
  - `.github/workflows/post-squash-label-hygiene.yml` workflow file (owner-implementable territory)
  - Webhook fires on `pull_request` action=`closed` AND `merged=true`
  - INDEX.md registration updated per ADR-0049 d-test framework

## Out of scope

- Pre-squash label hygiene (orthogonal, separate tooling, future sister-pattern)
- Issue close comment automation (separate concern, not in scope)
- Layer 5 race pattern itself (already codified in ADR-0053)

## Open questions

- [ ] **Architect**: Webhook vs workflow trigger — `repository_dispatch` event vs `pull_request` closed+merged event? Recommendation: pull_request closed+merged (sister-pattern to label-check workflow) → architect @ Sprint 15 kickoff workshop
- [ ] **Owner**: Webhook infrastructure — does owner-implement the `.github/workflows/` file (per file ownership matrix), or does arch draft and owner merge? → owner @ Sprint 15 kickoff
- [ ] **Developer**: Stale label detection — should `status:*` removal apply to all stale labels, or only `status:in-progress` + `status:ready` + `status:in-review` + `status:blocked` (exclude `status:backlog`)? Recommendation: exclude `status:backlog` since it's pre-work state → developer @ impl
- [ ] **Tester**: d-test TC ordering — should LIVE INSTANCE regression tests (TC1/TC2/TC3) come before sanity checks (TC6/TC9)? → tester @ AC2

## Mockups / references

- `scripts/tests/d058-claim-wip-workstream.sh` — sister-pattern (9 TCs, claim-next-ready)
- `scripts/post-squash/` (new directory) — impl home
- `.github/workflows/post-squash-label-hygiene.yml` (new workflow file, owner-implementable)
- RETRO-009 §3 (post-squash label hygiene codification, on main via PR #513 squash @ ebf6bc8)
- RETRO-009 §4 §14 NEW DUAL-AXIS (3-axis lag codification)
- ADR-0048 (Layer 5 race codification, Sprint 14 P1 #5, AC3 direct application)
- ADR-0053 (Layer 5 race pattern, sister-pattern to ADR-0048)
- Issue #507 (LIVE INSTANCE #1)
- Issue #508 (LIVE INSTANCE #2)
- Issue #512 (LIVE INSTANCE #3)

## Dependencies

- **Upstream**:
  - RETRO-009 §3 + §4 codifications (on main via PR #513) ✅ DONE
  - ADR-0048 Layer 5 race codification (Sprint 14 P1 #5, on main via PR #502) ✅ DONE
  - Issue #507/#508/#512 LIVE INSTANCES ✅ DOCUMENTED
- **Downstream**:
  - d061 d-test CI integration (HUMAN lane, sister-pattern to PR #511 d058 CI integration)
  - scripts/tests/INDEX.md registration (P2 #23 carry, tester lane)
- **Sister-pattern**:
  - d058-claim-wip-workstream.sh (9 TCs, claim-next-ready)
  - d050b-closes-anchor-strict-format.sh (Sprint 13 d-test, Issue #440 carrier)
  - PR #502 squash @ 30c9a97 (ADR-0053 origin)
  - PR #503 squash @ 2b66b73 (d053 4-cat verification sister)

## Metrics of success

- Dual-axis lag eliminated in CI per RETRO-009 §3 (leading)
- d061 d-test 9/9 TCs green (leading)
- Webhook fires on every squash (lagging)
- d-test family coverage: 12-sister pattern (10 + d059 + d060 + d061) all merged (lagging)

## Cross-refs

- docs/sprints/sprint-15/plan.md §Committed stories #3 (Sprint 15 P1 #3 home)
- docs/sprints/sprint-15/backlog.json (STORY-017 entry, d-test ID d061)
- RETRO-009 §3 (post-squash label hygiene codification)
- RETRO-009 §4 §14 NEW DUAL-AXIS (3-axis lag codification, 3 LIVE INSTANCES)
- ADR-0048 (Layer 5 race codification, direct application)
- ADR-0053 (Layer 5 race pattern, sister-pattern)
- Issue #507/#508/#512 (3 LIVE INSTANCES)
- PR #502 squash @ 30c9a97 (ADR-0053 origin)
- PR #513 squash @ ebf6bc8 (RETRO-009 ceremony 4/4)
- ADR-0044 (RED-first TDD discipline)
- ADR-0049 (d-test framework)

— @product-manager, 2026-06-27T17:58+03:00 = 14:58Z, Sprint 15 P1 #3 (post-squash label hygiene sweep, d-test ID d061)