#!/usr/bin/env bash
# proactive-sweep-test.sh — TDD contract tests for query_proactive_sweep()
# in scripts/agent-watch.sh.
#
# Issue #44 (Sprint 1 ORCH proactive mode — A: Proactive Board Scan).
# Design spec: see comment thread on Issue #44 (orchestrator, 2026-06-18).
#
# Detection contract (4 detections):
#   D1 ready_unblocked  — status:ready issue body has "Blocked by: #X,#Y"
#                        where ALL blockers are CLOSED → emit detection
#   D2 orphan_backlog   — status:backlog with no cc:* label → emit detection
#   D3 stalled          — status:in-progress > 4h, no PR opened → emit detection
#   D4 wip_overflow     — 3+ status:in-progress (WIP > 2) → emit detection
#
# Acceptance:
#   - Function exists, only fires for ROLE=orchestrator
#   - 4 detections implemented per pseudocode
#   - Throttle + HWM via state field `proactive_sweep_last_utc`
#   - Kill switch PROACTIVE_SWEEP_ENABLED=false → no-op
#   - Wired into poll_once; events flow through dedup ring
#   - Test script green (10/10)
#
# Test pattern: follow scripts/tests/d006-stable-event-ids.sh
#   - Mock `gh` to return canned fixture data per `--label` filter
#   - Sandbox AGENT_STATE_DIR so we don't touch /var/log/dev-studio
#   - Source the function under test via `source` after stubbing env
#
# Out of scope (separate issues): #45 STATUS action driver, #46 stale_verdict
# watchdog, #47 atomic-label-edit.sh + ADR-0020/0021.
#
# Exit code: 0 = all 10 pass, 1 = at least one fail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH_SH="$SCRIPT_DIR/../agent-watch.sh"
STATE_SH="$SCRIPT_DIR/../agent-state.sh"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Sanity: preflight
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 127
fi
if [ ! -r "$WATCH_SH" ]; then
  echo "ERROR: agent-watch.sh not found at $WATCH_SH" >&2; exit 127
fi
if [ ! -r "$STATE_SH" ]; then
  echo "ERROR: agent-state.sh not found at $STATE_SH" >&2; exit 127
fi

# Helper: extract a function from agent-watch.sh into a sourcable form.
# We can't source the whole script (it has a top-level `case "$MODE"` dispatch
# and a hard exit on missing ROLE). Strip the bottom dispatch + require lines
# and pipe through bash.
load_function() {
  local fn_name="$1"
  local out
  out="$(awk -v fn_name="$fn_name" '
    function start_re() { return "^" fn_name "\\(\\) \\{" }
    function end_re()   { return "^\\}" }
    BEGIN { re_start = start_re(); re_end = end_re() }
    $0 ~ re_start { inside=1 }
    inside { print }
    inside && $0 ~ re_end { exit }
  ' "$WATCH_SH")"
  if [ -z "$out" ]; then
    echo "ERROR: function ${fn_name} not found in $WATCH_SH" >&2
    return 1
  fi
  echo "$out"
}

# ============================================================================
# T1: function exists in agent-watch.sh
# ============================================================================
section "T1: query_proactive_sweep() exists in agent-watch.sh"

if grep -qE "^query_proactive_sweep\(\)" "$WATCH_SH"; then
  pass "query_proactive_sweep() defined in agent-watch.sh"
else
  fail "query_proactive_sweep() NOT found in agent-watch.sh" \
       "expected the function to be defined per Issue #44 design spec"
  printf "\n${R}==== early abort: cannot test missing function ====${D}\n"
  exit 1
fi

