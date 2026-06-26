#!/usr/bin/env bash
# d052-agent-watch-hardening.sh — regression test for agent-watch.sh hardening
#   (Issue #461 STORY-d052, Sprint 12 P2 dev TCs, RETRO-005 #26 cmt 4812587954)
#
# Why this test exists
# --------------------
# Issue #414 (5-soul §Dispatch Discipline) surfaced 3 dev-side misses during
# the PR #456+#458 cascade:
#   1. PR #456 closes-anchor gap — dev cache said 'Closes #440 AC2',
#      should have been 'Refs #440 AC2' (binary close doctrine unknown)
#   2. PR #457 cc:developer stale — 953s idle on stale label
#   3. PM RETEST on PR #456 — cross-in-flight noise from PM's stale read
#
# These are wake-loop and dispatch discipline gaps in scripts/agent-watch.sh.
# d052 covers the 4 dev-side hardening TCs from Issue #461 cmt 4812587954.
#
# Sister-pattern to:
#   - d024-agent-wake.sh (ADR-0033 dual-channel wake)
#   - d051-5-soul-dispatch-discipline.sh (Issue #414 test framework, tester lane)
#
# Test cases (per Issue #461 cmt 4812587954, RED-first):
#   T1: agent-watch.sh — self-wake filter (skip wake events whose sender == self)
#   T2: agent-watch.sh — cross-wake re-query hint (peer wake payload includes
#       're-query ground truth before processing' hint)
#   T3: agent-watch.sh — post-compact REPRIME flag (REPRIME mode env var/flag
#       that resets state and re-queries full)
#   T4: agent-watch.sh — stale-state re-query dispatch (periodic re-query
#       when state file age exceeds threshold)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d052-agent-watch-hardening.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH_SH="$SCRIPT_DIR/../agent-watch.sh"
STATE_HELPER="$SCRIPT_DIR/../agent-state.sh"

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
# T1: agent-watch.sh — self-wake filter
# ============================================================================
section "T1: agent-watch.sh — self-wake filter (skip wake events whose sender == self)"
# Pattern: a function or branch that detects when a wake event's sender
# matches the polling role and skips emitting it. The v7 self-cc filter
# (is_author_self_cc_pr, line 558) covers PR-level self-cc, but T1 covers
# the Telegram mirror loop pattern where notify.sh -w echoes back to sender.
#
# Implementation pattern (one of):
#   - Function named is_self_wake / is_self_attribution / self_wake_filter
#   - Variable SENDER_ROLE / SELF_ROLE with comparison logic
#   - Comment block "self-wake filter" or "Telegram mirror"
section "T1: agent-watch.sh — self-wake filter"
if [ ! -f "$WATCH_SH" ]; then
  fail "agent-watch.sh missing" "expected $WATCH_SH"
elif grep -Eq 'self_wake_filter|is_self_wake|self_attribution|SENDER_ROLE|SELF_ROLE' "$WATCH_SH"; then
  pass "self-wake filter pattern present (function or variable for sender == self detection)"
else
  fail "self-wake filter missing" "expected grep hit on 'self_wake_filter|is_self_wake|self_attribution|SENDER_ROLE|SELF_ROLE' — current agent-watch.sh has no mechanism to skip wake events whose sender == self (Telegram mirror loop not addressed)"
fi

# ============================================================================
# T2: agent-watch.sh — cross-wake re-query hint
# ============================================================================
section "T2: agent-watch.sh — cross-wake re-query hint (peer wake payload includes 're-query ground truth' hint)"
# Pattern: when constructing wake events from peer-attributed sources
# (pr_comment_mention, issue_comment_mention, pr_review_requested), the
# event payload should include a hint field like re_query_hint or
# re_query_before_processing that tells the receiving agent to re-query
# ground truth before acting on the wake. This addresses dev miss #3
# (PM RETEST on PR #456 from cross-in-flight noise).
section "T2: agent-watch.sh — cross-wake re-query hint"
if [ ! -f "$WATCH_SH" ]; then
  fail "agent-watch.sh missing" "expected $WATCH_SH"
elif grep -Eq 're_query_hint|re-query hint|requery_hint|RE_QUERY_BEFORE_PROCESSING|requery_before_processing' "$WATCH_SH"; then
  pass "cross-wake re-query hint present (hint field in peer wake payload)"
else
  fail "cross-wake re-query hint missing" "expected grep hit on 're_query_hint|re-query hint|requery_hint|RE_QUERY_BEFORE_PROCESSING|requery_before_processing' — wake events lack the re-query hint that would mitigate cross-in-flight noise"
fi

# ============================================================================
# T3: agent-watch.sh — post-compact REPRIME flag
# ============================================================================
section "T3: agent-watch.sh — post-compact REPRIME flag (REPRIME mode resets state + re-queries)"
# Pattern: env var or flag (REPRIME=1 or --reprime) that, when set, clears
# processed_event_ids from the agent state file and re-queries full state.
# This addresses dev miss #1 (PR #456 closes-anchor gap caused by stale
# post-compact cache) — after REPRIME, the agent re-discovers all events
# from GitHub ground truth.
section "T3: agent-watch.sh — post-compact REPRIME flag"
if [ ! -f "$WATCH_SH" ]; then
  fail "agent-watch.sh missing" "expected $WATCH_SH"
elif grep -Eq 'REPRIME|reprime|--reprime' "$WATCH_SH"; then
  pass "REPRIME mode flag present (post-compact state reset mechanism)"
else
  fail "REPRIME mode flag missing" "expected grep hit on 'REPRIME|reprime|--reprime' — no post-compact state reset mechanism; agents with stale caches cannot recover without manual state-file surgery"
fi

# ============================================================================
# T4: agent-watch.sh — stale-state re-query dispatch
# ============================================================================
section "T4: agent-watch.sh — stale-state re-query dispatch (periodic re-query when state age > threshold)"
# Pattern: a constant or env var (STALE_STATE_THRESHOLD_SEC or similar)
# combined with a check in poll_once() that triggers a full re-query when
# the state file's last_seen_utc age exceeds the threshold. This addresses
# dev miss #2 (PR #457 cc:developer stale 953s — no auto-detection of
# stale state).
section "T4: agent-watch.sh — stale-state re-query dispatch"
if [ ! -f "$WATCH_SH" ]; then
  fail "agent-watch.sh missing" "expected $WATCH_SH"
elif grep -Eq 'STALE_STATE_THRESHOLD|stale_state_threshold|STATE_AGE_THRESHOLD|state_age_threshold' "$WATCH_SH"; then
  pass "stale-state re-query dispatch present (threshold-based re-query trigger)"
else
  fail "stale-state re-query dispatch missing" "expected grep hit on 'STALE_STATE_THRESHOLD|stale_state_threshold|STATE_AGE_THRESHOLD|state_age_threshold' — no automatic re-query when state file age exceeds threshold; stale queue items silently persist"
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