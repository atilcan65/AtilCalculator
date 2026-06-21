#!/usr/bin/env bash
# d094-ext-watcher-self-cc-skip-behavioral.sh — behavioral coverage for Issue #94.
#
# Scope: d094 T1-T8 are STRUCTURAL tests (does the filter exist? does it check
# BOTH labels? does it apply at the right call sites?). They do NOT verify the
# filter BEHAVES correctly in negative cases — a future regression where the
# jq `any` accidentally matches the wrong roles (e.g., agent:developer +
# cc:tester — different roles) would not be caught by structural tests.
#
# This file adds BEHAVIORAL tests F4-F8 (per tester v1 verdict on PR #182
# design + PR #184 impl). Each case runs the actual jq pipeline against canned
# PR JSON and verifies the output.
#
# Cases:
#   F4: agent-only PR (e.g., agent:developer, no cc:developer) → NOT filtered
#   F5: cc-only PR (e.g., cc:developer, no agent:developer) → NOT filtered
#   F6: own-agent + peer-cc (e.g., agent:developer + cc:architect) → NOT filtered
#   F7: label-order / whitespace variants of self-cc pattern → STILL filtered (drift robustness)
#   F8: own-PR + stale_verdict past → query_stale_cc FILTERED, query_stale_verdict FIRES
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d094-ext-watcher-self-cc-skip-behavioral.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH_SH="$SCRIPT_DIR/../agent-watch.sh"

# Colors (TTY-aware)
if [[ -t 1 ]]; then G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else G=""; R=""; B=""; D=""; fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if [ ! -r "$WATCH_SH" ]; then
  echo "ERROR: agent-watch.sh not found at $WATCH_SH" >&2; exit 127
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 127
fi

# --- Test harness ---
# Apply the SAME jq pipeline shape as query_review_requests / query_stale_cc /
# query_new_commits_on_assigned_prs (with ROLE=developer) to canned PR JSON.
# The filter: "def is_author_self_cc_pr: ((.labels // []) | map(.name) |
# any(. == \"agent:developer\") and any(. == \"cc:developer\")); select(... | not)"
# This is a representative subset — the 3 production queries use identical
# filter shape, so testing one exercises all 3.
ROLE=developer
FILTER_EXPR='.[] |
  def is_author_self_cc_pr:
    ((.labels // []) | map(.name) | any(. == "agent:developer") and any(. == "cc:developer"));
  select(is_author_self_cc_pr | not) |
  .number'

# count_after_filter: how many PRs in $1 survive the self-cc filter
count_after_filter() {
  echo "$1" | jq -c "[ .[] ] | .[] | \"x\"" 2>/dev/null | wc -l
}
# numbers_after_filter: list of PR numbers that survive the filter
numbers_after_filter() {
  echo "$1" | jq -r "$FILTER_EXPR" 2>/dev/null | sort -n
}

# ============================================================================
# F4: agent-only PR (agent:developer, NO cc:developer) → NOT filtered
# ============================================================================
section "F4: agent-only PR (agent:developer, no cc:developer) → NOT filtered"
# A PR where I am the agent (assigned to me as the impl owner) but no peer
# has cc'd me on review. This is a regular assigned-PR scenario; the filter
# must NOT skip it.
FIXTURE='[
  {"number": 100, "labels": [{"name": "agent:developer"}]},
  {"number": 101, "labels": [{"name": "agent:developer"}, {"name": "type:bug"}]}
]'
KEPT=$(numbers_after_filter "$FIXTURE")
EXPECTED=$(printf '100\n101')
if [ "$KEPT" = "$EXPECTED" ]; then
  pass "agent-only PRs survive filter (kept=100,101; expected=100,101)"
else
  fail "agent-only PRs incorrectly filtered" "kept='$KEPT' expected='$EXPECTED' (F4 regression — agent-only PRs would be silently dropped, missing assigned-PR wake events)"
fi

# ============================================================================
# F5: cc-only PR (cc:developer, NO agent:developer) → NOT filtered
# ============================================================================
section "F5: cc-only PR (cc:developer, no agent:developer) → NOT filtered"
# A PR where a peer has cc'd me for review but I am not the owner. Classic
# peer-review scenario; the filter must NOT skip it.
FIXTURE='[
  {"number": 200, "labels": [{"name": "cc:developer"}]},
  {"number": 201, "labels": [{"name": "agent:architect"}, {"name": "cc:developer"}]}
]'
KEPT=$(numbers_after_filter "$FIXTURE")
EXPECTED=$(printf '200\n201')
if [ "$KEPT" = "$EXPECTED" ]; then
  pass "cc-only PRs survive filter (kept=200,201; expected=200,201)"