# ============================================================================
# Helper: sandboxed test runner. Sets up:
#   - $WORK_DIR/gh mock that returns canned data per --label filter
#   - AGENT_STATE_DIR sandboxed to $WORK_DIR/state
#   - GITHUB_REPO pinned
#   - state file pre-initialised for the given role
# ============================================================================
WORK_DIR=""
mock_gh() {
  local fixture="$1"
  # fixture is a JSON array. We route on --label flag.
  cat > "$WORK_DIR/gh" <<EOF
#!/usr/bin/env bash
# Mock gh: route on --label filter. Apply watcher's --jq filter ourselves
# (gh's --jq doesn't run on canned data — it rejects as not-real-API).
# Use jq -r (raw) so scalar strings (e.g. .state) come out unquoted.
JQ_FILTER=""
PREV=""
for arg in "\$@"; do
  if [ "\$PREV" = "--jq" ]; then JQ_FILTER="\$arg"; fi
  PREV="\$arg"
done
DATA='$fixture'
case "\$*" in
  *"--label status:ready"*)
    FILTERED=\$(echo "\$DATA" | jq -c '[ .[] | select((.labels // []) | map(.name) | any(. == "status:ready")) ]' 2>/dev/null)
    if [ -n "\$JQ_FILTER" ]; then echo "\$FILTERED" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$FILTERED"; fi
    ;;
  *"--label status:backlog"*)
    FILTERED=\$(echo "\$DATA" | jq -c '[ .[] | select((.labels // []) | map(.name) | any(. == "status:backlog")) ]' 2>/dev/null)
    if [ -n "\$JQ_FILTER" ]; then echo "\$FILTERED" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$FILTERED"; fi
    ;;
  *"--label status:in-progress"*)
    FILTERED=\$(echo "\$DATA" | jq -c '[ .[] | select((.labels // []) | map(.name) | any(. == "status:in-progress")) ]' 2>/dev/null)
    if [ -n "\$JQ_FILTER" ]; then echo "\$FILTERED" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$FILTERED"; fi
    ;;
  *)
    echo '[]'
    ;;
esac
EOF
  chmod +x "$WORK_DIR/gh"
}

# Compute timestamps for age-sensitive fixtures.
NOW_ISO=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
NOW_EPOCH=$(date -u +%s)
ISO_5H_AGO=$(date -u -d "@$((NOW_EPOCH - 5*3600))" '+%Y-%m-%dT%H:%M:%SZ')
ISO_30M_AGO=$(date -u -d "@$((NOW_EPOCH - 30*60))" '+%Y-%m-%dT%H:%M:%SZ')

# Sanity check: state schema field proactive_sweep_last_utc must be
# backfillable (i.e. agent-state.sh init or backfill adds it for existing
# state files). We don't pre-populate; the function reads it via the state
# helper. We only check the field name appears in the agent-state.sh schema.
section "T1b: state schema includes proactive_sweep_last_utc"
if grep -q "proactive_sweep_last_utc" "$STATE_SH"; then
  pass "agent-state.sh schema references proactive_sweep_last_utc"
else
  fail "agent-state.sh does NOT reference proactive_sweep_last_utc" \
       "Issue #44 design requires a new state field for the throttle HWM"
fi

# ============================================================================
# T2: empty board → no events (regression for D1-D4 with empty fixture)
# ============================================================================
section "T2: empty board → no events"

setup_workspace() {
  WORK_DIR=$(mktemp -d -t proact-sweep.XXXXXX)
  export AGENT_STATE_DIR="$WORK_DIR/state"
  export PATH="$WORK_DIR:$PATH"
  export GITHUB_REPO="atilcan65/AtilCalculator"
  # Disable kill switch unless overridden
  export PROACTIVE_SWEEP_ENABLED="${PROACTIVE_SWEEP_ENABLED:-true}"
  # Disable throttle for these tests by default — tests set PROACTIVE_SWEEP_INTERVAL_SEC=0
  export PROACTIVE_SWEEP_INTERVAL_SEC="${PROACTIVE_SWEEP_INTERVAL_SEC:-0}"
  # Initialise state file
  "$STATE_SH" init orchestrator >/dev/null
}

cleanup_workspace() {
  [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"
  WORK_DIR=""
}

# Helper: call the function. Source the function into a subshell, then call it.
# (Can't source the whole agent-watch.sh — it dispatches to poll_once at top.)
call_sweep() {
  local role="$1"
  # Write function body to a file in the work dir, then `source` it before
  # calling. (Using `bash -c "$body; call"` in one line confuses bash's parser
  # — the function definition needs to be on its own line at parse time.)
  local fn_file="$WORK_DIR/fn.sh"
  load_function query_proactive_sweep > "$fn_file"
  (
    ROLE="$role"
    REPO="atilcan65/AtilCalculator"
    STATE_HELPER="$STATE_SH"
    # shellcheck disable=SC1090
    source "$fn_file"
    query_proactive_sweep
  )
}

setup_workspace
mock_gh '[]'
OUT=$(call_sweep orchestrator 2>&1) || true
COUNT=$(echo "$OUT" | jq 'length' 2>/dev/null || echo "?")
if [ "$COUNT" = "0" ]; then
  pass "empty board → 0 events"
else
  fail "empty board → $COUNT event(s) (expected 0)" "$OUT"
fi
cleanup_workspace

# ============================================================================
# T3: role gate — function is a no-op for non-orchestrator roles
# ============================================================================
section "T3: function is a no-op for non-orchestrator roles"

setup_workspace
# Pass a fixture that would otherwise trigger D1-D4 if role gate were missing.
mock_gh "$(cat <<EOF
[
  {"number": 100, "title": "fake ready", "body": "Blocked by: #200", "updatedAt": "$NOW_ISO", "labels": [{"name":"status:ready"}]},
  {"number": 101, "title": "fake backlog", "body": "", "updatedAt": "$NOW_ISO", "labels": [{"name":"status:backlog"}]},
  {"number": 102, "title": "fake stalled", "body": "", "updatedAt": "$ISO_5H_AGO", "labels": [{"name":"status:in-progress"}]}
]
EOF
)"
OUT=$(call_sweep developer 2>&1) || true
COUNT=$(echo "$OUT" | jq 'length' 2>/dev/null || echo "?")
if [ "$COUNT" = "0" ]; then
  pass "non-orchestrator role → 0 events (gate works)"
