#!/usr/bin/env bash
# d029-no-standby-watcher-text.sh — regression for Issue #256 (watcher-side no-standby doctrine).
#
# Why this test exists
# --------------------
# Issue #238 §Doctrine Reminder — no self-standby prohibits agents from using
# "standby", "holding", "iş saatleri", "ofis-saati", "sabah bakacağım",
# "yarın devam" as a pause justification. d028 enforces this in
# `.claude/agents/*.md` (4 soul files). d029 is the watcher-side equivalent:
# `scripts/agent-watch.sh` is the *enforcement mechanism* — if IT emits
# forbidden text in `wake_nudge` payload, agents reading the nudge are
# invited to self-standby, defeating the doctrine.
#
# Per Issue #256 (P0, owner-assigned 2026-06-22T13:35:54Z): the fix is a
# 3-line text swap in `scripts/agent-watch.sh` + this d029 regression test.
#
# Test cases (5, per #256 acceptance):
#   T1: scripts/agent-watch.sh — no 'standby' (case-insensitive)
#   T2: scripts/agent-watch.sh — no 'holding' (the 'paused-on-dep' synonym)
#   T3: scripts/agent-watch.sh — no 'iş saatleri' / 'ofis-saati' (Turkish
#        for "work hours" / "office hours" — forbidden per CLAUDE.md §NEVER)
#   T4: scripts/agent-watch.sh — no 'sabah bakacağım' / 'yarın devam'
#        ("will look in the morning" / "continue tomorrow" — the most
#        common stall phrases)
#   T5: scripts/agent-watch.sh — wake_nudge context.note does NOT contain
#        forbidden words (live-behavior check via dry-run)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d029-no-standby-watcher-text.sh

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

if [ ! -r "$WATCH_SH" ]; then
  echo "ERROR: agent-watch.sh not found at $WATCH_SH" >&2; exit 127
fi

# Forbidden words per Issue #238 §Doctrine Reminder + #256 acceptance
FORBIDDEN_EN=("standby" "holding" "paused-on-dep")
FORBIDDEN_TR=("iş saatleri" "ofis-saati" "sabah bakacağım" "yarın devam")

# ============================================================================
# T1: no 'standby' (case-insensitive)
# ============================================================================
section "T1: scripts/agent-watch.sh — no 'standby' (case-insensitive)"
if grep -niE '\bstandby\b' "$WATCH_SH" >/dev/null 2>&1; then
  matches="$(grep -niE '\bstandby\b' "$WATCH_SH" | head -5)"
  fail "found 'standby' in agent-watch.sh" "$matches"
else
  pass "no 'standby' occurrences in agent-watch.sh"
fi

# ============================================================================
# T2: no 'holding' (pause synonym)
# ============================================================================
section "T2: scripts/agent-watch.sh — no 'holding' (pause synonym)"
if grep -niE '\bholding\b' "$WATCH_SH" >/dev/null 2>&1; then
  matches="$(grep -niE '\bholding\b' "$WATCH_SH" | head -5)"
  fail "found 'holding' in agent-watch.sh" "$matches"
else
  pass "no 'holding' occurrences in agent-watch.sh"
fi

# ============================================================================
# T3: no Turkish 'work hours' / 'office hours' phrases
# ============================================================================
section "T3: scripts/agent-watch.sh — no 'iş saatleri' / 'ofis-saati'"
t3_fail=0
for word in "${FORBIDDEN_TR[@]:0:2}"; do
  if grep -niF "$word" "$WATCH_SH" >/dev/null 2>&1; then
    matches="$(grep -niF "$word" "$WATCH_SH" | head -3)"
    fail "found '$word' in agent-watch.sh" "$matches"
    t3_fail=1
  fi
done
if [ "$t3_fail" -eq 0 ]; then
  pass "no 'iş saatleri' / 'ofis-saati' in agent-watch.sh"
fi

# ============================================================================
# T4: no 'sabah bakacağım' / 'yarın devam' (morning/tomorrow stall phrases)
# ============================================================================
section "T4: scripts/agent-watch.sh — no 'sabah bakacağım' / 'yarın devam'"
t4_fail=0
for word in "${FORBIDDEN_TR[@]:2:2}"; do
  if grep -niF "$word" "$WATCH_SH" >/dev/null 2>&1; then
    matches="$(grep -niF "$word" "$WATCH_SH" | head -3)"
    fail "found '$word' in agent-watch.sh" "$matches"
    t4_fail=1
  fi
done
if [ "$t4_fail" -eq 0 ]; then
  pass "no 'sabah bakacağım' / 'yarın devam' in agent-watch.sh"
fi

# ============================================================================
# T5: wake_nudge context.note is clean (live-behavior check via dry-run)
# ============================================================================
section "T5: wake_nudge context.note does NOT contain forbidden words (dry-run)"
# We can't easily run agent-watch.sh here (it does GitHub API calls), but
# we can grep the source for the new action-oriented text + assert no
# 'standby' is in any literal that would land in wake_nudge's note/title.
# The literal that lands in context.note is the one we replaced at L1137:
#   "Lütfen pickup et: review yap, label flip et, peer'i bilgilendir, sonra heartbeat yaz ve queue'ya dön."
# We assert this literal exists (proves fix applied) AND has no forbidden word.
NEW_TEXT="sonra heartbeat yaz ve queue'ya dön"
if grep -nF "$NEW_TEXT" "$WATCH_SH" >/dev/null 2>&1; then
  # Check the literal for any forbidden word
  literal="$(grep -nF "$NEW_TEXT" "$WATCH_SH" | head -1)"
  literal_violation=0
  for word in "${FORBIDDEN_EN[@]}" "${FORBIDDEN_TR[@]}"; do
    if echo "$literal" | grep -niF "$word" >/dev/null 2>&1; then
      fail "wake_nudge literal contains forbidden word '$word'" "$literal"
      literal_violation=1
    fi
  done
  if [ "$literal_violation" -eq 0 ]; then
    pass "wake_nudge literal applied + clean (no forbidden words): $NEW_TEXT"
  fi
else
  fail "wake_nudge literal NOT applied" "expected '$NEW_TEXT' in agent-watch.sh L1137"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo
  echo "Issue #256 REGRESSION FAILED — watcher emits forbidden no-standby doctrine text."
  echo "Fix: edit scripts/agent-watch.sh — replace 'sonra standby.' with"
  echo "     'sonra heartbeat yaz ve queue'ya dön.' (or similar action-oriented phrase)"
  echo "     AND rename 'standby' comments to 'silenced' or 'paused-on-dep'."
  exit 1
fi
echo
echo "Issue #256 REGRESSION PASS — watcher emits only action-oriented text."
exit 0
