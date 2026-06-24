#!/usr/bin/env bash
# d040-v8-verdict-posted-native.sh — regression test for Issue #326 Phase 2 v8 native
# verdict_posted kind in scripts/agent-watch.sh.
#
# Why this test exists
# --------------------
# Issue #312 RCA closed Phase 0 (PR #322 = standalone `agent-watch-verdicts.sh`,
# d036). Issue #326 covers Phase 2: the `verdict_posted` kind is now NATIVE
# in `scripts/agent-watch.sh` (v7 → v8 taxonomy bump), eliminating the need
# for the standalone script. ADR-0041 §Decision + Issue #326 ACs define the
# contract for this native kind:
#
#   AC-1 (OBS-2): Full scope guard — agent:<role> OR cc:<role> OR verdict-by:<ts>
#                 (not Phase 0's narrow `agent:<role>` only — that missed the
#                 RCA pattern: verdict on a PR that has cc:<role> but not agent:<role>).
#   AC-2 (OBS-3): Self-cc skip per Issue #94 — author does NOT wake on their
#                 own PR's incoming verdict. Sister to d036 T7 / Issue #94.
#   AC-3 (OBS-4): Emit `context.keyword_matched` for debug (which regex hit).
#   AC-4: v8 taxonomy registration — 12th kind (was 11 at v7).
#   AC-5: Event payload schema match per ADR-0041 §Decision verbatim:
#         {kind, number, verdict, author, comment_id, comment_url, pr_url,
#          context: {verdict_class, source, keyword_matched}}.
#
# Test cases (TDD red → green):
#   T1: query_verdict_posted() function exists in scripts/agent-watch.sh
#   T2: Header documents v8 + verdict_posted kind (taxonomy bump)
#   T3: Dispatch includes verdict_posted (merged list has 12 queries, was 11)
#   T4: Scope guard uses OR (agent:<role> OR cc:<role>), not agent-only
#   T5: Self-cc skip per Issue #94 (is_author_self_cc_pr filter applied)
#   T6: keyword_matched field emitted in context (AC-3)
#   T7: All 3 verdict classes detected (approved / suggestions / changes_requested)
#   T8: Event schema match — kind, number, verdict, author, comment_id,
#       comment_url, pr_url all present in jq emit template
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Hermetic test: pure file inspection (grep + jq parse). Does NOT call
# `gh` or hit the network. The Phase 2 v8 work is verified via shell contract
# matching, same pattern as d036/d037/d038/d039.
#
# Reference: Issue #326, Issue #312 RCA, ADR-0041 §Decision, Issue #94
# (self-cc skip), PR #322 (Phase 0 standalone), PR #313 (d036 regression).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WATCH_SH="$REPO_ROOT/scripts/agent-watch.sh"

if [ ! -f "$WATCH_SH" ]; then
  echo "ERROR: scripts/agent-watch.sh not found at $WATCH_SH" >&2
  exit 127
fi

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; D=""; B=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# ============================================================================
# T1: query_verdict_posted() function defined
# ============================================================================
section "T1: query_verdict_posted() function present"
if grep -Eq '^query_verdict_posted\(\) \{' "$WATCH_SH"; then
  pass "query_verdict_posted() defined in agent-watch.sh"
else
  fail "query_verdict_posted() not found" \
    "expected shell function 'query_verdict_posted() {' at line start (mirrors query_pr_mentions pattern)"
fi

# ============================================================================
# T2: Header documents v8 + verdict_posted kind
# ============================================================================
section "T2: header docs — Event Model v8 + verdict_posted"
if grep -Eq 'Event Model v8' "$WATCH_SH" && grep -Eq 'verdict_posted' "$WATCH_SH"; then
  pass "header mentions v8 Event Model + verdict_posted"
else
  fail "v8 / verdict_posted not in header docs" \
    "expected 'Event Model v8' and 'verdict_posted' to appear in the file header comment block"
fi