else
  fail "non-orchestrator role → $COUNT event(s) (expected 0 — role gate leak)" "$OUT"
fi
cleanup_workspace

# ============================================================================
# T4: kill switch — PROACTIVE_SWEEP_ENABLED=false → no-op
# ============================================================================
section "T4: PROACTIVE_SWEEP_ENABLED=false → no-op"

setup_workspace
export PROACTIVE_SWEEP_ENABLED="false"
# Mock that would otherwise fire D1 (ready + closed blocker).
cat > "$WORK_DIR/gh" <<EOF
#!/usr/bin/env bash
JQ_FILTER=""
PREV=""
for arg in "\$@"; do
  if [ "\$PREV" = "--jq" ]; then JQ_FILTER="\$arg"; fi
  PREV="\$arg"
done
case "\$*" in
  *"--label status:ready"*)
    DATA='[{"number":200,"title":"ready","body":"Blocked by: #201","updatedAt":"$NOW_ISO","labels":[{"name":"status:ready"}]}]'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *"--label status:backlog"*)
    if [ -n "\$JQ_FILTER" ]; then echo '[]' | jq -r "\$JQ_FILTER" 2>/dev/null; else echo '[]'; fi
    ;;
  *"--label status:in-progress"*)
    if [ -n "\$JQ_FILTER" ]; then echo '[]' | jq -r "\$JQ_FILTER" 2>/dev/null; else echo '[]'; fi
    ;;
  *"issue view 201"*)
    DATA='{"number":201,"state":"closed","title":"blocker"}'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *)
    echo '[]'
    ;;
esac
EOF
chmod +x "$WORK_DIR/gh"

OUT=$(call_sweep orchestrator 2>&1) || true
COUNT=$(echo "$OUT" | jq 'length' 2>/dev/null || echo "?")
if [ "$COUNT" = "0" ]; then
  pass "kill switch → 0 events (no detection runs)"
else
  fail "kill switch → $COUNT event(s) (expected 0 — kill switch not honoured)" "$OUT"
fi
cleanup_workspace
# IMPORTANT: unset the kill switch so subsequent tests aren't suppressed.
unset PROACTIVE_SWEEP_ENABLED

# ============================================================================
# T5: D1 ready_unblocked — fixture with closed blocker fires detection
# ============================================================================
section "T5: D1 ready_unblocked — 1 ready + 1 closed blocker → fires"

setup_workspace
cat > "$WORK_DIR/gh" <<EOF
#!/usr/bin/env bash
JQ_FILTER=""
PREV=""
for arg in "\$@"; do
  if [ "\$PREV" = "--jq" ]; then JQ_FILTER="\$arg"; fi
  PREV="\$arg"
done
case "\$*" in
  *"--label status:ready"*)
    DATA='[{"number":200,"title":"ready story","body":"Blocked by: #201","updatedAt":"$NOW_ISO","labels":[{"name":"status:ready"}]}]'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *"--label status:backlog"*)
    DATA='[]'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *"--label status:in-progress"*)
    DATA='[]'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *"issue view 201"*)
    # Blocker issue: state=closed (D1 happy path)
    DATA='{"number":201,"state":"closed","title":"blocker","stateReason":"completed"}'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *"issue view 200"*)
    DATA='{"number":200,"state":"open","title":"ready story"}'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *)
    echo '[]'
    ;;
esac
EOF
chmod +x "$WORK_DIR/gh"

OUT=$(call_sweep orchestrator 2>&1) || true
DETECTIONS=$(echo "$OUT" | jq -r '[.[].context.detections // [] | .[].detection] | .[]' 2>/dev/null || echo "")
if echo "$DETECTIONS" | grep -q "ready_unblocked"; then
  pass "D1 ready_unblocked fired"
