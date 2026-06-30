#!/usr/bin/env bash
# d035-cross-repo-close.sh — regression test for scripts/cross-repo-close.sh
#
# Implements ADR-0040 §d035 regression test plan (6 TUs). Locks in:
#   TU1: Template PR closes AtilCalc issue (normal case)
#   TU2: AtilCalc PR closes template issue (reverse direction)
#   TU3: Multi-PR same issue (idempotency — second call is no-op)
#   TU4: Missing PAT (graceful degradation — warn + PR comment, exit 0)
#   TU5: Rate-limit hit (graceful — warn, no exit 1, manual close comment)
#   TU6: Dry-run mode (lists actions without executing)
#
# Why this test exists
# --------------------
# ADR-0040 §d035 plan mandates regression coverage before the script
# is wired into the CI workflow (caveat 2) and the CROSS_REPO_CLOSE_TOKEN
# PAT is provisioned (caveat 1). Sprint 6 #290 template port depends on
# these 5 caveats being locked in.
#
# Test infrastructure:
#   - Mock `gh` CLI via PATH manipulation (per-TU temp dir + gh stub)
#   - Audit log captured per-TU (isolated file)
#   - All TUs use isolated mock state to avoid cross-contamination
#
# Exit code: 0 = all 6 pass, 1 = at least one fail.
#
# Run: bash scripts/tests/d035-cross-repo-close.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_UNDER_TEST="$SCRIPT_DIR/../cross-repo-close.sh"

PASSED=0
FAILED=0
TEST_NAME=""

cleanup() {
  if [[ -n "${TEST_TMPDIR:-}" && -d "$TEST_TMPDIR" ]]; then
    rm -rf "$TEST_TMPDIR"
  fi
  if [[ -n "${TEST_AUDIT_LOG:-}" && -f "$TEST_AUDIT_LOG" ]]; then
    rm -f "$TEST_AUDIT_LOG"
  fi
}
trap cleanup EXIT

assert_pass() {
  echo "  ✓ $1"
  PASSED=$((PASSED + 1))
}

assert_fail() {
  echo "  ✗ $1"
  FAILED=$((FAILED + 1))
}

assert_grep() {
  # $1 = label, $2 = file, $3 = pattern
  local label="$1" file="$2" pattern="$3"
  if [[ -f "$file" ]] && grep -qE "$pattern" "$file"; then
    assert_pass "$label"
  else
    assert_fail "$label (expected pattern: $pattern in $file)"
  fi
}

assert_not_grep() {
  # $1 = label, $2 = file, $3 = pattern
  local label="$1" file="$2" pattern="$3"
  if [[ -f "$file" ]] && grep -qE "$pattern" "$file"; then
    assert_fail "$label (unexpected pattern: $pattern in $file)"
  else
    assert_pass "$label"
  fi
}

# Mock gh CLI in a fresh temp dir.
# Mock state is set via env vars (MOCK_ISSUE_STATE, MOCK_API_MODE) at
# invocation time, so the mock reads them at runtime (not heredoc-time).
# This avoids heredoc-escape pitfalls and lets one mock serve all TUs.
setup_mock_gh() {
  local issue_state="$1"   # OPEN | CLOSED
  local api_mode="$2"      # ok | rate-limit | fail
  TEST_TMPDIR="$(mktemp -d)"
  mkdir -p "$TEST_TMPDIR/bin"

  cat > "$TEST_TMPDIR/bin/gh" <<'GH_MOCK_EOF'
#!/usr/bin/env bash
# d035 mock gh — mimics output of `gh ... --jq '.foo'` for the
# 4 call sites used by scripts/cross-repo-close.sh
case "$1" in
  issue)
    if [[ "$2" == "view" ]]; then
      # gh issue view --jq '.state' → just the state value
      if [[ "${MOCK_ISSUE_STATE:-OPEN}" == "CLOSED" ]]; then
        echo "CLOSED"
      else
        echo "OPEN"
      fi
    fi
    ;;
  pr)
    if [[ "$2" == "view" ]]; then
      # gh pr view --jq '.body // ""' → just the body string
      printf '%s' "${MOCK_PR_BODY:-}"
    elif [[ "$2" == "comment" ]]; then
      # Capture comments to log file
      if [[ -n "${MOCK_PR_COMMENT_LOG:-}" ]]; then
        echo "[$(date -u +%H:%M:%S)] $*" >> "$MOCK_PR_COMMENT_LOG"
      fi
    fi
    ;;
  api)
    case "${MOCK_API_MODE:-ok}" in
      rate-limit)
        echo "rate limit exceeded" >&2
        exit 1
        ;;
      fail)
        echo "API error" >&2
        exit 1
        ;;
      ok)
        echo '{"state":"closed","number":1}'
        ;;
    esac
    ;;