# ============================================================================
# T3: Dispatch merged-list includes verdict_posted (12 queries, was 11)
# ============================================================================
section "T3: dispatch merges 12 queries (v8 bump)"
# The merged list is the <(echo \"$...\") chain in poll_once. Each query var
# must appear in the merge AND be assigned earlier. Count named vars in the
# merge. The v7 dispatch has 11; v8 should add verdict_posted = 12.
ASSIGN_VARS="$(grep -E '^[[:space:]]+(assigned|reviews|commits|mentions|stale|stale_verdict|missing_expectation|board|pr_merged|pr_labeled|issue_mentions|periodic_scan|proactive_sweep|assigned_any|is_alive_event|wip_idle|verdict_posted)=' "$WATCH_SH" | grep -v '^[[:space:]]*#' | sed -E 's/^[[:space:]]+([a-z_]+)=.*/\1/' | sort -u)"
if printf '%s\n' "$ASSIGN_VARS" | grep -qx "verdict_posted"; then
  pass "verdict_posted variable assigned in poll_once dispatch"
else
  fail "verdict_posted variable not assigned" \
    "expected 'verdict_posted=\"...\$(query_verdict_posted ...)\"' line in poll_once"
fi
# Count should be >= 12 (verdict_posted is added on top of v7's 11 core queries,
# is_alive_event + wake_nudge don't merge; wip_idle conditional)
COUNT="$(printf '%s\n' "$ASSIGN_VARS" | wc -l | tr -d '[:space:]')"
if [ "${COUNT:-0}" -ge 12 ]; then
  pass "dispatch assigns ≥12 query vars (got $COUNT)"
else
  fail "dispatch has fewer than 12 query vars (got $COUNT)" \
    "expected ≥12 — v8 bump adds verdict_posted to the v7 core 11 (assigned, reviews, commits, mentions, stale, stale_verdict, missing_expectation, board, pr_merged, pr_labeled, issue_mentions)"
fi

# ============================================================================
# T4: Scope guard uses OR (agent OR cc), not agent-only
# ============================================================================
section "T4: scope guard — agent:<role> OR cc:<role> (AC-1)"
# Phase 0 narrow: gh pr list --label agent:${ROLE}
# Phase 2 required: agent OR cc — at minimum, the query must reference both
# labels, e.g., via separate gh pr list calls merged with jq, or via a label
# OR-pattern. Acceptable patterns:
#   - Two gh pr list calls (--label agent:X + --label cc:X) with jq union
#   - One call with --label "agent:X,cc:X" + jq filter
#   - One call followed by jq filter matching either label
# We require the query body to reference BOTH "agent:" and "cc:" with ${ROLE}.
if grep -E '^query_verdict_posted\(\)' "$WATCH_SH" >/dev/null 2>&1; then
  # Extract the function body (until the next blank line or next ^function)
  FN_BODY="$(awk '/^query_verdict_posted\(\) \{/{flag=1; next} flag && /^[^ \t]/{exit} flag' "$WATCH_SH")"
  if printf '%s' "$FN_BODY" | grep -qE 'agent:.*\$\{?ROLE\}?' && \
     printf '%s' "$FN_BODY" | grep -qE 'cc:.*\$\{?ROLE\}?'; then
    pass "function body references BOTH agent:<role> and cc:<role> (scope guard OR)"
  else
    fail "function body missing one of agent/cc scope" \
      "expected query_verdict_posted body to reference both 'agent:\${ROLE}' and 'cc:\${ROLE}' (AC-1 OBS-2)"
  fi
else
  fail "T4 — query_verdict_posted() not found, cannot inspect body"
fi

# ============================================================================
# T5: Self-cc skip per Issue #94 (is_author_self_cc_pr filter)
# ============================================================================
section "T5: self-cc skip per Issue #94 (AC-2)"
if grep -E '^query_verdict_posted\(\)' "$WATCH_SH" >/dev/null 2>&1; then
  FN_BODY="$(awk '/^query_verdict_posted\(\) \{/{flag=1; next} flag && /^[^ \t]/{exit} flag' "$WATCH_SH")"
  if printf '%s' "$FN_BODY" | grep -q 'is_author_self_cc_pr'; then
    pass "function body invokes is_author_self_cc_pr() filter (Issue #94 skip)"
  else
    fail "self-cc skip missing" \
      "expected query_verdict_posted to invoke is_author_self_cc_pr() — author must NOT wake on their own PR's verdict (AC-2 OBS-3)"
  fi
else
  fail "T5 — query_verdict_posted() not found, cannot inspect body"
fi

