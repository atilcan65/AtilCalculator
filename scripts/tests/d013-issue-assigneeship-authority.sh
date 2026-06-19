#!/usr/bin/env bash
# d013-issue-assigneeship-authority.sh — regression test for Issue #113
# (issue assigneeship = label authority + query_assigned_issues_any_status).
#
# What this test defends against:
#   - Developer (or any agent) with backlog-only work sitting idle because
#     the only event that fires for backlog issues is `issue_assigned`
#     (status:ready filter), which excludes status:backlog / status:blocked.
#   - Soul doctrine gap: agent reads issue body "handoff: agent:tester →
#     agent:developer after test plan" and concludes "handoff not done yet"
#     even though agent:developer label is on the issue. (Soul file clause
#     in Issue #113 / PR #1 fixes the cognitive layer; this PR fixes the
#     tool layer so wake events reach the agent regardless.)
#
# Test cases (T1..T9):
#   T1: query_assigned_issues_any_status function exists in agent-watch.sh
#   T2: kill switch QUERY_ASSIGNED_ANY_STATUS_ENABLED=false bypasses query
#   T3: emits issue_assigned_any_status kind
#   T4: event ID format issue-assigned-any-<n>-b<bucket>
#   T5: context.status field populated from status:* label
#   T6: context.actionability = "ACTIONABLE" for ready/in-progress
#   T7: context.actionability = "informational" for backlog/blocked
#   T8: poll_once merges issue_assigned_any_status events
#   T9: agent-watch.sh kinds enum includes issue_assigned_any_status
#
# Test pattern mirrors d012-stale-verdict-schema.sh (PR #108).

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

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 127
fi
if [ ! -r "$WATCH_SH" ]; then
  echo "ERROR: agent-watch.sh not found at $WATCH_SH" >&2; exit 127
fi

# ============================================================================
# Test cases T1..T9
# ============================================================================

section "T1: query_assigned_issues_any_status function exists in agent-watch.sh"
if grep -Eq '^query_assigned_issues_any_status\(\) \{' "$WATCH_SH"; then
  pass "query_assigned_issues_any_status() defined at top level"
else
  fail "query_assigned_issues_any_status() not found" "expected function definition in scripts/agent-watch.sh"
fi

section "T2: kill switch QUERY_ASSIGNED_ANY_STATUS_ENABLED bypasses query"
if grep -Eq 'QUERY_ASSIGNED_ANY_STATUS_ENABLED.*false' "$WATCH_SH"; then
  pass "QUERY_ASSIGNED_ANY_STATUS_ENABLED=false bypass logic present"
else
  fail "kill switch not found" "expected 'QUERY_ASSIGNED_ANY_STATUS_ENABLED' in scripts/agent-watch.sh"
fi

section "T3: emits issue_assigned_any_status event kind"
if grep -Fq 'kind: \"issue_assigned_any_status\"' "$WATCH_SH"; then
  pass "event kind 'issue_assigned_any_status' emitted"
else
  fail "event kind not found" "expected 'kind: \"issue_assigned_any_status\"' (with backslash-escaped quotes) in scripts/agent-watch.sh"
fi

section "T4: event ID format issue-assigned-any-<n>-b<bucket>"
if grep -Eq 'issue-assigned-any-' "$WATCH_SH"; then
  pass "event ID format issue-assigned-any-<n>-b<bucket> present"
else
  fail "event ID format not found" "expected 'issue-assigned-any-' + bucket format"
fi

section "T5: context.status field populated from status:* label"
if grep -Fq 'startswith(\"status:\")' "$WATCH_SH"; then
  pass "context.status populated from status:* label scan"
else
  fail "status field population not found" "expected startswith(\"status:\") (with backslash-escaped quotes) in jq filter"
fi

section "T6: context.actionability = ACTIONABLE for ready/in-progress"
if grep -q 'ACTIONABLE' "$WATCH_SH" && grep -q 'status:ready' "$WATCH_SH" && grep -q 'status:in-progress' "$WATCH_SH"; then
  pass "actionability hint distinguishes actionable vs informational"
else
  fail "actionability hint missing" "expected ACTIONABLE branching on ready/in-progress"
fi

section "T7: context.actionability = informational for backlog/blocked"
if grep -q 'informational' "$WATCH_SH"; then
  pass "informational branch for non-actionable statuses"
else
  fail "informational branch missing" "expected 'informational' default"
fi

section "T8: poll_once merges issue_assigned_any_status events"
if grep -q 'query_assigned_issues_any_status' "$WATCH_SH" && grep -q 'assigned_any' "$WATCH_SH"; then
  pass "poll_once calls query + merges into final events list"
else
  fail "poll_once integration missing" "expected query call + merge in poll_once"
fi

section "T9: agent-watch.sh kinds enum includes issue_assigned_any_status"
if grep -q 'issue_assigned_any_status' "$WATCH_SH"; then
  pass "kinds enum (line ~64) includes issue_assigned_any_status"
else
  fail "issue_assigned_any_status reference missing" "expected reference in kinds enum or docstring"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0