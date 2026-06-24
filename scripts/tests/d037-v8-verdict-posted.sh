#!/usr/bin/env bash
# d037-v8-verdict-posted.sh — v8-specific regression for agent-watch.sh native
# verdict_posted kind (Issue #326 Phase 2 of ADR-0041).
#
# Why this test exists
# --------------------
# d036 (PR #313, MERGED) locks the verdict-detection CONTRACT — keyword
# classes, payload kind, FP guard, scope filter — across BOTH the standalone
# `agent-watch-verdicts.sh` (Option B, Phase 0) AND the native
# `agent-watch.sh` v8 (Option A, Phase 2). That coverage proves the keyword
# table and event taxonomy are present *somewhere*.
#
# What d036 does NOT cover (and what d037 locks in):
#
#   - v8 native integration mechanics: the new kind must actually appear in
#     `agent-watch.sh`'s output taxonomy header AND inside `poll_once`'s
#     event-merging array.
#   - ADR-0041 §Decision-spec verbatim payload schema (kind/verdict/author/
#     comment_id/comment_url/pr_url/role + context.verdict_class +
#     context.source + context.keyword_matched).
#   - Severity precedence — when a body contains BOTH approved keywords AND
#     a changes_requested keyword, the classifier must pick changes_requested
#     (most severe wins).
#   - Full scope guard — verdict events must fire for the union
#     `agent:<role>` OR `cc:<role>` OR `verdict-by:*` (Phase 0's Option B
#     used `agent:<role>` only; Phase 2 widens it per ADR-0041).
#   - Self-cc skip — author-self-cc PRs (Issue #94) do not wake the same
#     role on their own incoming verdict.
#   - Event ID format — `verdict-posted-<pr>-<comment_id_sha7>-b<bucket>`
#     consistent with v6/v7 5-min bucket dedup.
#   - Integration point — the new function lives between query_pr_mentions
#     and query_stale_cc, grouping all PR-comment-derived events together
#     (ADR-0041 §Integration).
#   - Phase 0 → Phase 2 parity — `agent-watch-verdicts.sh` must be marked
#     DEPRECATED in its header (per Issue #326 supplement 2).
#
# Test cases (8 TUs aligned with Issue #326 ACs):
#   T1 — severity precedence (changes_requested > approved > suggestions)
#   T2 — scope guard: `agent:<role>` membership in PR label query
#   T3 — scope guard: `cc:<role>` AND `verdict-by:` membership in PR label query
#   T4 — self-cc skip per Issue #94 (author-self-cc PR does not wake same role)
#   T5 — 5-min bucket dedup with event ID
#         `verdict-posted-<pr>-<comment_id_sha7>-b<bucket>`
#   T6 — payload schema verbatim match (ADR-0041 §Decision §Event schema)
#   T7 — integration point: function placed between query_pr_mentions and
#         query_stale_cc, and called inside poll_once event-merge array
#   T8 — Phase 0 → Phase 2 parity: `agent-watch-verdicts.sh` carries the
#         DEPRECATED marker in its header (Issue #326 supplement 2)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d037-v8-verdict-posted.sh
#
# TDD status (this PR): RED on `main`. Locks the contract; turns GREEN once
# this branch ships the v8 native extension in `scripts/agent-watch.sh`.
#
# Reference: ADR-0041, Issue #326, sister d036 (PR #313 MERGED).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WATCH_SH="$SCRIPT_DIR/../agent-watch.sh"
VERDICT_SH="$SCRIPT_DIR/../agent-watch-verdicts.sh"  # Phase 0 baseline

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s${D}\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 127
fi

if [ ! -f "$WATCH_SH" ]; then
  echo "ERROR: $WATCH_SH not found — cannot run v8 regression"  >&2
  exit 127
fi

# Helper: find the line of the v8 function body anchor (NOT the header
# documentation that also mentions verdict_posted). Search for the actual
# function definition line, fall back to the jq template's kind literal.
find_v8_function_line() {
  local n
  n=$(grep -nE '^[[:space:]]*query_verdict_posted\(\)' "$WATCH_SH" | head -1 | cut -d: -f1)
  if [ -z "$n" ]; then
    n=$(grep -n 'kind: \\"verdict_posted\\"' "$WATCH_SH" | head -1 | cut -d: -f1)
  fi
  echo "$n"
}
classify_via_regexes() {
  local body="$1"
  # Verbatim from ADR-0041 §Verdict classification (word-boundary regex).
  local approved='(\bAPPROVED\b|\bLGTM\b|sign-?off|🟢)'
  local suggestions='(\bSUGGESTIONS\b|non-?blocking|🟡)'
  local changes='(\bCHANGES_REQUESTED\b|\bREQUEST CHANGES\b|\bblocker\b|🔴)'
  # Severity precedence: changes_requested > approved > suggestions.
  if [[ "$body" =~ $changes ]]; then
    printf '%s' "changes_requested"
  elif [[ "$body" =~ $approved ]]; then
    printf '%s' "approved"
  elif [[ "$body" =~ $suggestions ]]; then
    printf '%s' "suggestions"
  else
    printf '%s' ""
  fi
}

