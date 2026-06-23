#!/usr/bin/env bash
# d036a-cli-basic-arithmetic.sh — regression test for Issue #299 | PR #303 (test plan)
#
# Why this test exists
# --------------------
# Sprint 7 P0 (STORY-CLI-001, basic arithmetic via typer CLI). Test plan landed
# in PR #303 (docs/test-plans/STORY-299-tests.md, 8 TCs, 15 pytest cases).
# Per TDD RED-first discipline, this shell test exists BEFORE the CLI impl —
# it MUST FAIL until src/atilcalc/cli/ + src/atilcalc/__main__.py land.
#
# Sister test: pytest version lives in tests/cli/test_basic_arithmetic.py
# (same 15 TUs, ported to subprocess.run() for finer-grained assertions).
#
# Test cases (per docs/test-plans/STORY-299-tests.md):
#   T1:  M1 baseline `0.1 + 0.2 == 0.3` (4 cases, TC-1)
#   T2:  Integer/decimal arithmetic (4 cases, TC-2)
#   T3:  Large numbers (3 cases, TC-3)
#   T4:  Division by zero error path (3 cases, TC-4)
#   T5:  Invalid expression error path (3 cases, TC-5)
#   T6:  M1 acceptance test: `atilcalc 0.1 + 0.2` → stdout `0.3` (AC1, AC7)
#   T7:  Subprocess timeout / DoS guard (adversarial probe)
#   T8:  CLI is installed (binary on PATH or `python -m atilcalc` works)
#
# Exit code: 0 = all pass, 1 = at least one fail.
# Run standalone: bash scripts/tests/d036a-cli-basic-arithmetic.sh
#
# Refs: Issue #299, PR #303, docs/backlog/STORY-CLI-001.md, ADR-0017, ADR-0031

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