else
  fail "D1 ready_unblocked did NOT fire" "out=$OUT"
fi
cleanup_workspace

# ============================================================================
# T6: D1 silent — open blocker
# ============================================================================
section "T6: D1 silent when blocker is OPEN"

setup_workspace
cat > "$WORK_DIR/gh" <<EOF
#!/usr/bin/env bash
JQ_FILTER=""
PREV=""
for arg in "\$@"; do
  if [ "\$PREV" = "--jq" ]; then JQ_FILTER="\$arg"; fi
  PREV="\$arg"
done
case "\$*" in
  *"--label status:ready"*)
    DATA='[{"number":210,"title":"ready story","body":"Blocked by: #211","updatedAt":"$NOW_ISO","labels":[{"name":"status:ready"}]}]'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *"--label status:backlog"*)
    DATA='[]'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *"--label status:in-progress"*)
    DATA='[]'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *"issue view 211"*)
    DATA='{"number":211,"state":"open","title":"blocker still open"}'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *"issue view 210"*)
    DATA='{"number":210,"state":"open","title":"ready story"}'
    if [ -n "\$JQ_FILTER" ]; then echo "\$DATA" | jq -r "\$JQ_FILTER" 2>/dev/null; else echo "\$DATA"; fi
    ;;
  *)
    echo '[]'
    ;;
esac
EOF
chmod +x "$WORK_DIR/gh"

OUT=$(call_sweep orchestrator 2>&1) || true
DETECTIONS=$(echo "$OUT" | jq -r '[.[].context.detections // [] | .[].detection] | .[]' 2>/dev/null || echo "")
if echo "$DETECTIONS" | grep -q "ready_unblocked"; then
  fail "D1 ready_unblocked fired but blocker is still OPEN" "out=$OUT"
else
  pass "D1 silent (blocker still open)"
fi
cleanup_workspace

# ============================================================================
# T7: D2 orphan_backlog — backlog with no cc:*
# ============================================================================
section "T7: D2 orphan_backlog — backlog with no cc:* → fires"

setup_workspace
mock_gh "$(cat <<EOF
[
  {"number": 300, "title": "orphan", "body": "", "updatedAt": "$NOW_ISO", "labels": [{"name":"status:backlog"}, {"name":"agent:developer"}]}
]
EOF
)"
OUT=$(call_sweep orchestrator 2>&1) || true
DETECTIONS=$(echo "$OUT" | jq -r '[.[].context.detections // [] | .[].detection] | .[]' 2>/dev/null || echo "")
if echo "$DETECTIONS" | grep -q "orphan_backlog"; then
  pass "D2 orphan_backlog fired"
else
  fail "D2 orphan_backlog did NOT fire" "out=$OUT"
fi
cleanup_workspace

# ============================================================================
# T8: D2 silent — backlog WITH cc:* label
# ============================================================================
section "T8: D2 silent — backlog with cc:tester"

setup_workspace
mock_gh "$(cat <<EOF
[
  {"number": 310, "title": "tagged", "body": "", "updatedAt": "$NOW_ISO", "labels": [{"name":"status:backlog"}, {"name":"agent:developer"}, {"name":"cc:tester"}]}
]
EOF
)"
OUT=$(call_sweep orchestrator 2>&1) || true
DETECTIONS=$(echo "$OUT" | jq -r '[.[].context.detections // [] | .[].detection] | .[]' 2>/dev/null || echo "")
if echo "$DETECTIONS" | grep -q "orphan_backlog"; then
  fail "D2 fired on tagged backlog (should be silent)" "out=$OUT"
else
  pass "D2 silent (cc:tester present)"
fi
cleanup_workspace

# ============================================================================
# T9: D3 stalled — in-progress > 4h with no PR
# ============================================================================
section "T9: D3 stalled — in-progress 5h old → fires"

setup_workspace
mock_gh "$(cat <<EOF
[
  {"number": 400, "title": "stalled story", "body": "", "updatedAt": "$ISO_5H_AGO", "labels": [{"name":"status:in-progress"}]}
]
EOF
)"
OUT=$(call_sweep orchestrator 2>&1) || true
DETECTIONS=$(echo "$OUT" | jq -r '[.[].context.detections // [] | .[].detection] | .[]' 2>/dev/null || echo "")
if echo "$DETECTIONS" | grep -q "stalled"; then
  pass "D3 stalled fired (5h old)"
else
  fail "D3 stalled did NOT fire on 5h old in-progress" "out=$OUT"
fi
cleanup_workspace