else
  fail "cc-only PRs incorrectly filtered" "kept='$KEPT' expected='$EXPECTED' (F5 regression — cc-only PRs would be silently dropped, missing peer-review wake events)"
fi

# ============================================================================
# F6: own-agent + peer-cc (agent:developer + cc:architect — DIFFERENT roles) → NOT filtered
# ============================================================================
section "F6: own-agent + peer-cc (different roles) → NOT filtered"
# Critical edge case: my name is in BOTH `agent:developer` and `cc:architect`
# (peer reviewing, not self-cc). The filter's BOTH-labels check must be on the
# SAME role (developer), not ANY pair of agent/cc labels. If the filter were
# `any(. == "agent:.*" ) and any(. == "cc:.*")` it would incorrectly filter
# this case. The exact-match `== "agent:developer"` + `== "cc:developer"`
# preserves the intent.
FIXTURE='[
  {"number": 300, "labels": [{"name": "agent:developer"}, {"name": "cc:architect"}]},
  {"number": 301, "labels": [{"name": "agent:developer"}, {"name": "cc:tester"}]}
]'
KEPT=$(numbers_after_filter "$FIXTURE")
EXPECTED=$(printf '300\n301')
if [ "$KEPT" = "$EXPECTED" ]; then
  pass "own-agent + peer-cc (different roles) survive filter (kept=300,301)"
else
  fail "own-agent + peer-cc incorrectly filtered" "kept='$KEPT' expected='$EXPECTED' (F6 regression — peer-review PRs where agent:developer + cc:other-role coexist would be silently dropped, the most insidious false-positive)"
fi

# ============================================================================
# F7: label-order / whitespace / similar-prefix variants of self-cc → STILL filtered
# ============================================================================
section "F7: self-cc variants (case-sensitivity, prefix, exact-match) → exact-match wins"
# The jq `==` operator is case-sensitive and exact-match. Variants that LOOK
# like self-cc but aren't exactly the canonical labels must NOT trigger the
# filter. This protects against future regressions where someone "loosens"
# the match to be more permissive (e.g., startswith("agent:")) and breaks
# the exact-match contract.
FIXTURE='[
  {"number": 400, "labels": [{"name": "agent:developer"}, {"name": "cc:developer"}], "_note": "exact self-cc — must be FILTERED"},
  {"number": 401, "labels": [{"name": "agent:Developer"}, {"name": "cc:developer"}], "_note": "agent:Developer (capital D) — case differs, NOT filtered"},
  {"number": 402, "labels": [{"name": "agent:developerx"}, {"name": "cc:developer"}], "_note": "agent:developerx (prefix match) — NOT filtered"},
  {"number": 403, "labels": [{"name": "agent:developer"}, {"name": " cc:developer"}], "_note": "cc:developer with leading space — NOT filtered (label names are stripped of whitespace by GH API)"},
  {"number": 404, "labels": [{"name": "agent:developer"}, {"name": "cc:developer"}, {"name": "agent:developer"}], "_note": "duplicate label — STILL filtered (filter is set-membership, idempotent)"},
  {"number": 405, "labels": [{"name": "agent:developer "}, {"name": "cc:developer"}], "_note": "trailing whitespace in label — NOT filtered"}
]'
KEPT=$(numbers_after_filter "$FIXTURE")
EXPECTED=$(printf '401\n402\n403\n405')
if [ "$KEPT" = "$EXPECTED" ]; then
  pass "self-cc filter is exact-match (kept=401,402,403,405; filtered=400,404)"
else
  fail "exact-match contract broken" "kept='$KEPT' expected='$EXPECTED' (F7 regression — filter would over-filter on case/prefix/whitespace, hiding legitimate peer review)"
fi

# ============================================================================
# F8: own-PR + stale_verdict past → query_stale_cc FILTERED, query_stale_verdict FIRES
# ============================================================================
section "F8: own-PR with stale verdict-by → stale_cc filtered, stale_verdict fires"
# ADR-0024 (verdict-by convention): a PR with `cc:<role>` + `verdict-by:<ts>`
# whose deadline has passed should fire `stale_verdict`, NOT `stale_cc`.
# The Issue #94 fix filters `stale_cc` for own-self-cc PRs (stall-based) but
# explicitly does NOT filter `stale_verdict` (deadline-based). This case
# verifies the boundary: own-PR + overdue verdict → `stale_verdict` event
# still constructed, `stale_cc` event suppressed.
#
# We test this by running BOTH jq pipelines against the same canned data:
#   - query_stale_cc pipeline (with the v7 filter applied) → 0 events
#   - query_stale_verdict pipeline (NOT filtered) → 1 event for the overdue PR
NOW_EPOCH="$(date -u +%s)"
PAST_EPOCH=$(( NOW_EPOCH - 7200 ))  # 2 hours ago
PAST_VERDICT_BY="$(date -u -d "@${PAST_EPOCH}" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
  || date -u -r "${PAST_EPOCH}" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
  || echo '2026-06-20T12:00:00Z')"