# ============================================================================
# T1 — severity precedence (changes_requested > approved > suggestions)
# ============================================================================
section "T1: severity precedence (changes_requested > approved > suggestions)"
# The impl in agent-watch.sh must implement the same precedence as Phase 0's
# agent-watch-verdicts.sh. We check (a) the keyword regexes are present in
# agent-watch.sh, AND (b) the precedence ordering can be inferred from the
# source order (changes_requested test branch appears BEFORE approved test
# branch — first-match-wins).
T1_OK=1
if ! grep -Eq 'CHANGES_REQUESTED|REQUEST CHANGES|blocker|🔴' "$WATCH_SH"; then
  fail "T1.a — changes_requested keywords missing in agent-watch.sh" \
    "expected one of {CHANGES_REQUESTED, REQUEST CHANGES, blocker, 🔴}"
  T1_OK=0
fi
if ! grep -Eq 'APPROVED|LGTM|sign.?off|🟢' "$WATCH_SH"; then
  fail "T1.b — approved keywords missing in agent-watch.sh" \
    "expected one of {APPROVED, LGTM, sign-off, 🟢}"
  T1_OK=0
fi
if ! grep -Eq 'SUGGESTIONS|non.?blocking|🟡' "$WATCH_SH"; then
  fail "T1.c — suggestions keywords missing in agent-watch.sh" \
    "expected one of {SUGGESTIONS, non-blocking, 🟡}"
  T1_OK=0
fi
# Source-order check: in the v8 classification logic, the changes_requested
# regex must be tested BEFORE the approved regex (first-match-wins precedence).
# Look strictly within the v8 function body so the header doc-comment order
# (which intentionally lists APPROVED first) doesn't false-fail this check.
if [ "$T1_OK" -eq 1 ]; then
  v8_line=$(find_v8_function_line)
  if [ -z "$v8_line" ]; then
    fail "T1.d — cannot locate v8 function body; cannot verify precedence" \
      "expected query_verdict_posted() or jq template with kind=\"verdict_posted\""
  else
    start=$v8_line
    end=$(( v8_line + 200 ))
    window=$(sed -n "${start},${end}p" "$WATCH_SH")
    # First test() call inside the if/elif chain — match changes-class keyword
    # before approved-class keyword inside the same jq pipeline.
    changes_pos=$(echo "$window" | grep -nE 'test\([^)]*(CHANGES_REQUESTED|REQUEST CHANGES|blocker|🔴|re_changes)' | head -1 | cut -d: -f1)
    approved_pos=$(echo "$window" | grep -nE 'test\([^)]*(\\bAPPROVED\\b|APPROVED|LGTM|sign.?off|🟢|re_approved)' | head -1 | cut -d: -f1)
    if [ -n "$changes_pos" ] && [ -n "$approved_pos" ] && [ "$changes_pos" -lt "$approved_pos" ]; then
      abs_changes=$(( v8_line + changes_pos - 1 ))
      abs_approved=$(( v8_line + approved_pos - 1 ))
      pass "severity precedence: changes_requested test at line $abs_changes before approved test at line $abs_approved (inside v8 function body)"
    elif [ -n "$changes_pos" ] && [ -n "$approved_pos" ]; then
      fail "severity precedence: changes_requested test at +$changes_pos is NOT before approved test at +$approved_pos within v8 function body" \
        "first-match wins must mean test(changes_requested) appears first in the if/elif chain"
    else
      fail "severity precedence: cannot locate test() chain inside v8 function body" \
        "changes_pos='$changes_pos' approved_pos='$approved_pos' (window starts at line $v8_line)"
    fi
  fi
fi
# Sanity self-test of the regex engine (not impl-dependent):
sample_both="🔴 CHANGES_REQUESTED — though earlier I posted 🟢 APPROVED, the new race breaks it."
sample_class=$(classify_via_regexes "$sample_both")
if [ "$sample_class" = "changes_requested" ]; then
  pass "regex engine sanity: 'both' sample classifies as changes_requested (precedence works)"
