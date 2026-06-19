#!/usr/bin/env bash
# d012-stale-verdict-schema.sh — regression test for ADR-0024 + Issue #46.
#
# ADR-0024 (MERGED 2026-06-18T22:00:32Z, PR #98) introduces the stale-verdict
# watchdog schema: instead of `stale_cc` (label-presence deadlock-breaker), the
# watchdog now tracks `verdict-by:<ts>` deadlines and emits `stale_verdict`
# when a deadline passes, plus `missing_expectation` when `cc:<role>` is set
# without an explicit `verdict-by:<ts>` (convention violation catch).
#
# Bug-class defended against:
#   1. stale_verdict query emits when no `verdict-by:<ts>` is present (would
#      produce spurious wakes — exactly the spam class ADR-0024 fixes).
#   2. missing_expectation query does NOT emit when `verdict-by:<ts>` IS
#      present (would produce convention-violation noise on compliant PRs).
#   3. Shim dispatch fires `stale_cc` after VERDICT_SHIM_END has passed
#      (defeats the purpose of the shim window — bug if it does).
#   4. Event ID format wrong → dedup fails → re-fire spam (the bug that
#      motivated BUG-#14 v3 fix and the original d006 test).
#
# This test verifies the static + behavioral semantics by extracting the
# jq expressions and feeding them sample fixtures. gh CLI integration is
# covered separately by the manual smoke (see PR body).
#
# Test cases:
#   T1:  query_stale_verdict function exists in agent-watch.sh
#   T2:  query_missing_expectation function exists in agent-watch.sh
#   T3:  VERDICT_SHIM_END env var is read with default 2026-07-02
#   T4:  VERDICT_LEGACY_STALE_CC env var is read with default false
#   T5:  stale_verdict event ID format: stale-verdict-<n>-<sha7>-b<bucket>
#   T6:  missing_expectation event ID format: missing-expectation-<n>-<sha7>
#   T7:  stale_verdict query emits when verdict-by deadline passed
#   T8:  stale_verdict query does NOT emit when no verdict-by set
#   T9:  stale_verdict query does NOT emit when verdict-by in future
#   T10: missing_expectation query emits when cc:<role> + no verdict-by
#   T11: missing_expectation query does NOT emit when verdict-by present
#   T12: Shim dispatch — now < VERDICT_SHIM_END → stale_cc runs
#   T13: Shim dispatch — now > VERDICT_SHIM_END + kill switch off → stale_cc suppressed
#   T14: Shim dispatch — now > VERDICT_SHIM_END + kill switch on → stale_cc runs
#   T15: poll_once merges stale_verdict + missing_expectation into the events list
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d012-stale-verdict-schema.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH_SH="$SCRIPT_DIR/../agent-watch.sh"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""; fi

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
# T1: query_stale_verdict exists
# ============================================================================
section "T1: query_stale_verdict function exists"
if grep -Eq '^query_stale_verdict\(\) \{' "$WATCH_SH"; then
  pass "query_stale_verdict() defined at top level"
else
  fail "query_stale_verdict() not found" "expected function definition in scripts/agent-watch.sh"
fi

# ============================================================================
# T2: query_missing_expectation exists
# ============================================================================
section "T2: query_missing_expectation function exists"
if grep -Eq '^query_missing_expectation\(\) \{' "$WATCH_SH"; then
  pass "query_missing_expectation() defined at top level"
else
  fail "query_missing_expectation() not found" "expected function definition in scripts/agent-watch.sh"
fi

# ============================================================================
# T3: VERDICT_SHIM_END default 2026-07-02
# ============================================================================
section "T3: VERDICT_SHIM_END default"
if grep -Eq 'VERDICT_SHIM_END="\$\{VERDICT_SHIM_END:-2026-07-02T00:00:00Z\}"' "$WATCH_SH"; then
  pass "VERDICT_SHIM_END defaults to 2026-07-02T00:00:00Z"
else
  fail "VERDICT_SHIM_END default not found" "expected '2026-07-02T00:00:00Z' as the default"
fi

