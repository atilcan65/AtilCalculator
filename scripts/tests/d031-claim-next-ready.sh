#!/usr/bin/env bash
# d031-claim-next-ready.sh — ADR-0038 §Layer 2 + §Work-Stream Awareness regression test (10 TCs).
#
# Replaces scripts/tests/d031-claim-next-ready-stub.sh (Issue #276 STUB coverage).
# Tests the full impl of scripts/claim-next-ready.sh (Issue #271) via a fake
# `gh` binary that returns canned JSON for list/view calls and records
# edit/comment calls to a log the test can inspect.
#
# 10 TCs (per Issue #520 AC4 / STORY-019 / Sprint 15 P1 #5):
#   TC1: 3 ready items P0/P1/P2 → claim P0 first (priority sort)
#   TC2: 2 ready items same priority, different ages → claim oldest (age tie-break)
#   TC3: ready item with open dep → skip; another without dep → claim (dep parser)
#   TC4: 2 in-progress + 1 ready → exit 3, no claim (WIP cap, pre-work-stream)
#   TC5: 0 ready items → exit 1, no claim (negative)
#   TC6: usage error (no role arg) → exit 2
#   TC7: invalid role → exit 2
#   TC8: audit log written on claim (TC1 follow-up, bonus 3rd TC beyond 5+2)
#   TC9: 2 in-progress same work-stream (PR cluster) + 1 ready standalone → claim succeeds
#        (sister-pattern d058 TC1: PR cluster collapse to 1 work-stream)
#   TC10: 2 in-progress standalone + 1 ready standalone → exit 3, WIP cap (work-stream-aware)
#         (sister-pattern d058 TC5: WIP limit reached, work-stream-aware)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Usage:
#   bash scripts/tests/d031-claim-next-ready.sh           # run via fake-gh factory (CI default)
#   bash scripts/tests/d031-claim-next-ready.sh --self-test  # run inline fixture (no external deps)
#
# Sister-pattern: d058 (work-stream awareness extension), 9 TCs, PR #506 + PR #511.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAIM_SH="$REPO_ROOT/scripts/claim-next-ready.sh"

# --self-test flag (sister-pattern d058): inline fixture mode, no external deps beyond $CLAIM_SH.
# In self-test mode, the test still uses the fake-gh factory pattern (mktemp + tmp/gh), but
# prints a header indicating the mode. CI default = no flag = same behavior.
SELF_TEST=0
for arg in "$@"; do
  case "$arg" in
    --self-test) SELF_TEST=1 ;;
    --help|-h)
      echo "Usage: bash $0 [--self-test]"
      echo "  --self-test  inline fixture mode (sister-pattern d058)"
      exit 0
      ;;
  esac
done
if [ "$SELF_TEST" = "1" ]; then
  echo "d031 --self-test: inline fixture mode (10 TCs, fake-gh factory)"
fi

# --- test framework ---
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

PASS=0; FAIL=0
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""
fi
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# --- fake gh factory ---
# Usage: make_fake_gh <gh_path> <wip_count> <ready_json_or_empty> <dep_open_issue_n> <log_path>
# Writes the ready JSON to a file next to the fake gh, so the fake gh can
# cat it directly (avoids the "[ -n multi-line ]" test-arg-split bug).
make_fake_gh() {
  local gh_path="$1"
  local wip_count="$2"
  local ready_json="$3"
  local dep_open_n="$4"
  local log_path="$5"

  local ready_file="$gh_path.ready.json"
  if [ -n "$ready_json" ] && [ "$ready_json" != "EMPTY" ]; then
    printf '%s' "$ready_json" > "$ready_file"
  else
    : > "$ready_file"  # empty file = empty list
  fi

  cat > "$gh_path" <<EOF
#!/usr/bin/env bash
echo "CALL \$@" >> "$log_path"
case "\$*" in
  *"repo view"*)
    echo '{"nameWithOwner":"test-owner/test-repo"}'
    ;;
  *"status:in-progress"*)
    # Return JSON array (matches `gh issue list --json number` output).
    # Legacy versions of claim-next-ready.sh applied --jq 'length' to this;
    # post-ADR-0038 §Work-Stream Awareness impl parses the JSON array directly.
    case "$wip_count" in
      0) echo '[]' ;;
      1) echo '[{"number":900}]' ;;
      2) echo '[{"number":900},{"number":901}]' ;;
      3) echo '[{"number":900},{"number":901},{"number":902}]' ;;
      *) echo '[]' ;;
    esac
    ;;
  *"status:ready"*)
    if [ -s "$ready_file" ]; then
      cat "$ready_file"
    else
      echo '[]'
    fi
    ;;
  *"issue view "*)
    # Return just the state value (matches what the script's `gh -q .state`
    # would extract; the fake gh ignores -q and returns the raw value).
    n=\$(echo "\$*" | sed -n 's/.*issue view \([0-9]*\).*/\1/p')
    if [ "\$n" = "$dep_open_n" ]; then
      echo "open"
    else
      echo "closed"
    fi
    ;;
  *"issue edit"*)
    echo "EDIT \$@" >> "$log_path"
    ;;
  *"issue comment"*)
    echo "COMMENT \$@" >> "$log_path"
    ;;
  *)
    echo '[]'
    ;;
