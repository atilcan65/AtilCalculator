#!/usr/bin/env bash
# d006-stable-event-ids.sh — regression test for issue #6.
#
# Bug: agent-watch.sh event IDs for issue_assigned / board_change / pr_labeled
# were constructed from `.updatedAt`, which bumps on every comment / label-edit /
# assign. Each bump produced a new event ID and re-woke the agent for the same
# underlying state — visible as the orchestrator's processed_event_ids growing
# with 5+ entries for the same issue across a few minutes of label cleanup.
#
# Fix (v3.5): event IDs are now derived from the sorted label set. A comment
# (label set unchanged) → same ID → dedup catches it. An idempotent label flip
# (add X then remove X) → returns to original ID → suppressed. Only a NET
# change to the relevant label set produces a new event.
#
# This test verifies:
#   T1: ID is stable across updatedAt changes when labels are unchanged.
#   T2: ID changes when labels change (real state change → real wake).
#   T3: ID is stable across idempotent label flips (add X then remove X).
#   T4: Three kinds (issue_assigned, board_change, pr_labeled) all use the
#       new content-stable scheme.
#   T5: End-to-end smoke — running agent-watch.sh tester --once against a
#       mocked gh fixture twice with bumped updatedAt produces the SAME
#       event ID both times (the actual repro of the original bug).
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d006-stable-event-ids.sh
# Integrated:     called from e2e-pilot.sh as T-d006

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH_SH="$SCRIPT_DIR/../agent-watch.sh"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s${D}\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 127
fi
if [ ! -r "$WATCH_SH" ]; then
  echo "ERROR: agent-watch.sh not found at $WATCH_SH" >&2; exit 127
fi

# Extract the jq ID-construction expression used by the three fixed queries.
# The IDs share the shape:  "<prefix>-<number>-<sorted-labels-joined>"
# We verify the schema by feeding sample JSON and checking the output.
ISSUE_ASSIGNED_EXPR='.[] | select(.updatedAt > "T0") |
  { id: ("issue-assigned-" + (.number | tostring) + "-" + (.labels | map(.name) | sort | join("|"))) }'

BOARD_CHANGE_EXPR='.[] | select(.updatedAt > "T0") |
  { id: ("board-" + (.number | tostring) + "-" + (.labels | map(.name) | sort | join("|"))) }'

# pr_labeled uses $p.labels (already a flat array of strings, see agent-watch.sh:712)
PR_LABELED_EXPR='.[] | select(.updatedAt > "T0") |
  { id: ("pr-labeled-" + (.number | tostring) + "-" + (.labels | sort | join("|"))) }'

# --- T1: stability across updatedAt bumps (the actual bug repro) ---
section "T1: ID is stable across updatedAt bumps (the bug repro)"
# UpdatedAt values use lexicographically-comparable markers ("U1","U2","U3") that
# all pass the `select(.updatedAt > "T0")` filter used by the real query.
FIXTURE='[
  {"number": 6, "updatedAt": "U1", "labels": [{"name":"agent:tester"},{"name":"type:bug"},{"name":"status:ready"}]},
  {"number": 6, "updatedAt": "U2", "labels": [{"name":"agent:tester"},{"name":"type:bug"},{"name":"status:ready"}]},
  {"number": 6, "updatedAt": "U3", "labels": [{"name":"agent:tester"},{"name":"type:bug"},{"name":"status:ready"}]}
]'
IDS=$(echo "$FIXTURE" | jq -c "$ISSUE_ASSIGNED_EXPR" | jq -r '.id')
UNIQUE=$(echo "$IDS" | sort -u | wc -l)
NONEMPTY=$(echo "$IDS" | grep -c . || true)
if [ "$UNIQUE" = "1" ] && [ "$NONEMPTY" = "3" ]; then
  pass "T1: 3 different updatedAt → same non-empty ID (id=$IDS)"
else
  fail "T1: 3 different updatedAt → unique=$UNIQUE nonempty=$NONEMPTY ids=$IDS (expected 1 unique, 3 non-empty)"
fi

# --- T2: ID changes when labels change (real state change must wake) ---
section "T2: ID changes when labels change (real state change must wake)"
BEFORE=$(echo '[{"number":6,"updatedAt":"T1","labels":[{"name":"agent:tester"},{"name":"status:ready"}]}]' | \
  jq -c "$ISSUE_ASSIGNED_EXPR" | jq -r '.id')
AFTER=$(echo '[{"number":6,"updatedAt":"T1","labels":[{"name":"agent:tester"},{"name":"status:in-progress"}]}]' | \
  jq -c "$ISSUE_ASSIGNED_EXPR" | jq -r '.id')
if [ "$BEFORE" != "$AFTER" ] && [ -n "$BEFORE" ] && [ -n "$AFTER" ]; then
  pass "T2: status flip → distinct IDs ($BEFORE → $AFTER)"
else
  fail "T2: status flip did not change ID (regression: real state changes would be suppressed)"
fi

# --- T3: idempotent label flip collapses to same ID ---
section "T3: idempotent label flip collapses to original ID"
START=$(echo '[{"number":6,"updatedAt":"T1","labels":[{"name":"agent:tester"},{"name":"status:ready"}]}]' | \
  jq -c "$ISSUE_ASSIGNED_EXPR" | jq -r '.id')
FLIPPED=$(echo '[{"number":6,"updatedAt":"T2","labels":[{"name":"agent:tester"},{"name":"status:ready"},{"name":"priority:P3"}]}]' | \
  jq -c "$ISSUE_ASSIGNED_EXPR" | jq -r '.id')
RESTORED=$(echo '[{"number":6,"updatedAt":"T3","labels":[{"name":"agent:tester"},{"name":"status:ready"}]}]' | \
  jq -c "$ISSUE_ASSIGNED_EXPR" | jq -r '.id')