# ============================================================================
# T6: keyword_matched field emitted in event context (AC-3)
# ============================================================================
section "T6: context.keyword_matched field (AC-3)"
if grep -E '^query_verdict_posted\(\)' "$WATCH_SH" >/dev/null 2>&1; then
  FN_BODY="$(awk '/^query_verdict_posted\(\) \{/{flag=1; next} flag && /^[^ \t]/{exit} flag' "$WATCH_SH")"
  if printf '%s' "$FN_BODY" | grep -qE 'keyword_matched'; then
    pass "function body emits keyword_matched (debug field per AC-3 OBS-4)"
  else
    fail "keyword_matched missing" \
      "expected query_verdict_posted to emit 'keyword_matched' string per ADR-0041 §Decision event schema"
  fi
else
  fail "T6 — query_verdict_posted() not found, cannot inspect body"
fi

# ============================================================================
# T7: All 3 verdict classes detected (approved / suggestions / changes_requested)
# ============================================================================
section "T7: 3 verdict classes (AC schema per Issue #312 RCA table)"
# Per Issue #312 RCA Option A classification table:
#   APPROVED          — 🟢 / APPROVED / LGTM / sign-off / sign off
#   SUGGESTIONS       — 🟡 / SUGGESTIONS / non-blocking
#   CHANGES_REQUESTED — 🔴 / CHANGES_REQUESTED / REQUEST CHANGES / blocker
if grep -E '^query_verdict_posted\(\)' "$WATCH_SH" >/dev/null 2>&1; then
  FN_BODY="$(awk '/^query_verdict_posted\(\) \{/{flag=1; next} flag && /^[^ \t]/{exit} flag' "$WATCH_SH")"
  MISSING=0
  # APPROVED class — at least one keyword must be present
  if ! printf '%s' "$FN_BODY" | grep -Eq 'APPROVED|LGTM|sign-?off|🟢'; then
    MISSING=$((MISSING+1))
  fi
  if ! printf '%s' "$FN_BODY" | grep -Eq 'SUGGESTIONS|non-?blocking|🟡'; then
    MISSING=$((MISSING+1))
  fi
  if ! printf '%s' "$FN_BODY" | grep -Eq 'CHANGES_REQUESTED|REQUEST CHANGES|blocker|🔴'; then
    MISSING=$((MISSING+1))
  fi
  if [ "$MISSING" -eq 0 ]; then
    pass "all 3 verdict classes have keyword detection (approved/suggestions/changes_requested)"
  else
    fail "$MISSING verdict class(es) missing keyword detection" \
      "expected at least one keyword per class (per Issue #312 RCA table)"
  fi
else
  fail "T7 — query_verdict_posted() not found, cannot inspect body"
fi

# ============================================================================
# T8: Event schema match — kind/number/verdict/author/comment_id/comment_url/pr_url
# ============================================================================
section "T8: event payload schema match per ADR-0041 §Decision"
# Required fields: kind, number, verdict, author, comment_id, comment_url, pr_url
# Plus context: verdict_class + source + keyword_matched.
if grep -E '^query_verdict_posted\(\)' "$WATCH_SH" >/dev/null 2>&1; then
  FN_BODY="$(awk '/^query_verdict_posted\(\) \{/{flag=1; next} flag && /^[^ \t]/{exit} flag' "$WATCH_SH")"
  MISSING=0
  for field in kind number verdict author comment_id comment_url pr_url; do
    if ! printf '%s' "$FN_BODY" | grep -qE "\\b$field\\b"; then
      MISSING=$((MISSING+1))
      echo "    [missing field: $field]" >&2
    fi
  done
  # verdict_class also required in context
  if ! printf '%s' "$FN_BODY" | grep -qE 'verdict_class'; then
    MISSING=$((MISSING+1))
    echo "    [missing context field: verdict_class]" >&2
  fi
  if [ "$MISSING" -eq 0 ]; then
    pass "all 7 schema fields + verdict_class present (kind, number, verdict, author, comment_id, comment_url, pr_url, verdict_class)"
  else
    fail "$MISSING schema field(s) missing" \
      "expected all 7 + verdict_class per ADR-0041 §Decision event schema"
  fi
else
  fail "T8 — query_verdict_posted() not found, cannot inspect body"
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
  echo "SOME TESTS FAILED (TDD RED: query_verdict_posted() impl not yet present)"
  exit 1
fi

echo "ALL TESTS PASSED (TDD GREEN: v8 verdict_posted native kind shipped in agent-watch.sh)"
exit 0
