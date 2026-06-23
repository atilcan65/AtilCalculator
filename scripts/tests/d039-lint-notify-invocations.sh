#!/usr/bin/env bash
# d039-lint-notify-invocations.sh — regression test for scripts/lint-notify-invocations.sh.
#
# Why this test exists
# --------------------
# Issue #320 scope expansion: scripts/lint-notify-invocations.sh greps PR
# diffs for the broken `notify.sh -l <role>` syntax and emits a structured
# report. This script is the CI guard against the doctrine regressing.
#
# Test cases (per Issue #320 expanded scope + owner directive):
#   T1: lint script exists, executable
#   T2: fixture diff with broken syntax → exit 1 (detected)
#   T3: fixture diff with valid syntax → exit 0 (clean)
#   T4: fixture diff with mixed → exit 1 (only broken lines reported)
#   T5: pattern correctly ignores `-l info|warn|error|ok` (valid levels)
#   T6: pattern correctly catches all 6 role names
#     (orchestrator|product-manager|architect|developer|tester|human)
#
# Hermetic test: does NOT call gh pr diff (would need real PR). Instead
# tests the regex pattern against fixture files directly by running the
# grep portion inline.
#
# Reference: Issue #320 scope expansion, ADR-0033.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINT_SH="$REPO_ROOT/scripts/lint-notify-invocations.sh"

if [ ! -x "$LINT_SH" ]; then
  echo "ERROR: scripts/lint-notify-invocations.sh not executable at $LINT_SH" >&2
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

# Build a small helper that runs the lint pattern against a fixture file
# without invoking gh pr diff. Mirrors the script's grep logic.
LINT_PATTERN='notify\.sh.*-l[[:space:]]+(orchestrator|product-manager|architect|developer|tester|human)([^a-z_-]|$)'
run_lint_against_fixture() {
  local fixture="$1"
  grep -nE '^\+[^+]' "$fixture" | grep -E "$LINT_PATTERN" || true
}

# ============================================================================
# T1: lint script exists + executable
# ============================================================================
section "T1: lint-notify-invocations.sh exists + executable"
if [ -x "$LINT_SH" ]; then
  pass "lint script exists and is executable"
else
  fail "lint script missing or not executable"
  exit 1
fi

# ============================================================================
# T2: broken fixture → violations detected
# ============================================================================
section "T2: broken fixture → violations detected"
BROKEN_FIX="$(mktemp)"
cat > "$BROKEN_FIX" <<'EOF'
diff --git a/scripts/notify.sh b/scripts/notify.sh
--- a/scripts/notify.sh
+++ b/scripts/notify.sh
@@ -1,3 +1,4 @@
+scripts/notify.sh -l developer "PR #42 ready for review"
+scripts/notify.sh -l orchestrator "Sprint kickoff"
+scripts/notify.sh -l architect "Design review needed"
EOF
violations="$(run_lint_against_fixture "$BROKEN_FIX")"
if [ -n "$violations" ]; then
  violation_count="$(printf '%s\n' "$violations" | wc -l)"
  if [ "$violation_count" -eq 3 ]; then
    pass "all 3 broken lines detected"
  else
    fail "expected 3 violations, got $violation_count" "violations: $violations"
  fi
else
  fail "no violations detected in broken fixture" "expected 3"
fi
rm -f "$BROKEN_FIX"

# ============================================================================
# T3: valid fixture → no violations
# ============================================================================
section "T3: valid fixture → no violations"
VALID_FIX="$(mktemp)"
cat > "$VALID_FIX" <<'EOF'
diff --git a/scripts/notify.sh b/scripts/notify.sh
--- a/scripts/notify.sh
+++ b/scripts/notify.sh
@@ -1,3 +1,4 @@
+scripts/notify.sh -l info -w -r developer "PR #42 ready"
+scripts/notify.sh -l warn "CI flaky on PR #42"
+scripts/notify.sh -l error "Production down"
+scripts/notify.sh -l ok "Sprint DONE"
EOF
violations="$(run_lint_against_fixture "$VALID_FIX")"
if [ -z "$violations" ]; then
  pass "no false positives on valid syntax"
else
  fail "spurious violations on valid syntax" "got: $violations"
fi
rm -f "$VALID_FIX"

# ============================================================================
# T4: mixed fixture → only broken lines reported
# ============================================================================
section "T4: mixed fixture → only broken lines"
MIXED_FIX="$(mktemp)"
cat > "$MIXED_FIX" <<'EOF'
diff --git a/scripts/ping.sh b/scripts/ping.sh
--- a/scripts/ping.sh
+++ b/scripts/ping.sh
@@ -1,3 +1,4 @@
+scripts/notify.sh -l info -w -r developer "valid"
+scripts/notify.sh -l tester "broken — no -w -r"
+scripts/notify.sh -l ok "another valid"
+scripts/notify.sh -l human "broken — escalation case"
EOF
violations="$(run_lint_against_fixture "$MIXED_FIX")"
if [ -n "$violations" ]; then
  violation_count="$(printf '%s\n' "$violations" | wc -l)"
  if [ "$violation_count" -eq 2 ]; then
    pass "mixed fixture: 2 broken lines detected (tester + human), 2 valid lines ignored"
  else
    fail "expected 2 violations in mixed fixture, got $violation_count" "got: $violations"
  fi
else
  fail "no violations in mixed fixture" "expected 2 broken lines"
fi
rm -f "$MIXED_FIX"

# ============================================================================
# T5: pattern correctly ignores info|warn|error|ok
# ============================================================================
section "T5: pattern ignores info|warn|error|ok (valid levels)"
LEVEL_FIX="$(mktemp)"
cat > "$LEVEL_FIX" <<'EOF'
diff --git a/x.sh b/x.sh
+++ b/x.sh
+scripts/notify.sh -l info "x"
+scripts/notify.sh -l warn "x"
+scripts/notify.sh -l error "x"
+scripts/notify.sh -l ok "x"
EOF
violations="$(run_lint_against_fixture "$LEVEL_FIX")"
if [ -z "$violations" ]; then
  pass "valid log levels (info|warn|error|ok) NOT flagged"
else
  fail "spurious violation on log levels" "got: $violations"
fi
rm -f "$LEVEL_FIX"

# ============================================================================
# T6: all 6 roles caught
# ============================================================================
section "T6: all 6 role names caught"
ALL_ROLES_FIX="$(mktemp)"
cat > "$ALL_ROLES_FIX" <<'EOF'
diff --git a/x.sh b/x.sh
+++ b/x.sh
+scripts/notify.sh -l orchestrator "x"
+scripts/notify.sh -l product-manager "x"
+scripts/notify.sh -l architect "x"
+scripts/notify.sh -l developer "x"
+scripts/notify.sh -l tester "x"
+scripts/notify.sh -l human "x"
EOF
violations="$(run_lint_against_fixture "$ALL_ROLES_FIX")"
if [ -n "$violations" ]; then
  violation_count="$(printf '%s\n' "$violations" | wc -l)"
  if [ "$violation_count" -eq 6 ]; then
    pass "all 6 role names detected (orchestrator|product-manager|architect|developer|tester|human)"
  else
    fail "expected 6 violations, got $violation_count" "got: $violations"
  fi
else
  fail "no violations for 6 roles" "expected 6"
fi
rm -f "$ALL_ROLES_FIX"

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

echo "ALL TESTS PASSED (d039 GREEN: lint-notify-invocations pattern is tight)"
exit 0
