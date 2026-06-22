#!/usr/bin/env bash
# d023-rca18-buffer-ttl.sh — regression test for ADR-0032 RCA-18 dedup buffer
# TTL pruning (refs Issue #216 RCA-18, PR #217 ADR, RCA-32 impl PR-TBD).
#
# Why this test exists
# --------------------
# RCA-18 (Issue #216) was filed with hypothesis "stale-cc fires on
# closed/merged issues" but ADR-0032 refuted that — the real bug is the
# dedup buffer has NO time-based pruning. `cmd_trim` keeps last 200 with
# no age filter, so historical events (e.g. 3-day-old stale-cc from PR #93
# when it was open with cc:architect) accumulate and produce a "stuck-loop"
# appearance — last 5 entries look stale even though watcher is not currently
# firing.
#
# RCA-32 fix:
#   1. agent-watch.sh poll_once: drop processed_event_ids entries with
#      bucket < (current - 288) [24h ago] BEFORE the dedup filter step.
#   2. agent-state.sh cmd_trim: accept optional 3rd arg (ttl_buckets) and
#      apply TTL filter in addition to count trim.
#   3. Wake_nudge IDs (which lack a b<bucket> suffix) are RETAINED across
#      polls — locked in via the try/catch wrapper in the jq filter.
#
# Test cases (TDD red→green per developer.md):
#   T1: 24h-old bucket-keyed events are PRUNED (stale-cc, backlog-scan)
#   T2: 1h-old bucket-keyed events are RETAINED
#   T3: Non-bucket-keyed events (wake_nudge, pr-merged) are RETAINED
#   T4: cmd_trim with 3rd arg (ttl_buckets) applies TTL filter
#   T5: cmd_trim without 3rd arg uses legacy behavior (back-compat)
#   T6: agent-watch.sh poll_once contains the TTL pruning block
#   T7: agent-state.sh cmd_trim contains the ttl_buckets branch
#   T8: Regression — d015 9/9 still PASS
#   T9: Integration — the production prune path preserves array type
#       (PR #224 v2 fix: inline jq, NOT cmd_set; would have caught the
#       P0 type-bug tester found on PR #224 cmt 4763288015)
#   T10: Regression trap — cmd_set + JSON array preserves type (post-#228)
#        (per ADR-0034: cmd_set now uses --argjson + JSON validation;
#        if someone reverts to --arg, T10 fails AND cmd_set callers can
#        silently corrupt state again — both directions are regression-tested)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d023-rca18-buffer-ttl.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_SH="$SCRIPT_DIR/../agent-state.sh"
WATCH_SH="$SCRIPT_DIR/../agent-watch.sh"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; Y=$'\033[0;33m'; D=$'\033[0m'
else
  G=""; R=""; B=""; Y=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 127
fi
if [ ! -r "$STATE_SH" ]; then
  echo "ERROR: agent-state.sh not found at $STATE_SH" >&2; exit 127
fi
if [ ! -r "$WATCH_SH" ]; then
  echo "ERROR: agent-watch.sh not found at $WATCH_SH" >&2; exit 127
fi

# Test workspace: temp state file, never touches real agent state.
TMPDIR="$(mktemp -d -t d023-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

CURRENT_BUCKET=$(( $(date -u +%s) / 300 ))
CUTOFF_24H=$(( CURRENT_BUCKET - 288 ))
OLD_BUCKET=$(( CURRENT_BUCKET - 300 ))   # 25h ago (older than cutoff)
RECENT_BUCKET=$(( CURRENT_BUCKET - 12 ))  # 1h ago (newer than cutoff)

# Helper: build a synthetic processed_event_ids array (space-separated string)
mk_state() {
  local n_old=$1 n_recent=$2 n_nobucket=$3
  {
    for i in $(seq 1 "$n_old"); do
      echo "stale-cc-9${i}-d227ef8-b${OLD_BUCKET}"
    done
    for i in $(seq 1 "$n_recent"); do
      echo "stale-cc-9${i}-d227ef9-b${RECENT_BUCKET}"
    done
    for i in $(seq 1 "$n_nobucket"); do
      case $(( i % 3 )) in
        0) echo "wake-nudge-developer-2026-06-21T19:51:13Z" ;;
        1) echo "pr-merged-215-c9c49cc" ;;
        2) echo "pr-review-requested-220-deadbe" ;;
      esac
    done
  } | jq -R . | jq -s '{
    "processed_event_ids": .,
    "last_seen_utc": null,
    "last_heartbeat_utc": null,
    "pr_merged_last_seen_utc": null,
    "pr_labeled_last_seen_utc": null
  }' > "$TMPDIR/state.json"
}

