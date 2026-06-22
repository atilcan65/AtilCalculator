# Proposal: `agent-watch.sh` is_alive heartbeat + wake_nudge-on-missed patch (Issue #238 sub-task 2)

**Status**: Proposed (architect PR — pending dev impl after owner merge)
**Date**: 2026-06-22
**Source issue**: #238 (P0 — `[Doctrin] Agents self-standby on dependency — violates no-pause doctrine`)
**Sub-task**: 2 of 3
**Author**: @architect
**Deciders**: @developer (impl), @tester (d028 TCs), @atilcan65 (owner approval)

## Why this proposal exists

The `#238 RCA at 2026-06-22T06:46Z` found 4 agents in self-invented standby. Two of them ("GitHub rate limit" architect, "state corruption" tester) had root cause: **the watcher had no observable signal that the agent was supposed to be alive but wasn't**. The per-poll heartbeat (L1143) only fires when poll_once runs; if the watcher is stuck in a 60s `gh api` retry loop (rate limit) or a 5-min query deadlock, no heartbeat = no signal = orchestrator can't distinguish "agent asleep" from "agent working hard".

**The fix**: add a synthetic `is_alive` event emitted **every 5 min** (regardless of queue state), and expand the `wake_nudge` trigger to fire on **heartbeat-missed** (in addition to the current "queue non-empty" trigger).

## Current state (`scripts/agent-watch.sh`)

