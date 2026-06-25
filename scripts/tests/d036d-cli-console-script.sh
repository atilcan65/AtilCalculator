#!/usr/bin/env bash
# d036d-cli-console-script.sh — hermetic regression test for STORY-316
# (installable `atilcalc` console-script in pyproject.toml).
#
# Why this test exists
# --------------------
# Issue #316 spec: `pip install atilcalc` (or `pip install -e .[dev]` in dev)
# must create an `atilcalc` console-script entry on PATH so users can run
# `atilcalc 0.1 + 0.2` instead of `python -m atilcalc 0.1 + 0.2`.
#
# The contract has two halves:
#   (a) pyproject.toml declarative half — `[project.scripts]` section with
#       `atilcalc = "atilcalc.cli:main"` entry. This is the source of truth.
#   (b) Install verification half — after `pip install -e .[dev]`, `which atilcalc`
#       returns a path. Sister pytest test in tests/cli/test_console_script.py
#       (skipped when not installed — same portable pattern as d036a/b/c).
#
# This d-test covers half (a) hermetically (no install required) so the
# TDD red is observable on a fresh checkout BEFORE `pip install` has been run.
#
# Sister test: tests/cli/test_console_script.py (pytest, install-dependent).
#
# Test cases (4 TUs):
#   T1: preflight — pyproject.toml exists at repo root
#   T2: pyproject.toml has [project.scripts] section
#   T3: [project.scripts] has `atilcalc = "atilcalc.cli:main"` entry
#   T4: [project.scripts] atilcalc entry's module path resolves (src/atilcalc/cli/__init__.py
#       has `def main(` callable)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d036d-cli-console-script.sh
#
# TDD status (this PR): RED on master — T2/T3 fail because [project.scripts]
# is not present. Turns GREEN once dev adds the [project.scripts] entry.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PYPROJECT="$REPO_ROOT/pyproject.toml"
CLI_MODULE="$REPO_ROOT/src/atilcalc/cli/__init__.py"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# --- T0: preflight — pyproject.toml exists ---
section "T0: preflight — pyproject.toml exists"
if [[ ! -f "$PYPROJECT" ]]; then
  fail "pyproject.toml not found at $PYPROJECT" "TDD-red: pyproject.toml must exist"
  printf "\n${B}==== SUMMARY ====${D}\n  ${G}PASS${D}: %d\n  ${R}FAIL${D}: %d\n" "$PASS" "$FAIL"
  exit 1
fi
pass "pyproject.toml exists at $PYPROJECT"

# --- T1: [project.scripts] section present ---
section "T1: pyproject.toml has [project.scripts] section"
if grep -qE '^\[project\.scripts\]' "$PYPROJECT"; then
  pass "[project.scripts] section present in pyproject.toml"
else
  fail "[project.scripts] section MISSING" "expected: [project.scripts] section header in pyproject.toml. Issue #316 §How sub-task 1."
fi

# --- T2: atilcalc = "atilcalc.cli:main" entry present ---
section "T2: [project.scripts] has atilcalc = \"atilcalc.cli:main\" entry"
# Match the assignment line, tolerating whitespace + quoting variants.
if grep -EqE '^[[:space:]]*atilcalc[[:space:]]*=[[:space:]]*["'"'"']atilcalc\.cli:main["'"'"']' "$PYPROJECT"; then
  pass "atilcalc = \"atilcalc.cli:main\" entry present"
else
  fail "atilcalc = \"atilcalc.cli:main\" entry MISSING" "expected: atilcalc = \"atilcalc.cli:main\" under [project.scripts]. Issue #316 §How sub-task 1."
fi

# --- T3: atilcalc.cli:main resolves to a real callable ---
section "T3: atilcalc.cli module exposes a main() callable"
if [[ ! -f "$CLI_MODULE" ]]; then
  fail "src/atilcalc/cli/__init__.py not found at $CLI_MODULE" "Issue #316 AC depends on the CLI module + main() callable from PR #306 (STORY-CLI-001)"
else
  if grep -EqE '^def main\(' "$CLI_MODULE"; then
    pass "src/atilcalc/cli/__init__.py defines def main("
  else
    fail "src/atilcalc/cli/__init__.py does NOT define def main(" "Issue #316 AC: console-script entry must point to atilcalc.cli:main — module must expose it"
  fi
fi

printf "\n${B}==== SUMMARY ====${D}\n  ${G}PASS${D}: %d\n  ${R}FAIL${D}: %d\n" "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
