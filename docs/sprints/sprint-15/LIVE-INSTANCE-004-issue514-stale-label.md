# Sprint 15 LIVE INSTANCE #4 — Issue #514 stale `status:in-progress` while CLOSED

> **Captured**: 2026-06-27T18:10+03:00, @orchestrator (auto-wake pickup)
> **Carrier**: STORY-017 §3 / d061 / Sprint 15 P1 #3 / RETRO-009 §4
> **Sister-pattern**: Issue #507, #508, #512 (3 LIVE INSTANCES in Sprint 14 P1 cluster)
> **Doctrinal cite**: docs/CLAUDE.md §Dispatch Discipline 6-step + §Timing window (RETRO-007 watchlist #6) + RETRO-009 §4 (3-axis lag codification) + ADR-0048 (Layer 5 race)

## Observation

Issue #514 (`[Sprint 15] Kickoff — sizing matrix LOCKED, dispatch coordination`) was CLOSED at 2026-06-27T15:07:51Z via Closes-anchor (PR #515 squash). However, the issue still carries the `status:in-progress` label, while it does NOT carry `status:done`. This is a stale-label dual-axis lag pattern.

## Diagnosis

Per docs/CLAUDE.md §Dispatch Discipline 6-step + §Timing window (RETRO-007 watchlist #6) + RETRO-009 §4 (3-axis lag codification) + ADR-0048 (Layer 5 race):

1. **Issue state axis**: CLOSED ✅ (correctly transitioned at squash via Closes-anchor)
2. **Label state axis**: `status:in-progress` ❌ (NOT auto-flipped to `status:done`)
3. **Watcher state axis**: agent-watch loop emitted `label_change` event with stale label observation ✅ (catch worked)

The label flip `status:in-progress` → `status:done` was NOT auto-applied on Closes-anchor. This is the **cascade-strip pattern** documented in RETRO-009 §4 LIVE INSTANCE #3 (Issue #512) and replicated here for Issue #514.

## Why it matters

Sprint 15 P1 #3 / STORY-017 / d061 d-test is supposed to codify the post-squash label hygiene sweep:
- Auto-flip `status:*` → `status:done` on Closes-anchor
- Auto-remove stale `status:*` on squash via post-squash webhook
- 9/9 TCs regression-testing 3-axis lag pattern (Issue #507, #508, #512 LIVE INSTANCES)

Until d061 is implemented (Sprint 15 P1 #3 work), stale labels on closed issues will accumulate. This is the 4th LIVE INSTANCE after Issue #507 (status:in-progress stale on CLOSED Sprint 14 P1 #7 close), #508 (status:ready stale on CLOSED Sprint 14 P1 #6 follow-up), #512 (closedBy:[] empty, cascade-stripped pre-close).

## Lane hygiene action (orchestrator)

Pending orchestrator decision:
- **Option A**: Manual cleanup `gh issue edit 514 --remove-label status:in-progress --add-label status:done` — lane hygiene, but bypasses d061 d-test detection logic (defeats the point of testing)
- **Option B**: Leave as-is, document as LIVE INSTANCE #4 evidence carrier for d061 — preserves the test signal for Sprint 15 P1 #3 work
- **Recommended**: Option B (preserve test signal). d061 d-test will catch + fix this pattern systematically.

## Cross-refs

- Issue #507 (LIVE INSTANCE #1, Sprint 14 P1 #7 close, status:in-progress stale)
- Issue #508 (LIVE INSTANCE #2, Sprint 14 P1 #6 follow-up, status:ready stale)
- Issue #512 (LIVE INSTANCE #3, RETRO-009 dispatch, closedBy:[] cascade-strip)
- Issue #514 (LIVE INSTANCE #4, this issue, status:in-progress stale while CLOSED)
- Sprint 15 P1 #3 / STORY-017 / d061 (post-squash label hygiene sweep, codification carrier)
- RETRO-009 §4 (3-axis lag codification)
- ADR-0048 (Layer 5 race codification)
- docs/CLAUDE.md §Dispatch Discipline + §Timing window

— @orchestrator, 2026-06-27T18:10+03:00, Sprint 15 LIVE INSTANCE #4 capture
