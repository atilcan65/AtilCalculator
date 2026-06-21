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
# Summary
# ============================================================================
printf "\n${B}==== SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