esac
GH_MOCK_EOF
  chmod +x "$TEST_TMPDIR/bin/gh"
  export PATH="$TEST_TMPDIR/bin:$PATH"
  export MOCK_ISSUE_STATE="$issue_state"
  export MOCK_API_MODE="$api_mode"
}

# =============================================================
echo "=== TU1: Template PR closes AtilCalc issue (normal case) ==="
TEST_NAME="TU1"
TEST_AUDIT_LOG="$(mktemp -u /tmp/cross-repo-close-TU1-XXXXXX.log)"
setup_mock_gh "OPEN" "ok"

CROSS_REPO_CLOSE_TOKEN="mock-pat-123" \
PR_NUMBER="57" \
REPO="atilproject/dev-studio-template" \
MOCK_PR_BODY="Closes atilproject/AtilCalculator#272" \
AUDIT_LOG="$TEST_AUDIT_LOG" \
  bash "$SCRIPT_UNDER_TEST" > /tmp/tu1.stdout 2> /tmp/tu1.stderr
TU1_EXIT=$?

if [[ $TU1_EXIT -eq 0 ]]; then
  assert_pass "TU1: exit code 0"
else
  assert_fail "TU1: exit code (expected 0, got $TU1_EXIT)"
fi
assert_grep "TU1: OK closed atilproject/AtilCalculator#272 logged" "$TEST_AUDIT_LOG" "OK closed atilproject/AtilCalculator#272"
assert_grep "TU1: summary logged" "$TEST_AUDIT_LOG" "summary PR=#57"
assert_grep "TU1: processed=1 in summary" "$TEST_AUDIT_LOG" "processed=1"

# =============================================================
echo "=== TU2: AtilCalc PR closes template issue (reverse direction) ==="
TEST_NAME="TU2"
TEST_AUDIT_LOG="$(mktemp -u /tmp/cross-repo-close-TU2-XXXXXX.log)"
setup_mock_gh "OPEN" "ok"

CROSS_REPO_CLOSE_TOKEN="mock-pat-456" \
PR_NUMBER="300" \
REPO="atilproject/AtilCalculator" \
MOCK_PR_BODY="Fixes atilproject/dev-studio-template#58" \
AUDIT_LOG="$TEST_AUDIT_LOG" \
  bash "$SCRIPT_UNDER_TEST" > /tmp/tu2.stdout 2> /tmp/tu2.stderr
TU2_EXIT=$?

if [[ $TU2_EXIT -eq 0 ]]; then
  assert_pass "TU2: exit code 0"
else
  assert_fail "TU2: exit code (expected 0, got $TU2_EXIT)"
fi
assert_grep "TU2: closed template repo issue logged" "$TEST_AUDIT_LOG" "OK closed atilproject/dev-studio-template#58"
assert_grep "TU2: Fixes keyword preserved" "$TEST_AUDIT_LOG" "Fixes"

# =============================================================
echo "=== TU3: Multi-PR same issue (idempotency) ==="
TEST_NAME="TU3"
TEST_AUDIT_LOG="$(mktemp -u /tmp/cross-repo-close-TU3-XXXXXX.log)"
setup_mock_gh "CLOSED" "ok"  # Issue already closed

CROSS_REPO_CLOSE_TOKEN="mock-pat-789" \
PR_NUMBER="999" \
REPO="atilproject/dev-studio-template" \
MOCK_PR_BODY="Closes atilproject/AtilCalculator#272" \
AUDIT_LOG="$TEST_AUDIT_LOG" \
  bash "$SCRIPT_UNDER_TEST" > /tmp/tu3.stdout 2> /tmp/tu3.stderr
TU3_EXIT=$?

if [[ $TU3_EXIT -eq 0 ]]; then
  assert_pass "TU3: exit code 0"
else
  assert_fail "TU3: exit code (expected 0, got $TU3_EXIT)"
fi
assert_grep "TU3: SKIP already-closed logged" "$TEST_AUDIT_LOG" "SKIP already-closed atilproject/AtilCalculator#272"
assert_not_grep "TU3: no OK closed (idempotent skip)" "$TEST_AUDIT_LOG" "OK closed atilproject/AtilCalculator#272"
assert_grep "TU3: skipped=1 in summary" "$TEST_AUDIT_LOG" "skipped=1"

# =============================================================
echo "=== TU4: Missing PAT (graceful degradation) ==="
TEST_NAME="TU4"
TEST_AUDIT_LOG="$(mktemp -u /tmp/cross-repo-close-TU4-XXXXXX.log)"
TU4_COMMENT_LOG="/tmp/d035-TU4-pr-comments.log"
rm -f "$TU4_COMMENT_LOG"
setup_mock_gh "OPEN" "ok"