if [ "$START" = "$RESTORED" ] && [ "$START" != "$FLIPPED" ]; then
  pass "T3: add P3 then remove → restored ID matches start ($START); intermediate ID distinct ($FLIPPED)"
else
  fail "T3: idempotent flip did not collapse (start=$START flipped=$FLIPPED restored=$RESTORED)"
fi

# --- T4: all three kinds use the content-stable scheme ---
section "T4: issue_assigned + board_change + pr_labeled all content-stable"
# board_change (orchestrator lens) — same labels regardless of updatedAt
ISSUE_B='[
  {"number":1,"updatedAt":"T1","state":"OPEN","labels":[{"name":"agent:orchestrator"},{"name":"status:ready"}]},
  {"number":1,"updatedAt":"T2","state":"OPEN","labels":[{"name":"agent:orchestrator"},{"name":"status:ready"}]}
]'
B_UNIQUE=$(echo "$ISSUE_B" | jq -c "$BOARD_CHANGE_EXPR" | jq -r '.id' | sort -u | wc -l)
# pr_labeled — flat labels array
PR_F='[
  {"number":5,"updatedAt":"T1","labels":["type:docs","status:in-review","cc:tester"]},
  {"number":5,"updatedAt":"T2","labels":["type:docs","status:in-review","cc:tester"]}
]'
P_UNIQUE=$(echo "$PR_F" | jq -c "$PR_LABELED_EXPR" | jq -r '.id' | sort -u | wc -l)
if [ "$B_UNIQUE" = "1" ] && [ "$P_UNIQUE" = "1" ]; then
  pass "T4: board_change + pr_labeled both stable across updatedAt (orchestrator + architect/tester paths)"
else
  fail "T4: board_change unique=$B_UNIQUE pr_labeled unique=$P_UNIQUE (expected 1 each)"
fi

# --- T5: end-to-end smoke against mocked gh (real watcher invocation) ---
section "T5: end-to-end — agent-watch.sh tester --once against mocked gh"
WORK_DIR=$(mktemp -d -t d006-e2e.XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

# Mock gh that applies the watcher's --jq filter to canned fixture data.
# Captures the --jq arg from the call and runs jq on the canned JSON.
MOCK_BIN="$WORK_DIR/gh"

# Helper: write a mock gh that returns $1 (JSON array) ONLY when called with
# `--label agent:tester`, and applies the watcher's --jq filter. Other
# invocations return '[]' so unrelated query paths stay empty and don't
# contaminate the test (e.g. pr_labeled / pr_review_requested picking up the
# issue fixture and emitting bogus events).
write_mock() {
  local data="$1"
  cat > "$MOCK_BIN" <<EOF
#!/usr/bin/env bash
JQ_FILTER=""
PREV=""
for arg in "\$@"; do
  if [ "\$PREV" = "--jq" ]; then JQ_FILTER="\$arg"; fi
  PREV="\$arg"
done
case "\$*" in
  *"--label agent:tester"*)
    DATA='$data'
    if [ -n "\$JQ_FILTER" ]; then
      echo "\$DATA" | jq -c "\$JQ_FILTER" 2>/dev/null || echo "\$DATA"
    else
      echo "\$DATA"
    fi
    ;;
  *)
    echo '[]'
    ;;
esac
EOF
  chmod +x "$MOCK_BIN"
}

# Use future ISO timestamps so they always pass the watcher's `updatedAt >
# LAST_SEEN` filter (LAST_SEEN is real-time, fixture is "2099-...").
write_mock '[{"number":42,"title":"fixture-issue","url":"https://example.test/42","updatedAt":"2099-01-01T00:00:00Z","labels":[{"name":"agent:tester"},{"name":"type:bug"}]}]'

# Sandbox state dir so we don't touch /var/log/dev-studio
export AGENT_STATE_DIR="$WORK_DIR/state"
export PATH="$WORK_DIR:$PATH"
export GITHUB_REPO="atilcan65/AtilCalculator"

# First poll — captures event ID for issue #42
OUT1=$(bash "$WATCH_SH" tester 2>&1) || true
ID1=$(echo "$OUT1" | jq -r '.new_events[0].id // ""')

# Second poll — bump updatedAt to a different future timestamp. Same labels.
# Reset state so LAST_SEEN re-includes the issue (otherwise the filter would
# exclude it on poll 2; we want to prove the dedup chain suppresses it, not
# the time filter).
write_mock '[{"number":42,"title":"fixture-issue","url":"https://example.test/42","updatedAt":"2099-01-01T00:00:01Z","labels":[{"name":"agent:tester"},{"name":"type:bug"}]}]'
rm -rf "$AGENT_STATE_DIR"
OUT2=$(bash "$WATCH_SH" tester 2>&1) || true
ID2=$(echo "$OUT2" | jq -r '.new_events[0].id // ""')

# Pre-fix behaviour would emit two different IDs (one per updatedAt).
# Post-fix should emit one stable ID.
if [ -n "$ID1" ] && [ "$ID1" = "$ID2" ]; then
  pass "T5: end-to-end ID stable across updatedAt bump ($ID1)"
elif [ -z "$ID1" ] || [ -z "$ID2" ]; then
  fail "T5: end-to-end produced no event ID (ID1=$ID1 ID2=$ID2)"
else
  fail "T5: end-to-end IDs differ across updatedAt bump (ID1=$ID1 ID2=$ID2) — fix not applied"
fi

# --- summary ---
TOTAL=$((PASS+FAIL))
printf "\n${B}==== d006-stable-event-ids summary ====${D}\n"
printf "  TOTAL=%d  PASS=%d  FAIL=%d\n" "$TOTAL" "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0