#!/usr/bin/env bash
# d094-watcher-self-cc-skip.sh — regression test for Issue #94
# (Watcher loop: stale_cc on own-PR self-cc emits every poll cycle)
#
# Bug class defended against (Issue #94 root cause):
#   - The watcher emits `pr_review_requested`, `pr_new_commit`, and `stale_cc`
#     events every poll cycle for PRs where `agent:<role> == cc:<role>`
#     (the author-self-cc pattern, an intentional watchdog anchor per TD-001
#     Option A + ADR-0021 §peer cc on own docs PR).
#   - The dedup chain in `agent-state.sh` suppresses re-PROCESSING of the same
#     event ID, but the watcher continues to EMIT the same event IDs every
#     cycle. After `processed_event_ids` trim rolls over (~200 events, ~hours
#     of activity), the same event IDs re-fire, causing the agent's autonomy
#     loop to never idle.
#
# Fix (architect design PR #182 + this impl PR):
#   - Add `is_author_self_cc_pr()` helper function in `scripts/agent-watch.sh`
#     that takes a JSON label array and returns true if BOTH `agent:<role>`
#     AND `cc:<role>` are present (the author-self-cc pattern).
#   - Apply the filter at the top of the `.[]` pipeline in:
#     (a) `query_review_requests`      → `pr_review_requested` events
#     (b) `query_new_commits_on_assigned_prs` → `pr_new_commit` events
#     (c) `query_stale_cc`             → `stale_cc` events
#   - Increment counter `agent_watch_own_self_cc_filtered_total` per skip
#     (one counter, one function — DRY, observability hook).
#   - DO NOT touch `query_stale_verdict` or `query_missing_expectation`
#     (ADR-0024 — deadline-based, not stall-based; correct to fire on own-PRs
#     because the verdict-by deadline is independent of the cc-stall).
#
# Test cases (T1..T8) — verify the impl is in place:
#   T1: `is_author_self_cc_pr()` helper function defined in agent-watch.sh
#   T2: helper uses jq `select` for BOTH `agent:${ROLE}` AND `cc:${ROLE}`
#   T3: query_review_requests uses the filter
#   T4: query_new_commits_on_assigned_prs uses the filter
#   T5: query_stale_cc uses the filter
#   T6: counter `agent_watch_own_self_cc_filtered_total` declared/incremented
#   T7: header comment documents Issue #94 + the skip rule
#   T8: filter is DRY (one function called from all 3 sites, not copy-pasted)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d094-watcher-self-cc-skip.sh

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

# Helper: extract a function body from agent-watch.sh by name + closing brace.
# Used to verify "function X is defined" + "function body has pattern Y".
extract_function_body() {
  local fn_name="$1"
  awk -v fn="$fn_name" '
    $0 ~ "^" fn "\\(\\)" { in_fn=1; brace=0 }
    in_fn { print; for (i=1; i<=length($0); i++) { c=substr($0,i,1); if (c=="{") brace++; if (c=="}") brace--; if (brace==0 && c=="}") { in_fn=0; exit } } }
  ' "$WATCH_SH"
}

# ============================================================================
# Test cases T1..T8
# ============================================================================

section "T1: is_author_self_cc_pr() helper function defined (Issue #94 fix)"
# Pattern: a top-level bash function named `is_author_self_cc_pr` must exist
# in agent-watch.sh. Per design doc PR #182 §Implementation contract + my dev
# verdict S1 (vote for `is_author_self_cc_pr` to match TD-001 Option A +
# ADR-0021 §peer cc on own docs PR doctrine terminology).
if grep -Eq '^is_author_self_cc_pr\(\)' "$WATCH_SH"; then
  pass "is_author_self_cc_pr() function defined"
else
  fail "is_author_self_cc_pr() not defined" "expected top-level function 'is_author_self_cc_pr() { ... }' in agent-watch.sh (Issue #94 fix — author-self-cc filter helper)"
fi

section "T2: helper uses jq to check BOTH 'agent:\${ROLE}' AND 'cc:\${ROLE}'"
# Pattern: the function body must check for BOTH labels via jq. Either form
# is acceptable: `any(.[]?; . == "X" and . == "Y")` (boolean) or
# `select(any(...))` (filter). Without both checks, the filter is incorrect
# (e.g., would skip on agent-only PRs, which are legitimate peer work).
fn_body="$(extract_function_body 'is_author_self_cc_pr')"
if [ -n "$fn_body" ] && echo "$fn_body" | grep -Eq 'agent:\$\{?ROLE\}?' \
   && echo "$fn_body" | grep -Eq 'cc:\$\{?ROLE\}?' \
   && echo "$fn_body" | grep -Eq 'select|any'; then
  pass "helper checks both 'agent:\${ROLE}' AND 'cc:\${ROLE}' via jq (any/select)"
else
  fail "helper missing dual-label check" "expected 'is_author_self_cc_pr()' body to use jq 'any' OR 'select' with BOTH 'agent:\${ROLE}' and 'cc:\${ROLE}' references (Issue #94 — author-self-cc is BOTH labels, not just one)"
