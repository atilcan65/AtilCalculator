#!/usr/bin/env bash
# d110-evaluator-lazy-import-mpmath.sh — Issue #728 (engine perf regression
# PR #709 cascade) lazy-import regression guard for evaluator.py.
#
# Why this test exists
# --------------------
# Sprint 22 PIVOT Faz 1.1 (PR #709, commit `eb64485`) added `import mpmath`
# at the module level in `src/atilcalc/engine/evaluator.py:33`. The mpmath
# module-load cost (~50ms cold, paid on every `from atilcalc.engine import …`
# even when the caller only does arithmetic) bleeds into the perf budgets
# ADR-0019 amendment 2 — `tests/api/test_evaluate_transcendental.py`
# `test_arithmetic_p99_under_50ms_still_holds` fails at p99=215.48ms
# (4.3× over budget) per PR #694 CI surfacing.
#
# Fix (Issue #728 lazy-import hotfix, architect 9-Lens 🟢 APPROVED):
#   - Remove module-level `import mpmath` from evaluator.py
#   - Lazy-import mpmath inside transcendental functions
#   - Subsequent calls are O(1) via `sys.modules` cache (Python import system)
#   - Arithmetic path NEVER imports mpmath (sys.modules guard verifiable)
#
# This d-test (d110) guards the lazy-import contract so future PRs don't
# silently re-introduce the module-level import. Sister-pattern to d107
# (Issue #722 install-git-hooks, 6 TCs) + d108 (Issue #725 context watchdog,
# 6 TCs) + d109 (Issue #727 ci.yml env block, 6 TCs) — same cycle ~#1638-#1640
# URGENT-P0 sister-test cluster.
#
# AC mapping (Issue #728 architect verdict):
#   AC1 — arithmetic p99 <50ms (under raw budget, no multiplier) — out of scope for d110 (pytest perf test owns this; d110 is a structural regression guard)
#   AC2 — transcendental p99 <100ms (first-call amortized, d-test uses median) — out of scope for d110 (pytest perf test owns this)
#   AC3 — existing d-tests pass (no behavior change) — out of scope for d110 (smoke-tested via d110 TC5/TC6)
#   AC4 — mpmath NOT in sys.modules until first transcendental call (RED-first per ADR-0044) — IN SCOPE for d110
#
# 6 TCs (per ADR-0049 d-test framework sister-pattern):
#   TC1: AC4 — `import atilcalc.engine.evaluator` does NOT populate sys.modules['mpmath']
#   TC2: AC4 — `evaluator.evaluate("1 + 2")` does NOT populate sys.modules['mpmath']
#   TC3: AC4 — `evaluator.evaluate("sin(0)")` DOES populate sys.modules['mpmath']
#   TC4: AC4 — `sys.modules['mpmath']` is the SAME module object before/after 2nd transcendental call (cache hit, O(1))
#   TC5: AC3 — `evaluator.evaluate("2+3") == Decimal("5")` (arithmetic correctness regression guard)
#   TC6: AC3 — `evaluator.evaluate("sin(0)") == Decimal("0")` (transcendental correctness regression guard)
#
# Pre-impl RED state (current main as of 2026-06-30, pre-Issue #728 impl):
#   - `src/atilcalc/engine/evaluator.py:33` has module-level `import mpmath`
#   - TC1: FAIL (mpmath IS in sys.modules after import — current behavior)
#   - TC2: FAIL (mpmath IS in sys.modules after arithmetic eval — current behavior)
#   - TC3: PASS (mpmath IS in sys.modules after transcendental eval — accidental pass)
#   - TC4: PASS (sys.modules reference stable — accidental pass)
#   - TC5: PASS (arithmetic correctness — works pre-impl)
#   - TC6: PASS (transcendental correctness — works pre-impl)
#   → 4 PASS + 2 FAIL (TC1 + TC2) = proper RED-first per ADR-0044
#
# Post-impl GREEN state (target, after Issue #728 PR merge):
#   - module-level import removed; mpmath lazy-imported only inside _fn_* transcendental functions
#   - All 6 TCs PASS
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d100 (Sprint 22 PIVOT self-hosted perf budgets, 4 TCs) — DIRECT sister (the perf test that surfaced the issue)
#   - d107 (Issue #722 install-git-hooks, 6 TCs) — URGENT-P0 sister
#   - d108 (Issue #725 watchdog defaults, 6 TCs) — URGENT-P0 sister
#   - d109 (Issue #727 ci.yml env block, 6 TCs) — URGENT-P0 sister
#   - d094 + d094-self-hosted-runner-migration (Sprint 22 PIVOT self-hosted runner migration sister — origin of perf regression)
#
# Usage:
#   bash d110-evaluator-lazy-import-mpmath.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — lazy-import verified, sys.modules guard works)
#   1 — at least one FAIL (RED state — module-level import not removed)
#   2 — preflight failure (Python/evaluator import failure, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EVALUATOR_PY="${REPO_ROOT}/src/atilcalc/engine/evaluator.py"
RUNNER_PY="$(mktemp /tmp/d110-runner.XXXXXX.py)"