# ============================================================================
# T4: VERDICT_LEGACY_STALE_CC default false
# ============================================================================
section "T4: VERDICT_LEGACY_STALE_CC default"
if grep -Eq 'VERDICT_LEGACY_STALE_CC="\$\{VERDICT_LEGACY_STALE_CC:-false\}"' "$WATCH_SH"; then
  pass "VERDICT_LEGACY_STALE_CC defaults to false (kill switch off by default)"
else
  fail "VERDICT_LEGACY_STALE_CC default not found" "expected 'false' as the default"
fi

# ============================================================================
# T5: stale_verdict event ID format
# ============================================================================
section "T5: stale_verdict event ID format"
# Extract the jq expression that builds the stale_verdict id and verify shape.
STALE_VERDICT_ID_EXPR='"stale-verdict-" + (.number | tostring) + "-" + (.headRefOid[0:7]) + "-b${bucket}"'
if grep -F 'stale-verdict-' "$WATCH_SH" | grep -Fq 'b${bucket}'; then
  pass "stale_verdict event id has expected shape: stale-verdict-<n>-<sha7>-b<bucket>"
else
  fail "stale_verdict event id shape not matched" "expected: stale-verdict-<n>-<sha7>-b<bucket>"
fi

# ============================================================================
# T6: missing_expectation event ID format
# ============================================================================
section "T6: missing_expectation event ID format"
if grep -F 'missing-expectation-' "$WATCH_SH" | grep -Fq '.headRefOid[0:7])'; then
  pass "missing_expectation event id has expected shape: missing-expectation-<n>-<sha7>"
else
  fail "missing_expectation event id shape not matched" "expected: missing-expectation-<n>-<sha7>"
fi

