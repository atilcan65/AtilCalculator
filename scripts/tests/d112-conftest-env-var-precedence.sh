#!/usr/bin/env bash
# d112-conftest-env-var-precedence.sh — TD-046-extension conftest.py env-var precedence regression guard
#
# Why this test exists
# --------------------
# Sprint 22 PIVOT path-(b) self-hosted runner baseline revealed dual-source-of-truth
# violation in tests/conftest.py:115 — module-level BUDGET_MULTIPLIER constant
# evaluated at conftest import time via _BUDGET_MULTIPLIER_MAP[detect_runner_env()],
# bypassing os.environ.get("BUDGET_MULTIPLIER") set by .github/workflows/ci.yml.
#
# Per ADR-0019 amendment 3 §Runner-aware multipliers, env var = single source of
# truth for operator overrides. conftest.py must align. Arch design cmt 4847385602
# delivers the canonical precedence:
#   1. Operator env var (os.environ['BUDGET_MULTIPLIER' / 'SUBPROCESS_TIMEOUT_S'])
#   2. Runner detection (detect_runner_env() → self-hosted|github-hosted|local)
#   3. Hardcoded map fallback (_BUDGET_MULTIPLIER_MAP / _SUBPROCESS_TIMEOUT_MAP_S)
# Fail-loud (ValueError) on unparseable env var per ADR-0056 silent_skip sister-pattern.
#
# 7 TCs (≥5 baseline per ADR-0049 d-test framework sister-pattern):
#   TC1: env var BUDGET_MULTIPLIER=1.5 set, RUNNER_ENV unset → 1.5 / 5.0
#        (operator override takes precedence; SUBPROCESS_TIMEOUT_S still uses runner-default)
#   TC2: env unset, RUNNER_ENV=self-hosted → 2.0 / 10.0
#        (Sprint 22 PIVOT self-hosted canonical baseline; map fallback path)
#   TC3: env unset, RUNNER_ENV=github-hosted → 1.0 / 5.0
#        (TC4 regression guard — strict budgets preserved for GH-hosted)
#   TC4: env unset, RUNNER_ENV=local → 1.0 / 5.0
#        (dev workstation default; map fallback path)
#   TC5: env var BUDGET_MULTIPLIER=0 (edge: zero override) → 0.0 / 5.0
#        (zero is a valid override — float('0') == 0.0, NOT missing)
#   TC6: env var BUDGET_MULTIPLIER=garbage ("abc") → raises ValueError at import
#        (fail-loud per ADR-0056 silent_skip sister-pattern)
#   TC7: env var SUBPROCESS_TIMEOUT_S=20.0 (operator override) → 1.0 / 20.0
#        (parallel treatment for SUBPROCESS_TIMEOUT_S sister-contract)
#
# Sister-pattern: d069 (Layer 5 verdict-emoji gate), d036a-d (CLI d-tests invoking
# Python via subprocess), d031 (claim-next-ready shell + Python sister-pattern).
# ≥3 sister-pattern requirement: TC1+TC2+TC6 cover the 3 resolution tiers (env var /
# runner detection / fail-loud) per ADR-0049 §Sister-pattern coverage.
#
# Pre-impl RED state (current main 675a8030):
#   - TC1, TC5, TC7 FAIL: env var precedence not implemented (module-level constant
#     reads _BUDGET_MULTIPLIER_MAP[detect_runner_env()] only, ignoring env var)
#   - TC6 FAIL: garbage env var does NOT raise (coerces to map default via detection)
#   - TC2, TC3, TC4 PASS (by coincidence — runner detection works, env var ignored)
#   → 4/7 FAIL in RED state per ADR-0044 RED-first discipline.
#
# Post-impl GREEN state (after conftest-fix PR lands):
#   - All 7 TCs PASS (env var precedence implemented + fail-loud + parallel treatment)
#   → 7/7 PASS in GREEN state.
#
# Usage:
#   bash d112-conftest-env-var-precedence.sh --self-test
#
# Exit codes:
#   0 — all 7 PASS (GREEN state — TD-046-extension landed)
#   1 — at least one FAIL (RED state — env-var precedence broken)
#   2 — preflight failure (python3 missing, conftest.py missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFTEST_PATH="${REPO_ROOT}/tests/conftest.py"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[0;33m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; Y=""; B=""; D=""
fi