| Line | Mechanism | What's missing |
|---|---|---|
| L1143 | `STATE_HELPER heartbeat "$ROLE"` — per-poll heartbeat (every 60s default) | No 5-min observability signal; no way to distinguish "alive but rate-limited" from "silent" |
| L1198-1227 | `wake_nudge` emitted when `agent:<role> + cc:<role > 0` (Katman 1, Issue #119) | Only fires when queue is non-empty; doesn't fire on heartbeat-missed |
| L1280 | Wake pane on `new_events + wake_nudge` (Katman 2) | OK, no change |

## Proposed patch (~25 lines, fits architect POC limit)

The patch adds:
1. **New env var** `IS_ALIVE_INTERVAL_SEC=300` (5 min default)
2. **New synthetic event** `is_alive` emitted every 5 min (independent of queue state)
3. **Expanded wake_nudge trigger** — fires on (queue non-empty) OR (last_is_alive_utc > 2x IS_ALIVE_INTERVAL_SEC = 10 min)
4. **New state field** `last_is_alive_utc` (similar to existing `last_heartbeat_utc`)

### Diff spec (architect POC, 30 lines)

```bash
# In poll_once, after L1143 heartbeat:
# --- v6.3 (Issue #238 sub-task 2): synthetic is_alive heartbeat ---
IS_ALIVE_INTERVAL_SEC="${IS_ALIVE_INTERVAL_SEC:-300}"
last_is_alive="$("$STATE_HELPER" get "$ROLE" last_is_alive_utc 2>/dev/null || true)"
emit_is_alive=false
if [ -z "$last_is_alive" ] || [ "$last_is_alive" = "null" ]; then
  emit_is_alive=true
else
  last_is_alive_epoch="$(date -u -d "$last_is_alive" +%s 2>/dev/null || echo 0)"
  now_epoch="$(date -u +%s)"
  if [ $(( now_epoch - last_is_alive_epoch )) -gt "$IS_ALIVE_INTERVAL_SEC" ]; then
    emit_is_alive=true
  fi
fi
is_alive='[]'
if [ "$emit_is_alive" = "true" ]; then
  is_alive="$(jq -n --arg role "$ROLE" --arg now "$now" \
    '[{ kind: "is_alive", id: ("is-alive-" + $role + "-" + $now),
        number: 0, title: ("is_alive heartbeat: " + $role),
        url: "", updated_at: $now,
        context: { role: $role, interval_sec: '"$IS_ALIVE_INTERVAL_SEC"' } }]')"
  "$STATE_HELPER" set "$ROLE" last_is_alive_utc "$now" >/dev/null 2>&1 || true
fi

# In wake_nudge computation (L1198-1227), add heartbeat-missed branch:
#   if (now - last_is_alive_epoch) > 2 * IS_ALIVE_INTERVAL_SEC → force wake_nudge
# This catches the "watcher stuck on rate-limited gh api" case
# where queue is non-empty but poll_once hasn't completed in 10 min.
```

(The 30-line POC above is for the 2 main changes — `is_alive` emit + wake_nudge trigger expansion. The full impl with merge into `merged` array + state helper v6 backfill is ~50 lines total — dev writes the final.)

### State schema bump (agent-state.sh v6)

Add `last_is_alive_utc` to the init schema (line 95-107) with default `null`. Backfill in `cmd_init` (line 130-137 pattern, add new check):

```bash
# v5 → v6 backfill (Issue #238 sub-task 2): last_is_alive_utc for synthetic heartbeat
if ! jq -e 'has("last_is_alive_utc")' "$file" >/dev/null 2>&1; then
  jq_inplace "$file" '.last_is_alive_utc = null'
fi
```

(2 lines added to `cmd_init`; 1 line added to init JSON template.)

## Backward compatibility

- Existing `last_heartbeat_utc` field: UNCHANGED. Per-poll heartbeat continues.
- Existing `wake_nudge` trigger (queue non-empty): UNCHANGED. New heartbeat-missed branch is ADDITIVE.
- Existing `d015-dev-idle-prevention.sh` (9/9 PASS): UNCHANGED. The 4 new d028 TCs cover the new surface.
- New state field `last_is_alive_utc`: defaults to `null`; backfill via `cmd_init` (v5→v6); no migration needed for existing state files.

## Observability impact

- **New metric**: `is_alive` event emitted every 5 min per role. If a role is silent for >10 min (2x interval), wake_nudge fires for that role → orchestrator can route help.
- **Doctor check**: `agent-doctor.sh` can add a "last_is_alive" check (parallel to existing "last_heartbeat" check) to detect stuck-watchers specifically.
- **Per-call cost**: 1 new `agent-state.sh get` + 1 new `agent-state.sh set` per 5 min (negligible; state helper is local file I/O).
- **No new gh API calls** (uses local state helper).

## Risks

| Risk | Mitigation |
|---|---|
| `is_alive` event floods consumer dedup buffer | Event ID is `is-alive-<role>-<ts>` (per-second granularity); with 5-min throttle, only ~12 unique IDs per role per hour; well under `processed_event_ids` 200-cap |
| State helper v6 backfill breaks existing state files | Backfill is `null` (no value change), idempotent; covered by existing backfill pattern (line 117-137 of `cmd_init`) |
| `wake_nudge` on heartbeat-missed fires spuriously (e.g. during deploy restart) | 2x interval threshold (10 min) absorbs normal restart jitter (typical restart <2 min per ADR-0030) |
| Patch conflicts with PR #239 (auto-ping impl) | PR #239 is dev's `feat/221-autoping-impl` branch; the #238 patch is on a separate `docs-238-3-subtasks` branch. Dev can fold both into a single combined impl PR after owner merge. |

## Sprint 4 commitment (this sub-task)

| Role | SP | Scope |
|---|---|---|
| **Architect** (me) | 0.25 | This proposal — DONE on PR open |
| **Developer** | 0.5 | agent-watch.sh patch (~25-50 lines) + agent-state.sh v6 backfill (~5 lines) |
| **Tester** | 0.25 | d028 TCs (covered in d028 proposal) |
| **Sub-task 2 total** | **1.0** | Fits Sprint 4 EOD |

## Cross-references

- Issue #238 (parent)
- PR #242 (sister — CLAUDE.md amendment, sub-task 0)
- `docs/proposals/238-soul-amendment-forbidden-standby-modes.md` (sister — sub-task 1)
- `docs/proposals/238-d028-regression-test-spec.md` (sister — sub-task 3, covers the test surface for this patch)
- `scripts/agent-watch.sh` L1143 (existing per-poll heartbeat), L1198-1227 (existing wake_nudge)
- `scripts/agent-state.sh` line 95-107 (init JSON template), 117-137 (backfill pattern)
- ADR-0037 (proactive gap-scan — D6 dev_idle is the operational detector for the "GitHub rate limit" + "state corruption" modes this patch addresses)
- PR #239 (auto-ping dual-channel impl, OPEN — dev can fold #238 patch into a combined impl PR)

## Rollback

Revert the impl PR (after dev lands). The 2 changes (is_alive emit + wake_nudge expansion) are additive; removing them restores L1143-only heartbeat + queue-non-empty-only wake_nudge. Zero impact on existing d015 regression.
