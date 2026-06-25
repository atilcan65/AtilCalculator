#!/usr/bin/env bash
# d296-peer-poke-helper.sh — regression test for scripts/peer-poke.sh.
#
# Why this test exists
# --------------------
# Issue #296 + docs/peer-poke-spec.md §Deliverable 1: scripts/peer-poke.sh is
# a single-arg wrapper that FORCES notify.sh to be called with the dual-channel
# syntax (`-l info -w -r <role>`). It closes the `notify.sh -l <role>` (Telegram-
# only) footgun by making the wrong form unreachable through this entry point.
#
# Test cases (per docs/peer-poke-spec.md §Deliverable 1 §Acceptance, 3 TCs):
#   T1: peer-poke.sh <role> "<msg>" → notify.sh called with -l info -w -r <role> "<msg>"
#       (argv captured via d-stub mock that replaces notify.sh for the test duration)
#   T2: Missing args (no role, no msg) → exit 2 + usage line to stderr
#   T3: bash -n scripts/peer-poke.sh syntactically valid (lint pre-commit)
#
# Sister test: n/a (this is a standalone d-test; ping.sh sister is d038-ping-wrapper.sh
# but ping.sh and peer-poke.sh have identical wrapper semantics, only the calling
# convention differs at argv-parsing edges).
#
# Exit code: 0 = all pass, 1 = at least one fail.
# Run standalone: bash scripts/tests/d296-peer-poke-helper.sh
#
# Refs: Issue #296, docs/peer-poke-spec.md §Deliverable 1, ADR-0033.
# TDD status (this PR): RED on master — T1/T2/T3 all FAIL because
# scripts/peer-poke.sh does not exist. Turns GREEN once dev lands the
# reference impl from docs/peer-poke-spec.md §Deliverable 1.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PEER_POKE_SH="$REPO_ROOT/scripts/peer-poke.sh"

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
# Setup: replace real notify.sh with a mock that captures argv, restore on EXIT.
# WHY: peer-poke.sh uses absolute path "$SCRIPT_DIR/notify.sh" (not $PATH lookup),
# so a PATH-based mock would be ignored. We must mock the actual file at the path
# peer-poke.sh invokes. Pattern lifted from d038-ping-wrapper.sh.
# ============================================================================
REAL_NOTIFY="$REPO_ROOT/scripts/notify.sh"
BACKUP_NOTIFY="$REAL_NOTIFY.real-backup-$$"
MOCK_LOG="$(mktemp)"

# If real notify.sh doesn't exist yet (unlikely but defensive), skip move.
if [[ -f "$REAL_NOTIFY" ]]; then
  mv "$REAL_NOTIFY" "$BACKUP_NOTIFY"
fi

cat > "$REAL_NOTIFY" <<EOF
#!/usr/bin/env bash
# mock notify.sh — logs full argv to MOCK_LOG, exits 0
echo "\$@" >> "$MOCK_LOG"
exit 0
EOF
chmod +x "$REAL_NOTIFY"

# EXIT trap restores real notify.sh on success OR failure (or kill if bash signals).
trap 'if [[ -f "$BACKUP_NOTIFY" ]]; then mv "$BACKUP_NOTIFY" "$REAL_NOTIFY"; fi; rm -f "$MOCK_LOG"' EXIT

section "Setup: real notify.sh replaced with argv-capturing mock"
pass "mock notify.sh installed at $REAL_NOTIFY; restore trap armed"

# ============================================================================
# T1: peer-poke.sh <role> "<msg>" invokes notify.sh with -l info -w -r <role> "<msg>"
# ============================================================================
section "T1: peer-poke.sh invokes notify.sh with correct dual-channel flags"

# Preflight: script must exist
if [[ ! -x "$PEER_POKE_SH" ]]; then
  fail "scripts/peer-poke.sh missing or not executable at $PEER_POKE_SH" \
       "expected -x flag; Issue #296 §Deliverable 1 + docs/peer-poke-spec.md §Reference impl"
