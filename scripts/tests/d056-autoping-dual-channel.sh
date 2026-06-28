#!/usr/bin/env bash
# d056-autoping-dual-channel.sh — Auto-Ping dual-channel enforcement guard
#
# Why this test exists
# --------------------
# d056 codifies ADR-0033 (Auto-Ping dual-channel doctrine). notify.sh from
# tmux context WITHOUT -w -r silently falls through to Telegram-only delivery
# — peer tmux panes never wake (Issue #221, Issue #320, owner directive
# 2026-06-25). Commit 4695a15 hard-enforced this on the notify.sh side.
# ping.sh is the canonical wrapper that always sets -l info -w -r <role>.
#
# Sister-pattern: d054 (deep-narrow single-purpose), d051 (5-soul dispatch),
# d058 (work-stream aware factory), d060 (fake-gh).
#
# 9 TCs (1 PASS baseline + 8 regression guards, ADR-0044 RED-first doctrine):
# TC1 baseline PASS + TC2-TC9 regression guards on the dual-channel enforcement.
# Pre-impl expected: 9 PASS (doctrine already enforced by commit 4695a15).
# Post-impl expected: 9 PASS (regression guard — if dual-channel breaks, RED).
#
# Doctrine anchors:
# - ADR-0033 (Auto-Ping dual-channel doctrine, Issue #221 + Issue #320)
# - Owner directive 2026-06-25 (tmux-context callers MUST use dual-channel)
# - §17 LIVE INSTANCE #5 (orch stale-cache drift — sister-pattern origin)
# - Issue #320 RCA (broken `notify.sh -l <role>` form, 22 places)
# - Commit 4695a15 (notify.sh hard-enforce dual-channel from tmux context)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NOTIFY_SH="${REPO_ROOT}/scripts/notify.sh"
PING_SH="${REPO_ROOT}/scripts/ping.sh"

# TTY-aware color setup (sister-pattern to d054/d058)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[0;33m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; Y=""; B=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Preflight
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
[ -f "$NOTIFY_SH" ] || { echo "ERROR: notify.sh not found at $NOTIFY_SH" >&2; exit 2; }
[ -f "$PING_SH" ] || { echo "ERROR: ping.sh not found at $PING_SH" >&2; exit 2; }

# Self-test mode (RED-first per ADR-0044)
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

# Mock Telegram env (so notify.sh would-send path doesn't crash with empty creds)
export TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-test-bot-token-for-d056}"
export TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-test-chat-id-for-d056}"

# Helper: stub curl so Telegram POST never hits network in self-test
# We replace curl with a function that returns ok:true JSON
curl() {
  # Stub for tests — anything we don't override explicitly exits 0 + ok:true
  if [ "${D056_CURL_FAIL:-0}" = "1" ]; then
    echo '{"ok":false,"description":"rate limit"}'
  else
    echo '{"ok":true}'
  fi
}
export -f curl

# ============================================================================
# TC1 (BASELINE PASS): ping.sh ALWAYS uses -l info -w -r internally
# ============================================================================
section "TC1: ping.sh canonical wrapper uses -l info -w -r (canonical form)"
# Anchor: line 59 of ping.sh MUST exec notify.sh with -l info -w -r
if grep -qE '^exec[[:space:]]+"\$SCRIPT_DIR/notify.sh"[[:space:]]+-l[[:space:]]+info[[:space:]]+-w[[:space:]]+-r[[:space:]]+"\$ROLE"' "$PING_SH"; then
  pass "TC1: ping.sh line 59 has canonical -l info -w -r invocation"
else
  fail "TC1: ping.sh MUST invoke notify.sh with -l info -w -r <role> (ADR-0033)"
fi

# ============================================================================
# TC2 (PASS): ping.sh accepts all 6 valid roles
# ============================================================================
section "TC2: ping.sh accepts all 6 valid roles (orch/PM/arch/dev/tester/human)"
# Anchor: line 47-54 case statement
if grep -qE 'orchestrator\|product-manager\|architect\|developer\|tester\|human' "$PING_SH"; then
  pass "TC2: ping.sh role whitelist covers all 6 valid roles"
else
  fail "TC2: ping.sh MUST whitelist orchestrator|product-manager|architect|developer|tester|human"
fi

# ============================================================================
# TC3 (PASS): ping.sh with invalid role → exit 2 + error message
# ============================================================================
section "TC3: ping.sh invalid role → exit 2 + usage hint"
# Functional test: invoke ping.sh with bogus role, verify exit 2
TMUX='' bash "$PING_SH" bogus-role "test message" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then
  pass "TC3: ping.sh invalid role exits 2 (canonical wrapper discipline)"
else
  fail "TC3: ping.sh invalid role should exit 2, got $rc"
fi

# ============================================================================
# TC4 (PASS): ping.sh with missing role → exit 2 + usage
# ============================================================================
section "TC4: ping.sh missing role arg → exit 2 + usage hint"
# Functional test: invoke ping.sh with no args, verify exit 2
TMUX='' bash "$PING_SH" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then
  pass "TC4: ping.sh missing role exits 2 (canonical wrapper discipline)"