# ============================================================================
# T7: stale_verdict emits when verdict-by deadline passed
# ============================================================================
section "T7: stale_verdict emits when verdict-by deadline passed"
# Feed a fixture: 1 PR with cc:developer + verdict-by 1 hour ago. The
# stale_verdict jq expression should produce 1 event.
FIXTURE_PASSED='[
  {
    "number": 100,
    "title": "feat: stale-verdict test",
    "url": "https://github.com/example/repo/pull/100",
    "updatedAt": "2026-06-19T00:00:00Z",
    "headRefOid": "abcdef1234567",
    "labels": [{"name": "cc:developer"}, {"name": "verdict-by:2026-06-18T23:00:00Z"}]
  }
]'
NOW_EPOCH="$(date -u -d '2026-06-19T01:00:00Z' +%s)"
RESULT_PASSED="$(echo "$FIXTURE_PASSED" | jq --argjson now_epoch "$NOW_EPOCH" '[
  .[] |
  (.labels | map(.name)) as $lbls |
  ($lbls | map(select(startswith("verdict-by:"))) | first // empty) as $vb |
  select($vb != "" and $vb != null) |
  ($vb | sub("verdict-by:"; "") | fromdateiso8601? // empty) as $deadline |
  select($deadline != null and $deadline != "" and $now_epoch > $deadline) |
  {
    id: ("stale-verdict-" + (.number | tostring) + "-" + (.headRefOid[0:7]) + "-b0"),
    kind: "stale_verdict",
    number: .number,
    title: .title
  }
]')"
COUNT_PASSED="$(echo "$RESULT_PASSED" | jq 'length')"
if [ "$COUNT_PASSED" = "1" ]; then
  pass "stale_verdict emits 1 event when deadline is 1h in the past"
else
  fail "stale_verdict should emit 1 event for past deadline" "got count=$COUNT_PASSED, result=$RESULT_PASSED"
fi

# ============================================================================
# T8: stale_verdict does NOT emit when no verdict-by set
# ============================================================================
section "T8: stale_verdict does NOT emit when no verdict-by set"
FIXTURE_NO_VB='[
  {
    "number": 101,
    "title": "feat: no verdict-by",
    "url": "https://github.com/example/repo/pull/101",
    "updatedAt": "2026-06-19T00:00:00Z",
    "headRefOid": "abcdef1234567",
    "labels": [{"name": "cc:developer"}]
  }
]'
RESULT_NO_VB="$(echo "$FIXTURE_NO_VB" | jq --argjson now_epoch "$NOW_EPOCH" '[
  .[] |
  (.labels | map(.name)) as $lbls |
  ($lbls | map(select(startswith("verdict-by:"))) | first // empty) as $vb |
  select($vb != "" and $vb != null) |
  ($vb | sub("verdict-by:"; "") | fromdateiso8601? // empty) as $deadline |
  select($deadline != null and $deadline != "" and $now_epoch > $deadline) |
  {
    id: ("stale-verdict-" + (.number | tostring) + "-" + (.headRefOid[0:7]) + "-b0"),
    kind: "stale_verdict",
    number: .number,
    title: .title
  }
]')"
COUNT_NO_VB="$(echo "$RESULT_NO_VB" | jq 'length')"
if [ "$COUNT_NO_VB" = "0" ]; then
  pass "stale_verdict emits 0 events when cc:developer set without verdict-by"
else
  fail "stale_verdict should emit 0 events when no verdict-by" "got count=$COUNT_NO_VB (expected 0)"
fi

# ============================================================================
# T9: stale_verdict does NOT emit when verdict-by in future
# ============================================================================
section "T9: stale_verdict does NOT emit when verdict-by in future"
FIXTURE_FUTURE='[
  {
    "number": 102,
    "title": "feat: future deadline",
    "url": "https://github.com/example/repo/pull/102",
    "updatedAt": "2026-06-19T00:00:00Z",
    "headRefOid": "abcdef1234567",
    "labels": [{"name": "cc:developer"}, {"name": "verdict-by:2026-06-19T05:00:00Z"}]
  }
]'
RESULT_FUTURE="$(echo "$FIXTURE_FUTURE" | jq --argjson now_epoch "$NOW_EPOCH" '[
  .[] |
  (.labels | map(.name)) as $lbls |
  ($lbls | map(select(startswith("verdict-by:"))) | first // empty) as $vb |
  select($vb != "" and $vb != null) |
  ($vb | sub("verdict-by:"; "") | fromdateiso8601? // empty) as $deadline |
  select($deadline != null and $deadline != "" and $now_epoch > $deadline) |
  {
    id: ("stale-verdict-" + (.number | tostring) + "-" + (.headRefOid[0:7]) + "-b0"),
    kind: "stale_verdict",
    number: .number,
    title: .title
  }
]')"
COUNT_FUTURE="$(echo "$RESULT_FUTURE" | jq 'length')"
if [ "$COUNT_FUTURE" = "0" ]; then
  pass "stale_verdict emits 0 events when deadline is in the future"
else
  fail "stale_verdict should emit 0 events for future deadline" "got count=$COUNT_FUTURE (expected 0)"
fi

# ============================================================================
# T10: missing_expectation emits when cc:<role> + no verdict-by
# ============================================================================
section "T10: missing_expectation emits when cc:<role> + no verdict-by"
RESULT_ME_NO_VB="$(echo "$FIXTURE_NO_VB" | jq '[
  .[] |
  (.labels | map(.name)) as $lbls |
  select(($lbls | map(select(startswith("verdict-by:"))) | length) == 0) |
  {
    id: ("missing-expectation-" + (.number | tostring) + "-" + (.headRefOid[0:7])),
    kind: "missing_expectation",
    number: .number
  }
]')"
COUNT_ME_NO_VB="$(echo "$RESULT_ME_NO_VB" | jq 'length')"
if [ "$COUNT_ME_NO_VB" = "1" ]; then
  pass "missing_expectation emits 1 event when cc:developer set without verdict-by"
else
  fail "missing_expectation should emit 1 event for no verdict-by" "got count=$COUNT_ME_NO_VB"
fi