esac
EOF
  chmod +x "$gh_path"
}

# --- run helper: invoke claim script with fake gh on PATH ---
# Usage: run_claim <role> <wip_count> <ready_json> <dep_open_n> [extra_env...]
# Sets globals: CLAIM_OUT, CLAIM_RC, CLAIM_LOG
run_claim() {
  local role="$1"
  local wip_count="$2"
  local ready_json="$3"
  local dep_open_n="$4"
  shift 4

  # Each test gets a fresh temp dir with a `gh` binary at the top of PATH.
  local fake_bin
  fake_bin="$(mktemp -d "$TEST_TMPDIR/fakebin-XXXXXX")"
  local gh_path="$fake_bin/gh"
  local log_path="$fake_bin/gh-log"
  make_fake_gh "$gh_path" "$wip_count" "$ready_json" "$dep_open_n" "$log_path"

  CLAIM_LOG="$log_path"
  # Debug: verify fake gh is on PATH
  echo "DEBUG: which gh = $(PATH="$fake_bin:$PATH" which gh 2>&1)" >&2
  CLAIM_OUT="$(PATH="$fake_bin:$PATH" GITHUB_REPO="test-owner/test-repo" \
    AUTO_CLAIM_LOG_DIR="$TEST_TMPDIR/logs" \
    "$@" \
    bash "$CLAIM_SH" "$role" 2>&1)"
  CLAIM_RC=$?
}

# Pre-create audit log dir
mkdir -p "$TEST_TMPDIR/logs"