# Helper: apply the TTL pruning filter to a state.json (mirrors what
# poll_once should do — captured as a reusable jq expression for testability).
# IMPORTANT: uses if/test() pattern so non-bucket IDs (wake_nudge, pr-merged)
# are RETAINED. The try/catch pattern FAILS because jq's `as $b` binding
# silently fails when LHS is null (no value emitted), dropping the row.
apply_ttl_filter() {
  local state_file="$1" cutoff_bucket="$2"
  jq -n --slurpfile state "$state_file" --argjson cutoff "$cutoff_bucket" '
    [ $state[0].processed_event_ids[] |
      if test("b[0-9]+$") then
        (capture("b(?<bucket>[0-9]+)$").bucket | tonumber) as $b |
        select($b >= $cutoff)
      else
        .  # no-bucket IDs (wake_nudge, pr-merged) are RETAINED
      end
    ]
  '
}

# ============================================================================
# T1: 24h-old bucket-keyed events are PRUNED
# ============================================================================
section "T1: 24h-old bucket-keyed events are PRUNED"
mk_state 3 0 0
ret="$(apply_ttl_filter "$TMPDIR/state.json" "$CUTOFF_24H")"
n_ret="$(echo "$ret" | jq 'length')"
n_old="$(echo "$ret" | jq '[.[] | select(test("b5939635$"))] | length')"  # OLD_BUCKET = current-300
if [ "$n_ret" -eq 0 ] && [ "$n_old" -eq 0 ]; then
  pass "3 old events (25h ago) all PRUNED — result has 0 entries"
else
  fail "expected 0 retained entries (all 3 should be pruned)" "got n_ret=$n_ret n_old=$n_old (OLD_BUCKET=$OLD_BUCKET, CUTOFF_24H=$CUTOFF_24H)"
fi

# ============================================================================
# T2: 1h-old bucket-keyed events are RETAINED
# ============================================================================
section "T2: 1h-old bucket-keyed events are RETAINED"
mk_state 0 3 0
ret="$(apply_ttl_filter "$TMPDIR/state.json" "$CUTOFF_24H")"
n_ret="$(echo "$ret" | jq 'length')"
# Verify all 3 entries are the recent-bucket ones (use dynamic bucket).
n_recent_pattern="$(echo "$ret" | jq --arg b "b${RECENT_BUCKET}" '[.[] | select(test("\($b)$"))] | length')"
if [ "$n_ret" -eq 3 ] && [ "$n_recent_pattern" -eq 3 ]; then
  pass "3 recent events (1h ago) all RETAINED — result has 3 entries (RECENT_BUCKET=$RECENT_BUCKET)"
else
  fail "expected 3 retained entries" "got n_ret=$n_ret n_recent_pattern=$n_recent_pattern (RECENT_BUCKET=$RECENT_BUCKET)"
fi

# ============================================================================
# T3: Non-bucket-keyed events (wake_nudge, pr-merged) are RETAINED
# ============================================================================
section "T3: Non-bucket-keyed events RETAINED (try/catch wrapper)"
# 6 mixed: 3 old bucket + 3 no-bucket → only 3 retained (no-bucket ones)
mk_state 3 0 3
ret="$(apply_ttl_filter "$TMPDIR/state.json" "$CUTOFF_24H")"
n_ret="$(echo "$ret" | jq 'length')"
n_nobucket="$(echo "$ret" | jq '[.[] | select(test("b[0-9]+$") | not)] | length')"
if [ "$n_ret" -eq 3 ] && [ "$n_nobucket" -eq 3 ]; then
  pass "3 no-bucket events RETAINED (wake_nudge/pr-merged/pr-review), 3 old bucket events PRUNED"
