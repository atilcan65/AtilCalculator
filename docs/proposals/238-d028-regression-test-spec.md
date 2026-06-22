# Proposal: d028 forbidden-standby-modes regression test spec (Issue #238 sub-task 3)

**Status**: Proposed (architect PR — pending dev impl after owner merge)
**Date**: 2026-06-22
**Source issue**: #238 (P0)
**Sub-task**: 3 of 3
**Author**: @architect
**Deciders**: @developer (impl), @tester (sign-off), @atilcan65 (owner approval)

## Why this proposal exists

The 2 architect deliverable sub-tasks (1: soul file patches; 2: agent-watch.sh patch) define NEW behavior. Without a regression test, the behavior is undocumented AND unverifiable. Per architect's "demand observability in every design" doctrine, every new behavior MUST have a test.

The test surface is the 4 forbidden standby modes (from sub-task 0 / PR #242):
1. "blocked on dependency" — agent should take OTHER queue items, not pause
2. "GitHub rate limit hit" — agent should work locally, not pause
3. "state corruption" — agent should flag to orchestrator + take OTHER items, not pause
4. "no new events" / "queue is empty" — agent should scan queue, not pause

d028 covers the operational surface that the agent-watch.sh patch (sub-task 2) exposes. The soul file patches (sub-task 1) are doctrine, not runtime behavior; they're not directly testable in bash (they're text). d028 covers the **operational** surface.

## d028 contract (architect spec — 4 TCs)

The test is `scripts/tests/d028-forbidden-standby-modes.sh` (per d015 / d012 / d022 naming convention). Pattern: bash script that runs scenarios and asserts expected output.

### Test setup (shared by all 4 TCs)

```bash
# Use a mock agent-state file (NOT the real /var/log/dev-studio/.../architect.json).
# This is critical: tests must NOT corrupt the live watcher state.
TMP_STATE="$(mktemp -d)/architect.json"
AGENT_STATE_DIR_OVERRIDE="$TMP_STATE" bash /home/atilcan/projects/AtilCalculator/scripts/agent-state.sh init architect
# Patch state with scenario-specific data per TC
```

### TC1 — "blocked on dependency" should NOT pause (D7 dep_broken detects it instead)

**Scenario**: agent has 1 issue with `blocks on #N` (predecessor open) + 3 other open issues with `agent:<role>` (the agent's OTHER queue).

**Expected behavior**:
- `agent-watch.sh` emits events for the 3 OTHER issues (via `query_assigned_issues`)
- `wake_nudge` is `[]` (queue IS non-empty but not in dep-broken pattern)
- No "standby" event is ever emitted
- **Key assertion**: agent-watch output does NOT contain a `kind: "standby"` (proves no self-standby event exists in the taxonomy)

**Mock state**:
```json
{
  "role": "architect",
  "agent_count_assigned": 3,
  "dep_blocked_count": 1,
  "queue_open": 3
}
```

**Pass criterion**: jq `.new_events + .wake_nudge | map(.kind) | unique` does NOT contain `"standby"`.

### TC2 — "GitHub rate limit hit" should NOT pause (D6 dev_idle catches it; agent keeps working locally)

**Scenario**: `gh api rate_limit` returns 0 remaining; agent-watch is supposed to keep running (with degraded gh calls) and emit `is_alive` heartbeat (per sub-task 2 patch).

**Expected behavior**:
- `agent-watch.sh` completes its poll cycle (even with rate-limited gh calls)
- Emits `is_alive` synthetic event (every 5 min)
- `wake_nudge` is non-empty (heartbeat-missed branch fires after 10 min of rate limit)
- No "standby" event emitted

**Mock state** (simulate rate limit via env var):
```bash
GH_RATE_LIMIT_REMAINING=0 bash scripts/agent-watch.sh architect
```

**Pass criterion**: output contains `kind: "is_alive"` event with `id: "is-alive-architect-..."` (proves the watcher is still running despite rate limit).

### TC3 — "state corruption" should NOT pause (agent flags to orchestrator + takes OTHER items)

**Scenario**: agent's `processed_event_ids` field is a JSON string (the #228 bug pattern, not yet fixed by dev's cmd_set impl).