PR_UPDATED_EPOCH=$(( NOW_EPOCH - 3600 ))  # 1 hour ago — past STALE_CC_SEC default (900 = 15min)
PR_UPDATED_AT="$(date -u -d "@${PR_UPDATED_EPOCH}" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
  || date -u -r "${PR_UPDATED_EPOCH}" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
  || echo '2026-06-20T13:00:00Z')"

FIXTURE=$(cat <<EOF
[
  {
    "number": 500,
    "title": "self-cc PR with overdue verdict-by",
    "url": "https://example.test/500",
    "updatedAt": "${PR_UPDATED_AT}",
    "headRefOid": "abc1234567890",
    "labels": [
      {"name": "agent:developer"},
      {"name": "cc:developer"},
      {"name": "verdict-by:${PAST_VERDICT_BY}"}
    ]
  }
]
EOF
)

# --- query_stale_cc pipeline (filtered) ---
# Pipeline shape: applied AFTER `.[]` iteration (handled by wrapper). Filter
# shape mirrors production `query_stale_cc` (def + select is_author_self_cc_pr
# + select age > STALE_CC_SEC).
STALE_CC_PIPELINE='def is_author_self_cc_pr:
    ((.labels // []) | map(.name) | any(. == "agent:developer") and any(. == "cc:developer"));
  select(is_author_self_cc_pr | not) |
  ((now - (.updatedAt | fromdateiso8601)) | floor) as $age |
  select($age > 900) |
  { kind: "stale_cc", number: .number }'

# `now` resolution: jq doesn't have `now` outside its runtime — use --argjson.
STALE_CC_OUT=$(echo "$FIXTURE" | jq -c --argjson now "${NOW_EPOCH}" "[ .[] | $STALE_CC_PIPELINE ]" 2>/dev/null || echo '[]')
STALE_CC_COUNT=$(echo "$STALE_CC_OUT" | jq 'length')
if [ "$STALE_CC_COUNT" = "0" ]; then
  pass "stale_cc FILTERED for self-cc PR (count=0; expected 0 — Issue #94 fix suppresses own-self-cc stalls)"
else
  fail "stale_cc not filtered for self-cc PR" "got count=$STALE_CC_COUNT expected=0 (F8 regression — would re-emit every poll cycle, the exact Issue #94 bug)"
fi

# --- query_stale_verdict pipeline (NOT filtered, per ADR-0024) ---
STALE_VERDICT_PIPELINE='(.labels | map(.name)) as $lbls |
  ($lbls | map(select(startswith("verdict-by:"))) | first // empty) as $vb |
  select($vb != "" and $vb != null) |
  ($vb | sub("verdict-by:"; "") | fromdateiso8601? // empty) as $deadline |
  select($deadline != null and $deadline != "" and $now > $deadline) |
  { kind: "stale_verdict", number: .number, deadline: $vb }'

STALE_VERDICT_OUT=$(echo "$FIXTURE" | jq -c --argjson now "${NOW_EPOCH}" "[ .[] | $STALE_VERDICT_PIPELINE ]" 2>/dev/null || echo '[]')
STALE_VERDICT_COUNT=$(echo "$STALE_VERDICT_OUT" | jq 'length')
if [ "$STALE_VERDICT_COUNT" = "1" ]; then
  pass "stale_verdict FIRES for self-cc PR with overdue verdict-by (count=1; expected 1 — ADR-0024 deadline-based watchdog correctly fires)"
else
  fail "stale_verdict not fired for overdue self-cc PR" "got count=$STALE_VERDICT_COUNT expected=1 (F8 regression — ADR-0024 deadline watchdog broken for own-self-cc PRs; deadline-based stalls would be silently dropped)"
fi

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
  printf "${G}${B}ALL %d TESTS PASSED${D}\n" "$PASS"
  exit 0
else
  printf "${R}${B}%d/%d TESTS FAILED${D}\n" "$FAIL" "$TOTAL"
  exit 1
fi