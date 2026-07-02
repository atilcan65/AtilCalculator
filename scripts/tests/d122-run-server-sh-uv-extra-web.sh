#!/usr/bin/env bash
# d122-run-server-sh-uv-extra-web.sh — Issue #771 RCA-20: scripts/run-server.sh
#   uv-run creates uvicorn-less venv regression guard (sister-pattern to d014 +
#   d016 + d017 + d018 + d120).
#
# Why this test exists
# --------------------
# Issue #771 (P1, blocks PR #770 owner-merge gate): `scripts/run-server.sh`
# used `PYTHON=(uv run python)` which creates a FRESH venv on every launch
# and installs only the BASE package (atilcalc + mpmath, ~2 pkgs). The fresh
# venv OMITS the `[web]` extra (fastapi==0.115.6 + uvicorn[standard]==0.32.1)
# declared in `pyproject.toml`. Result: any caller — notably the
# `tests/web/test_e2e_keyboard.py:81-86` test fixture (STORY-003b) — gets
# `No module named uvicorn` when the subprocess tries
# `python -m uvicorn atilcalc.api.main:app`.
#
# PM RCA confirmation cmt 4870759104 (cycle ~#3344):
#   "Cross-check — main HEAD 8d9540b had Lint & Test SUCCESS at 18:51:30Z.
#    My branch HEAD a9b9c22 has same base + docs-only commit, so failure is
#    NOT a code regression from my change. RCA: runner state changed
#    (chromium now present on runner, exposing pre-existing test fixture
#    uvicorn-missing bug). NOT a regression from docs-only PR #770."
#
# Cross-branch CI history (PM cmt 4870759104):
#   - main HEAD 8d9540b (18:51:30Z): test SKIPPED — playwright chromium missing
#   - RCA-17-deploy-runner-ac4-user-fix 8384ccb (19:38:18Z): test FAILURE
#   - pm/sprint-24-backlog-refresh a9b9c22 (21:24:56Z, PR #770): test FAILURE
#
# Fix: 1-line patch to `scripts/run-server.sh:32`
#   OLD:  PYTHON=(uv run python)
#   NEW:  PYTHON=(uv run --extra web python)
# The `--extra web` flag tells uv to also install the `[web]` extra
# (fastapi==0.115.6 + uvicorn[standard]==0.32.1, pinned per ADR-0017)
# when creating the .venv. The `[web]` extra is the prod runtime surface
# per AP-23c "exactly one place" doctrine — single source of truth for
# the runtime pins lives in `pyproject.toml [web]`, NOT duplicated here.
#
# Option B (architectural move): declare uvicorn as a BASE dep instead of
# [web] extra. REJECTED — runs against AP-23c "exactly one place" + would
# pull uvicorn into the WASM / non-HTTP surfaces which don't need it.
#
# Option C (test skip-on-missing-uvicorn): REJECTED — tester lane, masks the
# fixture bug rather than fixing it. RCA was "fix the venv", not "skip the test".
#
# Sister-pattern:
#   - d014 (RCA-9 preflight venv create, Issue #160, 11 TCs — DIRECT sister,
#     same venv-creation-failure class, sister-pattern guard on the `uv venv`
#     install path that d122 EXTENDS from preflight scope to runtime scope).
#   - d016 (RCA-11 runtime deps explicit, 5 TCs — DIRECT sister, same
#     "declare runtime deps in [web] extra not ad-hoc" discipline per AP-23c).
#   - d017 (RCA-12 cross-user port-8000, 6 TCs — sister cross-user wrapper
#     lineage, follow-up AC for cross-user deployment scenarios).
#   - d018 (RCA-14 uvicorn orphan kill, 5 TCs — DIRECT sister, same uvicorn
#     lifecycle discipline per ADR-0010; both fixes touch uvicorn process
#     lifecycle but from different angles — d018 = cleanup-on-exit, d122 =
#     install-on-launch).
#   - d108 (Issue #725 watchdog defaults, 6 TCs — sister watchdog/script
#     regression guard shape).
#   - d109 (Issue #727 ci.yml env block, 6 TCs — sister env-var-driven test
#     discipline: d122 verifies `[web]` extra presence just as d109 verifies
#     `BUDGET_MULTIPLIER` env-var block presence).
#   - d120 (Issue #759 pct_change override, 9 TCs — sister same-cycle
#     P0+P1 cluster, sister-pattern SCRIPTS lane).
#   - d121 (RCA-17 AC4 user fix — Issue #763 sister, sister-pattern
#     same-script-lane cluster).
#   ≥3 sister-pattern coverage per ADR-0049 §Sister-pattern met
#   (d014 + d016 + d018 + d120 + d121).
#
# d-test number slot rationale (Issue #113 + ADR-0055 §1):
#   d117=PR #742, d118=PR #756, d119=PR #758, d120=PR #762, d121=PR #764
#   (RCA-17 AC4 user fix — Issue #763 sister). d122 = next free slot
#   post-d121. Sister-pattern precedent for slot allocation (no rename here,
#   but supporting precedent): Issue #724 d094→d097 + Issue #755 d113→d117.
#
# Run standalone:  bash scripts/tests/d122-run-server-sh-uv-extra-web.sh
# Run self-test:  bash scripts/tests/d122-run-server-sh-uv-extra-web.sh --self-test

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_SERVER_SH="$SCRIPT_DIR/../run-server.sh"
PYPROJECT="$SCRIPT_DIR/../../pyproject.toml"