# Helper: run CLI and capture stdout/stderr/exit code.
# Writes to the caller's variables by name (printf -v trick). The out/err/code
# variables inside the function are NOT local so printf -v can write back to
# the caller's scope.
run_cli() {
  local stdout_var="$1"; shift
  local stderr_var="$1"; shift
  local exit_var="$1"; shift
  out="" err="" code=0
  if [[ ${#CLI_CMD[@]} -eq 0 ]]; then
    # No CLI available; capture the import error
    err="$(python3 -m atilcalc "$@" 2>&1 >/dev/null || true)"
    code=1
  else
    # Use a temp file to capture exit code reliably (no subshell issue with $?)
    tmpout=$(mktemp); tmperr=$(mktemp)
    "${CLI_CMD[@]}" "$@" >"$tmpout" 2>"$tmperr"
    code=$?
    out=$(cat "$tmpout"); err=$(cat "$tmperr")
    rm -f "$tmpout" "$tmperr"
  fi
  printf -v "$stdout_var" '%s' "$out"
  printf -v "$stderr_var" '%s' "$err"
  printf -v "$exit_var" '%d' "$code"
}

# ---------------------------------------------------------------------------
# T1: M1 baseline `0.1 + 0.2 == 0.3` (4 cases from TC-1)
# ---------------------------------------------------------------------------
section "T1: M1 baseline — 0.1 + 0.2 == 0.3 (AC1, TC-1)"
declare -a T1_CASES=(
  "0.1 + 0.2|0.3"
  "0.1 + 0.2 + 0.3|0.6"
  "0.1 + 0.2 + 0.3 + 0.4|1.0"
  "2 + 3|5"
)
for case in "${T1_CASES[@]}"; do
  expr="${case%|*}"; want="${case##*|}"
  run_cli out err code $expr
  if [[ "$code" -eq 0 && "$out" == "$want" ]]; then
    pass "M1 baseline: '$expr' → '$want'"
  else
    fail "M1 baseline: '$expr' → '$want'" "got exit=$code stdout='$out' stderr='$err'"
  fi
done

# ---------------------------------------------------------------------------
# T2: Integer/decimal arithmetic (4 cases from TC-2)
# ---------------------------------------------------------------------------
section "T2: Integer/decimal arithmetic (AC2, TC-2)"
declare -a T2_CASES=(
  "1.5 * 3|4.5"
  "2 + 3|5"
  "10 / 3|3.333333333333333333333333333"
  "100 - 50|50"
)
for case in "${T2_CASES[@]}"; do
  expr="${case%|*}"; want="${case##*|}"
  run_cli out err code $expr
  if [[ "$code" -eq 0 && "$out" == "$want" ]]; then
    pass "int/decimal: '$expr' → '$want'"
  else
    fail "int/decimal: '$expr' → '$want'" "got exit=$code stdout='$out' stderr='$err'"
  fi
done

# ---------------------------------------------------------------------------
# T3: Large numbers (3 cases from TC-3)
# ---------------------------------------------------------------------------
section "T3: Large numbers (AC3, TC-3)"
declare -a T3_CASES=(
  "999999999 * 999999999|999999998000000001"
  "2 ** 64|18446744073709551616"
  "0.000000001 + 0.000000002|0.000000003"
)
for case in "${T3_CASES[@]}"; do
  expr="${case%|*}"; want="${case##*|}"
  run_cli out err code $expr
  if [[ "$code" -eq 0 && "$out" == "$want" ]]; then
    pass "large: '$expr' → '$want'"
  else
    fail "large: '$expr' → '$want'" "got exit=$code stdout='$out' stderr='$err'"
  fi
done

# ---------------------------------------------------------------------------
# T4: Division by zero error path (3 cases from TC-4)
# ---------------------------------------------------------------------------
section "T4: Division by zero error path (AC5, TC-4)"
declare -a T4_CASES=(
  "1 / 0"
  "0 / 0"
  "1 / (2 - 2)"
)
for expr in "${T4_CASES[@]}"; do
  run_cli out err code $expr
  err_norm="$(echo "$err" | tr '[:upper:]' '[:lower:]' | tr -d ' _')"
  if [[ "$code" -ne 0 ]] \
     && [[ "$out" != *"inf"* && "$out" != *"Inf"* && "$out" != *"INFINITY"* ]] \
     && [[ "$err_norm" == *"divisionbyzero"* ]]; then
    pass "div/zero: '$expr' → clear error"
  else
    fail "div/zero: '$expr' → clear error" "got exit=$code stdout='$out' stderr='$err'"
  fi
done

# ---------------------------------------------------------------------------
# T5: Invalid expression error path (3 cases from TC-5)
# ---------------------------------------------------------------------------
section "T5: Invalid expression error path (AC6, TC-5)"
declare -a T5_CASES=(
  "1 + + 2"
  ""
  "abc"
)
for expr in "${T5_CASES[@]}"; do
  # Split expression on whitespace for argv
  if [[ -z "$expr" ]]; then
    run_cli out err code ""
  else
    # shellcheck disable=SC2086
    run_cli out err code $expr
  fi
  err_lower="$(echo "$err" | tr '[:upper:]' '[:lower:]')"
  if [[ "$code" -ne 0 ]] \
     && [[ "$out" != *"Traceback"* ]] \
     && [[ "$err" != *"Traceback"* ]] \
     && [[ "$err_lower" == *"parse"* || "$err_lower" == *"error"* ]]; then
    pass "invalid expr: '$expr' → clear error"
  else
    fail "invalid expr: '$expr' → clear error" "got exit=$code stdout='$out' stderr='$err'"
  fi
done

# ---------------------------------------------------------------------------
# T6: M1 acceptance test (AC1) — `atilcalc 0.1 + 0.2` → stdout `0.3`
# This is the persona-level acceptance: P1 (Atil) runs this daily.
# ---------------------------------------------------------------------------
section "T6: M1 acceptance — atilcalc 0.1 + 0.2 → 0.3 (AC1)"
run_cli out err code 0.1 + 0.2
if [[ "$code" -eq 0 && "$out" == "0.3" ]]; then
  pass "M1 acceptance: 0.1 + 0.2 → 0.3 (no float artifact)"
else
  fail "M1 acceptance: 0.1 + 0.2 → 0.3" "got exit=$code stdout='$out' stderr='$err'"
fi

# ---------------------------------------------------------------------------
# T7: Subprocess timeout / DoS guard (adversarial probe: long expression)
# Per test plan §Adversarial Probes: 1000-op expression should be < 1s
# ---------------------------------------------------------------------------
section "T7: Adversarial — 1000-op expression completes in < 5s (DoS guard)"
if [[ ${#CLI_CMD[@]} -eq 0 ]]; then
  # No CLI; trivially pass for now (we'll wire this up after impl lands)
  skip_msg="no CLI available yet; TDD RED state"
  printf "  ${B}— SKIP${D} — %s\n" "$skip_msg"
else
  long_expr="$(python3 -c 'print("+".join(["1"]*1000))')"
  start_ms=$(date +%s%3N 2>/dev/null || date +%s)
  run_cli out err code $long_expr
  end_ms=$(date +%s%3N 2>/dev/null || date +%s)
  elapsed_ms=$((end_ms - start_ms))
  if [[ "$code" -eq 0 && "$elapsed_ms" -lt 5000 ]]; then
    pass "1000-op expression in ${elapsed_ms}ms (< 5000ms DoS guard)"
  else
    fail "1000-op expression" "got exit=$code in ${elapsed_ms}ms"
  fi
fi

# ---------------------------------------------------------------------------
# T8: CLI driver detection (preflight: is the binary callable?)
# ---------------------------------------------------------------------------
section "T8: Preflight — CLI driver detection"
if [[ ${#CLI_CMD[@]} -eq 0 ]]; then
  # TDD RED: no impl yet, expected to fail
  fail "CLI driver available" "neither 'atilcalc' binary nor 'python3 -m atilcalc' resolves"
else
  pass "CLI driver available: ${CLI_CMD[*]}"
fi

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------
printf "\n${B}==== SUMMARY ====${D}\n  ${G}PASS${D}: %d\n  ${R}FAIL${D}: %d\n" "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