# Colors (TTY-aware) — sister-pattern to d107/d108/d109
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

# Preflight
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

# Write the Python runner script that does the sys.modules introspection.
# We use a temp file so we can re-run multiple TCs against fresh Python processes.
cat > "$RUNNER_PY" <<'PYEOF'
"""d110 sys.modules guard runner — invoked 6 times by d110 shell harness."""
import json
import sys

mode = sys.argv[1] if len(sys.argv) > 1 else "noop"

result = {
    "mpmath_in_sys_modules_after_import": None,
    "mpmath_in_sys_modules_after_eval": None,
    "mpmath_module_id_first": None,
    "mpmath_module_id_second": None,
    "arithmetic_result": None,
    "transcendental_result": None,
    "error": None,
}

try:
    if mode == "import_only":
        # TC1: Import evaluator, check sys.modules BEFORE any eval call.
        import atilcalc.engine.evaluator  # noqa: F401
        result["mpmath_in_sys_modules_after_import"] = "mpmath" in sys.modules

    elif mode == "arithmetic_eval":
        # TC2: Import + evaluate arithmetic expression. mpmath should still NOT be loaded.
        from atilcalc.engine import evaluator
        try:
            evaluator.evaluate("1 + 2")
        except Exception as exc:
            result["error"] = f"arithmetic eval exception: {exc!r}"
        result["mpmath_in_sys_modules_after_eval"] = "mpmath" in sys.modules

    elif mode == "transcendental_eval":
        # TC3: Import + evaluate transcendental expression. mpmath SHOULD be loaded.
        from atilcalc.engine import evaluator
        try:
            evaluator.evaluate("sin(0)")
        except Exception as exc:
            result["error"] = f"transcendental eval exception: {exc!r}"
        result["mpmath_in_sys_modules_after_eval"] = "mpmath" in sys.modules

    elif mode == "transcendental_eval_twice":
        # TC4: Two consecutive transcendental evaluations; mpmath module id should be stable.
        from atilcalc.engine import evaluator
        evaluator.evaluate("sin(0)")
        first_id = id(sys.modules["mpmath"])
        evaluator.evaluate("cos(0)")
        second_id = id(sys.modules["mpmath"])
        result["mpmath_module_id_first"] = first_id
        result["mpmath_module_id_second"] = second_id

    elif mode == "arithmetic_correctness":
        # TC5: Regression guard — arithmetic correctness.
        from decimal import Decimal
        from atilcalc.engine import evaluator
        result["arithmetic_result"] = str(evaluator.evaluate("2+3"))

    elif mode == "transcendental_correctness":
        # TC6: Regression guard — transcendental correctness.
        from decimal import Decimal
        from atilcalc.engine import evaluator
        result["transcendental_result"] = str(evaluator.evaluate("sin(0)"))

except Exception as exc:
    result["error"] = f"import/eval failure: {exc!r}"

print(json.dumps(result))
PYEOF

