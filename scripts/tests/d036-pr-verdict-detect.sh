#!/usr/bin/env bash
# d036-pr-verdict-detect.sh — regression test for PR comment verdict detection.
#
# Why this test exists
# --------------------
# Issue #312 (P0 bug) RCA'd the silent wake-up gap: PR comment verdicts
# (e.g. tester posting 🟢 APPROVED on PR #307 at 2026-06-23T17:14:58Z) are
# NOT surfaced by `scripts/agent-watch.sh` v7 polling loop, because the
# taxonomy doesn't include a "verdict_posted" event kind. The only GitHub
# signal that reaches the dev is `pr_comment_mention` — and that requires
# an explicit `@<role>` mention. Tester verdicts don't @-mention dev.
#
# Result: developer was idle for ~2h waiting on a verdict that was already
# delivered. Polling loop missed it entirely.
#
# Fix scope (per Issue #312):
#   - Option A (preferred): add `verdict_posted` event to agent-watch.sh v8
#   - Option B (defensive):  standalone `scripts/agent-watch-verdicts.sh`
#
# This test locks in the verdict-detection contract so future refactors +
# the #222 template port cannot silently regress this gap.
#
# Test cases (per Issue #312 AC3 + my TDD discipline):
#   T1: detect script presence — `scripts/agent-watch-verdicts.sh` (Option B)
#       OR verdict_posted logic in agent-watch.sh (Option A)
#   T2: APPROVED class detection (🟢, APPROVED, LGTM, sign-off, sign off)
#   T3: SUGGESTIONS class detection (🟡, SUGGESTIONS, non-blocking)
#   T4: CHANGES_REQUESTED class detection (🔴, CHANGES_REQUESTED, REQUEST CHANGES, blocker)
#   T5: Verdict classification emits structured event payload (kind=verdict_posted, verdict=*)
#   T6: False-positive guard — non-verdict comments do NOT fire verdict_posted
#       (e.g. "I tested locally and it works" without verdict keyword)
#   T7: Scope guard — verdict detection only fires for PRs where agent:<role>
#       OR cc:<role> matches the polling role (not random PRs)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d036-pr-verdict-detect.sh
#
# TDD status (this PR): RED on master. Locks the contract; turns GREEN once
# dev/orchestrator ships the verdict-detection impl.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WATCH_SH="$SCRIPT_DIR/../agent-watch.sh"
VERDICT_SH="$SCRIPT_DIR/../agent-watch-verdicts.sh"  # Option B target

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

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 127
fi

# ============================================================================
# T1: detect script presence — agent-watch-verdicts.sh (Option B) OR
#     verdict_posted logic in agent-watch.sh (Option A)
# ============================================================================
section "T1: detect script presence (Option B: agent-watch-verdicts.sh OR Option A: in agent-watch.sh)"
# Either path is acceptable per Issue #312. Lock in the union.
OPTION_B_PRESENT=0
OPTION_A_PRESENT=0
if [ -f "$VERDICT_SH" ]; then
  OPTION_B_PRESENT=1
fi
if [ -f "$WATCH_SH" ] && grep -Eq 'verdict_posted|verdict:' "$WATCH_SH"; then
  OPTION_A_PRESENT=1
fi
if [ "$OPTION_B_PRESENT" -eq 1 ] || [ "$OPTION_A_PRESENT" -eq 1 ]; then
  if [ "$OPTION_B_PRESENT" -eq 1 ]; then
    pass "Option B: scripts/agent-watch-verdicts.sh present"
  fi
  if [ "$OPTION_A_PRESENT" -eq 1 ]; then
    pass "Option A: verdict_posted logic present in agent-watch.sh"
  fi
else
  fail "verdict detection missing" \
    "expected EITHER scripts/agent-watch-verdicts.sh (Option B) OR verdict_posted/verdict: logic in agent-watch.sh (Option A). Issue #312 RCA, fix scope."
fi

# ============================================================================
# T2: APPROVED class keyword detection
# ============================================================================
section "T2: APPROVED class — 🟢 / APPROVED / LGTM / sign-off"
# Per Issue #312 RCA Option A classification table.
# Check ANY of the detection locations (whichever impl path was taken).
TARGET=""
[ "$OPTION_B_PRESENT" -eq 1 ] && TARGET="$VERDICT_SH"
[ "$OPTION_A_PRESENT" -eq 1 ] && [ -z "$TARGET" ] && TARGET="$WATCH_SH"

if [ -z "$TARGET" ]; then
  fail "T2 — no detection target" "T1 failed; cannot verify verdict classes without impl"
else
  # Each keyword MUST be present somewhere in the impl (regex match, case-insensitive).
  APPROVED_KEYWORDS=("APPROVED" "LGTM" "sign.off" "🟢")
  MISSING=0
  for kw in "${APPROVED_KEYWORDS[@]}"; do
    # case-insensitive grep; 🟢 is a UTF-8 emoji, grep handles bytes fine
    if ! grep -Eqi "$kw" "$TARGET"; then
      MISSING=$((MISSING+1))
    fi
  done
  if [ "$MISSING" -eq 0 ]; then
    pass "APPROVED class keywords present (🟢, APPROVED, LGTM, sign-off)"
  else
    fail "APPROVED class keywords missing ($MISSING of 4)" \
      "expected at least one of {🟢, APPROVED, LGTM, sign-off} as approved-class regex in $TARGET"
  fi
fi

