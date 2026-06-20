#!/usr/bin/env bash
# d014-rca-9-preflight-venv-create.sh — regression test for Issue #160
# (RCA-9 — first auto-deploy after PR #157 v5 merge FAILED at
# run #27862367000 because v5 preflight dep install was WARN/SKIP
# when `.venv` was missing on a fresh self-hosted runner checkout).
#
# Bug-class defended against (RCA-9 root cause):
#   v5 deploy-runner.sh preflight dep install block was:
#     if [[ -d "$REPO_DIR/.venv" ]] && command -v uv >/dev/null 2>&1; then
#       uv pip install ...   # happy path
#     else
#       log "WARN: .venv or uv not found at ... — skipping preflight dep install"
#     fi
#   Then `restart_service()` failed at `.venv/bin/uvicorn not found` (exit 3).
#   v6 replaces this with FAIL-or-CREATE:
#     - uv missing         → fail with exit 4
#     - .venv missing      → uv venv .venv (fail with exit 4 if creation fails)
#     - uv pip install fail → fail with exit 4 (NOT log-only continuation)
#
# Test cases (T1..T11):
#   T1:  preflight dep install block exists in deploy-runner.sh
#   T2:  preflight uses FAIL-or-CREATE pattern (uv-missing → fail with exit 4)
#   T3:  preflight uses FAIL-or-CREATE pattern (.venv-missing → uv venv)
#   T4:  preflight uses FAIL-or-CREATE pattern (uv venv creation failure → fail with exit 4)
#   T5:  uv pip install failure → fail with exit 4 (NOT log-only)
#   T6:  v5 WARN/SKIP phrase "skipping preflight dep install" NOT present
#   T7:  v5 WARN/SKIP phrase ".venv or uv not found" NOT present (else-branch)
#   T8:  v5 WARN/SKIP phrase "engine may fail to import" NOT present
#   T9:  restart_service() defense-in-depth .venv/bin/uvicorn check uses exit 4 (parity)
#   T10: header comment documents RCA-9 fix + new exit code 4
#   T11: --dry-run output mentions FAIL/CREATE / RCA-9 in step 2 line
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d014-rca-9-preflight-venv-create.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_SH="$SCRIPT_DIR/../deploy-runner.sh"

# Colors (TTY-aware)
if [[ -t 1 ]]; then G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else G=""; R=""; B=""; D=""; fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if [ ! -r "$RUNNER_SH" ]; then
  echo "ERROR: deploy-runner.sh not found at $RUNNER_SH" >&2; exit 127
fi

# Helper: extract 3 lines after the FIRST match of a pattern, and check that
# result matches a second pattern. Avoids awk's quoting hell with `2>&1`.
after_match() {
  # usage: after_match <pattern1> <num_lines> <pattern2>
  # returns 0 (true) if pattern2 matches within num_lines after pattern1
  local p1="$1"; local n="$2"; local p2="$3"
  grep -A "$n" -m 1 -E "$p1" "$RUNNER_SH" | grep -Eq "$p2"
}

# ============================================================================
# Test cases T1..T11
# ============================================================================

section "T1: preflight dep install block exists in deploy-runner.sh"
if grep -Eq '^# --- Step 2: preflight dep install' "$RUNNER_SH"; then
  pass "Step 2 preflight block labeled"
else
  fail "Step 2 preflight block not found" "expected '# --- Step 2: preflight dep install' header in $RUNNER_SH"
fi

section "T2: preflight uses FAIL-or-CREATE pattern (uv-missing → fail with exit 4)"
# Pattern: 'command -v uv' check, followed within 3 lines by 'fail ... uv not found ... " 4"'.
if after_match 'command -v uv >/dev/null 2>&1' 3 'fail "uv not found.*4'; then
  pass "uv-missing branch fails with exit 4 (FAIL-or-CREATE pattern)"
else
  fail "uv-missing branch does not fail with exit 4" "expected 'command -v uv' check followed by 'fail ... 4' (RCA-9 v6 pattern)"
fi

section "T3: preflight uses FAIL-or-CREATE pattern (.venv-missing → uv venv)"
if grep -Eq '\[\[ ! -d "\$REPO_DIR/\.venv" \]\]' "$RUNNER_SH" \
   && grep -Eq 'uv venv "\$REPO_DIR/\.venv"' "$RUNNER_SH"; then
  pass ".venv-missing branch creates venv via 'uv venv' (FAIL-or-CREATE pattern)"