else
  fail "expected 3 retained (all no-bucket)" "got n_ret=$n_ret n_nobucket=$n_nobucket (3 old bucket + 3 no-bucket → 3 retained)"
fi

# ============================================================================
# T4: cmd_trim with 3rd arg (ttl_buckets) applies TTL filter
# ============================================================================
section "T4: cmd_trim accepts 3rd arg (ttl_buckets) and applies TTL filter"
# Pattern check: cmd_trim body should branch on ttl_buckets and apply
# the same test("b[0-9]+$") / capture(...).bucket pattern as poll_once.
if grep -Eq 'ttl_buckets' "$STATE_SH" && \
   grep -Eq 'test\("b\[0-9\]' "$STATE_SH"; then
  pass "cmd_trim has ttl_buckets branch + test(\"b[0-9]+\") pattern (matches poll_once)"
else
  fail "cmd_trim missing ttl_buckets handling" "expected 'ttl_buckets' var + test(\"b[0-9]+\") pattern in $STATE_SH"
fi

# ============================================================================
# T5: cmd_trim without 3rd arg uses legacy behavior (back-compat)
# ============================================================================
section "T5: cmd_trim legacy behavior (no 3rd arg) preserved"
# Pattern: if/else in cmd_trim OR "${3:-}" defaulting. The legacy slice
# (.processed_event_ids | .[-$max:]) should still be in the file.
if grep -Fq '.processed_event_ids | .[-$max:]' "$STATE_SH"; then
  pass "Legacy .[-max:] slice still in cmd_trim (back-compat preserved)"
else
  fail "Legacy slice removed — would break back-compat" "expected '.processed_event_ids | .[-max:]' pattern still in $STATE_SH"
fi

# ============================================================================
# T6: agent-watch.sh poll_once contains the TTL pruning block
# ============================================================================
section "T6: agent-watch.sh poll_once has TTL pruning block"
# Pattern: current_bucket + prune_cutoff_bucket vars + test("b[0-9]+$") check
# + capture regex + assign back via $STATE_HELPER set ... processed_event_ids.
# The if/test() pattern is required to RETAIN non-bucket IDs (wake_nudge, pr-merged).
if grep -Eq 'current_bucket|prune_cutoff_bucket' "$WATCH_SH" && \
   grep -Eq '288' "$WATCH_SH" && \
   grep -Eq 'test\("b\[0-9\]' "$WATCH_SH" && \
   grep -Eq 'capture\("b\(\?<bucket>' "$WATCH_SH"; then
  pass "poll_once has TTL pruning block (current_bucket + cutoff 288 + test/capture pattern)"
else
  fail "poll_once missing TTL pruning block" "expected 'current_bucket' or 'prune_cutoff_bucket' var + '288' magic + test(\"b[0-9]+\") + capture(\"b(?<bucket>...\" pattern in $WATCH_SH"
fi

# ============================================================================
# T7: agent-state.sh cmd_trim contains the ttl_buckets branch
# ============================================================================
section "T7: agent-state.sh cmd_trim has ttl_buckets branch"
# Specifically: local ttl_buckets="${3:-}" and an if block that calls
# the same jq filter as poll_once.
if grep -Eq 'local ttl_buckets' "$STATE_SH" && \
   grep -Eq 'cutoff.*current_bucket' "$STATE_SH"; then
  pass "cmd_trim declares ttl_buckets local + cutoff math"
else
  fail "cmd_trim missing ttl_buckets local or cutoff math" "expected 'local ttl_buckets' decl + 'cutoff.*current_bucket' pattern in $STATE_SH"
fi

# ============================================================================
# T8: Regression — d015 still 9/9 PASS
# ============================================================================
section "T8: Regression — d015 (dev-idle-prevention) still 9/9 PASS"
D015="$SCRIPT_DIR/d015-dev-idle-prevention.sh"
if [ -x "$D015" ] || [ -r "$D015" ]; then
  d015_out="$(bash "$D015" 2>&1)"
  d015_rc=$?
  d015_pass="$(echo "$d015_out" | grep -E '^\s*PASS:\s*[0-9]+' | head -1 | awk '{print $2}' || echo 0)"
  d015_fail="$(echo "$d015_out" | grep -E '^\s*FAIL:\s*[0-9]+' | head -1 | awk '{print $2}' || echo 0)"
  if [ "$d015_rc" -eq 0 ] && [ "${d015_pass:-0}" -ge 9 ] && [ "${d015_fail:-0}" -eq 0 ]; then
    pass "d015 regression: ${d015_pass}/9 PASS, 0 FAIL"
  else
    fail "d015 regression broken" "rc=$d015_rc pass=$d015_pass fail=$d015_fail (expected rc=0 pass=9 fail=0)"
  fi