else
  # Test all 5 agent roles + human per docs/peer-poke-spec.md §Reference impl usage list
  for role in orchestrator product-manager architect developer tester; do
    : > "$MOCK_LOG"  # truncate mock log
    "$PEER_POKE_SH" "$role" "test message for $role at $(date +%s)" >/dev/null 2>&1 || true

    # Mock log line: -l info -w -r <role> test message for <role> at <ts>
    if grep -qF -- "-l info -w -r $role" "$MOCK_LOG"; then
      pass "peer-poke.sh invoked notify.sh with -l info -w -r $role"
    else
      fail "peer-poke.sh did not invoke correct flags for $role" \
           "expected '-l info -w -r $role' in mock log; got: $(cat "$MOCK_LOG")"
    fi

    # Anti-pattern check: MUST NOT use broken -l <role> syntax (Issue #320 RCA,
    # the footgun this wrapper closes). If we see `-l <role>` not preceded by
    # `info`, the wrapper is broken.
    if grep -qE -- "^-l $role([^a-z_-]|$)" "$MOCK_LOG"; then
      fail "peer-poke.sh used broken -l $role syntax" \
           "wrapper should always pass -l info (the whole point)"
    else
      pass "peer-poke.sh does NOT use broken -l $role syntax"
    fi
  done
fi

# ============================================================================
# T2: Missing args → exit 2 + usage to stderr
# ============================================================================
section "T2: missing args → exit 2 + usage to stderr"

# Skip if impl missing (T1 already failed)
if [[ ! -x "$PEER_POKE_SH" ]]; then
  fail "scripts/peer-poke.sh missing — cannot test arg-validation" \
       "T2 requires impl; see T1 failure above"
else
  # No args at all
  rc=0
  stderr_capture="$(mktemp)"
  "$PEER_POKE_SH" >/dev/null 2>"$stderr_capture" || rc=$?
  if [[ "$rc" -eq 2 ]]; then
    pass "no-args invocation → exit 2 (usage error)"
  else
    fail "no-args invocation → exit $rc" "expected 2"
  fi
  if grep -qiE "usage|Usage" "$stderr_capture"; then
    pass "no-args invocation printed usage hint to stderr"
  else
    fail "no-args invocation did NOT print usage hint to stderr" \
         "stderr was: $(cat "$stderr_capture")"
  fi
  rm -f "$stderr_capture"

  # Only role, no message
  rc=0
  stderr_capture="$(mktemp)"
  "$PEER_POKE_SH" developer >/dev/null 2>"$stderr_capture" || rc=$?
  if [[ "$rc" -eq 2 ]]; then
    pass "role-only (no msg) invocation → exit 2 (usage error)"
  else
    fail "role-only (no msg) invocation → exit $rc" "expected 2"
  fi
  rm -f "$stderr_capture"
fi

# ============================================================================
# T3: bash -n syntactically valid (lint pre-commit)
# ============================================================================
section "T3: bash -n scripts/peer-poke.sh syntactically valid"

if [[ ! -f "$PEER_POKE_SH" ]]; then
  fail "scripts/peer-poke.sh does not exist — bash -n cannot lint" \
       "T3 requires impl; see T1 failure above"
else
  if bash -n "$PEER_POKE_SH" 2>/dev/null; then
    pass "bash -n $PEER_POKE_SH → exit 0 (syntactically valid)"
  else
    fail "bash -n $PEER_POKE_SH → syntax error" \
         "expected clean parse; check shell quoting, here-docs, getopts"
  fi
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

if [[ "$FAIL" -gt 0 ]]; then
  echo "SOME TESTS FAILED"
  exit 1
fi

echo "ALL TESTS PASSED (d296 GREEN: peer-poke.sh wrapper enforces correct dual-channel syntax)"
exit 0