# ============================================================================
# T10: D3 silent — in-progress < 4h
# ============================================================================
section "T10: D3 silent — in-progress 30min old"

setup_workspace
mock_gh "$(cat <<EOF
[
  {"number": 410, "title": "fresh", "body": "", "updatedAt": "$ISO_30M_AGO", "labels": [{"name":"status:in-progress"}]}
]
EOF
)"
OUT=$(call_sweep orchestrator 2>&1) || true
DETECTIONS=$(echo "$OUT" | jq -r '[.[].context.detections // [] | .[].detection] | .[]' 2>/dev/null || echo "")
if echo "$DETECTIONS" | grep -q "stalled"; then
  fail "D3 fired on 30min old in-progress (should be silent)" "out=$OUT"
else
  pass "D3 silent (30min old)"
fi
cleanup_workspace

# ============================================================================
# T11: D4 wip_overflow — 3 in-progress → fires
# ============================================================================
section "T11: D4 wip_overflow — 3 in-progress → fires"

setup_workspace
mock_gh "$(cat <<EOF
[
  {"number": 500, "title": "ip1", "body": "", "updatedAt": "$NOW_ISO", "labels": [{"name":"status:in-progress"}]},
  {"number": 501, "title": "ip2", "body": "", "updatedAt": "$NOW_ISO", "labels": [{"name":"status:in-progress"}]},
  {"number": 502, "title": "ip3", "body": "", "updatedAt": "$NOW_ISO", "labels": [{"name":"status:in-progress"}]}
]
EOF
)"
OUT=$(call_sweep orchestrator 2>&1) || true
DETECTIONS=$(echo "$OUT" | jq -r '[.[].context.detections // [] | .[].detection] | .[]' 2>/dev/null || echo "")
if echo "$DETECTIONS" | grep -q "wip_overflow"; then
  pass "D4 wip_overflow fired (3 in-progress)"
else
  fail "D4 wip_overflow did NOT fire on 3 in-progress" "out=$OUT"
fi
cleanup_workspace

# ============================================================================
# T12: D4 silent — 2 in-progress
# ============================================================================
section "T12: D4 silent — 2 in-progress"

setup_workspace
mock_gh "$(cat <<EOF
[
  {"number": 510, "title": "ip1", "body": "", "updatedAt": "$NOW_ISO", "labels": [{"name":"status:in-progress"}]},
  {"number": 511, "title": "ip2", "body": "", "updatedAt": "$NOW_ISO", "labels": [{"name":"status:in-progress"}]}
]
EOF
)"
OUT=$(call_sweep orchestrator 2>&1) || true
DETECTIONS=$(echo "$OUT" | jq -r '[.[].context.detections // [] | .[].detection] | .[]' 2>/dev/null || echo "")
if echo "$DETECTIONS" | grep -q "wip_overflow"; then
  fail "D4 fired on 2 in-progress (should be silent — WIP=2 is OK)" "out=$OUT"
else
  pass "D4 silent (2 in-progress)"
fi
cleanup_workspace

# ============================================================================
# T13: Throttle — 2nd call within 5min → no re-fire
# ============================================================================
section "T13: Throttle — 2nd call within 5min → no re-fire"

setup_workspace
# Re-enable the 5min throttle window (tests above set it to 0 to avoid noise).
export PROACTIVE_SWEEP_INTERVAL_SEC=300
# Pre-set the HWM to "now" so the next call is throttled.
"$STATE_SH" set orchestrator proactive_sweep_last_utc "$NOW_ISO" >/dev/null
mock_gh "$(cat <<EOF
[
  {"number": 600, "title": "should-not-fire", "body": "", "updatedAt": "$NOW_ISO", "labels": [{"name":"status:backlog"}, {"name":"agent:developer"}]}
]
EOF
)"
OUT=$(call_sweep orchestrator 2>&1) || true
COUNT=$(echo "$OUT" | jq 'length' 2>/dev/null || echo "?")
if [ "$COUNT" = "0" ]; then
  pass "throttle: 2nd call within 5min → 0 events"
else
  fail "throttle: 2nd call within 5min → $COUNT event(s) (expected 0)" "out=$OUT"
fi
cleanup_workspace
# Restore default for any subsequent test runs in same shell
unset PROACTIVE_SWEEP_INTERVAL_SEC

# ============================================================================
# Summary
# ============================================================================
echo ""
printf "${B}==== proactive-sweep-test summary ====${D}\n"
TOTAL=$((PASS+FAIL))
printf "  TOTAL=%d  PASS=%d  FAIL=%d\n" "$TOTAL" "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
