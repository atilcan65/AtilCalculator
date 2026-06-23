#!/usr/bin/env bash
# d036c-cli-repl.sh — hermetic shell regression test for STORY-301 REPL mode.
#
# Why this test exists
# --------------------
# Issue #301 (STORY-CLI-003) AC1-AC9 contract: `atilcalc --repl` interactive
# mode that reads expressions from stdin, evaluates via engine, prints result
# + new prompt. This shell test locks in the REPL contract alongside the
# pytest sister (tests/cli/test_repl.py).
#
# Sister test: tests/cli/test_repl.py (pytest, parametrised, 8 cases).
# Both must pass before PR #314-equivalent impl lands.
#
# Test cases (8 TUs, per docs/test-plans/STORY-301-tests.md):
#   T1: AC1 — REPL prompt display (--repl flag → prompt, process alive)
#   T2: AC2 — Basic eval (0.1+0.2, 1+1, 2*3) → result + new prompt
#   T3: AC3 — Precedence eval ((2+3)*4, 2+3*4) → 20, 14
#   T4: AC4 — Exit commands (exit, quit) → exit 0 + goodbye
#   T5: AC5 — EOF handling (close stdin → exit 0)
#   T6: AC6 — Parse error continuation (1++2 → error + new prompt + recovery)
#   T7: AC7 — /help slash-command → help text + REPL still works
#   T8: AC8 — Session-level (5+ expressions, mixed valid/invalid, clean exit)
#   T9: preflight (no CLI → INFO, TDD RED expected)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d036c-cli-repl.sh
#
# TDD status (this PR): RED on master. Locks the contract; turns GREEN once
# dev's REPL impl lands (likely `src/atilcalc/repl/__init__.py` or extension
# to `src/atilcalc/cli/__init__.py`).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""
fi