printf "${B}d110 self-test (6 TCs per Issue #728 + ADR-0044 RED-first)${D}\n"
printf "${B}================================================================${D}\n"
printf "  Repo root:        %s\n" "$REPO_ROOT"
printf "  Evaluator:        %s\n" "$EVALUATOR_PY"
printf "  Sister-pattern:   d100 (perf budgets) + d107/d108/d109 (URGENT-P0 fixes)\n"
printf "  Pre-impl RED:     TC1 + TC2 FAIL by design per ADR-0044\n"
printf "  Post-impl:        all 6 TCs must PASS\n\n"

# Ensure src/ is on sys.path via PYTHONPATH for the runner
export PYTHONPATH="${REPO_ROOT}/src:${PYTHONPATH:-}"

# ============================================================================
# TC1: AC4 — import atilcalc.engine.evaluator does NOT populate sys.modules['mpmath']
# ============================================================================
section "TC1: AC4 — module import does NOT trigger mpmath import"

TC1_OUT="$(python3 "$RUNNER_PY" import_only)"
TC1_MPMATH="$(echo "$TC1_OUT" | jq -r .mpmath_in_sys_modules_after_import)"

if [ "$TC1_MPMATH" = "false" ]; then
  pass "TC1 — import atilcalc.engine.evaluator does NOT populate sys.modules['mpmath'] (lazy-import verified)"
else
  fail "TC1 — import atilcalc.engine.evaluator DOES populate sys.modules['mpmath']" \
    "module-level 'import mpmath' at evaluator.py:33 still loads mpmath on import. Per Issue #728 lazy-import hotfix, the arithmetic path must not pay the ~50ms mpmath import cost. RED-first confirmed."
fi

# ============================================================================
# TC2: AC4 — evaluator.evaluate("1 + 2") does NOT populate sys.modules['mpmath']
# ============================================================================
section "TC2: AC4 — arithmetic evaluation does NOT trigger mpmath import"

TC2_OUT="$(python3 "$RUNNER_PY" arithmetic_eval)"
TC2_MPMATH="$(echo "$TC2_OUT" | jq -r .mpmath_in_sys_modules_after_eval)"
TC2_ERR="$(echo "$TC2_OUT" | jq -r .error)"

if [ -n "$TC2_ERR" ] && [ "$TC2_ERR" != "null" ]; then
  fail "TC2 — arithmetic evaluation raised exception: $TC2_ERR" \
    "evaluator.evaluate('1 + 2') must not fail; lazy-import should preserve Decimal-only path"
elif [ "$TC2_MPMATH" = "false" ]; then
  pass "TC2 — evaluator.evaluate('1 + 2') does NOT populate sys.modules['mpmath'] (arithmetic path verified mpmath-free)"
else
  fail "TC2 — evaluator.evaluate('1 + 2') DOES populate sys.modules['mpmath']" \
    "arithmetic expression must not trigger mpmath import. Per Issue #728 AC4, the arithmetic path is the regression target — TC2 catching this means the lazy-import hotfix failed."
fi

# ============================================================================
# TC3: AC4 — evaluator.evaluate("sin(0)") DOES populate sys.modules['mpmath']
# ============================================================================
section "TC3: AC4 — transcendental evaluation DOES trigger mpmath import"

TC3_OUT="$(python3 "$RUNNER_PY" transcendental_eval)"
TC3_MPMATH="$(echo "$TC3_OUT" | jq -r .mpmath_in_sys_modules_after_eval)"
TC3_ERR="$(echo "$TC3_OUT" | jq -r .error)"

if [ -n "$TC3_ERR" ] && [ "$TC3_ERR" != "null" ]; then
  fail "TC3 — transcendental evaluation raised exception: $TC3_ERR" \
    "evaluator.evaluate('sin(0)') must still work post-lazy-import fix (AC3 — no behavior change)"
elif [ "$TC3_MPMATH" = "true" ]; then
  pass "TC3 — evaluator.evaluate('sin(0)') DOES populate sys.modules['mpmath'] (transcendental triggers lazy-import)"