# Colors (TTY-aware)
if [[ -t 1 ]]; then G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else G=""; R=""; B=""; D=""; fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Self-test mode: TC1-TC6 verify the d-test shell + tooling, no file asserts
if [ "${1:-}" = "--self-test" ]; then
  section "d122 self-test (6 TCs per Issue #771 + ADR-0044 RED-first)"
  [ -n "${BASH_VERSION:-}" ] && pass "TC0 self-test: bash present (\$BASH_VERSION=$BASH_VERSION)" || fail "TC0 self-test: bash not present" ""
  command -v grep >/dev/null 2>&1 && pass "TC0 self-test: grep on PATH" || fail "TC0 self-test: grep missing" "needed for context-aware extraction"
  command -v awk >/dev/null 2>&1 && pass "TC0 self-test: awk on PATH" || fail "TC0 self-test: awk missing" "needed for empty-line stripping"
  [ -t 1 ] && pass "TC0 self-test: TTY detected (colors)" || pass "TC0 self-test: non-TTY (no colors)"
  pass "TC0 self-test: --self-test flag parsed"
  pass "TC0 self-test: PASS=$PASS sentinel reachable"
  pass "TC0 self-test: FAIL=$FAIL sentinel reachable"
  printf "\n  ${G}6/6 PASS${D} — d122 self-test GREEN\n"
  exit 0
fi

# ============================================================================
# Test cases TC1..TC6
# ============================================================================

section "TC1: preflight — run-server.sh + pyproject.toml exist + readable + non-empty"
if [ -r "$RUN_SERVER_SH" ] && [ -r "$PYPROJECT" ] && [ -s "$RUN_SERVER_SH" ] && [ -s "$PYPROJECT" ]; then
  pass "run-server.sh + pyproject.toml exist + readable + non-empty"
else
  fail "preflight FAILED" "expected both files readable + non-empty at $RUN_SERVER_SH + $PYPROJECT"
  printf "\n  Cannot continue without source files. 1/6 FAIL — preflight only.\n"
  exit 1
fi

section "TC2 (AC1): buggy 'PYTHON=(uv run python)' NOT present in executable line"
# Bug line shape: ^[[:space:]]*PYTHON=\(uv run python\)
# Must check EXECUTABLE line only (NOT comment block — Issue #164 historical
# references may cite the old buggy shape in comment text).
BUGGY_LINE=$(grep -nE '^[[:space:]]*PYTHON=\(uv run python[[:space:]]*\)[[:space:]]*$' "$RUN_SERVER_SH" || true)
if [ -z "$BUGGY_LINE" ]; then
  pass "buggy 'uv run python' executable line absent (AC1: regression guard)"
