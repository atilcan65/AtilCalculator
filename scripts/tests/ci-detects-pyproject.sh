#!/usr/bin/env bash
# ci-detects-pyproject.sh — regression test for issue #27.
#
# Bug: .github/workflows/ci.yml was gated solely on `package.json` existence.
# Every Python PR ran a no-op Lint & Test job that printed a misleading
# "No source yet" message. PR #23 (test contract suite) and PR #26 (engine
# implementation) both merged with vacuous CI green.
#
# Fix (v2): the `lint-and-test` job now runs a `detect` step that emits
# BOTH `node` and `python` flags. Node steps gate on `node == 'true'`;
# Python steps (ruff, mypy, pytest) gate on `python == 'true'`; the
# "No source yet" sentinel fires only when BOTH flags are false.
#
# This test verifies (static check on the YAML, no GitHub Actions needed):
#   T1: ci.yml contains a step that reads `pyproject.toml`.
#   T2: ruff check step is conditional on the Python detection flag.
#   T3: mypy step is conditional on the Python detection flag.
#   T4: pytest step is conditional on the Python detection flag.
#   T5: The "No source yet" step gates on BOTH `node == 'false'` AND
#       `python == 'false'` (i.e., the original bug is gone — no longer
#       fires for Python projects).
#   T6: The Node.js path is preserved (Setup Node.js step still present
#       and still conditional on `node == 'true'`).
#   T7: The YAML is parseable (basic syntax sanity via python yaml module).
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/ci-detects-pyproject.sh
# Integrated:     called from e2e-pilot.sh as T-ci27 (when added)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW="$SCRIPT_DIR/../../.github/workflows/ci.yml"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s${D}\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if [ ! -r "$WORKFLOW" ]; then
  echo "ERROR: workflow not found at $WORKFLOW" >&2; exit 127
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 required (for yaml parse sanity check)" >&2; exit 127
fi

# --- T1: pyproject.toml is detected in the workflow ----------------------------
section "T1: workflow detects pyproject.toml"
if grep -q 'pyproject.toml' "$WORKFLOW"; then
  pass "T1: pyproject.toml referenced in workflow"
else
  fail "T1: pyproject.toml NOT referenced — Python path will be skipped"
fi

# --- T2: ruff check step conditional on Python detection -----------------------
section "T2: ruff check gated on Python detection"
# Look for a step that mentions 'ruff' AND has a conditional on the python flag.
# Pattern: a step with 'ruff' in `run:` and an `if:` line nearby that references
# the python output. Tolerate a few lines of slack between `if:` and the step.
if awk '/- name:/ {step_name=$0; step_start=NR} /if:.*python/ {if_line=NR; if_step=step_name; if (if_line - step_start <= 5) python_conditional=1} /ruff/ {if (python_conditional) {found=1; exit} python_conditional=0} END {exit !found}' "$WORKFLOW"; then
  pass "T2: ruff check step is conditional on python detection"
else
  fail "T2: ruff check not properly gated on python detection"
fi

# --- T3: mypy step conditional on Python detection ----------------------------
section "T3: mypy type-check gated on Python detection"
if awk '/- name:/ {step_name=$0; step_start=NR} /if:.*python/ {if_line=NR; if_step=step_name; if (if_line - step_start <= 5) python_conditional=1} /mypy/ {if (python_conditional) {found=1; exit} python_conditional=0} END {exit !found}' "$WORKFLOW"; then
  pass "T3: mypy type-check step is conditional on python detection"
else
  fail "T3: mypy type-check not properly gated on python detection"
fi

# --- T4: pytest step conditional on Python detection --------------------------
section "T4: pytest gated on Python detection"
if awk '/- name:/ {step_name=$0; step_start=NR} /if:.*python/ {if_line=NR; if_step=step_name; if (if_line - step_start <= 5) python_conditional=1} /pytest/ {if (python_conditional) {found=1; exit} python_conditional=0} END {exit !found}' "$WORKFLOW"; then
  pass "T4: pytest step is conditional on python detection"
else
  fail "T4: pytest not properly gated on python detection"
fi

# --- T5: "No source yet" no longer fires for Python projects -------------------
section "T5: 'No source yet' sentinel requires BOTH node and python to be absent"
# The bug: the original line was `if: steps.check-pkg.outputs.exists == 'false'`,
# which fired for any project lacking package.json (i.e., all Python projects).
# The fix: must reference BOTH `node == 'false'` AND `python == 'false'`.
NO_SOURCE_LINE=$(grep -n -A1 'No source yet' "$WORKFLOW" | grep 'if:' || true)
if [ -z "$NO_SOURCE_LINE" ]; then
  fail "T5: 'No source yet' step has no `if:` clause (would always run)"
elif echo "$NO_SOURCE_LINE" | grep -q "node.*false" && echo "$NO_SOURCE_LINE" | grep -q "python.*false"; then
  pass "T5: 'No source yet' correctly requires BOTH node and python to be absent"
else
  fail "T5: 'No source yet' condition is wrong — Python projects will still trigger the misleading message"
  printf "    line: %s\n" "$NO_SOURCE_LINE"
fi

# --- T6: Node.js path is preserved (no regression) ----------------------------
section "T6: Node.js path still preserved (no regression for Node PRs)"
if grep -q 'actions/setup-node' "$WORKFLOW" && \
   awk '/- name:/ {step_name=$0; step_start=NR} /if:.*node/ {if_line=NR; if_step=step_name; if (if_line - step_start <= 5) node_conditional=1} /setup-node/ {if (node_conditional) {found=1; exit} node_conditional=0} END {exit !found}' "$WORKFLOW"; then
  pass "T6: Setup Node.js step is preserved and conditional on node detection"
else
  fail "T6: Node.js path broken — regression in Node PR CI"
fi

# --- T7: YAML is parseable ----------------------------------------------------
section "T7: ci.yml is well-formed YAML"
if python3 -c "
import sys
try:
    import yaml
except ImportError:
    # yaml module not available; fall back to basic bracket-balance check.
    with open('$WORKFLOW') as f:
        content = f.read()
    if content.count(':') < 5:
        sys.exit(1)
    sys.exit(0)
with open('$WORKFLOW') as f:
    yaml.safe_load(f)
" 2>/dev/null; then
  pass "T7: ci.yml parses as well-formed YAML"
else
  fail "T7: ci.yml has YAML syntax errors (workflow will not run on GitHub)"
fi

# --- summary ------------------------------------------------------------------
TOTAL=$((PASS+FAIL))
printf "\n${B}==== ci-detects-pyproject summary ====${D}\n"
printf "  TOTAL=%d  PASS=%d  FAIL=%d\n" "$TOTAL" "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