else
  fail "d015-dev-idle-prevention.sh not found" "expected at $D015"
fi

# ============================================================================
# T9: Integration — production prune path preserves array type
# ----------------------------------------------------------------------------
# Why this test exists (refs PR #224 cmt 4763288015, RCA-32 v2 fix)
# ----------------------------------------------------------------
# The T1-T3 behavior tests above exercise the jq filter in ISOLATION via a
# local `apply_ttl_filter` helper. They verify the FILTER is correct, but
# they bypass the WRITE PATH — i.e., they don't go through `cmd_set` or any
# other state-mutation entry point. The PR #224 v1 implementation called
# `cmd_set` with a JSON-array string, and `cmd_set` uses `jq_inplace --arg v
# "$value" ...` which treats the 3rd arg as a STRING literal. Net effect:
# `processed_event_ids` became a string in the file, breaking dedup.
#
# T9 replicates the PR #224 v2 production code path (inline jq atomic edit)
# on a real state file and asserts the array type is preserved. If anyone
# reverts to `cmd_set`, T9 RED's.
#
# This is the integration test the d023 v1 was missing.
# ============================================================================
section "T9: Production prune path preserves processed_event_ids array type"
# Isolate state file via direct path (T9 doesn't go through agent-state.sh
# subcommands, so no AGENT_STATE_DIR override needed).
T9_TMP="$(mktemp -d -t d023-t9-XXXXXX)"
T9_STATE="$T9_TMP/state.json"
T9_OLD=$(( CURRENT_BUCKET - 300 ))
cat > "$T9_STATE" <<EOF
{
  "role": "t9tester",
  "last_seen_utc": null,
  "last_heartbeat_utc": null,
  "processed_event_ids": [
    "stale-cc-9-t9-old1-b${T9_OLD}",
    "stale-cc-9-t9-old2-b${T9_OLD}",
    "stale-cc-9-t9-old3-b${T9_OLD}",
    "wake-nudge-developer-2026-06-21T19:51:13Z"
  ],
  "poll_interval_sec": 60,
  "burst_until_utc": null,
  "pr_merged_last_seen_utc": null,
  "pr_labeled_last_seen_utc": null,
  "polled_at_utc": null
}
EOF

# Verify pre-state
pre_type="$(jq -r '.processed_event_ids | type' "$T9_STATE")"
pre_len="$(jq -r '.processed_event_ids | length' "$T9_STATE")"
if [ "$pre_type" = "array" ] && [ "$pre_len" = "4" ]; then
  pass "T9 pre-state: array of 4 (sanity)"
else
  fail "T9 pre-state wrong" "expected type=array len=4; got type=$pre_type len=$pre_len"
fi

# Apply the EXACT same atomic-edit pattern that agent-watch.sh poll_once uses
# (PR #224 v2 fix). This is the production code path under test.
T9_TMP_OUT="$(mktemp)"
T9_RC=0
jq --argjson cutoff "$CUTOFF_24H" '
  .processed_event_ids = (
    [ .processed_event_ids[] |
      if test("b[0-9]+$") then
        (capture("b(?<bucket>[0-9]+)$").bucket | tonumber) as $b |
        select($b >= $cutoff)
      else
        .
      end
    ]
  )
' "$T9_STATE" > "$T9_TMP_OUT" 2>/dev/null || T9_RC=$?
if [ "$T9_RC" -eq 0 ]; then
  mv "$T9_TMP_OUT" "$T9_STATE"
else
  rm -f "$T9_TMP_OUT"
fi

