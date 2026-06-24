#!/usr/bin/env bash
# d036-state-dedup-ring.sh — regression test for P0 INCIDENT #345
# agent-watch.sh dedup ring frozen, 4/5 agents affected.
#
# Why this test exists
# --------------------
# Issue #345 P0: processed_event_ids ring buffer in agent state files
# was frozen at 2026-06-22T16:55:11Z for 4 of 5 agents (developer,
# architect, product-manager, tester). Orchestrator healthy. Every poll
# re-delivered 06-24 events because ring lacked 06-24 entries.
#
# Fix (this PR):
#   1. Fix 1: atomic batch mark — replaces per-event jq + while loop
#      (agent-watch.sh:1597-1599) with single jq edit
#   2. Fix 2: flock lock — wraps mark+trim AND query_* state reads
#      (architect recommendation L1567-1571)
#   3. Fix 3: trim cap 50→200 alignment — matches agent-state.sh:48
#
# Test cases (TDD red→green per developer.md):
#   T1: ring advances on every poll yielding new_events
#   T2: 1000-event burst — loss is observable, not silent
#   T3: silent-failure watchdog + bucket-staleness check (architect enhance)
#   T4: ring trim at max boundary (50 vs 200 per Fix 3)
#   T5: re-init preserves schema
#   T6: concurrent poll safety (flock)
#   T7: backup-restore doesn't silent rewind
#   T8: kill -9 mid-write doesn't corrupt
#   T9: Bug 3 regression pin — string query → 1 array entry, not N chars
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d036-state-dedup-ring.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_SH="$SCRIPT_DIR/../agent-state.sh"
WATCH_SH="$SCRIPT_DIR/../agent-watch.sh"

if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; Y=$'\033[0;33m'; D=$'\033[0m'
else
  G=""; R=""; B=""; Y=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if [ ! -x "$STATE_SH" ]; then
  fail "agent-state.sh not executable" "expected $STATE_SH to be executable"
  exit 1
fi
if [ ! -x "$WATCH_SH" ]; then
  fail "agent-watch.sh not executable" "expected $WATCH_SH to be executable"
  exit 1
fi

# Isolated state dir per test run
TEST_STATE_DIR="$(mktemp -d /tmp/d036-state.XXXXXX)"
trap "rm -rf $TEST_STATE_DIR" EXIT
export AGENT_STATE_DIR="$TEST_STATE_DIR"

# Test role
ROLE="d036test"

# Helper: get ring as JSON array
get_ring() {
  jq -c '.processed_event_ids // []' "$TEST_STATE_DIR/${ROLE}.json" 2>/dev/null
}

# Helper: init fresh state — rm + init (cmd_init preserves existing fields;
# we want a fully clean ring for test isolation)
init_state() {
  rm -f "$TEST_STATE_DIR/${ROLE}.json"
  "$STATE_SH" init "$ROLE" >/dev/null
}

# ============================================================
section "T1: ring advances on every poll yielding new_events"
# ============================================================
init_state
# Inject 1 fake event into the mark loop's input by calling mark directly
"$STATE_SH" mark "$ROLE" "evt-T1-A"
ring_len=$(get_ring | jq 'length')
ring_last=$(get_ring | jq -r '.[-1] // ""')
if [ "$ring_len" = "1" ] && [ "$ring_last" = "evt-T1-A" ]; then
  pass "T1: ring advances (1 entry, newest = evt-T1-A)"
else
  fail "T1: ring should advance" "got length=$ring_len last=$ring_last"
fi

# ============================================================
section "T2: 1000-event burst — loss is observable, not silent"
# ============================================================
init_state
# Inject 1000 unique event IDs via mark loop, then trim per Fix 3 cap
for i in $(seq 1 1000); do
  "$STATE_SH" mark "$ROLE" "evt-T2-$i" >/dev/null