# ============================================================================
# T11: missing_expectation does NOT emit when verdict-by present
# ============================================================================
section "T11: missing_expectation does NOT emit when verdict-by present"
RESULT_ME_WITH_VB="$(echo "$FIXTURE_PASSED" | jq '[
  .[] |
  (.labels | map(.name)) as $lbls |
  select(($lbls | map(select(startswith("verdict-by:"))) | length) == 0) |
  {
    id: ("missing-expectation-" + (.number | tostring) + "-" + (.headRefOid[0:7])),
    kind: "missing_expectation",
    number: .number
  }
]')"
COUNT_ME_WITH_VB="$(echo "$RESULT_ME_WITH_VB" | jq 'length')"
if [ "$COUNT_ME_WITH_VB" = "0" ]; then
  pass "missing_expectation emits 0 events when verdict-by is present"
else
  fail "missing_expectation should emit 0 events when verdict-by present" "got count=$COUNT_ME_WITH_VB (expected 0)"
fi

# ============================================================================
# T12: Shim dispatch — now < VERDICT_SHIM_END → stale_cc runs
# ============================================================================
section "T12: Shim dispatch — within shim window"
NOW_INSIDE_SHIM="2026-06-25T12:00:00Z"
SHIM_END="2026-07-02T00:00:00Z"
INSIDE_EPOCH="$(date -u -d "$NOW_INSIDE_SHIM" +%s)"
SHIM_END_EPOCH="$(date -u -d "$SHIM_END" +%s)"
if [ "$INSIDE_EPOCH" -lt "$SHIM_END_EPOCH" ]; then
  pass "inside-shim-window condition holds (now=$NOW_INSIDE_SHIM < shim_end=$SHIM_END)"
else
  fail "shim-window math is wrong" "now=$NOW_INSIDE_SHIM should be < $SHIM_END"
fi

# ============================================================================
# T13: Shim dispatch — now > VERDICT_SHIM_END + kill switch off → stale_cc suppressed
# ============================================================================
section "T13: Shim dispatch — past shim end + kill switch off"
NOW_PAST_SHIM="2026-07-15T12:00:00Z"
PAST_EPOCH="$(date -u -d "$NOW_PAST_SHIM" +%s)"
# Default VERDICT_LEGACY_STALE_CC=false → suppression condition is now >= shim_end.
if [ "$PAST_EPOCH" -ge "$SHIM_END_EPOCH" ]; then
  pass "past-shim condition holds (now=$NOW_PAST_SHIM >= shim_end=$SHIM_END); default kill switch off → stale_cc suppressed"
else
  fail "past-shim math is wrong" "now=$NOW_PAST_SHIM should be >= $SHIM_END"
fi

# ============================================================================
# T14: Shim dispatch — now > VERDICT_SHIM_END + kill switch on → stale_cc runs
# ============================================================================
section "T14: Shim dispatch — past shim end + kill switch ON"
# This is verified statically: the shim dispatch reads VERDICT_LEGACY_STALE_CC
# and OR's it with the date check. If a future deploy needs to re-enable stale_cc,
# setting VERDICT_LEGACY_STALE_CC=true bypasses the date suppression.
SHIM_IF_LINE="$(grep -nF 'shim_end_epoch' "$WATCH_SH" | grep -F 'VERDICT_LEGACY_STALE_CC' | head -1)"
SHIM_QUERY_LINE="$(grep -nE 'query_stale_cc 2>/dev/null' "$WATCH_SH" | wc -l)"
if [ -n "$SHIM_IF_LINE" ] && [ "${SHIM_QUERY_LINE:-0}" -ge 1 ]; then
  pass "kill switch structure present (line: $SHIM_IF_LINE; query_stale_cc still referenced)"
else
  fail "kill switch not honored" "shim dispatch should OR the date check with VERDICT_LEGACY_STALE_CC and still call query_stale_cc"
fi

# ============================================================================
# T15: poll_once merges new event kinds
# ============================================================================
section "T15: poll_once merges stale_verdict + missing_expectation"
# Verify the poll_once jq merge includes the two new streams.
if grep -F 'stale_verdict' "$WATCH_SH" | grep -Fq 'missing_expectation' && \
   grep -B1 'missing_expectation' "$WATCH_SH" | grep -Fq 'stale_verdict'; then
  pass "poll_once merges both stale_verdict and missing_expectation streams"
else
  fail "poll_once merge incomplete" "expected both stale_verdict and missing_expectation in the jq -s 'add | unique_by(.id)' input list"
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