else
  fail "TC4: ping.sh missing role should exit 2, got $rc"
fi

# ============================================================================
# TC5 (PASS): notify.sh from tmux WITHOUT -w -r → ERROR + exit 2
# ============================================================================
section "TC5: notify.sh from tmux WITHOUT -w -r → ERROR (ADR-0033 hard-enforce)"
# Anchor: line 76 of notify.sh: 'if [ -n "${TMUX:-}" ] && [ -z "$WAKE" ]; then'
# Functional: invoke notify.sh from simulated tmux context without -w
TMUX='/tmp/tmux-1000/default,12345,0' bash "$NOTIFY_SH" -l info "test" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then
  pass "TC5: notify.sh from tmux without -w -r exits 2 (ADR-0033 hard-enforce)"
else
  fail "TC5: notify.sh from tmux without -w -r MUST exit 2 (ADR-0033), got $rc"
fi

# ============================================================================
# TC6 (PASS): notify.sh from non-tmux (TMUX='') → Telegram-only allowed (bypass)
# ============================================================================
section "TC6: notify.sh from non-tmux context → Telegram-only path (bypass)"
# Functional: invoke notify.sh from non-tmux, verify it doesn't fail on TMUX check
# Stub curl to return ok:true (already done via exported function above)
output=$(TMUX='' bash "$NOTIFY_SH" -l info "test message" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$output" | grep -q "Notification sent"; then
  pass "TC6: notify.sh from non-tmux sends (Telegram-only allowed, bypass OK)"
else
  fail "TC6: notify.sh from non-tmux should send + exit 0, got rc=$rc output=$output"
fi

# ============================================================================
# TC7 (PASS): notify.sh -w without -r → ERROR + exit 2 (ADR-0033 AC1)
# ============================================================================
section "TC7: notify.sh -w without -r → ERROR (ADR-0033 AC1 — -w requires -r)"
# Anchor: line 63-67 of notify.sh: 'if [ -n "$WAKE" ] && [ -z "$ROLE" ]; then'
# Functional: invoke notify.sh with -w but no -r
TMUX='' bash "$NOTIFY_SH" -l info -w "test" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then
  pass "TC7: notify.sh -w without -r exits 2 (ADR-0033 AC1 enforced)"
else
  fail "TC7: notify.sh -w without -r MUST exit 2 (ADR-0033), got $rc"
fi

# ============================================================================
# TC8 (PASS): notify.sh -l <role> form → WARNING stderr + still sends (Issue #320 AC2)
# ============================================================================
section "TC8: notify.sh -l <role> deprecated form → WARNING + still sends (Issue #320 AC2)"
# Anchor: line 110-117 of notify.sh: case statement emits WARNING for role-like -l args
# Functional: invoke notify.sh with -l developer (wrong form)
output=$(TMUX='' bash "$NOTIFY_SH" -l developer "test" 2>&1)
if echo "$output" | grep -q "WARNING: -l developer looks like a ROLE"; then
  pass "TC8: notify.sh -l <role> emits WARNING (backward compat per Issue #320 AC2)"
else
  fail "TC8: notify.sh -l <role> MUST emit WARNING (Issue #320 AC2)"
fi

# ============================================================================
# TC9 (PASS): notify.sh with TMUX='' AND -w -r → dual-channel attempted
# ============================================================================
section "TC9: notify.sh valid invocation (TMUX='' + -w -r <role>) → dual-channel"
# Functional: invoke notify.sh from non-tmux with full dual-channel flags
# agent-wake.sh is silent no-op if tmux missing, so this just verifies the
# command path doesn't error out.
output=$(TMUX='' bash "$NOTIFY_SH" -l info -w -r developer "test" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$output" | grep -q "Notification sent"; then
  pass "TC9: notify.sh valid invocation sends + wake path attempted (dual-channel)"
else
  fail "TC9: notify.sh valid invocation should exit 0 + 'Notification sent', got rc=$rc"
fi

# ============================================================================
# Summary (sister-pattern to d054 + d058)
# ============================================================================
printf "\n${B}==== d056 SELF-TEST SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

# Pre-impl expected: 9 PASS (doctrine already enforced by commit 4695a15, regression guard)
# Post-impl expected: 9 PASS (regression guard — if dual-channel breaks, RED)
if [ "$PASS" -eq 9 ] && [ "$FAIL" -eq 0 ]; then
  printf "  ${G}d056 GREEN${D} — 9/9 PASS = Auto-Ping dual-channel enforcement regression-guarded\n"
  exit 0
elif [ "$PASS" -ge 5 ] && [ "$FAIL" -ge 1 ]; then
  printf "  ${Y}d056 RED${D} — %d/%d PASS + %d/%d FAIL = doctrine regression detected\n" "$PASS" 9 "$FAIL" 9
  exit 1
else
  printf "  ${R}d056 RED (unexpected)${D} — counts outside expected range. Investigate.\n"
  exit 1
fi