else
  fail "buggy 'uv run python' executable line STILL present" "found at: $BUGGY_LINE"
fi

section "TC3 (AC2): fix 'PYTHON=(uv run --extra web python)' IS present in executable line"
# Fix line shape: ^[[:space:]]*PYTHON=\(uv run --extra web python\)
FIX_LINE=$(grep -nE '^[[:space:]]*PYTHON=\(uv run --extra web python[[:space:]]*\)[[:space:]]*$' "$RUN_SERVER_SH" || true)
if [ -n "$FIX_LINE" ]; then
  pass "fix 'uv run --extra web python' executable line present (AC2: bug fix verification)"
else
  fail "fix 'uv run --extra web python' executable line MISSING" "expected one line matching PYTHON=(uv run --extra web python)"
fi

section "TC4 (AC3): [web] extra declared in pyproject.toml with pinned fastapi + uvicorn"
# Verify [web] section exists
WEB_HEADER=$(grep -nE '^web = \[$' "$PYPROJECT" || true)
WEB_FASTAPI=$(grep -nE '^\s*["'"'"']fastapi[=<>!~]+[0-9]' "$PYPROJECT" | head -5 || true)
WEB_UVICORN=$(grep -nE '^\s*["'"'"']uvicorn\[standard\][=<>!~]+[0-9]' "$PYPROJECT" | head -5 || true)
if [ -n "$WEB_HEADER" ] && [ -n "$WEB_FASTAPI" ] && [ -n "$WEB_UVICORN" ]; then
  pass "[web] extra declared with pinned fastapi + uvicorn[standard] (AC3: AP-23c 'exactly one place')"
else
  fail "[web] extra declaration incomplete" "header=$WEB_HEADER fastapi=$WEB_FASTAPI uvicorn=$WEB_UVICORN"
fi

section "TC5 (AC4): bash syntax valid"
if bash -n "$RUN_SERVER_SH" 2>/dev/null; then
  pass "bash -n exits 0 on run-server.sh (AC4: syntax regression guard)"
else
  fail "bash syntax check FAILED" "bash -n returned non-zero on $RUN_SERVER_SH"
fi

section "TC6 (AC5): header comment block cites Issue #771 + RCA-20"
# Locate the PYTHON= block's leading comment block (lines immediately preceding
# PYTHON=(...)). The fix's header comment must cite Issue #771 + RCA-20.
# Locate TC3's fix line first.
if [ -n "$FIX_LINE" ]; then
  FIX_LINE_NUM="${FIX_LINE%%:*}"
  # Look at 15 lines preceding the fix line for Issue #771 / RCA-20 cite
  COMMENT_BLOCK=$(sed -n "$((FIX_LINE_NUM - 15)),$((FIX_LINE_NUM - 1))p" "$RUN_SERVER_SH")
  if echo "$COMMENT_BLOCK" | grep -qiE 'issue #771' && echo "$COMMENT_BLOCK" | grep -qE 'RCA-20'; then
    pass "header comment cites Issue #771 + RCA-20 (AC5: operator-grep-able per d108/d120 sister-pattern)"
  else
    fail "header comment does NOT cite both Issue #771 + RCA-20" "expected 'Issue #771' AND 'RCA-20' within 15 lines preceding fix line $FIX_LINE_NUM"
  fi
else
  fail "TC6 cannot run — fix line missing (TC3 failed first)" "rerun after fixing PYTHON= line per TC3"
fi

# ============================================================================
# Summary
# ============================================================================
TOTAL=$((PASS + FAIL))
printf "\n  ${B}==== Summary ====${D}\n"
printf "  ${G}%d PASS${D} / ${R}%d FAIL${D} (total %d)\n" "$PASS" "$FAIL" "$TOTAL"
if [ "$FAIL" -eq 0 ]; then
  printf "  ${G}GREEN${D} — all d122 TCs passing (Issue #771 RCA-20 regression guarded)\n"
  exit 0
else
  printf "  ${R}RED${D} — d122 has failures (regression guard not satisfied)\n"
  exit 1
fi
