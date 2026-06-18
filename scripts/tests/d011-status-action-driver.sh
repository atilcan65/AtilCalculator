#!/usr/bin/env bash
# d011-status-action-driver.sh — regression test for Issue #45 (STATUS block
# as action driver).
#
# Bug-class defended against: "STATUS block is informational only; actionable
# conditions (P0/P1 blockers, idle team, queue staleness) require a human to
# read + react" — silent stall pattern. If the implementer breaks the parser,
# disables the conservative Phase 1 trigger, or the Phase 2 gating, the
# static checks below fire.
#
# This test verifies the parser + derivation logic (the developer-owned
# concern). Wiring into the orchestrator's pickup loop is the orchestrator's
# coordination concern and is covered separately by the orchestrator's own
# smoke tests + the 1-sprint dry-run.
#
# Test cases (per Issue #45 AC + PM conservative rollout):
#   T1: scripts/status-action-driver.sh exists + executable
#   T2: --version returns semver string
#   T3: parse STATUS block with no blockers → 0 derived actions
#   T4: parse STATUS block with P0 blocker → 1 escalation action, target=human
#   T5: parse STATUS block with P1 blocker → 1 escalation action, severity=P1
#   T6: Phase 2 idle-team trigger DISABLED by default in Sprint 1 dry-run
#   T7: Phase 2 idle-team trigger ENABLED with --enable-phase2 flag
#   T8: missing 'STATUS' header → exit code 3, error message
#   T9: empty stdin → exit code 4
#   T10: --dry-run does NOT call notify.sh (verify via PATH-override mock)
#   T11: non-dry-run DOES call notify.sh (verify via mock log)
#   T12: parsed fields surface in JSON output (sprint, active_agents array,
#        blockers_count, blockers_text, heartbeat)
#   T13: audit trail line appended to heartbeat with kind=status_derived
#   T14: malformed blockers count (e.g., "Blockers: several") treated as 0
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d011-status-action-driver.sh
# Integrated:     called from scripts/tests/e2e-pilot.sh as T-d011

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVER_SH="$SCRIPT_DIR/../status-action-driver.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Use an isolated test heartbeat to avoid polluting the real one
TEST_HEARTBEAT="$(mktemp -t d011-heartbeat-XXXXXX.log)"
trap 'rm -f "$TEST_HEARTBEAT" /tmp/d011-status-*.txt /tmp/d011-mock-notify.sh /tmp/d011-mock-notify.log' EXIT

# Colors (TTY-aware)
if [[ -t 1 ]]; then G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else G=""; R=""; B=""; D=""; fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Helper: run driver with isolated heartbeat
run_driver() {
  HEARTBEAT="$TEST_HEARTBEAT" bash "$DRIVER_SH" "$@"
}

# Helper: write a STATUS block fixture (body via stdin, e.g., heredoc)
write_status() {
  local name="$1"
  local body
  body="$(cat)"
  local path="/tmp/d011-status-${name}.txt"
  printf '%s\n' "$body" > "$path"
  printf '%s' "$path"
}

# ============================================================================
# T1: script exists + executable
# ============================================================================
section "T1: status-action-driver.sh exists + executable"

if [ -x "$DRIVER_SH" ]; then
  pass "status-action-driver.sh exists at $DRIVER_SH and is executable"
else
  fail "status-action-driver.sh missing or not executable" "expected at $DRIVER_SH (per issue #45)"
fi

# ============================================================================
# T2: --version
# ============================================================================
section "T2: --version returns semver string"

VERSION_OUT="$(bash "$DRIVER_SH" --version 2>&1 || true)"
if echo "$VERSION_OUT" | grep -Eq 'status-action-driver\.sh [0-9]+\.[0-9]+\.[0-9]+'; then
  pass "--version returns semver: $VERSION_OUT"
else
  fail "--version did not return semver" "got: $VERSION_OUT"
fi

