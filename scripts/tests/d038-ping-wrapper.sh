#!/usr/bin/env bash
# d038-ping-wrapper.sh — regression test for scripts/ping.sh wrapper.
#
# Why this test exists
# --------------------
# Issue #320 RCA + scope expansion: peer-ping syntax (`notify.sh -l <role>`)
# was broken in 22 places across 6 files. The fix is `scripts/ping.sh`, a
# wrapper that ALWAYS invokes notify.sh with the correct dual-channel syntax
# (`-l info -w -r <role>`). The wrapper cannot be misused — it bakes the
# correct flags in.
#
# Test cases (per Issue #320 expanded scope):
#   T1: scripts/ping.sh exists, executable
#   T2: ping.sh developer "msg" invokes notify.sh with -l info -w -r developer
#   T3: ping.sh orchestrator "msg" invokes notify.sh with -l info -w -r orchestrator
#   T4: ping.sh human "msg" invokes notify.sh with -l info -w -r human
#   T5: ping.sh with no args → exit 2 (usage error)
#   T6: ping.sh with invalid role → exit 2
#
# Hermetic test: uses a mock notify.sh on PATH that logs the args it was
# called with, so we can verify the wrapper's invocation shape WITHOUT
# hitting the real Telegram API.
#
# Reference: Issue #320 expanded scope, ADR-0033.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PING_SH="$REPO_ROOT/scripts/ping.sh"

if [ ! -x "$PING_SH" ]; then
  echo "ERROR: scripts/ping.sh not executable at $PING_SH" >&2
  exit 127
fi

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

# ============================================================================
# Setup: replace real notify.sh with a mock for the test duration, restore at end.
# WHY: ping.sh uses absolute path "$SCRIPT_DIR/notify.sh" (not $PATH lookup),
# so a PATH-based mock is ignored. We must mock the actual file at the path
# ping.sh invokes.
# ============================================================================
section "Setup: replace real notify.sh with mock (atomic move + restore trap)"
REAL_NOTIFY="$REPO_ROOT/scripts/notify.sh"
BACKUP_NOTIFY="$REAL_NOTIFY.real-backup-$$"
MOCK_LOG="$(mktemp)"
mv "$REAL_NOTIFY" "$BACKUP_NOTIFY"
cat > "$REAL_NOTIFY" <<EOF
#!/usr/bin/env bash
# mock notify.sh — logs args to MOCK_LOG, exits 0
echo "\$@" >> "$MOCK_LOG"
exit 0
EOF
chmod +x "$REAL_NOTIFY"
# Trap to restore on exit (success or failure)
trap 'mv "$BACKUP_NOTIFY" "$REAL_NOTIFY" && rm -f "$MOCK_LOG"' EXIT
pass "real notify.sh moved to backup, mock installed, restore trap armed"

# ============================================================================
# T1: ping.sh exists + executable
# ============================================================================
section "T1: ping.sh exists + executable"
if [ -x "$PING_SH" ]; then
  pass "scripts/ping.sh exists and is executable"
else
  fail "scripts/ping.sh missing or not executable" "expected -x flag"
  exit 1
fi

# ============================================================================
# T2-T4: ping.sh invokes notify.sh with -l info -w -r <role>
# ============================================================================
for role in developer orchestrator human; do
  section "T: ping.sh $role invokes notify.sh with correct flags"
  : > "$MOCK_LOG"  # truncate
  "$PING_SH" "$role" "test message from $role" >/dev/null 2>&1 || true

  # Mock log should contain: -l info -w -r <role> test message from <role>
  if grep -qF -- "-l info -w -r $role" "$MOCK_LOG"; then
    pass "ping.sh invoked notify.sh with -l info -w -r $role"
  else
    fail "ping.sh did not invoke correct flags for $role" \
      "expected '-l info -w -r $role' in mock log; got: $(cat "$MOCK_LOG")"
  fi

  # Should NOT have used the broken -l <role> pattern (Issue #320 RCA)
  if grep -qE -- "-l $role([^a-z_-]|$)" "$MOCK_LOG"; then
    fail "ping.sh used broken -l $role syntax" "wrapper should always pass -l info"
  else
    pass "ping.sh does NOT use broken -l $role syntax"
  fi
done

# ============================================================================
# T5: ping.sh with no args → exit 2
# ============================================================================
section "T5: ping.sh with no args → exit 2"
rc=0
"$PING_SH" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
  pass "no-args invocation → exit 2 (usage error)"
else
  fail "no-args invocation → exit $rc" "expected 2"
fi

# ============================================================================
# T6: ping.sh with invalid role → exit 2
# ============================================================================
section "T6: ping.sh with invalid role → exit 2"
rc=0
"$PING_SH" bogus-role "msg" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
  pass "invalid-role invocation → exit 2"
else
  fail "invalid-role invocation → exit $rc" "expected 2"
fi

# ============================================================================
# Cleanup
# ============================================================================
# Restore is handled by the EXIT trap (set in Setup section).
# Defensive explicit restore in case trap didn't fire (e.g., set -E off).
if [ -f "$BACKUP_NOTIFY" ]; then
  mv "$BACKUP_NOTIFY" "$REAL_NOTIFY"
fi

# ============================================================================
# SUMMARY
# ============================================================================
section "SUMMARY"
TOTAL=$((PASS + FAIL))
printf "  Total:  %d\n" "$TOTAL"
printf "  Passed: %d\n" "$PASS"
printf "  Failed: %d\n" "$FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "SOME TESTS FAILED"
  exit 1
fi

echo "ALL TESTS PASSED (d038 GREEN: ping.sh wrapper enforces correct syntax)"
exit 0