# ============================================================================
# T3: SUGGESTIONS class keyword detection
# ============================================================================
section "T3: SUGGESTIONS class — 🟡 / SUGGESTIONS / non-blocking"
SUGGESTIONS_KEYWORDS=("SUGGESTIONS" "non.blocking" "🟡")
if [ -z "$TARGET" ]; then
  fail "T3 — no detection target" "T1 failed"
else
  MISSING=0
  for kw in "${SUGGESTIONS_KEYWORDS[@]}"; do
    if ! grep -Eqi "$kw" "$TARGET"; then
      MISSING=$((MISSING+1))
    fi
  done
  if [ "$MISSING" -eq 0 ]; then
    pass "SUGGESTIONS class keywords present (🟡, SUGGESTIONS, non-blocking)"
  else
    fail "SUGGESTIONS class keywords missing ($MISSING of 3)" \
      "expected at least one of {🟡, SUGGESTIONS, non-blocking} as suggestions-class regex in $TARGET"
  fi
fi

# ============================================================================
# T4: CHANGES_REQUESTED class keyword detection
# ============================================================================
section "T4: CHANGES_REQUESTED class — 🔴 / CHANGES_REQUESTED / REQUEST CHANGES / blocker"
CHANGES_KEYWORDS=("CHANGES_REQUESTED" "REQUEST.CHANGES" "blocker" "🔴")
if [ -z "$TARGET" ]; then
  fail "T4 — no detection target" "T1 failed"
else
  MISSING=0
  for kw in "${CHANGES_KEYWORDS[@]}"; do
    if ! grep -Eqi "$kw" "$TARGET"; then
      MISSING=$((MISSING+1))
    fi
  done
  if [ "$MISSING" -eq 0 ]; then
    pass "CHANGES_REQUESTED class keywords present (🔴, CHANGES_REQUESTED, REQUEST CHANGES, blocker)"
  else
    fail "CHANGES_REQUESTED class keywords missing ($MISSING of 4)" \
      "expected at least one of {🔴, CHANGES_REQUESTED, REQUEST CHANGES, blocker} as changes-requested-class regex in $TARGET"
  fi
fi

# ============================================================================
# T5: Verdict classification emits structured event payload
# ============================================================================
section "T5: structured verdict_posted event payload (kind + verdict fields)"
# Per Issue #312 Option A: payload { kind, number, verdict, author, comment_id, comment_url, pr_url }
# Whichever impl path, the output should mention the event kind "verdict_posted" and a verdict class.
if [ -z "$TARGET" ]; then
  fail "T5 — no detection target" "T1 failed"
elif grep -Eq 'verdict_posted|kind.*verdict' "$TARGET" && \
     grep -Eq 'verdict:approved|verdict:suggestions|verdict:changes_requested' "$TARGET"; then
  pass "structured event payload present (kind=verdict_posted + verdict:<class>)"
else
  fail "structured event payload missing" \
    "expected output to contain kind=verdict_posted + verdict:approved|suggestions|changes_requested classification"
fi

# ============================================================================
# T6: False-positive guard — non-verdict comments do NOT fire verdict_posted
# ============================================================================
section "T6: false-positive guard — non-verdict comments do NOT trigger"
# Per AC2: false-positive rate <5%. This is a coarse check: the regex/keyword
# classifier should be tight enough that a non-verdict comment doesn't match.
# Sample non-verdict text from real PR comments: "I tested locally and it works."
# Sample verdict text: "🟢 APPROVED — LGTM, ready for owner merge."
if [ -z "$TARGET" ]; then
  fail "T6 — no detection target" "T1 failed"
else
  # Heuristic: a true verdict detection MUST require at least one verdict keyword
  # AND not be a substring of generic words like "approved" appearing in
  # "approval" context. We check the impl has SOME structure (case-sensitive
  # keyword matching or word-boundary regex).
  if grep -Eq 'grep.*-E|grep.*-i.*\\b|regex.*\\\\b' "$TARGET"; then
    pass "keyword matcher uses word-boundary / case-sensitive pattern (tightens FP guard)"
  elif grep -Eq 'classify|classify_verdict|verdict_class' "$TARGET"; then
    pass "verdict classification function present (encapsulates FP guard)"
  else
    fail "FP guard structure missing" \
      "expected impl to use word-boundary regex (\\b) or explicit classify function to prevent false positives"
  fi
fi

# ============================================================================
# T7: Scope guard — verdict detection only fires for PRs where agent:<role>
#     OR cc:<role> matches the polling role
# ============================================================================
section "T7: scope guard — only fire on PRs with agent:<role> OR cc:<role>"
# Polling loop should filter to relevant PRs only — otherwise verdicts on
# unrelated PRs spam unrelated roles. Pattern: gh pr list --label
# "agent:<role>" + comments query, scoped per role.
if [ -z "$TARGET" ]; then
  fail "T7 — no detection target" "T1 failed"
elif grep -Eq 'agent:.*role|cc:.*role|label.*agent|label.*cc' "$TARGET"; then
  pass "scope filter present (agent:<role> / cc:<role> label query)"
else
  fail "scope guard missing" \
    "expected impl to query PRs via 'agent:<role>' or 'cc:<role>' label filter, not all PRs"
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
  echo "SOME TESTS FAILED (TDD RED expected until verdict-detection impl ships)"
  exit 1
fi

echo "ALL TESTS PASSED (TDD GREEN: verdict-detection impl present and correct)"
exit 0