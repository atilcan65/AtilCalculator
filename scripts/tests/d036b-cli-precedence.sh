#!/usr/bin/env bash
# d036b-cli-precedence.sh — regression test for Issue #300 | PR #303 (test plan)
#
# Why this test exists
# --------------------
# Sprint 7 P0 (STORY-CLI-002, multi-op expressions with operator precedence).
# Test plan landed in PR #303 (docs/test-plans/STORY-300-tests.md, 5 TCs,
# 18 pytest cases). Per TDD RED-first discipline, this shell test exists
# BEFORE the precedence parser implementation — it MUST FAIL until
# src/atilcalc/parser/ lands.
#
# Sister test: pytest version lives in tests/cli/test_precedence.py
# (same 18 TUs, ported to subprocess.run() for finer-grained assertions).
#
# Test cases (per docs/test-plans/STORY-300-tests.md):
#   T1:  Precedence rules (6 cases, TC-1)
#   T2:  Power operator edge cases (4 cases, TC-2)
#   T3:  Unbalanced parens error path (3 cases, TC-3)
#   T4:  Unary minus (4 cases, TC-4)
#   T5:  M1 acceptance for #300: `atilcalc '2 + 3 * 4'` → stdout `14` (AC1, AC7)
#   T6:  Subprocess timeout / DoS guard (adversarial probe)
#   T7:  Parametrised regression suite (18 cases, TC-5)
#   T8:  CLI is installed (binary on PATH or `python -m atilcalc` works)
#
# Exit code: 0 = all pass, 1 = at least one fail.
# Run standalone: bash scripts/tests/d036b-cli-precedence.sh
#
# Refs: Issue #300, PR #303, docs/backlog/STORY-CLI-002.md, ADR-0017, ADR-0031

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=$'\033[0m'; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# CLI driver: prefer installed `atilcalc`, fall back to `python3 -m atilcalc`.
# We actually invoke the candidate to confirm it works (TDD RED: the `atilcalc`
# package is a directory but lacks `__main__.py`, so `python3 -m` fails at
# runtime; we mark it as "detected but not working" via a preflight probe).
CLI_CMD=()
if command -v atilcalc >/dev/null 2>&1; then
  if atilcalc --help >/dev/null 2>&1; then
    CLI_CMD=(atilcalc)
  fi