fi

section "T3: query_review_requests uses the filter (skip own-self-cc PRs)"
# Pattern: the jq pipeline in query_review_requests must reference the helper
# (or its filter shape) — i.e., contain 'is_author_self_cc_pr' OR a select()
# that excludes BOTH labels. Either is acceptable per design (DRY via helper
# is preferred; inline select is the fallback).
query_body="$(extract_function_body 'query_review_requests')"
if [ -n "$query_body" ] && echo "$query_body" | grep -Eq 'is_author_self_cc_pr|select.*agent:.*cc:'; then
  pass "query_review_requests uses the filter (helper call or inline select)"
else
  fail "query_review_requests missing filter" "expected query_review_requests jq pipeline to call 'is_author_self_cc_pr' OR contain a select() excluding own-self-cc PRs (Issue #94 — T3 of 3 query sites)"
fi

section "T4: query_new_commits_on_assigned_prs uses the filter (skip own-self-cc PRs)"
# Pattern: same as T3 but for the commits query.
query_body="$(extract_function_body 'query_new_commits_on_assigned_prs')"
if [ -n "$query_body" ] && echo "$query_body" | grep -Eq 'is_author_self_cc_pr|select.*agent:.*cc:'; then
  pass "query_new_commits_on_assigned_prs uses the filter"
else
  fail "query_new_commits_on_assigned_prs missing filter" "expected query_new_commits_on_assigned_prs jq pipeline to call 'is_author_self_cc_pr' OR contain a select() excluding own-self-cc PRs (Issue #94 — T4 of 3 query sites)"
fi

section "T5: query_stale_cc uses the filter (skip own-self-cc PRs)"
# Pattern: same as T3/T4 but for the stale_cc query.
query_body="$(extract_function_body 'query_stale_cc')"
if [ -n "$query_body" ] && echo "$query_body" | grep -Eq 'is_author_self_cc_pr|select.*agent:.*cc:'; then
  pass "query_stale_cc uses the filter"
else
  fail "query_stale_cc missing filter" "expected query_stale_cc jq pipeline to call 'is_author_self_cc_pr' OR contain a select() excluding own-self-cc PRs (Issue #94 — T5 of 3 query sites)"
fi

section "T6: counter 'agent_watch_own_self_cc_filtered_total' declared/incremented"
# Pattern: per architect's design PR #182 §Observability + my dev verdict S2
# (wire counter to components), a counter for filtered events must exist. The
# counter name is fixed (architect-specified) so the dashboard / observability
# tooling can rely on it.
if grep -Eq 'agent_watch_own_self_cc_filtered_total' "$WATCH_SH"; then
  pass "counter 'agent_watch_own_self_cc_filtered_total' present in agent-watch.sh"
else
  fail "counter missing" "expected reference to 'agent_watch_own_self_cc_filtered_total' in agent-watch.sh (Issue #94 design §Observability — observability hook for filter, increment per skip)"
fi

section "T7: header comment documents Issue #94 + the skip rule"
# Pattern: the file header comment block must mention Issue #94 (this fix
# closes it) and the skip rule (so future readers understand the watcher's
# self-cc-exclusion behavior without spelunking the code).
if grep -Eq 'Issue #94|Issue-94|issue 94|issue-94' "$WATCH_SH" \
   && grep -Eqi 'self.cc.skip|self.cc.skip rule|self.cc.exclusion|own.self.cc|author.self.cc' "$WATCH_SH"; then
  pass "header documents Issue #94 + self-cc skip rule"
else
  fail "header missing Issue #94 / skip rule doc" "expected header to mention BOTH 'Issue #94' AND one of 'self-cc skip', 'self-cc exclusion', 'own-self-cc', 'author-self-cc' in agent-watch.sh"
fi

section "T8: filter is DRY (one helper called from all 3 sites)"
# Pattern: each of the 3 query sites (T3/T4/T5) must call the SAME helper
# `is_author_self_cc_pr`, not 3 separate inline selects. Verifying via 3
# grep counts: should be 1 function definition + 3 call sites = 4 occurrences
# of the helper name.
helper_count="$(grep -c 'is_author_self_cc_pr' "$WATCH_SH" || true)"
# Expected: 1 function definition line + 3 call sites (one per query) = 4
if [ "$helper_count" -ge 4 ]; then
  pass "filter is DRY (helper defined + called from 3 sites, count=$helper_count)"
else
  fail "filter not DRY" "expected >=4 occurrences of 'is_author_self_cc_pr' in agent-watch.sh (1 function def + 3 call sites). Got: $helper_count. Issue #94 design calls for a single DRY helper, not 3 inline selects."
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
TOTAL=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
  printf "${G}${B}ALL %d TESTS PASSED${D}\n" "$PASS"
  exit 0
else
  printf "${R}${B}%d/%d TESTS FAILED${D}\n" "$FAIL" "$TOTAL"
  exit 1
fi