# ============================================================================
section "TC1: 3 ready items P0/P1/P2 → claim P0 first (priority sort)"
# 233 = P0 (newest), 260 = P1, 263 = P2 (oldest). Priority should override age.
ready='[
  {"number":263,"title":"P2 oldest","createdAt":"2026-06-22T08:00:00Z","labels":[{"name":"priority:P2"},{"name":"status:ready"},{"name":"agent:developer"}],"body":""},
  {"number":260,"title":"P1 mid","createdAt":"2026-06-22T09:00:00Z","labels":[{"name":"priority:P1"},{"name":"status:ready"},{"name":"agent:developer"}],"body":""},
  {"number":233,"title":"P0 newest","createdAt":"2026-06-22T10:00:00Z","labels":[{"name":"priority:P0"},{"name":"status:ready"},{"name":"agent:developer"}],"body":""}
]'
run_claim developer 0 "$ready" ""
if [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #233"; then
  pass "P0 (#233) claimed first despite being newest (priority > age)"
elif [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #260"; then
  fail "P1 claimed before P0" "got: $CLAIM_OUT"
elif [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #263"; then
  fail "P2 claimed before P0/P1" "got: $CLAIM_OUT"
else
  fail "unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
fi

# ============================================================================
section "TC2: 2 ready items same priority P1, different ages → claim oldest"
# 100 = older, 101 = newer. Both P1. Age tie-break → #100 first.
ready='[
  {"number":101,"title":"P1 newer","createdAt":"2026-06-22T10:00:00Z","labels":[{"name":"priority:P1"},{"name":"status:ready"},{"name":"agent:developer"}],"body":""},
  {"number":100,"title":"P1 older","createdAt":"2026-06-22T08:00:00Z","labels":[{"name":"priority:P1"},{"name":"status:ready"},{"name":"agent:developer"}],"body":""}
]'
run_claim developer 0 "$ready" ""
if [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #100"; then
  pass "older P1 (#100) claimed first (age tie-break)"
elif [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #101"; then
  fail "newer P1 claimed first" "age tie-break should prefer older; got: $CLAIM_OUT"
else
  fail "unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
fi

# ============================================================================
section "TC3: ready item with open dep → skip; another without dep → claim"
# 50 has 'depends on #225' (open). 51 has no dep. #51 should be claimed.
# Script processes in priority/age order; both P1, #50 older, so #50 is checked
# first → skipped (open dep) → then #51 → claimed.
ready='[
  {"number":50,"title":"with open dep","createdAt":"2026-06-22T08:00:00Z","labels":[{"name":"priority:P1"},{"name":"status:ready"},{"name":"agent:developer"}],"body":"## Problem\nDepends on #225 for the schema."},
  {"number":51,"title":"no dep","createdAt":"2026-06-22T09:00:00Z","labels":[{"name":"priority:P1"},{"name":"status:ready"},{"name":"agent:developer"}],"body":"## Problem\nNo external deps."}
]'
run_claim developer 0 "$ready" "225"
if [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #51"; then
  if grep -q "EDIT .* 50" "$CLAIM_LOG" 2>/dev/null; then
    fail "script tried to claim #50 (should have skipped)" "open dep should trigger try-next"
  else
    pass "open-dep item (#50) skipped, dep-free item (#51) claimed (try-next worked)"
  fi
elif [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #50"; then
  fail "claimed #50 despite open dep on #225" "dep parser missed"
else
  fail "unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
fi

# ============================================================================
section "TC4: 2 in-progress + 1 ready → exit 3, no claim (WIP cap)"
ready='[
  {"number":300,"title":"ready item","createdAt":"2026-06-22T10:00:00Z","labels":[{"name":"priority:P0"},{"name":"status:ready"},{"name":"agent:developer"}],"body":""}
]'
run_claim developer 2 "$ready" ""
if [ "$CLAIM_RC" = "3" ] && echo "$CLAIM_OUT" | grep -q "WIP limit reached"; then
  if grep -q "EDIT" "$CLAIM_LOG" 2>/dev/null; then
    fail "WIP cap hit but script still edited an issue" "should NOT edit when WIP >= limit"
  else
    pass "WIP cap honored (2/2, no edit, exit 3)"
  fi
else
  fail "WIP cap not honored" "expected exit 3 + 'WIP limit reached' message; got rc=$CLAIM_RC out=$CLAIM_OUT"
fi

# ============================================================================
section "TC5: 0 ready items → exit 1, no claim (negative)"
run_claim developer 0 "EMPTY" ""
if [ "$CLAIM_RC" = "1" ] && echo "$CLAIM_OUT" | grep -q "no ready items"; then
  if grep -q "EDIT" "$CLAIM_LOG" 2>/dev/null; then
    fail "no ready items but script edited an issue" "should NOT edit on negative path"
  else
    pass "negative path (exit 1, no edit, informative message)"
  fi
else
  fail "negative path not honored" "expected exit 1 + 'no ready items'; got rc=$CLAIM_RC out=$CLAIM_OUT"
fi

# ============================================================================
section "TC6: usage error (no role arg) → exit 2"
CLAIM_OUT="$(bash "$CLAIM_SH" 2>&1)"
CLAIM_RC=$?
if [ "$CLAIM_RC" = "2" ] && echo "$CLAIM_OUT" | grep -q "usage:"; then
  pass "missing role → exit 2 + usage message"
else
  fail "usage error not handled" "expected exit 2 + 'usage:'; got rc=$CLAIM_RC out=$CLAIM_OUT"
fi

# ============================================================================
section "TC7: invalid role → exit 2"
run_claim invalid-role 0 "EMPTY" ""
if [ "$CLAIM_RC" = "2" ] && echo "$CLAIM_OUT" | grep -q "invalid role"; then
  pass "invalid role → exit 2 + 'invalid role' message"
else
  fail "invalid role not validated" "expected exit 2 + 'invalid role'; got rc=$CLAIM_RC out=$CLAIM_OUT"
fi

# ============================================================================
section "TC8: audit log written on claim (TC1 follow-up)"
# The script writes to $AUTO_CLAIM_LOG_DIR/auto-claim.log (not appended with
# repo name when AUTO_CLAIM_LOG_DIR is set, per impl §repo_name branch).
audit_log="$TEST_TMPDIR/logs/auto-claim.log"
if [ -f "$audit_log" ]; then
  if grep -q "developer claimed #233" "$audit_log"; then
    pass "audit log entry written (ISO-8601 + role + issue + WIP + priority)"
  else
    fail "audit log present but content wrong" "expected: 'developer claimed #233'; got: $(cat "$audit_log")"
  fi
else
  fail "audit log file not created" "expected: $audit_log"
fi

# ============================================================================
section "TC9: 2 in-progress same work-stream (PR cluster) + 1 ready standalone → claim succeeds"
# Work-stream awareness: PR cluster (issues sharing Closes-anchor) collapses to 1 work-stream.
# Sister-pattern: d058 TC1 (PR cluster → WIP=1 per work-stream rule).
# Setup: PR #900 has body "Closes #100\nCloses #101" → issues #100, #101 cluster = 1 work-stream.
# Plus 1 ready standalone (#200, no Closes-anchor). WIP=1, claim #200.
ready='[
  {"number":200,"title":"ready standalone","createdAt":"2026-06-22T10:00:00Z","labels":[{"name":"priority:P1"},{"name":"status:ready"},{"name":"agent:developer"}],"body":"## Problem\nNo Closes-anchor, standalone."}
]'
fake_bin="$(mktemp -d "$TEST_TMPDIR/fakebin-tc9-XXXXXX")"
gh_path="$fake_bin/gh"
log_path="$fake_bin/gh-log"
ready_file="$gh_path.ready.json"
printf '%s' "$ready" > "$ready_file"
cat > "$gh_path" <<'GHEOF'
#!/usr/bin/env bash
echo "CALL $@" >> "$GH_LOG"
case "$*" in
  *"repo view"*) echo '{"nameWithOwner":"test-owner/test-repo"}' ;;
  *"status:in-progress"*) echo '[{"number":100,"title":"cluster A","labels":[{"name":"status:in-progress"},{"name":"agent:developer"}]},{"number":101,"title":"cluster B","labels":[{"name":"status:in-progress"},{"name":"agent:developer"}]}]' ;;
  *"status:ready"*) cat "$0.ready.json" ;;
  *"pr list"*"Closes"*)
    # Cluster detection: return PR #900 with body containing both cluster members.
    echo '[{"number":900,"body":"Closes #100\nCloses #101"}]'
    ;;
  *"issue view "*) echo "closed" ;;
  *"issue edit"*) echo "EDIT $@" >> "$GH_LOG" ;;
  *"issue comment"*) echo "COMMENT $@" >> "$GH_LOG" ;;
  *) echo '[]' ;;