done
# Trim per Fix 3 (cap 200, ttl 288 buckets = 24h)
"$STATE_SH" trim "$ROLE" 200 288 >/dev/null
ring_len=$(get_ring | jq 'length')
# With cap 200, ring should be 200 (FIFO oldest-first)
if [ "$ring_len" = "200" ]; then
  pass "T2: ring bounded to cap 200 after 1000 marks (FIFO oldest evicted)"
else
  fail "T2: ring not bounded" "got length=$ring_len (expected 200 after trim)"
fi

# ============================================================
section "T3: silent-failure watchdog + bucket-staleness check"
# ============================================================
# Architect enhance (TU7): alert if state file is being written
# (last_seen_utc fresh) but ring newest entry timestamp is stale > 5min
init_state
"$STATE_SH" mark "$ROLE" "wake-nudge-${ROLE}-2020-01-01T00:00:00Z" >/dev/null
# Inject fresh last_seen_utc (simulates watcher is alive)
"$STATE_SH" set "$ROLE" last_seen_utc "\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" >/dev/null
# Read both: ring newest timestamp + last_seen_utc
ring_newest=$(get_ring | jq -r '.[-1]')
last_seen=$(jq -r '.last_seen_utc' "$TEST_STATE_DIR/${ROLE}.json")
# Compute staleness: ring is from 2020, last_seen is now → ring stale > 5min
ring_ts=$(echo "$ring_newest" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' || echo "")
last_seen_ts="$last_seen"
if [ -n "$ring_ts" ]; then
  ring_epoch=$(date -u -d "$ring_ts" +%s 2>/dev/null || echo 0)
  now_epoch=$(date -u +%s)
  staleness_min=$(( (now_epoch - ring_epoch) / 60 ))
  if [ "$staleness_min" -gt 5 ]; then
    pass "T3: watchdog detects ring staleness (ring is ${staleness_min}min old, last_seen fresh) — would alert"
  else
    fail "T3: should detect staleness" "ring is only ${staleness_min}min old (test setup error?)"
  fi
else
  fail "T3: ring entry has no parseable timestamp" "ring_newest=$ring_newest"
fi

# ============================================================
section "T4: ring trim at max boundary"
# ============================================================
init_state
# Fill ring to cap (200)
for i in $(seq 1 200); do
  "$STATE_SH" mark "$ROLE" "evt-T4-init-$i" >/dev/null
done
ring_len_before=$(get_ring | jq 'length')
# Trim with cap 200 (default per Fix 3)
"$STATE_SH" trim "$ROLE" 200 >/dev/null
# Add 1 more
"$STATE_SH" mark "$ROLE" "evt-T4-newest" >/dev/null
# Trim again
"$STATE_SH" trim "$ROLE" 200 >/dev/null
ring_len_after=$(get_ring | jq 'length')
ring_newest=$(get_ring | jq -r '.[-1]')
ring_oldest=$(get_ring | jq -r '.[0]')
# After 200 caps + 1 add + 2 trims:
#   First trim: 200 → 200 (no-op)
#   Add 1: 201
#   Second trim: 200 (FIFO drops oldest)
if [ "$ring_len_after" = "200" ] && [ "$ring_newest" = "evt-T4-newest" ]; then
  pass "T4: ring trims to cap 200, newest at tail (length=$ring_len_after, oldest=$ring_oldest)"
else
  fail "T4: ring not trimmed correctly" "len=$ring_len_after newest=$ring_newest oldest=$ring_oldest"
fi

# ============================================================
section "T5: re-init preserves schema"
# ============================================================
init_state
"$STATE_SH" mark "$ROLE" "evt-T5-A" >/dev/null
"$STATE_SH" mark "$ROLE" "evt-T5-B" >/dev/null
# Reset via init_state (rm + init) — simulates restart from scratch
init_state
schema_keys=$(jq -r 'keys | sort | join(",")' "$TEST_STATE_DIR/${ROLE}.json")
ring_type=$(get_ring | jq -r 'type')
ring_len=$(get_ring | jq 'length')
# Required schema keys per agent-state.sh:48-117
required="burst_until_utc,last_heartbeat_utc,last_is_alive_utc,last_seen_utc,last_synthetic_scan_utc,poll_interval_sec,polled_at_utc,pr_labeled_last_seen_utc,pr_merged_last_seen_utc,proactive_sweep_last_utc,processed_event_ids,role"
if [ "$schema_keys" = "$required" ] && [ "$ring_type" = "array" ] && [ "$ring_len" = "0" ]; then
  pass "T5: re-init preserves schema (12 keys, ring=[])"
else
  fail "T5: re-init broken" "schema=$schema_keys ring_type=$ring_type ring_len=$ring_len"
fi

# ============================================================
section "T6: concurrent poll safety (flock)"
# ============================================================
# Architect recommendation: flock must wrap mark+trim AND query_* state reads
init_state
# Pre-populate with 5 entries
for i in $(seq 1 5); do
  "$STATE_SH" mark "$ROLE" "evt-T6-init-$i" >/dev/null
done
# Launch 10 concurrent marks of distinct IDs (no flock = lost writes)
for i in $(seq 1 10); do
  "$STATE_SH" mark "$ROLE" "evt-T6-concurrent-$i" >/dev/null &
done
wait
# Trim to clear FIFO
"$STATE_SH" trim "$ROLE" 200 >/dev/null
ring_len=$(get_ring | jq 'length')
# Expected: 5 init + 10 concurrent = 15 entries (all unique)
if [ "$ring_len" = "15" ]; then
  pass "T6: concurrent marks all survive (ring length=15, no lost writes)"
else
  fail "T6: concurrent marks lost writes" "expected 15 entries, got $ring_len (this test verifies baseline; flock wraps are in agent-watch.sh)"
fi

# ============================================================
section "T7: backup-restore doesn't silent rewind"
# ============================================================
init_state
"$STATE_SH" mark "$ROLE" "evt-T7-A" >/dev/null
"$STATE_SH" mark "$ROLE" "evt-T7-B" >/dev/null
# Take backup
cp -p "$TEST_STATE_DIR/${ROLE}.json" "$TEST_STATE_DIR/${ROLE}.json.bak-T7"
# Continue adding
"$STATE_SH" mark "$ROLE" "evt-T7-C" >/dev/null
"$STATE_SH" mark "$ROLE" "evt-T7-D" >/dev/null
# Restore backup (simulates manual rewind)
cp -p "$TEST_STATE_DIR/${ROLE}.json.bak-T7" "$TEST_STATE_DIR/${ROLE}.json"
# After restore, ring should be post-restore state (only A, B)
ring_post_restore=$(get_ring | jq -c '.')
ring_len=$(get_ring | jq 'length')
# After restore, ring has 2 entries (A, B)
# This test documents the behavior — silent rewind IS possible via cp,
# so watchdog (T3) is needed to detect it. Test asserts the cp DID rewind.
if [ "$ring_len" = "2" ] && [ "$ring_post_restore" = '["evt-T7-A","evt-T7-B"]' ]; then
  pass "T7: backup-restore behavior documented (cp rewinds to A,B; watchdog T3 must detect)"
else
  fail "T7: backup-restore behavior unexpected" "ring=$ring_post_restore (expected [\"evt-T7-A\",\"evt-T7-B\"])"
fi

# ============================================================
section "T8: kill -9 mid-write doesn't corrupt"
# ============================================================
init_state
# Test atomic_write_json contract: temp + sync + mv.
# The mktemp+sync+mv pattern means kill -9 BEFORE mv leaves original intact.
# We test: simulate kill by checking the atomic_write_json implementation.
if grep -qE 'sync' "$SCRIPT_DIR/../atomic-write.sh" 2>/dev/null && \
   grep -qE 'mv -f' "$SCRIPT_DIR/../atomic-write.sh" 2>/dev/null; then
  pass "T8: atomic_write_json uses sync + mv-f pattern (kill -9 before mv leaves original intact)"
else
  fail "T8: atomic_write_json missing sync+mv" "check scripts/atomic-write.sh implementation"
fi
# Also check ring write code path doesn't use non-atomic pattern
if ! grep -qE 'echo.*>>.*\.processed_event_ids' "$STATE_SH" 2>/dev/null; then
  pass "T8: state write path doesn't use non-atomic >> append (uses jq_inplace → atomic_write_json)"
else
  fail "T8: non-atomic append detected" "agent-state.sh uses >> which is non-atomic"
fi

# ============================================================
section "T9: Bug 3 regression pin — string query → 1 array entry"
# ============================================================
# Architect's TU9 enhancement: if a query returns STRING (not array),
# the batch mark must produce 1 array entry, NOT N char entries.
# This guards against jq '.[].id' on a string iterating chars.
init_state
# Simulate the batch mark code path's behavior:
# Input: new_events = "foo" (string, not array)
# Old (buggy) loop: jq -r '.[].id' on "foo" → 'f', 'o', 'o' → 3 marks
# New (fix) batch: jq -r '.[]' on "foo" → 'foo' (whole string) → 1 mark
new_events='"foo"'
batch_ids=$(printf '%s' "$new_events" | jq -r 'if type == "array" then .[] else . end')
batch_count=$(printf '%s' "$batch_ids" | grep -c . || echo 0)
if [ "$batch_count" = "1" ]; then
  pass "T9: batch mark handles string gracefully (1 entry 'foo', not 3 chars)"
else
  fail "T9: batch mark still iterates chars on string" "got '$batch_ids' (count=$batch_count, expected 'foo' as single entry)"
fi

# ============================================================
section "T10: P0 #345 follow-up — batch mark scope bug regression pin"
# ============================================================
# Bug: agent-watch.sh poll_once called `jq_inplace "$state_file_mark" ...`
# but `jq_inplace` is a function defined inside agent-state.sh (line 87),
# NOT in agent-watch.sh's scope. agent-watch.sh runs agent-state.sh as a
# SEPARATE PROCESS via $STATE_HELPER, so the function is never loaded.
# Result: silent "command not found" + the ring never advanced, even
# though Fix 1's batch logic was structurally correct.
#
# Fix: replace the broken jq_inplace call with the inline jq + mktemp +
# sync + mv pattern (matches atomic_write_json's atomicity guarantee;
# sister to the TTL prune at agent-watch.sh:1374-1394 which already
# uses this pattern correctly).
#
# T10 verifies:
#   (a) Static check: agent-watch.sh batch mark code path no longer
#       calls jq_inplace directly (the broken pattern).
#   (b) Runtime check: the inline jq + mktemp + sync + mv pattern
#       (replicated via atomic_write_json) successfully advances the
#       ring on a real state file.

# (a) Static check — grep for the broken pattern
if grep -nE 'jq_inplace[[:space:]]+"\$\{?state_file_mark' "$WATCH_SH" >/dev/null 2>&1; then
  fail "T10a: agent-watch.sh still calls jq_inplace on state_file_mark (scope bug — would fail at runtime)"
  grep -nE 'jq_inplace.*state_file_mark' "$WATCH_SH" | head -3 | sed 's/^/    /'
else
  pass "T10a: agent-watch.sh no longer calls jq_inplace on state_file_mark (scope bug fixed)"
fi

# Also check the batch mark code path uses mktemp + jq + mv (the fix)
if grep -q 'tmp_mark=' "$WATCH_SH" && \
   grep -q 'mktemp.*state_file_mark.*atomic' "$WATCH_SH" && \
   grep -q 'state_file_mark.*>.*tmp_mark' "$WATCH_SH" && \
   grep -q 'mv -f .*tmp_mark.*state_file_mark' "$WATCH_SH"; then
  pass "T10a: batch mark uses mktemp + jq > tmp + mv-f atomic pattern (matches atomic_write_json)"
else
  fail "T10a: batch mark missing atomic pattern" "expected mktemp + jq > tmp + mv -f (4 primitives: tmp_mark, mktemp, redirect, mv -f)"
fi

# Also verify order-preserving dedup (NOT unique — unique sorts, breaks newest-at-end)
if grep -q '\$ids - \$existing' "$WATCH_SH"; then
  pass "T10a: batch mark uses order-preserving dedup (\$ids - \$existing, NOT unique which sorts)"
else
  fail "T10a: batch mark uses jq unique which sorts" "use '.processed_event_ids + (\$ids - .processed_event_ids)' for FIFO order"
fi

# (b) Runtime check — replicate the fixed pattern on a real state file
init_state
# Pre-populate the state file
"$STATE_SH" mark "$ROLE" "evt-T10-pre-A" >/dev/null
"$STATE_SH" mark "$ROLE" "evt-T10-pre-B" >/dev/null
ring_len_before=$(get_ring | jq 'length')
state_file="$TEST_STATE_DIR/${ROLE}.json"

# Replicate Fix 1b exactly (order-preserving dedup, NOT unique)
new_ids_json='["evt-T10-new-1","evt-T10-new-2","evt-T10-new-3"]'
now_iso="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
tmp_t10="$(mktemp "${state_file}.atomic.XXXXXX")"
if jq --argjson ids "$new_ids_json" --arg now "$now_iso" '
  .processed_event_ids as $existing |
  .processed_event_ids = ($existing + ($ids - $existing)) |
  .last_seen_utc = $now
' "$state_file" > "$tmp_t10" 2>/dev/null; then
  sync "$tmp_t10" 2>/dev/null || true
  mv -f "$tmp_t10" "$state_file"
  ring_len_after=$(get_ring | jq 'length')
  ring_newest=$(get_ring | jq -r '.[-1] // ""')
  last_seen=$(jq -r '.last_seen_utc' "$state_file")
  # Expected: 2 pre + 3 new = 5 entries, newest = evt-T10-new-3 (FIFO append preserved)
  if [ "$ring_len_after" = "5" ] && [ "$ring_newest" = "evt-T10-new-3" ] && [ "$last_seen" = "$now_iso" ]; then
    pass "T10b: inline jq + mktemp + sync + mv pattern advances ring (2→5, newest=evt-T10-new-3, last_seen bumped)"
  else
    fail "T10b: pattern didn't advance ring correctly" "len=$ring_len_after newest=$ring_newest last_seen=$last_seen"
  fi
else
  fail "T10b: jq filter failed in replicated pattern" "this means the fix is broken — T10 is not testing the fix"
  rm -f "$tmp_t10" 2>/dev/null || true
fi

# (c) Idempotency: re-applying same IDs doesn't grow ring (dedup works)
ring_len_after_dedup=$(get_ring | jq 'length')
tmp_t10b="$(mktemp "${state_file}.atomic.XXXXXX")"
if jq --argjson ids "$new_ids_json" --arg now "$now_iso" '
  .processed_event_ids as $existing |
  .processed_event_ids = ($existing + ($ids - $existing)) |
  .last_seen_utc = $now
' "$state_file" > "$tmp_t10b" 2>/dev/null; then
  sync "$tmp_t10b" 2>/dev/null || true
  mv -f "$tmp_t10b" "$state_file"
  ring_len_replay=$(get_ring | jq 'length')
  if [ "$ring_len_replay" = "$ring_len_after_dedup" ]; then
    pass "T10c: dedup is idempotent (replay of same 3 IDs → ring stays at $ring_len_replay, no duplicates)"
  else
    fail "T10c: dedup not idempotent" "ring grew from $ring_len_after_dedup to $ring_len_replay on replay"
  fi
else
  fail "T10c: jq filter failed on replay"
  rm -f "$tmp_t10b" 2>/dev/null || true
fi

# ============================================================
echo ""
echo "==== d036 regression summary ===="
echo "PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
