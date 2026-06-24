#!/usr/bin/env bash
# d037-notify-deprecation.sh — regression test for Issue #320 deprecation warning.
#
# Why this test exists
# --------------------
# Issue #320 RCA found broken `notify.sh -l <role>` syntax in 22 places
# across 6 files. The `-l <role>` form silently falls through to the default
# 🤖 emoji and Telegram-only delivery — the target agent's tmux pane NEVER
# wakes. Sprint 3+ peer-pings have been silently broken for months.
#
# Fix scope: scripts/notify.sh must print a stderr WARNING + usage hint
# when -l is passed a role-like string (orchestrator|product-manager|
# architect|developer|tester|human). Exit code unchanged (still sends
# message — backward compat per Issue #320 AC2).
#
# Test cases (per Issue #320 AC):
#   T1: broken -l developer → stderr WARNING printed (5 lines: warning + hint + doc ref + compat note)
#   T2: broken -l orchestrator → stderr WARNING printed
#   T3: broken -l human → stderr WARNING printed (escalation case)
#   T4: valid -l info → no WARNING printed
#   T5: valid -l warn → no WARNING printed
#   T6: valid -l error → no WARNING printed
#   T7: valid -l ok → no WARNING printed
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Hermetic test: Telegram API will fail (no real env), but stderr still
# contains the WARNING line before the failure. We `|| true` to capture
# stderr regardless of exit code.
#
# Reference: Issue #320, ADR-0033, CLAUDE.md §Auto-Ping Hard-Rule.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NOTIFY_SH="$REPO_ROOT/scripts/notify.sh"

if [ ! -x "$NOTIFY_SH" ]; then
  echo "ERROR: scripts/notify.sh not executable at $NOTIFY_SH" >&2
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
# T1-T3: broken -l <role> prints WARNING
# ============================================================================
for role in developer orchestrator human; do
  section "T: broken -l $role → WARNING printed"
  out_file="$(mktemp)"
  err_file="$(mktemp)"
  # Telegram API will fail (no real env), but stderr still has WARNING.
  # We use || true because notify.sh exits 1 on Telegram failure.
  "$NOTIFY_SH" -l "$role" "test message" >"$out_file" 2>"$err_file" || true

  if grep -qF "WARNING: -l $role looks like a ROLE" "$err_file"; then
    pass "WARNING line present for -l $role"
  else
    fail "WARNING missing for -l $role" "expected 'WARNING: -l $role looks like a ROLE' in stderr; got: $(cat "$err_file")"
  fi

  # Hint references CLAUDE.md (per AC3)
  if grep -qF "CLAUDE.md §Auto-Ping Hard-Rule" "$err_file"; then
    pass "Hint references CLAUDE.md §Auto-Ping Hard-Rule"
  else
    fail "Hint missing CLAUDE.md reference" "expected 'CLAUDE.md §Auto-Ping Hard-Rule' in stderr"
  fi

  # Hint shows the correct fix syntax (per AC1: must reference -l info -w -r <role>)
  if grep -qF "notify.sh -l info -w -r $role" "$err_file"; then
    pass "Hint shows correct syntax (-l info -w -r $role)"
  else
    fail "Hint missing correct syntax" "expected 'notify.sh -l info -w -r $role' in hint"
  fi

  # Backward compat note (per AC2)
  if grep -qF "backward compat" "$err_file"; then
    pass "Backward compat note present (message still sent)"
  else
    fail "Backward compat note missing" "expected 'backward compat' note in stderr"
  fi

  rm -f "$out_file" "$err_file"
done

# ============================================================================
# T4-T7: valid -l <level> → NO WARNING
# ============================================================================
for level in info warn error ok; do
  section "T: valid -l $level → NO WARNING"
  out_file="$(mktemp)"
  err_file="$(mktemp)"
  "$NOTIFY_SH" -l "$level" "test message" >"$out_file" 2>"$err_file" || true

  if grep -qF "WARNING: -l $level looks like a ROLE" "$err_file"; then
    fail "spurious WARNING for valid -l $level" "should NOT warn on info|warn|error|ok"
  else
    pass "no WARNING for valid -l $level"
  fi
  rm -f "$out_file" "$err_file"
done

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

echo "ALL TESTS PASSED (d037 GREEN: deprecation warning fires on broken -l <role>)"
exit 0