# ============================================================================
# T3: no blockers → 0 derived actions
# ============================================================================
section "T3: no blockers → 0 derived actions"

STATUS_PATH="$(write_status clean <<'EOF'
STATUS
Sprint: 01 (day 5/14)
Active agents: developer, tester
Blockers: 0 clean
Next action: pick up next dispatch
Heartbeat: OK
EOF
)"
OUT="$(run_driver --status-file "$STATUS_PATH" --dry-run)"
ACTIONS="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["actions_derived"])')"
if [ "$ACTIONS" = "0" ]; then
  pass "no blockers → 0 derived actions"
else
  fail "expected 0 actions for no-blockers STATUS" "got actions_derived=$ACTIONS"
fi

# ============================================================================
# T4: P0 blocker → 1 escalation, target=human
# ============================================================================
section "T4: P0 blocker → 1 escalation, target=human"

STATUS_PATH="$(write_status p0 <<'EOF'
STATUS
Sprint: 01 (day 5/14)
Active agents: developer, tester
Blockers: 1 P0 post-merge CI red (issue #55)
Next action: fix PR #56
Heartbeat: WARN
EOF
)"
OUT="$(run_driver --status-file "$STATUS_PATH" --dry-run)"
ACTIONS="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["actions_derived"])')"
KIND="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["derived_actions"][0]["kind"])' 2>/dev/null || echo "")"
TARGET="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["derived_actions"][0]["target"])' 2>/dev/null || echo "")"
if [ "$ACTIONS" = "1" ] && [ "$KIND" = "blocker_escalation" ] && [ "$TARGET" = "human" ]; then
  pass "P0 blocker → 1 escalation, target=human (kind=$KIND)"
else
  fail "expected 1 escalation action to human" "got actions=$ACTIONS kind=$KIND target=$TARGET"
fi

# ============================================================================
# T5: P1 blocker → severity correctly identified as P1
# ============================================================================
section "T5: P1 blocker → severity=P1 in ping_text"

STATUS_PATH="$(write_status p1 <<'EOF'
STATUS
Sprint: 01 (day 5/14)
Active agents: developer, tester, architect
Blockers: 2 P1 stale-cc watchdog (TD-006), other noise
Next action: monitor
Heartbeat: WARN
EOF
)"
OUT="$(run_driver --status-file "$STATUS_PATH" --dry-run)"
PING="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["derived_actions"][0]["ping_text"])')"
if echo "$PING" | grep -q "P1 blocker"; then
  pass "P1 blocker → ping_text contains 'P1 blocker'"
else
  fail "expected 'P1 blocker' in ping_text" "got: $PING"
fi

# ============================================================================
# T6: Phase 2 idle-team DISABLED by default
# ============================================================================
section "T6: Phase 2 idle-team trigger DISABLED by default (Sprint 1 dry-run)"

STATUS_PATH="$(write_status idle <<'EOF'
STATUS
Sprint: 01 (day 5/14)
Active agents: developer, tester, architect, product-manager, orchestrator
Blockers: 0
Next action: standby
Heartbeat: OK
EOF
)"
OUT="$(run_driver --status-file "$STATUS_PATH" --dry-run)"
ACTIONS="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["actions_derived"])')"
PHASE2="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["phase2_enabled"])')"
if [ "$ACTIONS" = "0" ] && [ "$PHASE2" = "False" ]; then
  pass "Phase 2 disabled by default → 0 actions even with 5 agents listed"
else
  fail "expected 0 actions, phase2=False" "got actions=$ACTIONS phase2=$PHASE2"
fi

# ============================================================================
# T7: Phase 2 idle-team ENABLED with --enable-phase2 flag
# ============================================================================
section "T7: Phase 2 idle-team trigger ENABLED with --enable-phase2"

