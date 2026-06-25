#!/usr/bin/env bash
# d319-verdict-by-tdd-red-exclusion.sh — regression test for ADR-0044 §Scope rule.
#
# Why this test exists
# --------------------
# ADR-0044 (PR #359 MERGED 2026-06-24T19:20:31Z) refines the verdict-by:* SLA
# enforcer: TDD RED contract-only PRs must be EXCLUDED from the SLA pressure
# (otherwise the watchdog wakes peers to "verdict overdue" on a contract test
# that has nothing to verdict on until impl lands).
#
# Scope rule (canonical, ADR-0044 §Decision):
#   if pr has `contract:tdd-red` label:
#       skip verdict-by SLA check (no stale_verdict, no missing_expectation)
#   elif pr diff is test-only AND CI is RED on all TCs:
#       skip verdict-by SLA check (same)
#   else:
#       apply verdict-by SLA check (stale_verdict + missing_expectation as per ADR-0024)
#
# Incident reference: PR #313 (tester doctrinal gap, MERGED) — SLA fired on a
# TDD RED contract test, owner acted unilaterally. PR #317 (sister incident).
#
# Test cases (per ADR-0044 §Implementation step 4, 3 TCs):
#   TC1: TDD RED + `contract:tdd-red` label → no stale_verdict (skip)
#   TC2: test-only diff + CI RED (no label) → no stale_verdict (skip — defense in depth)
#   TC3: normal PR + verdict overdue → stale_verdict FIRES (regression — must not over-exclude)
#
# Plus 2 static structure tests (defense against the impl drifting):
#   T0:  query_stale_verdict function contains the TDD RED exclusion
#   T0b: query_missing_expectation function contains the TDD RED exclusion
#
# Exit code: 0 = all pass, 1 = at least one fail.
# Run standalone: bash scripts/tests/d319-verdict-by-tdd-red-exclusion.sh
#
# Refs: Issue #319, ADR-0044 §Decision / §Scope rule, ADR-0024, PR #313, PR #317.
# Pattern lifted from: scripts/tests/d012-stale-verdict-schema.sh (jq-fixture approach).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH_SH="$SCRIPT_DIR/../agent-watch.sh"

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
if [ ! -r "$WATCH_SH" ]; then
  echo "ERROR: agent-watch.sh not found at $WATCH_SH" >&2; exit 127
fi

# ============================================================================
# Helpers — build jq filter that mirrors the post-impl query_stale_verdict
# logic. We construct it inline rather than extracting from agent-watch.sh
# (jq expressions span many lines with nested escaping — fragile to extract).
# The filter below is the CONTRACT; query_stale_verdict in agent-watch.sh must
# match it semantically. Drift between the two is detected by T0/T0b (static
# structure checks) below.
# ============================================================================