PASS=0; FAIL=0; INFO=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
info() { printf "  ${Y}ℹ INFO${D} — %s\n" "$1"; INFO=$((INFO+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Pre-flight (ADR-0049 sister-pattern — preflight checks first)
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required for conftest resolution" >&2; exit 2; }
[ -f "$CONFTEST_PATH" ] || { echo "ERROR: conftest.py not found at $CONFTEST_PATH" >&2; exit 2; }
[ -f "${REPO_ROOT}/tests/__init__.py" ] || { echo "ERROR: tests/__init__.py missing (PR #721 — required for 'from tests.conftest import X')" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d112 self-test (TD-046-extension conftest env-var precedence, 7 TCs ≥5 baseline per ADR-0049)${D}\n"
printf "${B}=======================================================================${D}\n"
printf "  Conftest path:  %s\n" "$CONFTEST_PATH"
printf "  Sister-pattern: d069 (verdict-gate), d036a-d (CLI+Python), d031 (shell+Python)\n"
printf "  Resolution:     env var > runner detection > hardcoded map (arch cmt 4847385602)\n"
printf "  Fail-loud:      ValueError on garbage env var (ADR-0056 sister-pattern)\n"
printf "  RED-first:      pre-impl TC1,TC5,TC6,TC7 FAIL; TC2,TC3,TC4 PASS-by-coincidence.\n\n"

# Helper: invoke conftest.py resolution under given env vars, capture (stdout, stderr, exit_code).
# Uses subprocess to a temp script that imports conftest + prints constants on one line.
# Args:
#   $1 = "KEY=VAL KEY2=VAL2 ..." env var assignments (space-separated)
# Writes to globals: RES_OUT, RES_ERR, RES_CODE
resolve_conftest() {
  local env_assign="$1"
  local tmpout tmperr
  tmpout=$(mktemp); tmperr=$(mktemp)
  # shellcheck disable=SC2086
  env $env_assign python3 -c "
import sys
sys.path.insert(0, '${REPO_ROOT}')
from tests.conftest import BUDGET_MULTIPLIER, SUBPROCESS_TIMEOUT_S
print(f'{BUDGET_MULTIPLIER} {SUBPROCESS_TIMEOUT_S}')
" >"$tmpout" 2>"$tmperr"
  RES_CODE=$?
  RES_OUT="$(cat "$tmpout")"
  RES_ERR="$(cat "$tmperr")"
  rm -f "$tmpout" "$tmperr"
}

# ============================================================================
# TC1: env var BUDGET_MULTIPLIER=1.5 set, RUNNER_ENV unset → 1.5 / 5.0
# ============================================================================
section "TC1: env var BUDGET_MULTIPLIER=1.5, RUNNER_ENV unset → 1.5 / 5.0"
resolve_conftest "BUDGET_MULTIPLIER=1.5"
if [ "$RES_CODE" -eq 0 ] && [ "$RES_OUT" = "1.5 5.0" ]; then
  pass "TC1 — operator override BUDGET_MULTIPLIER=1.5 takes precedence; SUBPROCESS_TIMEOUT_S uses local-default 5.0"
else
  fail "TC1 — env var precedence broken" "expected '1.5 5.0' (exit 0); got exit=$RES_CODE stdout='$RES_OUT' stderr='$RES_ERR'"
fi

# ============================================================================
# TC2: env unset, RUNNER_ENV=self-hosted → 2.0 / 10.0 (Sprint 22 PIVOT canonical baseline)
# ============================================================================
section "TC2: env unset, RUNNER_ENV=self-hosted → 2.0 / 10.0 (Sprint 22 PIVOT canonical baseline)"
resolve_conftest "RUNNER_ENV=self-hosted"
if [ "$RES_CODE" -eq 0 ] && [ "$RES_OUT" = "2.0 10.0" ]; then
  pass "TC2 — runner detection self-hosted → BUDGET_MULTIPLIER=2.0 SUBPROCESS_TIMEOUT_S=10.0 (per Sprint 22 PIVOT Option B)"
else
  fail "TC2 — self-hosted map fallback broken" "expected '2.0 10.0' (exit 0); got exit=$RES_CODE stdout='$RES_OUT' stderr='$RES_ERR'"
fi

# ============================================================================
# TC3: env unset, RUNNER_ENV=github-hosted → 1.0 / 5.0 (TC4 regression guard)
# ============================================================================
section "TC3: env unset, RUNNER_ENV=github-hosted → 1.0 / 5.0 (TC4 regression guard)"
resolve_conftest "RUNNER_ENV=github-hosted"
if [ "$RES_CODE" -eq 0 ] && [ "$RES_OUT" = "1.0 5.0" ]; then
  pass "TC3 — github-hosted map fallback → strict budgets preserved (BUDGET_MULTIPLIER=1.0 SUBPROCESS_TIMEOUT_S=5.0)"
else
  fail "TC3 — github-hosted map fallback broken" "expected '1.0 5.0' (exit 0); got exit=$RES_CODE stdout='$RES_OUT' stderr='$RES_ERR'"
fi

# ============================================================================
# TC4: env unset, RUNNER_ENV=local → 1.0 / 5.0 (dev workstation default)
# ============================================================================
section "TC4: env unset, RUNNER_ENV=local → 1.0 / 5.0 (dev workstation default)"
resolve_conftest "RUNNER_ENV=local"
if [ "$RES_CODE" -eq 0 ] && [ "$RES_OUT" = "1.0 5.0" ]; then
  pass "TC4 — local map fallback → BUDGET_MULTIPLIER=1.0 SUBPROCESS_TIMEOUT_S=5.0"
else
  fail "TC4 — local map fallback broken" "expected '1.0 5.0' (exit 0); got exit=$RES_CODE stdout='$RES_OUT' stderr='$RES_ERR'"
fi

# ============================================================================
# TC5: env var BUDGET_MULTIPLIER=0 (edge: zero override) → 0.0 / 5.0
# ============================================================================
section "TC5: env var BUDGET_MULTIPLIER=0 (zero override edge) → 0.0 / 5.0"
resolve_conftest "BUDGET_MULTIPLIER=0"
if [ "$RES_CODE" -eq 0 ] && [ "$RES_OUT" = "0.0 5.0" ]; then
  pass "TC5 — zero override accepted (float('0')==0.0, NOT coerced to map default)"
else
  fail "TC5 — zero override broken" "expected '0.0 5.0' (exit 0); got exit=$RES_CODE stdout='$RES_OUT' stderr='$RES_ERR'"
fi

# ============================================================================
# TC6: env var BUDGET_MULTIPLIER=garbage ("abc") → raises ValueError at import (fail-loud)
# ============================================================================
section "TC6: env var BUDGET_MULTIPLIER=abc (garbage) → ValueError (fail-loud per ADR-0056)"
resolve_conftest "BUDGET_MULTIPLIER=abc"
if [ "$RES_CODE" -ne 0 ] && echo "$RES_ERR" | grep -qE "ValueError"; then
  pass "TC6 — garbage env var raises ValueError at conftest import (fail-loud, ADR-0056 silent_skip sister-pattern)"
else
  fail "TC6 — fail-loud broken (env var coercion or silent skip)" \
    "expected exit != 0 + ValueError in stderr; got exit=$RES_CODE stdout='$RES_OUT' stderr='$RES_ERR'"
fi

# ============================================================================
# TC7: env var SUBPROCESS_TIMEOUT_S=20.0 (parallel treatment) → 1.0 / 20.0
# ============================================================================
section "TC7: env var SUBPROCESS_TIMEOUT_S=20.0 (parallel treatment) → 1.0 / 20.0"
resolve_conftest "SUBPROCESS_TIMEOUT_S=20.0"
if [ "$RES_CODE" -eq 0 ] && [ "$RES_OUT" = "1.0 20.0" ]; then
  pass "TC7 — SUBPROCESS_TIMEOUT_S operator override takes precedence; BUDGET_MULTIPLIER uses local-default 1.0"
else
  fail "TC7 — SUBPROCESS_TIMEOUT_S env-var precedence broken" \
    "expected '1.0 20.0' (exit 0); got exit=$RES_CODE stdout='$RES_OUT' stderr='$RES_ERR'"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS:           %d\n" "$PASS"
printf "  FAIL:           %d\n" "$FAIL"
printf "  INFO:           %d\n" "$INFO"
printf "  Conftest:       %s\n" "$CONFTEST_PATH"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — env-var precedence broken per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 7 TCs PASS — TD-046-extension env-var precedence landed${D}\n"
exit 0