OUT="$(run_driver --status-file "$STATUS_PATH" --dry-run --enable-phase2)"
ACTIONS="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["actions_derived"])')"
PHASE2="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["phase2_enabled"])')"
if [ "$PHASE2" = "True" ]; then
  # Actions may be 0 or 1 depending on whether `gh` finds in-progress issues;
  # the load-bearing claim is that the flag is honoured, not the action count.
  pass "--enable-phase2 sets phase2_enabled=True (actions_derived=$ACTIONS; depends on live gh state)"
else
  fail "expected phase2_enabled=True with --enable-phase2" "got phase2=$PHASE2"
fi

# ============================================================================
# T8: missing STATUS header → exit 3
# ============================================================================
section "T8: missing 'STATUS' header → exit code 3"

STATUS_PATH="$(write_status bad <<'EOF'
This is not a STATUS block
No header
EOF
)"
set +e
run_driver --status-file "$STATUS_PATH" --dry-run >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" = "3" ]; then
  pass "missing STATUS header → exit code 3 (parse error)"
else
  fail "expected exit 3 for missing STATUS header" "got exit=$EXIT_CODE"
fi

# ============================================================================
# T9: empty stdin → exit code 4
# ============================================================================
section "T9: empty stdin → exit code 4"

set +e
: | HEARTBEAT="$TEST_HEARTBEAT" bash "$DRIVER_SH" --from-stdin --dry-run >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" = "4" ]; then
  pass "empty stdin → exit code 4 (read failure)"
else
  fail "expected exit 4 for empty stdin" "got exit=$EXIT_CODE"
fi

# ============================================================================
# T10: --dry-run does NOT call notify.sh
# ============================================================================
section "T10: --dry-run does NOT call notify.sh"

MOCK_NOTIFY="/tmp/d011-mock-notify.sh"
MOCK_LOG="/tmp/d011-mock-notify.log"
cat > "$MOCK_NOTIFY" <<'EOF'
#!/usr/bin/env bash
echo "called:$*" >> "$MOCK_NOTIFY_LOG"
EOF
chmod +x "$MOCK_NOTIFY"
export MOCK_NOTIFY_LOG="$MOCK_LOG"
rm -f "$MOCK_LOG"

# Build a PATH that puts the mock first
ORIG_PATH="$PATH"
MOCK_DIR="$(mktemp -d)"
ln -sf "$MOCK_NOTIFY" "$MOCK_DIR/notify.sh"
export PATH="$MOCK_DIR:$PATH"

# Temporarily point DRIVER_SH at a copy that uses our mock notify
# Easier: just rely on the fact that DRIVER_SH resolves notify.sh relative
# to its own dir. We'll move the real notify.sh aside briefly.
REAL_NOTIFY="$SCRIPT_DIR/../notify.sh"
NOTIFY_BACKUP="$SCRIPT_DIR/../notify.sh.bak.d011"
if [ -f "$REAL_NOTIFY" ]; then
  mv "$REAL_NOTIFY" "$NOTIFY_BACKUP"
fi
ln -sf "$MOCK_NOTIFY" "$REAL_NOTIFY"

STATUS_PATH="$(write_status p0-dry <<'EOF'
STATUS
Sprint: 01 (day 5/14)
Active agents: developer, tester
Blockers: 1 P0 escalation test
Next action: dry run
Heartbeat: OK
EOF
)"

HEARTBEAT="$TEST_HEARTBEAT" bash "$DRIVER_SH" --status-file "$STATUS_PATH" --dry-run >/dev/null

if [ ! -s "$MOCK_LOG" ]; then
  pass "--dry-run does NOT invoke notify.sh (mock log empty)"
else
  fail "--dry-run invoked notify.sh unexpectedly" "mock log: $(cat "$MOCK_LOG")"
fi

# ============================================================================
# T11: non-dry-run DOES call notify.sh
# ============================================================================
section "T11: non-dry-run DOES call notify.sh"