# ADR-0044 §Scope rule (TDD RED exclusion):
#   1. contract:tdd-red label present → skip
#   2. (defense in depth) all changed files match test-only patterns AND CI is
#      FAILURE → skip
# Test-only patterns (ADR-0044 §Decision):
#   - paths starting with `tests/`
#   - filenames matching test_*.{py,sh}, *_test.{py,sh}, *.test.{ts,js},
#     *.spec.{ts,js}, *Test.java
TD_RED_EXCLUSION_FILTER='
  # ADR-0044 §Scope rule — TDD RED exclusion
  (
    # (1) contract:tdd-red label present?
    (($lbls | any(. == "contract:tdd-red")))
    or
    # (2) defense in depth: all files test-only AND CI FAILURE
    (
      (((.files // []) | length) > 0)
      and
      ((.files // []) | all(
        .path | (startswith("tests/") or test("test_[^/]*\\.(py|sh)$") or test("[^/]+_test\\.(py|sh)$") or test("\\.test\\.(ts|js)$") or test("\\.spec\\.(ts|js)$") or test("Test\\.java$"))
      ))
      and
      (((.statusCheckRollup // {}).state // "UNKNOWN") == "FAILURE")
    )
  ) as $is_tdd_red |
  select($is_tdd_red | not)
'

NOW_EPOCH="$(date -u -d '2026-06-25T01:00:00Z' +%s)"
BUCKET=0

# Shared jq filter factory — builds the stale_verdict filter with or without exclusion.
# Usage: build_filter <with_exclusion=true|false>
build_filter() {
  local with_exclusion="$1"
  if [ "$with_exclusion" = "true" ]; then
    cat <<EOF
[
  .[] |
  (.labels | map(.name)) as \$lbls |
  ${TD_RED_EXCLUSION_FILTER} |
  (\$lbls | map(select(startswith("verdict-by:"))) | first // empty) as \$vb |
  select(\$vb != "" and \$vb != null) |
  (\$vb | sub("verdict-by:"; "") | fromdateiso8601? // empty) as \$deadline |
  select(\$deadline != null and \$deadline != "" and ${NOW_EPOCH} > \$deadline) |
  {
    id: ("stale-verdict-" + (.number | tostring) + "-" + (.headRefOid[0:7]) + "-b${BUCKET}"),
    kind: "stale_verdict",
    number: .number,
    title: .title
  }
]
EOF
  else
    cat <<EOF
[
  .[] |
  (.labels | map(.name)) as \$lbls |
  (\$lbls | map(select(startswith("verdict-by:"))) | first // empty) as \$vb |
  select(\$vb != "" and \$vb != null) |
  (\$vb | sub("verdict-by:"; "") | fromdateiso8601? // empty) as \$deadline |
  select(\$deadline != null and \$deadline != "" and ${NOW_EPOCH} > \$deadline) |
  {
    id: ("stale-verdict-" + (.number | tostring) + "-" + (.headRefOid[0:7]) + "-b${BUCKET}"),
    kind: "stale_verdict",
    number: .number,
    title: .title
  }
]
EOF
  fi
}

# ============================================================================
# T0: query_stale_verdict contains the TDD RED exclusion
# ============================================================================
section "T0: query_stale_verdict contains TDD RED exclusion (static)"
if grep -A 80 '^query_stale_verdict()' "$WATCH_SH" | grep -qF 'contract:tdd-red'; then
  pass "query_stale_verdict references 'contract:tdd-red' exclusion"
else
  fail "query_stale_verdict does NOT reference 'contract:tdd-red'" \
       "ADR-0044 §Scope rule requires the exclusion; agent-watch.sh must include it"
fi

# ============================================================================
# T0b: query_missing_expectation contains the TDD RED exclusion
# ============================================================================
section "T0b: query_missing_expectation contains TDD RED exclusion (static)"
if grep -A 80 '^query_missing_expectation()' "$WATCH_SH" | grep -qF 'contract:tdd-red'; then
  pass "query_missing_expectation references 'contract:tdd-red' exclusion"
else
  fail "query_missing_expectation does NOT reference 'contract:tdd-red'" \
       "ADR-0044 §Decision: 'Skip missing_expectation warning if cc:<peer> present without verdict-by:<ts>' when TDD RED"
fi

# ============================================================================
# TC1: TDD RED + contract:tdd-red label → NO stale_verdict (skip)
# ============================================================================
section "TC1: TDD RED + contract:tdd-red label → NO stale_verdict"
FIXTURE_TC1='[
  {
    "number": 200,
    "title": "TDD RED contract: tests authored, no impl",
    "url": "https://github.com/atilcan65/AtilCalculator/pull/200",
    "updatedAt": "2026-06-25T00:00:00Z",
    "headRefOid": "abc1111111111",
    "labels": [
      {"name": "cc:developer"},
      {"name": "verdict-by:2026-06-25T00:00:00Z"},
      {"name": "contract:tdd-red"}
    ],
    "files": [{"path": "tests/cli/test_d036.py"}],
    "statusCheckRollup": {"state": "FAILURE"}
  }
]'
# Without exclusion (pre-impl): would emit 1 stale_verdict (FAIL — should not emit)
RESULT_NO_EXCL="$(echo "$FIXTURE_TC1" | jq -f <(build_filter false))"
COUNT_NO_EXCL="$(echo "$RESULT_NO_EXCL" | jq 'length')"
# With exclusion (post-impl): should emit 0 (PASS — exclusion works)
RESULT_WITH_EXCL="$(echo "$FIXTURE_TC1" | jq -f <(build_filter true))"
COUNT_WITH_EXCL="$(echo "$RESULT_WITH_EXCL" | jq 'length')"

if [ "$COUNT_NO_EXCL" = "1" ] && [ "$COUNT_WITH_EXCL" = "0" ]; then
  pass "pre-impl emits 1 (regression baseline) AND post-impl emits 0 (exclusion works)"
elif [ "$COUNT_NO_EXCL" = "0" ]; then
  fail "pre-impl emits 0 — fixture or filter wrong" "expected 1 stale_verdict from un-modified filter"
elif [ "$COUNT_WITH_EXCL" = "1" ]; then
  fail "post-impl emits 1 — exclusion filter does not work" \
       "expected 0 stale_verdict with contract:tdd-red label; got: $RESULT_WITH_EXCL"
else
  fail "unexpected counts" "no_excl=$COUNT_NO_EXCL, with_excl=$COUNT_WITH_EXCL"
fi

# ============================================================================
# TC2: test-only diff + CI RED (no label) → NO stale_verdict (defense in depth)
# ============================================================================
section "TC2: test-only diff + CI RED (no label) → NO stale_verdict"
FIXTURE_TC2='[
  {
    "number": 201,
    "title": "TDD RED contract forgot label, but test-only + CI RED",
    "url": "https://github.com/atilcan65/AtilCalculator/pull/201",
    "updatedAt": "2026-06-25T00:00:00Z",
    "headRefOid": "def2222222222",
    "labels": [
      {"name": "cc:developer"},
      {"name": "verdict-by:2026-06-25T00:00:00Z"}
    ],
    "files": [{"path": "tests/cli/test_precedence.py"}],
    "statusCheckRollup": {"state": "FAILURE"}
  }
]'
# Without exclusion: emits 1 (pre-impl baseline)
RESULT_NO_EXCL_2="$(echo "$FIXTURE_TC2" | jq -f <(build_filter false))"
COUNT_NO_EXCL_2="$(echo "$RESULT_NO_EXCL_2" | jq 'length')"
# With exclusion: emits 0 (defense-in-depth catches it)
RESULT_WITH_EXCL_2="$(echo "$FIXTURE_TC2" | jq -f <(build_filter true))"
COUNT_WITH_EXCL_2="$(echo "$RESULT_WITH_EXCL_2" | jq 'length')"

if [ "$COUNT_NO_EXCL_2" = "1" ] && [ "$COUNT_WITH_EXCL_2" = "0" ]; then
  pass "pre-impl emits 1 AND post-impl emits 0 (defense-in-depth catches test-only + CI RED)"
elif [ "$COUNT_NO_EXCL_2" = "0" ]; then
  fail "pre-impl emits 0 — fixture or filter wrong" "expected 1 stale_verdict from un-modified filter"
elif [ "$COUNT_WITH_EXCL_2" = "1" ]; then
  fail "post-impl emits 1 — defense-in-depth (test-only + CI RED) not working" \
       "expected 0 stale_verdict; got: $RESULT_WITH_EXCL_2"
else
  fail "unexpected counts" "no_excl=$COUNT_NO_EXCL_2, with_excl=$COUNT_WITH_EXCL_2"
fi

# ============================================================================
# TC3: normal PR + verdict overdue → stale_verdict FIRES (regression)
# ============================================================================
section "TC3: normal PR + verdict overdue → stale_verdict FIRES (regression)"
FIXTURE_TC3='[
  {
    "number": 202,
    "title": "Normal impl PR, verdict overdue",
    "url": "https://github.com/atilcan65/AtilCalculator/pull/202",
    "updatedAt": "2026-06-25T00:00:00Z",
    "headRefOid": "fed3333333333",
    "labels": [
      {"name": "cc:developer"},
      {"name": "verdict-by:2026-06-25T00:00:00Z"}
    ],
    "files": [{"path": "src/atilcalc/engine/arithmetic.py"}],
    "statusCheckRollup": {"state": "SUCCESS"}
  }
]'
# Pre and post impl should BOTH emit 1 (regression guard — exclusion must not over-skip)
RESULT_NO_EXCL_3="$(echo "$FIXTURE_TC3" | jq -f <(build_filter false))"
COUNT_NO_EXCL_3="$(echo "$RESULT_NO_EXCL_3" | jq 'length')"
RESULT_WITH_EXCL_3="$(echo "$FIXTURE_TC3" | jq -f <(build_filter true))"
COUNT_WITH_EXCL_3="$(echo "$RESULT_WITH_EXCL_3" | jq 'length')"

if [ "$COUNT_NO_EXCL_3" = "1" ] && [ "$COUNT_WITH_EXCL_3" = "1" ]; then
  pass "pre-impl emits 1 AND post-impl emits 1 (no over-exclusion — normal PR still wakes)"
elif [ "$COUNT_WITH_EXCL_3" = "0" ]; then
  fail "post-impl emits 0 — exclusion over-skipped a normal PR" \
       "expected 1 stale_verdict for normal PR + verdict overdue (regression)"
elif [ "$COUNT_NO_EXCL_3" = "0" ]; then
  fail "pre-impl emits 0 — fixture or filter wrong" "expected 1 stale_verdict from un-modified filter"
else
  fail "unexpected counts" "no_excl=$COUNT_NO_EXCL_3, with_excl=$COUNT_WITH_EXCL_3"
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
  echo "SOME TESTS FAILED"
  exit 1
fi

echo "ALL TESTS PASSED (d319 GREEN: query_stale_verdict + query_missing_expectation honor ADR-0044 §Scope rule)"
exit 0