**Expected behavior**:
- `agent-watch.sh` reads state, sees stringified `processed_event_ids`
- Emits a `state_corruption` event with context: `{"role": "architect", "field": "processed_event_ids", "expected_type": "array", "actual_type": "string", "fix_issue": 228}`
- Continues polling (does NOT pause)
- `wake_nudge` may be non-empty (queue non-empty + corruption flagged)

**Mock state** (write stringified field):
```bash
TMP_STATE="$(mktemp -d)/architect.json"
mkdir -p "$TMP_STATE"
echo '{"role": "architect", "processed_event_ids": "[\"event-1\", \"event-2\"]", "last_heartbeat_utc": "2026-06-22T07:00:00Z"}' > "$TMP_STATE/architect.json"
AGENT_STATE_DIR_OVERRIDE="$TMP_STATE" bash scripts/agent-watch.sh architect
```

**Pass criterion**: output contains `kind: "state_corruption"` event AND `.new_events | length > 0` (proves the agent continued to work, not paused).

### TC4 — "no new events / queue is empty" should NOT pause (D6 dev_idle detects queue non-empty + agent scans for expired)

**Scenario**: agent's `new_events` is `[]` (no new events) but `agent:<role>` queue is non-empty (e.g., 5 open issues, all `status:ready` past 24h).

**Expected behavior**:
- `agent-watch.sh` emits `wake_nudge` (Katman 1, queue non-empty)
- Emits `is_alive` synthetic heartbeat (per sub-task 2)
- Does NOT emit any "standby" event
- **Key assertion**: the agent's queue is re-surfaced via `wake_nudge`, allowing the agent to take work from "expired" issues

**Mock state**:
```json
{
  "role": "architect",
  "agent_count_assigned": 5,
  "queue_open": 5,
  "expired_ready_count": 5  // all past 24h
}
```

**Pass criterion**: jq `.wake_nudge | map(.kind) | unique` contains `"wake_nudge"` AND does NOT contain `"standby"`.

## Total TCs: 4

Plus **integration TC#5** (optional, recommended):
- All 4 forbidden modes in single test run → agent-watch emits 4 distinct detection events (or equivalent) → no standby event anywhere

This is similar to d015's "integration" TC at the end (TC9).

## Pattern reference

- `scripts/tests/d015-dev-idle-prevention.sh` — 9 TCs, same structure (bash + jq + mock state)
- `scripts/tests/d012-stale-verdict-schema.sh` — 5 TCs, schema tests
- `scripts/tests/d022-proactive-board-detections.sh` — D1-D4 detections (the gap-scan target for #235 / ADR-0037 D5-D8 uses the same pattern)

## Sprint 4 commitment (this sub-task)

| Role | SP | Scope |
|---|---|---|
| **Architect** (me) | 0.25 | This d028 spec — DONE on PR open |
| **Developer** | 0.5 | d028 test impl (~80-120 lines bash, 4-5 TCs) |
| **Tester** | 0.25 | d028 sign-off (4-5 TCs) |
| **Sub-task 3 total** | **1.0** | Fits Sprint 4 EOD |

## Cross-references

- Issue #238 (parent)
- PR #242 (sister — sub-task 0, CLAUDE.md amendment)
- `docs/proposals/238-soul-amendment-forbidden-standby-modes.md` (sister — sub-task 1)
- `docs/proposals/238-agent-watch-heartbeat-and-wake-nudge-patch.md` (sister — sub-task 2, defines the runtime behavior d028 tests)
- `scripts/tests/d015-dev-idle-prevention.sh` (pattern reference — same author, same domain)
- `scripts/tests/d022-proactive-board-detections.sh` (pattern reference — multi-TC detection tests)
- ADR-0037 (proactive gap-scan, D5-D8 — D6 dev_idle overlaps with d028 TC#2 and TC#4; can share test infrastructure)
- Issue #228 (cmd_set stringification — root cause of TC#3's mock state)

## Rollback

Revert the d028 file (after dev lands). d028 is additive; removing it leaves d015 + d022 (existing tests) intact. Zero impact on existing regression surface.