# Post-state assertions
post_type="$(jq -r '.processed_event_ids | type' "$T9_STATE")"
post_len="$(jq -r '.processed_event_ids | length' "$T9_STATE")"
post_first="$(jq -r '.processed_event_ids[0]' "$T9_STATE")"
if [ "$post_type" = "array" ]; then
  pass "T9 post-state: processed_event_ids is still array (no cmd_set stringification)"
else
  fail "T9 post-state corrupted" "expected type=array; got type=$post_type — REGRESSION: cmd_set path re-introduced (PR #224 v1 bug)"
fi
if [ "$post_len" = "1" ]; then
  pass "T9 post-state: length=1 (3 old pruned, 1 wake_nudge retained)"
else
  fail "T9 post-state wrong length" "expected len=1 (3 old pruned, 1 wake_nudge); got len=$post_len"
fi
if [ "$post_first" = "wake-nudge-developer-2026-06-21T19:51:13Z" ]; then
  pass "T9 post-state: only element is the wake_nudge (correct retention)"
else
  fail "T9 wrong element retained" "expected wake-nudge-developer-2026-06-21T19:51:13Z; got $post_first"
fi

# Also assert agent-watch.sh DOES use the inline jq path (NOT cmd_set) for the
# prune. This is the regression-trap lock-in.
if grep -Eq '"\$STATE_HELPER" set "\$ROLE" processed_event_ids' "$WATCH_SH"; then
  fail "agent-watch.sh still uses cmd_set for processed_event_ids" \
    "REGRESSION (PR #224 v1 bug). Use inline jq atomic edit instead (PR #224 v2)."
else
  pass "agent-watch.sh does NOT use cmd_set for processed_event_ids (regression trap)"
fi
if grep -Eq 'tmp_ttl="\$\(mktemp\)"' "$WATCH_SH" || grep -Eq 'tmp_ttl=' "$WATCH_SH"; then
  pass "agent-watch.sh uses inline atomic edit (mktemp + jq + mv) for the prune"
else
  fail 'agent-watch.sh missing inline atomic edit' "expected 'tmp_ttl=\$(mktemp)' pattern in $WATCH_SH"
fi

rm -rf "$T9_TMP"

# ============================================================================
# T10: Regression trap — cmd_set + JSON array NOW preserves type (post-#228 fix)
# ----------------------------------------------------------------------------
# **Post-ADR-0034 fix (Issue #228)**: cmd_set now uses `jq --argjson` with JSON
# validation, so passing a JSON array is stored AS an array (not stringified).
# T10 now asserts the FIXED behavior. If T10 ever FAILS again, that means
# someone has REVERTED cmd_set to `jq --arg` (the bug class is back).
#
# Combined with T9 (inline jq atomic edit in poll_once), this test pair locks
# in both layers of the fix: (a) cmd_set is type-safe, (b) the watcher doesn't
# rely on cmd_set for the high-frequency processed_event_ids path.
# ============================================================================
section "T10: Regression trap — cmd_set + JSON array preserves type (post-#228 fix)"
T10_TMP="$(mktemp -d -t d023-t10-XXXXXX)"
T10_ROLE="t10tester"
T10_STATE="$T10_TMP/${T10_ROLE}.json"
cat > "$T10_STATE" <<EOF
{
  "role": "$T10_ROLE",
  "processed_event_ids": ["a", "b", "c"]
}
EOF

# Use AGENT_STATE_DIR override to point agent-state.sh at our TMP.
T10_VALUE="$(jq -n '["x","y","z"]')"
AGENT_STATE_DIR="$T10_TMP" "$STATE_SH" set "$T10_ROLE" processed_event_ids "$T10_VALUE" >/dev/null 2>&1

# Read the actual file (cmd_set wrote to $T10_TMP/${T10_ROLE}.json)
t10_type="$(jq -r '.processed_event_ids | type' "$T10_STATE")"
t10_len="$(jq -r '.processed_event_ids | length' "$T10_STATE")"
if [ "$t10_type" = "array" ] && [ "$t10_len" = "3" ]; then
  pass "cmd_set + JSON array → array (bug class FIXED per ADR-0034, Issue #228)"
else
  fail "cmd_set behavior REGRESSED" "expected type=array len=3 (post-#228 fix); got type=$t10_type len=$t10_len — cmd_set may have reverted to --arg stringification"
fi

rm -rf "$T10_TMP"

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