fi
if [[ ${#CLI_CMD[@]} -eq 0 ]] && python3 -c "import atilcalc" 2>/dev/null; then
  if python3 -m atilcalc --help >/dev/null 2>&1; then
    CLI_CMD=(python3 -m atilcalc)
  fi
fi

# ----------------------------------------------------------------------------
# run_cli — invoke CLI with a SINGLE quoted expression argument, capture exit
# code reliably. Note: precedence expressions contain spaces, parens, and
# operators, so we must pass them as a single argv (not split).
# Writes tmpout/tmperr files to capture output, then returns exit code in $rc.
# Avoids the `code=$?` subshell pitfall (works under `set -u`).
# ----------------------------------------------------------------------------
run_cli() {
  local expr="$1"
  local tmpout tmperr rc
  tmpout=$(mktemp); tmperr=$(mktemp)
  if [[ ${#CLI_CMD[@]} -eq 0 ]]; then
    # No CLI available — emit the same failure mode the impl would.
    printf 'ModuleNotFoundError: No module named atilcalc.__main__\n' > "$tmperr"
    rc=1
  else
    "${CLI_CMD[@]}" "$expr" >"$tmpout" 2>"$tmperr"
    rc=$?
  fi
  STDOUT=$(cat "$tmpout")
  STDERR=$(cat "$tmperr")
  rm -f "$tmpout" "$tmperr"
  return $rc
}

# ----------------------------------------------------------------------------
# CLI preflight — TDD RED: if no CLI is installed, the T7/T8 sub-cases that
# probe the CLI are skipped (with explicit skip message), but T1-T6 can still
# run and fail RED-by-design (they assert on the implementation).
# ----------------------------------------------------------------------------
CLI_AVAILABLE=false
if [[ ${#CLI_CMD[@]} -gt 0 ]]; then
  CLI_AVAILABLE=true
fi

# ============================================================================
# T1: Precedence rules (6 cases, TC-1)
# ============================================================================
section "T1: Precedence rules (6 cases)"

declare -a T1_EXPR=(
  "2 + 3 * 4"
  "(2 + 3) * 4"
  "2 + 3 + 4 * 5"
  "10 - 2 * 3"
  "100 / 5 / 2"
  "2 ** 3"
)
declare -a T1_WANT=(
  "14"
  "20"
  "25"
  "4"
  "10"
  "8"
)
for i in "${!T1_EXPR[@]}"; do
  expr="${T1_EXPR[$i]}"
  want="${T1_WANT[$i]}"
  if run_cli "$expr"; then
    got="$STDOUT"
    if [[ "$got" == "$want" ]]; then
      pass "T1.$((i+1)): '$expr' → '$want'"
    else
      fail "T1.$((i+1)): '$expr' → expected '$want', got '$got'"
    fi
  else
    fail "T1.$((i+1)): '$expr' → non-zero exit (rc=$?); stderr='$STDERR'" "$STDERR"
  fi
done

# ============================================================================
# T2: Power operator edge cases (4 cases, TC-2)
# ============================================================================
section "T2: Power operator edge cases (4 cases)"

declare -a T2_EXPR=(
  "2 ** 10"
  "0.5 ** 2"
  "2 ** 0"
  "2 ** -1"
)
declare -a T2_WANT=(
  "1024"
  "0.25"
  "1"
  "0.5"
)
for i in "${!T2_EXPR[@]}"; do
  expr="${T2_EXPR[$i]}"
  want="${T2_WANT[$i]}"
  if run_cli "$expr"; then
    got="$STDOUT"
    if [[ "$got" == "$want" ]]; then
      pass "T2.$((i+1)): '$expr' → '$want'"
    else
      fail "T2.$((i+1)): '$expr' → expected '$want', got '$got'"
    fi
  else
    fail "T2.$((i+1)): '$expr' → non-zero exit; stderr='$STDERR'" "$STDERR"
  fi
done

# ============================================================================
# T3: Unbalanced parens error path (3 cases, TC-3)
# ============================================================================
section "T3: Unbalanced parens error path (3 cases)"

declare -a T3_EXPR=(
  "(1 + 2"
  "1 + 2)"
  "((1 + 2)"
)
for i in "${!T3_EXPR[@]}"; do
  expr="${T3_EXPR[$i]}"
  if run_cli "$expr"; then
    fail "T3.$((i+1)): '$expr' → expected non-zero exit for unbalanced parens, got rc=0; stdout='$STDOUT'"
  else
    # Check stderr mentions parse/unbalanced AND no Python traceback leaked.
    # Tight check: drop loose "error" match (matches "ModuleNotFoundError" too)
    # to avoid false-positive passes on the TDD RED "no module" failure mode.
    if [[ -z "$STDERR" ]]; then
      fail "T3.$((i+1)): '$expr' → non-zero exit but empty stderr"
    elif [[ "$STDERR" == *"Traceback"* ]]; then
      fail "T3.$((i+1)): '$expr' → Python traceback leaked to user: $STDERR"
    else
      stderr_norm=$(printf '%s' "$STDERR" | tr '[:upper:]' '[:lower:]' | tr -d ' _')
      if [[ "$stderr_norm" == *"parse"* || "$stderr_norm" == *"unbalanced"* || "$stderr_norm" == *"paren"* ]]; then
        pass "T3.$((i+1)): '$expr' → parse error as expected"
      else
        fail "T3.$((i+1)): '$expr' → stderr not parse/unbalanced-themed (got: $STDERR)"
      fi
    fi
  fi
done

# ============================================================================
# T4: Unary minus (4 cases, TC-4)
# ============================================================================
section "T4: Unary minus (4 cases)"

declare -a T4_EXPR=(
  "-5 + 3"
  "5 + -3"
  "--5"
  "-(2 + 3)"
)
declare -a T4_WANT=(
  "-2"
  "2"
  "5"
  "-5"
)
for i in "${!T4_EXPR[@]}"; do
  expr="${T4_EXPR[$i]}"
  want="${T4_WANT[$i]}"
  if run_cli "$expr"; then
    got="$STDOUT"
    if [[ "$got" == "$want" ]]; then
      pass "T4.$((i+1)): '$expr' → '$want'"
    else
      fail "T4.$((i+1)): '$expr' → expected '$want', got '$got'"
    fi
  else
    fail "T4.$((i+1)): '$expr' → non-zero exit; stderr='$STDERR'" "$STDERR"
  fi
done

# ============================================================================
# T5: M1 acceptance for #300 — single golden case (AC1, AC7)
# ============================================================================
section "T5: M1 acceptance — `atilcalc '2 + 3 * 4'` → 14"

if run_cli "2 + 3 * 4"; then
  if [[ "$STDOUT" == "14" ]]; then
    pass "M1 acceptance: '2 + 3 * 4' → '14' (precedence correct)"
  else
    fail "M1 acceptance: '2 + 3 * 4' → expected '14', got '$STDOUT'"
  fi
else
  fail "M1 acceptance: '2 + 3 * 4' → non-zero exit; stderr='$STDERR'" "$STDERR"
fi

# ============================================================================
# T6: Subprocess timeout / DoS guard (adversarial probe)
# ============================================================================
section "T6: Subprocess timeout / DoS guard"

if [[ "$CLI_AVAILABLE" == "true" ]]; then
  # Long chain (1000 additions): should complete in < 1s, not hang
  long_expr=$(python3 -c 'print("+".join(["1"]*1000))')
  start=$(date +%s%N)
  if timeout 2 "${CLI_CMD[@]}" "$long_expr" >/dev/null 2>&1; then
    end=$(date +%s%N)
    elapsed_ms=$(( (end - start) / 1000000 ))
    if [[ $elapsed_ms -lt 1000 ]]; then
      pass "1000-op chain completed in ${elapsed_ms}ms (< 1000ms budget)"
    else
      fail "1000-op chain took ${elapsed_ms}ms (>= 1000ms budget)"
    fi
  else
    rc=$?
    if [[ $rc -eq 124 ]]; then
      fail "1000-op chain TIMED OUT (DoS risk)"
    else
      fail "1000-op chain failed with rc=$rc"
    fi
  fi
else
  printf "  ${B}⊘ SKIP${D} — T6 (no CLI available for DoS probe)\n"
fi

# ============================================================================
# T7: Parametrised regression suite (18 cases, TC-5)
# ============================================================================
section "T7: Parametrised regression suite (18 cases)"

declare -a T7_EXPR=(
  # Precedence (6)
  "2 + 3 * 4"
  "(2 + 3) * 4"
  "2 + 3 + 4 * 5"
  "10 - 2 * 3"
  "100 / 5 / 2"
  "2 ** 3"
  # Power (4)
  "2 ** 10"
  "0.5 ** 2"
  "2 ** 0"
  "2 ** -1"
  # Unary minus (4)
  "-5 + 3"
  "5 + -3"
  "--5"
  "-(2 + 3)"
  # Mixed extra (4)
  "1 + 2 * 3 - 4"
  "(1 + 2) * (3 - 4)"
  "2 * 3 + 4 * 5"
  "(2 + 3 + 4) * 2"
)
declare -a T7_WANT=(
  "14" "20" "25" "4" "10" "8"
  "1024" "0.25" "1" "0.5"
  "-2" "2" "5" "-5"
  "3" "-3" "26" "18"
)
for i in "${!T7_EXPR[@]}"; do
  expr="${T7_EXPR[$i]}"
  want="${T7_WANT[$i]}"
  if run_cli "$expr"; then
    got="$STDOUT"
    if [[ "$got" == "$want" ]]; then
      pass "T7.$((i+1)): '$expr' → '$want'"
    else
      fail "T7.$((i+1)): '$expr' → expected '$want', got '$got'"
    fi
  else
    fail "T7.$((i+1)): '$expr' → non-zero exit; stderr='$STDERR'" "$STDERR"
  fi
done

# ============================================================================
# T8: CLI is installed (preflight, reports environment)
# ============================================================================
section "T8: CLI installation preflight"

if [[ "$CLI_AVAILABLE" == "true" ]]; then
  pass "CLI driver available: ${CLI_CMD[*]}"
else
  printf "  ${B}ℹ INFO${D} — T8: no CLI installed (TDD RED expected; will work after Issue #299 impl lands)\n"
  # Don't fail T8 — it's a preflight, not a contract. The contract is in T1-T7.
fi

# ============================================================================
# Summary
# ============================================================================
section "SUMMARY"
TOTAL=$((PASS + FAIL))
printf "  ${B}Total:${D}  %d\n" "$TOTAL"
printf "  ${G}Passed:${D} %d\n" "$PASS"
if [[ $FAIL -gt 0 ]]; then
  printf "  ${R}Failed:${D} %d\n" "$FAIL"
fi
printf "\n"

if [[ $FAIL -eq 0 ]]; then
  printf "${G}${B}ALL TESTS PASSED${D}\n"
  exit 0
else
  printf "${R}${B}SOME TESTS FAILED${D} (TDD RED expected until parser impl lands)\n"
  exit 1
fi