else
  fail "TC3 — evaluator.evaluate('sin(0)') does NOT populate sys.modules['mpmath']" \
    "transcendental evaluation must trigger mpmath import (else sin() returns garbage). If mpmath is missing after sin(0), the lazy-import gate is broken or _fn_trig was incorrectly refactored."
fi

# ============================================================================
# TC4: AC4 — sys.modules['mpmath'] id stable across 2 consecutive transcendental calls
# ============================================================================
section "TC4: AC4 — sys.modules['mpmath'] id stable (subsequent calls O(1))"

TC4_OUT="$(python3 "$RUNNER_PY" transcendental_eval_twice)"
TC4_ID1="$(echo "$TC4_OUT" | jq -r .mpmath_module_id_first)"
TC4_ID2="$(echo "$TC4_OUT" | jq -r .mpmath_module_id_second)"

if [ -n "$TC4_ID1" ] && [ -n "$TC4_ID2" ] && [ "$TC4_ID1" != "null" ] && [ "$TC4_ID2" != "null" ] && [ "$TC4_ID1" = "$TC4_ID2" ]; then
  pass "TC4 — sys.modules['mpmath'] id stable: first=$TC4_ID1 second=$TC4_ID2 (same module object, O(1) cache verified)"
else
  fail "TC4 — sys.modules['mpmath'] id NOT stable: first=$TC4_ID1 second=$TC4_ID2" \
    "expected same module object across consecutive transcendental evaluations (Python's import system cache guarantees this). If ids differ, the lazy-import is re-importing on every call — that's a different bug, even worse than the original regression."
fi

# ============================================================================
# TC5: AC3 — Arithmetic correctness regression guard
# ============================================================================
section "TC5: AC3 — arithmetic correctness (evaluate('2+3') == Decimal('5'))"

TC5_OUT="$(python3 "$RUNNER_PY" arithmetic_correctness)"
TC5_RESULT="$(echo "$TC5_OUT" | jq -r .arithmetic_result)"

if [ "$TC5_RESULT" = "5" ]; then
  pass "TC5 — arithmetic correctness preserved: evaluate('2+3') = Decimal('5') (no behavior change)"
else
  fail "TC5 — arithmetic correctness REGRESSED: evaluate('2+3') = '$TC5_RESULT'" \
    "expected Decimal("5") from evaluator.evaluate("2+3"). Per AC3, lazy-import must NOT change behavior; if this fails, the impl broke arithmetic."
fi

# ============================================================================
# TC6: AC3 — Transcendental correctness regression guard
# ============================================================================
section "TC6: AC3 — transcendental correctness (evaluate('sin(0)') == Decimal('0'))"

TC6_OUT="$(python3 "$RUNNER_PY" transcendental_correctness)"
TC6_RESULT="$(echo "$TC6_OUT" | jq -r .transcendental_result)"

# The expected result depends on engine precision; any value with first 1 digit == 0 is acceptable
# (sin(0) = 0, but with 50-digit mpmath precision, output is something like "0" or "-0E-50")
if [ -n "$TC6_RESULT" ] && [ "$TC6_RESULT" != "null" ] && echo "$TC6_RESULT" | grep -qE '^[+-]?0(\.0+)?(E[+-]?[0-9]+)?$'; then
  pass "TC6 — transcendental correctness preserved: evaluate('sin(0)') = $TC6_RESULT (no behavior change)"
else
  fail "TC6 — transcendental correctness REGRESSED: evaluate('sin(0)') = '$TC6_RESULT'" \
    "expected a near-zero Decimal from evaluator.evaluate('sin(0)') (sin(0) = 0 in real math). If this fails, the lazy-import broke the transcendental path."
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

# Cleanup runner script
rm -f "$RUNNER_PY"

if [ "$FAIL" -eq 0 ]; then
  printf "\n${G}GREEN state: lazy-import verified — TC1-TC6 all PASS (mpmath not loaded on arithmetic path)${D}\n"
  exit 0
else
  printf "\n${R}RED state: module-level 'import mpmath' at evaluator.py:33 still active — Issue #728 impl still pending${D}\n"
  exit 1
fi