rm -f "$MOCK_LOG"
HEARTBEAT="$TEST_HEARTBEAT" bash "$DRIVER_SH" --status-file "$STATUS_PATH" >/dev/null

if [ -s "$MOCK_LOG" ] && grep -q "called:" "$MOCK_LOG"; then
  pass "non-dry-run invokes notify.sh (mock log present: $(wc -l < "$MOCK_LOG") line(s))"
else
  fail "non-dry-run did NOT invoke notify.sh" "mock log: $(cat "$MOCK_LOG" 2>/dev/null || echo MISSING)"
fi

# Restore real notify.sh
rm -f "$REAL_NOTIFY"
if [ -f "$NOTIFY_BACKUP" ]; then
  mv "$NOTIFY_BACKUP" "$REAL_NOTIFY"
fi
rm -rf "$MOCK_DIR"
export PATH="$ORIG_PATH"
unset MOCK_NOTIFY_LOG

# ============================================================================
# T12: parsed fields surface in JSON output
# ============================================================================
section "T12: parsed fields surface in JSON output"

STATUS_PATH="$(write_status full <<'EOF'
STATUS
Sprint: 01 (day 7/14)
Active agents: developer, tester, architect
Blockers: 1 P1 stale-cc watchdog
Next action: monitor TD-006
Heartbeat: WARN
EOF
)"
OUT="$(run_driver --status-file "$STATUS_PATH" --dry-run)"
SPRINT="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["parsed"]["sprint"])')"
ACTIVE_LEN="$(echo "$OUT" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)["parsed"]["active_agents"]))')"
BCOUNT="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["parsed"]["blockers_count"])')"
BTEXT="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["parsed"]["blockers_text"])')"
HB="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["parsed"]["heartbeat"])')"

if [ "$SPRINT" = "01 (day 7/14)" ] && \
   [ "$ACTIVE_LEN" = "3" ] && \
   [ "$BCOUNT" = "1" ] && \
   [ "$BTEXT" = "P1 stale-cc watchdog" ] && \
   [ "$HB" = "WARN" ]; then
  pass "all parsed fields correct: sprint='$SPRINT' active=$ACTIVE_LEN bcount=$BCOUNT hb='$HB'"
else
  fail "parsed field mismatch" "sprint='$SPRINT' active=$ACTIVE_LEN bcount=$BCOUNT text='$BTEXT' hb='$HB'"
fi

# ============================================================================
# T13: audit trail line appended to heartbeat
# ============================================================================
section "T13: audit trail line with kind=status_derived"

if [ -s "$TEST_HEARTBEAT" ] && grep -q "kind=status_derived" "$TEST_HEARTBEAT"; then
  LINES="$(wc -l < "$TEST_HEARTBEAT")"
  pass "audit trail written (kind=status_derived present, $LINES line(s) total)"
else
  fail "audit trail missing or no kind=status_derived marker" "heartbeat content: $(cat "$TEST_HEARTBEAT" 2>/dev/null | head -3)"
fi

# ============================================================================
# T14: malformed blockers count treated as 0
# ============================================================================
section "T14: malformed blockers count (non-numeric) treated as 0"

STATUS_PATH="$(write_status bad-bcount <<'EOF'
STATUS
Sprint: 01 (day 5/14)
Active agents: developer
Blockers: several issues pending
Next action: monitor
Heartbeat: OK
EOF
)"
OUT="$(run_driver --status-file "$STATUS_PATH" --dry-run)"
BCOUNT="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["parsed"]["blockers_count"])')"
ACTIONS="$(echo "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["actions_derived"])')"
if [ "$BCOUNT" = "0" ] && [ "$ACTIONS" = "0" ]; then
  pass "malformed blockers count → 0, no actions"
else
  fail "expected bcount=0, actions=0 for malformed blockers" "got bcount=$BCOUNT actions=$ACTIONS"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  Passed: ${G}%d${D}\n" "$PASS"
printf "  Failed: ${R}%d${D}\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0