else
  fail ".venv-missing branch does not create venv" "expected '[[ ! -d \"$REPO_DIR/.venv\" ]]' followed by 'uv venv \"$REPO_DIR/.venv\"' (RCA-9 v6 pattern)"
fi

section "T4: preflight uses FAIL-or-CREATE pattern (uv venv creation failure → fail with exit 4)"
if after_match 'if ! uv venv' 3 'fail .*4'; then
  pass "uv venv creation failure exits with code 4"
else
  fail "uv venv creation failure does not exit 4" "expected 'if ! uv venv ... ; then fail ... 4' (RCA-9 v6 pattern)"
fi

section "T5: uv pip install failure → fail with exit 4 (NOT log-only)"
if after_match 'if ! uv pip install' 3 'fail .*4'; then
  pass "uv pip install failure exits with code 4"
else
  fail "uv pip install failure does not exit 4" "expected 'if ! uv pip install ... ; then fail ... 4' (RCA-9 v6 pattern, was WARN-only in v5)"
fi
# Also check the v5 anti-pattern is NOT present.
if grep -Eq 'WARN: uv pip install exited non-zero; engine may fail to import' "$RUNNER_SH"; then
  fail "v5 WARN/SKIP anti-pattern REGRESSED" "phrase 'WARN: uv pip install exited non-zero; engine may fail to import' is the v5 silent-WARN bug; v6 must fail-fast"
fi

section "T6: v5 WARN/SKIP phrase 'skipping preflight dep install' NOT present"
if grep -Fq 'skipping preflight dep install' "$RUNNER_SH"; then
  fail "v5 WARN/SKIP anti-pattern present" "phrase 'skipping preflight dep install' is the v5 silent-skip bug; v6 must fail-fast"
else
  pass "v5 silent-skip phrase absent"
fi

section "T7: v5 WARN/SKIP phrase '.venv or uv not found' (else-branch) NOT present"
if grep -Fq 'WARN: .venv or uv not found' "$RUNNER_SH"; then
  fail "v5 else-branch WARN/SKIP anti-pattern present" "phrase 'WARN: .venv or uv not found' is the v5 silent-skip else-branch; v6 must split into FAIL/CREATE"
else
  pass "v5 silent-skip else-branch absent"
fi

section "T8: v5 WARN/SKIP phrase 'engine may fail to import' NOT present"
if grep -Fq 'engine may fail to import' "$RUNNER_SH"; then
  fail "v5 continuation-WARN anti-pattern present" "phrase 'engine may fail to import' is the v5 'WARN and continue' bug; v6 must fail-fast"
else
  pass "v5 continuation-WARN phrase absent"
fi

section "T9: restart_service() defense-in-depth .venv/bin/uvicorn check uses exit 4 (parity)"
if after_match 'uvicorn.*not found or not executable' 3 'fail .*4'; then
  pass "restart_service() existence check fails with exit 4"
else
  fail "restart_service() existence check does not use exit 4" "expected 'fail ... 4' (parity with preflight category); was exit 3 in v5"
fi

section "T10: header comment documents RCA-9 fix + new exit code 4"
if grep -Eq 'RCA-9' "$RUNNER_SH" \
   && grep -Eq 'preflight failure' "$RUNNER_SH" \
   && grep -Eq '^#   4  — preflight failure' "$RUNNER_SH"; then
  pass "header documents RCA-9 + new exit code 4"
else
  fail "header missing RCA-9 + exit code 4 documentation" "expected 'RCA-9', 'preflight failure', and exit code 4 line in header comment"
fi

section "T11: --dry-run output mentions FAIL/CREATE / RCA-9 in step 2 line"
if grep -Eq 'step 2: preflight uv venv \.venv \(if missing\) \+ uv pip install.*RCA-9' "$RUNNER_SH"; then
  pass "dry-run step 2 line references FAIL/CREATE + RCA-9"
else
  fail "dry-run step 2 line does not reference RCA-9" "expected 'step 2: preflight uv venv .venv (if missing) + uv pip install ... (RCA-9 FAIL/CREATE)'"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
TOTAL=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
  printf "${G}${B}ALL %d TESTS PASSED${D}\n" "$PASS"
  exit 0
else
  printf "${R}${B}%d/%d TESTS FAILED${D}\n" "$FAIL" "$TOTAL"
  exit 1
fi