esac
GHEOF
chmod +x "$gh_path"
# Fix: $0.ready.json in heredoc won't expand — use env var
sed -i "s|cat \"\\$0.ready.json\"|cat \"$ready_file\"|" "$gh_path"
GH_LOG="$log_path" CLAIM_LOG="$log_path"
CLAIM_OUT="$(GH_LOG="$log_path" PATH="$fake_bin:$PATH" GITHUB_REPO="test-owner/test-repo" \
  AUTO_CLAIM_LOG_DIR="$TEST_TMPDIR/logs" \
  bash "$CLAIM_SH" developer 2>&1)"
CLAIM_RC=$?
if [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #200"; then
  pass "PR cluster collapsed to 1 work-stream, ready standalone claimed (#200)"
elif [ "$CLAIM_RC" = "3" ]; then
  fail "WIP cap hit despite work-stream collapse" "expected claim success, got WIP cap; out=$CLAIM_OUT"
else
  fail "unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
fi

# ============================================================================
section "TC10: 2 in-progress standalone + 1 ready standalone → exit 3, WIP cap (work-stream-aware)"
# All 3 issues are standalone (no Closes-anchor, no cluster). WIP=2 (2 separate work-streams).
# 1 ready standalone → WIP cap hit, exit 3.
ready='[
  {"number":300,"title":"ready standalone","createdAt":"2026-06-22T10:00:00Z","labels":[{"name":"priority:P0"},{"name":"status:ready"},{"name":"agent:developer"}],"body":"## Problem\nStandalone, no Closes-anchor."}
]'
run_claim developer 2 "$ready" ""
if [ "$CLAIM_RC" = "3" ] && echo "$CLAIM_OUT" | grep -q "WIP limit reached"; then
  if grep -q "EDIT" "$CLAIM_LOG" 2>/dev/null; then
    fail "WIP cap hit but script still edited an issue (work-stream-aware)" "should NOT edit when WIP >= limit"
  else
    pass "WIP cap honored work-stream-aware (2 standalone + 1 ready = 3 work-streams, no edit, exit 3)"
  fi
else
  fail "work-stream-aware WIP cap not honored" "expected exit 3 + 'WIP limit reached'; got rc=$CLAIM_RC out=$CLAIM_OUT"
fi

# ============================================================================
printf "\n${B}==== SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo
  echo "d031 REGRESSION FAILED — claim-next-ready.sh contract violated."
  echo "Fix: ensure claim script honors priority sort, age tie-break, dep parser, WIP cap, negative path."
  exit 1
fi
echo
echo "d031 REGRESSION PASS — claim-next-ready.sh (ADR-0038 §Layer 2) contract honored."
exit 0