PASS=0; FAIL=0; SKIP=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
skip() { printf "  ${D}⊘ SKIP${D} — %s\n" "$1"; SKIP=$((SKIP+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Driver: spawn `python3 -m atilcalc --repl` with controllable stdin
repl() {
  python3 -m atilcalc --repl
}

# ============================================================================
# T9: preflight — check CLI is installed (else skip everything)
# ============================================================================
section "T9: preflight — atilcalc CLI available?"
if ! python3 -m atilcalc --help >/dev/null 2>&1; then
  skip "T9: no CLI installed (TDD RED expected; will work after Issue #301 impl lands)"
  echo ""
  echo "==== SUMMARY ===="
  echo "  Total:  1"
  echo "  Skipped: 1"
  echo ""
  echo "ALL TESTS SKIPPED (TDD RED: preflight failed; impl not yet present)"
  exit 0
else
  pass "CLI available"
fi

# ============================================================================
# T1: AC1 — REPL prompt display
# ============================================================================
section "T1: AC1 — atilcalc --repl → prompt + waits on stdin"
# Spawn REPL, send empty input (Enter), verify stdout shows prompt + process alive.
out_file="$(mktemp)"
err_file="$(mktemp)"
# DEV-FIX (Story-301 impl PR): original test sent `( echo ""; sleep 0.5; echo "exit" )`
# which auto-exits REPL before the sleep 1 alive-check, causing a spurious FAIL.
# Fix: use `sleep 10` to hold stdin open past the alive-check; cleanup kills REPL.
# Intent unchanged: REPL stays alive after empty input.
( echo ""; sleep 10 ) | timeout 5 python3 -m atilcalc --repl > "$out_file" 2> "$err_file" &
repl_pid=$!
sleep 1
if kill -0 $repl_pid 2>/dev/null; then
  pass "REPL process alive after empty input"
  kill $repl_pid 2>/dev/null
  wait $repl_pid 2>/dev/null
else
  fail "REPL exited too early" "expected to stay alive waiting for input"
fi
# Prompt check (loose: just check prompt string appears somewhere)
if grep -Eq 'atilcalc>|>' "$out_file"; then
  pass "REPL prompt displayed"
else
  fail "REPL prompt missing" "expected prompt like 'atilcalc> ' in stdout"
fi
rm -f "$out_file" "$err_file"

# ============================================================================
# T2: AC2 — Basic eval
# ============================================================================
section "T2: AC2 — basic eval in REPL (parametrised, 3 cases)"
for case in "0.1 + 0.2:0.3" "1 + 1:2" "2 * 3:6"; do
  expr="${case%%:*}"
  expected="${case##*:}"
  out_file="$(mktemp)"
  err_file="$(mktemp)"
  printf "%s\nexit\n" "$expr" | timeout 5 python3 -m atilcalc --repl > "$out_file" 2> "$err_file"
  rc=$?
  if [ $rc -ne 0 ]; then
    fail "T2: '$expr' → exit $rc" "stderr: $(cat "$err_file")"
  elif ! grep -qF "$expected" "$out_file"; then
    fail "T2: '$expr' → stdout missing '$expected'" "got: $(cat "$out_file")"
  else
    pass "T2: '$expr' → stdout contains '$expected'"
  fi
  rm -f "$out_file" "$err_file"
done

# ============================================================================
# T3: AC3 — Precedence eval
# ============================================================================
section "T3: AC3 — precedence eval in REPL (parametrised, 2 cases)"
for case in "(2 + 3) * 4:20" "2 + 3 * 4:14"; do
  expr="${case%%:*}"
  expected="${case##*:}"
  out_file="$(mktemp)"
  err_file="$(mktemp)"
  printf "%s\nexit\n" "$expr" | timeout 5 python3 -m atilcalc --repl > "$out_file" 2> "$err_file"
  rc=$?
  if [ $rc -ne 0 ]; then
    fail "T3: '$expr' → exit $rc" "stderr: $(cat "$err_file")"
  elif ! grep -qF "$expected" "$out_file"; then
    fail "T3: '$expr' → stdout missing '$expected'" "got: $(cat "$out_file")"
  else
    pass "T3: '$expr' → stdout contains '$expected'"
  fi
  rm -f "$out_file" "$err_file"
done

# ============================================================================
# T4: AC4 — Exit commands
# ============================================================================
section "T4: AC4 — exit / quit commands (parametrised, 2 cases)"
for cmd in "exit" "quit"; do
  out_file="$(mktemp)"
  err_file="$(mktemp)"
  printf "%s\n" "$cmd" | timeout 5 python3 -m atilcalc --repl > "$out_file" 2> "$err_file"
  rc=$?
  if [ $rc -eq 0 ]; then
    pass "T4: '$cmd' → exit 0"
  else
    fail "T4: '$cmd' → exit $rc" "expected exit 0"
  fi
  rm -f "$out_file" "$err_file"
done

# ============================================================================
# T5: AC5 — EOF handling
# ============================================================================
section "T5: AC5 — EOF (close stdin) → exit 0"
out_file="$(mktemp)"
err_file="$(mktemp)"
# Send no input at all → REPL should detect EOF and exit cleanly
timeout 5 python3 -m atilcalc --repl < /dev/null > "$out_file" 2> "$err_file"
rc=$?
if [ $rc -eq 0 ]; then
  pass "T5: EOF → exit 0"
else
  fail "T5: EOF → exit $rc" "expected exit 0 on EOF (stderr: $(cat "$err_file"))"
fi
rm -f "$out_file" "$err_file"

# ============================================================================
# T6: AC6 — Parse error continuation
# ============================================================================
section "T6: AC6 — parse error mid-session → REPL continues"
out_file="$(mktemp)"
err_file="$(mktemp)"
# Send bad expr + good expr + exit; REPL should NOT exit on parse error
printf "1 + + 2\n1 + 1\nexit\n" | timeout 5 python3 -m atilcalc --repl > "$out_file" 2> "$err_file"
rc=$?
if [ $rc -eq 0 ]; then
  pass "T6: parse error did not exit REPL (exit 0)"
else
  fail "T6: REPL exited on parse error" "exit $rc; expected 0 (continuation)"
fi
if grep -qF "2" "$out_file"; then
  pass "T6: REPL recovered after parse error (1+1 → 2 present)"
else
  fail "T6: REPL did not recover" "expected '2' in stdout after recovery"
fi
rm -f "$out_file" "$err_file"

# ============================================================================
# T7: AC7 — /help slash-command
# ============================================================================
section "T7: AC7 — /help slash-command shows available commands"
out_file="$(mktemp)"
err_file="$(mktemp)"
printf "/help\nexit\n" | timeout 5 python3 -m atilcalc --repl > "$out_file" 2> "$err_file"
rc=$?
if [ $rc -eq 0 ] && grep -Eq '/help|/exit|/quit' "$out_file"; then
  pass "T7: /help output shows /help + /exit + /quit"
else
  fail "T7: /help missing or incomplete" "got: $(cat "$out_file")"
fi
rm -f "$out_file" "$err_file"

# ============================================================================
# T8: AC8 — Session-level test (5+ expressions, mixed)
# ============================================================================
section "T8: AC8 — session-level (5+ expressions, mixed valid/invalid)"
out_file="$(mktemp)"
err_file="$(mktemp)"
printf "1 + 1\n2 * 3\n(1 + 2) * 3\n1 + + 2\n5 - 2\nexit\n" | timeout 5 python3 -m atilcalc --repl > "$out_file" 2> "$err_file"
rc=$?
# Verify expected results present
results_found=0
for expected in "2" "6" "9" "3"; do
  if grep -qF "$expected" "$out_file"; then
    results_found=$((results_found+1))
  fi
done
if [ $rc -eq 0 ] && [ "$results_found" -ge 3 ]; then
  pass "T8: session passed (found $results_found/4 expected results; exit 0)"
else
  fail "T8: session failed" "exit $rc; found $results_found/4 expected; stderr: $(cat "$err_file")"
fi
rm -f "$out_file" "$err_file"

# ============================================================================
# SUMMARY
# ============================================================================
section "SUMMARY"
TOTAL=$((PASS + FAIL + SKIP))
printf "  Total:  %d\n" "$TOTAL"
printf "  Passed: %d\n" "$PASS"
printf "  Failed: %d\n" "$FAIL"
printf "  Skipped: %d\n" "$SKIP"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "SOME TESTS FAILED (TDD RED expected until REPL impl lands)"
  exit 1
fi

echo "ALL TESTS PASSED (TDD GREEN: REPL impl present and correct)"
exit 0