# CROSS_REPO_CLOSE_TOKEN NOT SET
unset CROSS_REPO_CLOSE_TOKEN
PR_NUMBER="100" \
REPO="atilproject/AtilCalculator" \
MOCK_PR_BODY="Closes atilproject/dev-studio-template#58" \
AUDIT_LOG="$TEST_AUDIT_LOG" \
MOCK_PR_COMMENT_LOG="$TU4_COMMENT_LOG" \
  bash "$SCRIPT_UNDER_TEST" > /tmp/tu4.stdout 2> /tmp/tu4.stderr
TU4_EXIT=$?

if [[ $TU4_EXIT -eq 0 ]]; then
  assert_pass "TU4: exit code 0 (graceful, NOT 1)"
else
  assert_fail "TU4: exit code (expected 0, got $TU4 — must NEVER block PR merge per caveat 4)"
fi
assert_grep "TU4: WARN CROSS_REPO_CLOSE_TOKEN missing" "$TEST_AUDIT_LOG" "WARN CROSS_REPO_CLOSE_TOKEN missing"
# "Manual close required" text is in PR comment body, captured in MOCK_PR_COMMENT_LOG
assert_grep "TU4: manual close PR comment posted" "$TU4_COMMENT_LOG" "Manual close required"
# Confirm no API call attempted (mock would have logged OK; check absence)
assert_not_grep "TU4: no gh api PATCH attempted" "$TEST_AUDIT_LOG" "OK closed"

# =============================================================
echo "=== TU5: Rate-limit hit (graceful degradation) ==="
TEST_NAME="TU5"
TEST_AUDIT_LOG="$(mktemp -u /tmp/cross-repo-close-TU5-XXXXXX.log)"
setup_mock_gh "OPEN" "rate-limit"

CROSS_REPO_CLOSE_TOKEN="mock-pat-rl" \
PR_NUMBER="200" \
REPO="atilproject/dev-studio-template" \
MOCK_PR_BODY="Closes atilproject/AtilCalculator#272" \
AUDIT_LOG="$TEST_AUDIT_LOG" \
MOCK_PR_COMMENT_LOG="$(mktemp -u /tmp/TU5-comments-XXXXXX.log)" \
  bash "$SCRIPT_UNDER_TEST" > /tmp/tu5.stdout 2> /tmp/tu5.stderr
TU5_EXIT=$?

if [[ $TU5_EXIT -eq 0 ]]; then
  assert_pass "TU5: exit code 0 (rate-limit graceful)"
else
  assert_fail "TU5: exit code (expected 0, got $TU5 — caveat 4 forbids exit 1 on rate-limit)"
fi
assert_grep "TU5: WARN failed-close logged" "$TEST_AUDIT_LOG" "WARN failed-close"
assert_grep "TU5: failed=1 in summary" "$TEST_AUDIT_LOG" "failed=1"

# =============================================================
echo "=== TU6: Dry-run mode (--dry-run) ==="
TEST_NAME="TU6"
TEST_AUDIT_LOG="$(mktemp -u /tmp/cross-repo-close-TU6-XXXXXX.log)"
setup_mock_gh "OPEN" "ok"

# --dry-run flag, NO CROSS_REPO_CLOSE_TOKEN (would normally warn, but dry-run overrides)
PR_NUMBER="57" \
REPO="atilproject/dev-studio-template" \
MOCK_PR_BODY="Closes atilproject/AtilCalculator#272" \
AUDIT_LOG="$TEST_AUDIT_LOG" \
  bash "$SCRIPT_UNDER_TEST" --dry-run > /tmp/tu6.stdout 2> /tmp/tu6.stderr
TU6_EXIT=$?

if [[ $TU6_EXIT -eq 0 ]]; then
  assert_pass "TU6: exit code 0"
else
  assert_fail "TU6: exit code (expected 0, got $TU6)"
fi
assert_grep "TU6: dry-run INFO logged" "$TEST_AUDIT_LOG" "dry-run mode"
assert_grep "TU6: would process listed" "$TEST_AUDIT_LOG" "would process"
# CRITICAL: no gh api PATCH call (script would have logged OK; check absence)
assert_not_grep "TU6: NO API call (dry-run)" "$TEST_AUDIT_LOG" "OK closed"
assert_not_grep "TU6: NO PAT warning (dry-run skips PAT check)" "$TEST_AUDIT_LOG" "CROSS_REPO_CLOSE_TOKEN missing"

# =============================================================
echo
echo "=== d035 summary ==="
echo "  PASSED: $PASSED"
echo "  FAILED: $FAILED"
if [[ $FAILED -gt 0 ]]; then
  echo "  STATUS: ❌ FAIL"
  exit 1
fi
echo "  STATUS: ✅ PASS (all 6 TUs)"
exit 0