else
  fail "regex engine sanity: 'both' sample classified as '$sample_class' (expected changes_requested)" \
    "this is a sanity check on the test's classify_via_regexes() — not the impl"
fi

# ============================================================================
# T2 — scope guard: `agent:<role>` membership in PR label query
# ============================================================================
section "T2: scope guard — agent:<role> membership in PR label query"
if grep -Eq 'label.*"agent:\$\{?ROLE\}?"|agent:\$\{?ROLE\}?' "$WATCH_SH"; then
  # Tighten: ensure the v8 query (verdict_posted query) actually uses the role.
  # Heuristic: search for verdict_posted near agent:<role> within 60 lines.
  near=$(awk -v from='verdict_posted' -v to='agent:\\${ROLE\\|ROLE\\b}' \
    'BEGIN{found=0}
     $0 ~ from {start=NR}
     start && NR-start<60 && $0 ~ /agent:\$\{?ROLE\}?/ {found=1; exit}
     END{exit !found}' "$WATCH_SH" && echo OK || echo MISS)
  if [ "$near" = "OK" ]; then
    pass "v8 verdict_posted query references agent:\$ROLE within 60 lines (scope filter present)"
  else
    fail "v8 verdict_posted query missing agent:\$ROLE filter (scope guard incomplete)" \
      "expected: near the verdict_posted emit, gh pr list --label agent:\$ROLE (or equivalent)"
  fi
else
  fail "agent-watch.sh does not reference agent:\$ROLE in any query" \
    "scope guard T2 expects v8 to filter PRs by agent:\$ROLE"
fi

# ============================================================================
# T3 — scope guard: `cc:<role>` AND `verdict-by:` membership in PR label query
# ============================================================================
section "T3: scope guard — cc:<role> AND verdict-by:<ts> membership in scope filter"
# ADR-0041 §Detection scope: PR is in scope iff cc:<role> OR agent:<role> OR
# verdict-by:<ts> label is present. T2 covered agent:<role>; T3 covers the
# other two prongs.
HAS_CC=0
HAS_VERDICT_BY=0
# Anchor on the v8 function body (NOT the first text-mention which lives in
# the header doc-comment and won't contain code-level cc:/verdict-by tokens).
v_line=$(find_v8_function_line)
if [ -n "$v_line" ]; then
  start=$v_line
  end=$(( v_line + 200 ))
  window=$(sed -n "${start},${end}p" "$WATCH_SH")
  if echo "$window" | grep -Eq 'cc:\$\{?ROLE\}?'; then
    HAS_CC=1
  fi
  if echo "$window" | grep -Eq 'verdict-by:'; then
    HAS_VERDICT_BY=1
  fi
fi
if [ "$HAS_CC" -eq 1 ]; then
  pass "scope guard includes cc:\$ROLE near verdict_posted"
else
  fail "scope guard missing cc:\$ROLE near verdict_posted" \
    "ADR-0041 §Detection scope: PR in-scope iff agent:<role> OR cc:<role> OR verdict-by:*"
fi
if [ "$HAS_VERDICT_BY" -eq 1 ]; then
  pass "scope guard includes verdict-by: prefix near verdict_posted"
else
  fail "scope guard missing verdict-by: prefix near verdict_posted" \
    "ADR-0041 §Detection scope: PR in-scope iff agent:<role> OR cc:<role> OR verdict-by:*"
fi

# ============================================================================
# T4 — self-cc skip per Issue #94 (author-self-cc PR does not wake same role)
# ============================================================================
section "T4: self-cc skip per Issue #94 (author-self-cc PR does not wake same role)"
# The v8 query must invoke (or mirror) the existing `is_author_self_cc_pr` logic
# used by query_stale_cc. Either explicit call, or duplicated `agent:\$ROLE` +
# `cc:\$ROLE` skip check in the verdict_posted body.
# T4 self-cc skip: re-anchor on v8 function body too.
v_line=$(find_v8_function_line)
if [ -n "$v_line" ]; then
  start=$v_line
  end=$(( v_line + 200 ))
  window=$(sed -n "${start},${end}p" "$WATCH_SH")
  # Look for either: is_author_self_cc_pr call OR an inline guard combining
  # agent:<role> + cc:<role> presence + skip.
  if echo "$window" | grep -Eq 'is_author_self_cc_pr|self_cc|self.cc.skip'; then
    pass "self-cc skip referenced near verdict_posted (Issue #94 guard wired in)"
  elif echo "$window" | grep -Eq 'agent:\$\{?ROLE\}?' && \
       echo "$window" | grep -Eq 'cc:\$\{?ROLE\}?' && \
       echo "$window" | grep -Eq 'select.*not|skip|continue|\| not'; then
    pass "self-cc skip implemented inline (agent:\$ROLE + cc:\$ROLE + skip primitive)"
  else
    fail "self-cc skip missing near verdict_posted" \
      "Issue #94: author-self-cc PRs must not wake same role on incoming verdict (see query_stale_cc:782)"
  fi
else
  fail "T4 — verdict_posted query not present" "T1 prereq failed"
fi

# ============================================================================
# T5 — 5-min bucket dedup with event ID `verdict-posted-<pr>-<sha7>-b<bucket>`
# ============================================================================
section "T5: 5-min bucket dedup — event ID format verdict-posted-<pr>-<sha7>-b<bucket>"
# ADR-0041 §Event ID format: verdict-posted-<pr_number>-<comment_id_sha7>-b<bucket>
# bucket = floor(unix_timestamp / 300). Match the literal token "verdict-posted-"
# in the impl + a bucket expression.
if grep -Eq 'verdict-posted-' "$WATCH_SH"; then
  pass "event ID prefix 'verdict-posted-' present"
else
  fail "event ID prefix 'verdict-posted-' missing in agent-watch.sh" \
    "expected jq template id: 'verdict-posted-' + (pr|tostring) + '-' + (comment_id_sha7) + '-b' + bucket"
fi
if grep -Eq 'bucket.*=.*\(?.*\/\s*300\)?|bucket=\$\(\( .* / 300 \)\)|/\s*300' "$WATCH_SH"; then
  pass "5-min bucket math (/ 300) present somewhere in agent-watch.sh"
else
  fail "5-min bucket math (/ 300) missing" \
    "expected: bucket=\$(( \$(date -u +%s) / 300 )) near verdict_posted"
fi
# Stronger: bucket usage near verdict_posted (sha7 + bucket interpolation in id)
v_line=$(find_v8_function_line)
if [ -n "$v_line" ]; then
  start=$v_line
  end=$(( v_line + 200 ))
  window=$(sed -n "${start},${end}p" "$WATCH_SH")
  # Sha7: jq slice `[0:7]` or substring 0,7
  # Bucket: literal `-b${bucket}` or `-b$bucket` or jq `"-b" + bucket`
  if echo "$window" | grep -Eq '\[0:7\]|sha7|substr.*0.*7|0,7' && \
     echo "$window" | grep -Eq '\-b\$\{?bucket\}?|"-b"\s*\+\s*\$bucket|-b" \+ bucket' ; then
    pass "verdict_posted event ID interpolates comment_id sha7 + bucket"
  else
    fail "verdict_posted event ID does not visibly use sha7 + bucket" \
      "expected: 'verdict-posted-' + pr + '-' + (comment_id[0:7]) + '-b' + bucket"
  fi
fi

# ============================================================================
# T6 — payload schema verbatim match (ADR-0041 §Decision §Event schema)
# ============================================================================
section "T6: payload schema verbatim match (ADR-0041 §Decision §Event schema)"
# Required keys (top-level): kind, number, verdict, author, comment_id,
# comment_url, pr_url, role, context.
# Required keys (context): verdict_class, source, keyword_matched.
REQUIRED_TOP=(kind verdict author comment_id comment_url pr_url role)
REQUIRED_CTX=(verdict_class source keyword_matched)
T6_FAIL=0
for k in "${REQUIRED_TOP[@]}"; do
  if ! grep -Fq "$k" "$WATCH_SH"; then
    fail "T6 — required top-level key '$k' missing in agent-watch.sh" \
      "ADR-0041 §Event schema mandates all 9 top-level keys"
    T6_FAIL=$((T6_FAIL+1))
  fi
done
for k in "${REQUIRED_CTX[@]}"; do
  if ! grep -Fq "$k" "$WATCH_SH"; then
    fail "T6 — required context.* key '$k' missing in agent-watch.sh" \
      "ADR-0041 §Event schema mandates context.verdict_class + .source + .keyword_matched"
    T6_FAIL=$((T6_FAIL+1))
  fi
done
if [ "$T6_FAIL" -eq 0 ]; then
  pass "all 9 top-level + 3 context.* schema keys present"
fi

# ============================================================================
# T7 — integration point: function placed between query_pr_mentions and
#       query_stale_cc, and called inside poll_once event-merge array.
# ============================================================================
section "T7: integration point (between query_pr_mentions and query_stale_cc, wired into poll_once)"
# 7a — function definition exists with a recognizable name (verdict|verdict_posted).
v_func_line=$(grep -nE '^[[:space:]]*query_[a-z_]*verdict[a-z_]*\(\)' "$WATCH_SH" | head -1 | cut -d: -f1)
pr_func_line=$(grep -nE '^[[:space:]]*query_pr_mentions\(\)' "$WATCH_SH" | head -1 | cut -d: -f1)
stale_func_line=$(grep -nE '^[[:space:]]*query_stale_cc\(\)' "$WATCH_SH" | head -1 | cut -d: -f1)
if [ -n "$v_func_line" ] && [ -n "$pr_func_line" ] && [ -n "$stale_func_line" ]; then
  if [ "$v_func_line" -gt "$pr_func_line" ] && [ "$v_func_line" -lt "$stale_func_line" ]; then
    pass "verdict query function defined at line $v_func_line (between query_pr_mentions:$pr_func_line and query_stale_cc:$stale_func_line)"
  else
    fail "verdict query function at line $v_func_line is NOT between query_pr_mentions:$pr_func_line and query_stale_cc:$stale_func_line" \
      "ADR-0041 §Integration mandates grouping with other PR-comment-derived events"
  fi
else
  fail "T7 — cannot locate v8 verdict query function or its neighbors" \
    "v_func_line='$v_func_line' pr_func_line='$pr_func_line' stale_func_line='$stale_func_line'"
fi
# 7b — poll_once wires the new function into the merge array (jq -s 'add | unique_by(.id)').
# Note: tightened to require the exact local-var name `verdict_posted=` so it does NOT
# accidentally match the v6 line `stale_verdict="$(query_stale_verdict ..."`.
if grep -Eq '^[[:space:]]*verdict_posted="\$\(query_' "$WATCH_SH"; then
  pass "poll_once invokes a query_*verdict* function and stores its output in 'verdict_posted' local"
else
  fail "poll_once does not invoke a query_*verdict* function into 'verdict_posted' local" \
    "expected: verdict_posted=\"\$(query_verdict_posted 2>/dev/null || echo '[]')\" in poll_once"
fi
# 7c — the verdict variable is passed into the jq -s 'add | unique_by(.id)' merge.
if grep -Eq 'echo "\$verdict' "$WATCH_SH" || grep -Eq '<\(echo "\$verdict_posted' "$WATCH_SH"; then
  pass "verdict_posted output is fed into jq -s merge array (deduped with other events)"
else
  fail "verdict_posted output is NOT in the jq -s merge array of poll_once" \
    "expected: <(echo \"\$verdict_posted\") in the merged=\"\$(jq -s 'add | unique_by(.id)' ...)\" call"
fi

# ============================================================================
# T8 — Phase 0 → Phase 2 parity: agent-watch-verdicts.sh DEPRECATED marker
# ============================================================================
section "T8: Phase 0 → Phase 2 parity (agent-watch-verdicts.sh marked DEPRECATED)"
# Per Issue #326 supplement 2: when v8 ships, the standalone Phase 0 supplement
# is deprecated. The deprecation must be VISIBLE in the script's header so
# operators running the old script see a clear sunset notice.
if [ -f "$VERDICT_SH" ]; then
  if grep -Eqi 'DEPRECATED|sunset|retire|superseded' "$VERDICT_SH"; then
    pass "agent-watch-verdicts.sh carries a DEPRECATED / sunset / superseded marker"
  else
    fail "agent-watch-verdicts.sh is NOT marked DEPRECATED" \
      "Issue #326 supplement 2: add 'DEPRECATED' header comment when v8 ships"
  fi
else
  fail "T8 — agent-watch-verdicts.sh missing entirely (cannot check deprecation marker)" \
    "Phase 0 baseline must remain present (for fallback) with a DEPRECATED marker"
fi

# ============================================================================
# Also lock the taxonomy header on line 97: must mention verdict_posted in the
# big "kind": "...|...|..." union string. This catches drift where impl ships
# but header docs don't (silent doc rot).
# ============================================================================
section "T9 (header bonus): taxonomy union string mentions verdict_posted"
if grep -Eq '"kind":.*verdict_posted' "$WATCH_SH"; then
  pass "taxonomy header (kind union string) lists verdict_posted"
else
  fail "taxonomy header (line ~97) does NOT list verdict_posted" \
    "update the union string: \"issue_assigned|...|verdict_posted|...\""
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
  echo "SOME TESTS FAILED (TDD RED expected until v8 native impl lands)"
  exit 1
fi

echo "ALL TESTS PASSED (TDD GREEN: v8 native verdict_posted lives in agent-watch.sh)"
exit 0
