#!/usr/bin/env bash
# d031-recovery-scan.sh — regression test for Sprint 4 P0 AUTO-REVERT-FIX (#125).
#
# Issue #125 (2026-06-19): PR cc:* labels auto-revert within 90s. RCA
# (architect, 2026-06-21T08:30Z): 2-mechanism split.
#   - Mechanism A (REAL): actor=User, label re-flip <90s after owner-override merge
#   - Mechanism B (EXPECTED): actor=Bot (label-cleanup.yml), <15s after close
#
# This test enforces the d031-recovery-scan.sh script contract per ADR-0031
# §"Owner-override recovery procedure" (Accepted via PR #206).
#
# Test cases:
#   T1:  script exists at scripts/d031-recovery-scan.sh
#   T2:  script is executable (chmod +x)
#   T3:  header comment references ADR-0031 + Issue #125
#   T4:  script accepts REPO env var (required)
#   T5:  missing REPO → exit code 2 + "ERROR: REPO" message on stderr
#   T6:  kill switch (D031_ENABLED=false) → exit 0 + kill_switch:true JSON
#   T7:  role gate (ROLE=tester) → exit 0 + role_gate:true JSON
#   T8:  happy path (ROLE=orchestrator, REPO=atilcan65/AtilCalculator) → exit 0
#        + JSON with scan_at + drift_findings:[] + todo:[] (scaffold mode)
#   T9:  JSON output has required schema fields (overrides_observed, drift_findings, summary)
#   T10: REPORT_PATH env var appends a line to the report file (no stdout corruption)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d031-recovery-scan.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_SH="$SCRIPT_DIR/../d031-recovery-scan.sh"

if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""; fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 127
fi

# ============================================================================
# T1: script exists
# ============================================================================
section "T1: script exists"
if [ -r "$SCAN_SH" ]; then
  pass "d031-recovery-scan.sh found at $SCAN_SH"
else
  fail "script not found" "expected $SCAN_SH to be readable"
  printf "\n${R}Cannot continue — script missing${D}\n"
  exit 1
fi

# ============================================================================
# T2: script is executable
# ============================================================================
section "T2: script is executable"
if [ -x "$SCAN_SH" ]; then
  pass "d031-recovery-scan.sh is executable"
else
  fail "not executable" "run: chmod +x $SCAN_SH"
fi

# ============================================================================
# T3: header comment references ADR-0031 + Issue #125
# ============================================================================
section "T3: header references ADR-0031 + Issue #125"
if grep -Fq "ADR-0031" "$SCAN_SH" && grep -Fq "#125" "$SCAN_SH"; then
  pass "header has ADR-0031 + Issue #125 references"
else
  fail "header missing references" "expected 'ADR-0031' and '#125' in first 30 lines"
fi

# ============================================================================
# T4: script accepts REPO env var (and reads from ${1:-})
# ============================================================================
section "T4: REPO env var support"
if grep -Eq '^REPO="\$\{REPO:-\$\{1:-' "$SCAN_SH"; then
  pass "REPO env var + positional arg fallback present"
else
  fail "REPO parsing missing" "expected 'REPO=\"\${REPO:-\${1:-}}\"' line"
fi

# ============================================================================
# T5: missing REPO → exit 2 + stderr message
# ============================================================================
section "T5: missing REPO exits with code 2"
set +e
out="$(REPO="" bash "$SCAN_SH" 2>&1 1>/dev/null)"
rc=$?
set -e
if [ "$rc" = "2" ] && echo "$out" | grep -Fq "ERROR: REPO"; then
  pass "missing REPO → exit 2 + 'ERROR: REPO' stderr"
else
  fail "missing REPO wrong exit/msg" "rc=$rc (want 2), stderr=$out"
fi

# ============================================================================
# T6: kill switch (D031_ENABLED=false) → exit 0 + kill_switch:true
# ============================================================================
section "T6: D031_ENABLED=false kill switch"
out="$(REPO=atilcan65/AtilCalculator D031_ENABLED=false ROLE=orchestrator bash "$SCAN_SH" 2>&1)"
rc=$?
if [ "$rc" = "0" ] && echo "$out" | jq -e '.kill_switch == true' >/dev/null 2>&1; then
  pass "kill switch → exit 0 + kill_switch:true"
else
  fail "kill switch not honored" "rc=$rc, out=$out"
fi

# ============================================================================
# T7: role gate (ROLE=tester) → exit 0 + role_gate:true
# ============================================================================
section "T7: ROLE=tester → role gate exit"
out="$(REPO=atilcan65/AtilCalculator ROLE=tester bash "$SCAN_SH" 2>&1)"
rc=$?
if [ "$rc" = "0" ] && echo "$out" | jq -e '.role_gate == true' >/dev/null 2>&1; then
  pass "ROLE=tester → exit 0 + role_gate:true"
else
  fail "role gate not honored" "rc=$rc, out=$out"
fi

# ============================================================================
# T8: happy path → exit 0 + JSON with scan_at + drift_findings:[] + todo:[]
# ============================================================================
section "T8: happy path returns scaffold-mode JSON"
out="$(REPO=atilcan65/AtilCalculator ROLE=orchestrator bash "$SCAN_SH" 2>&1)"
rc=$?
if [ "$rc" = "0" ] && \
   echo "$out" | jq -e '.scan_at' >/dev/null 2>&1 && \
   echo "$out" | jq -e '.drift_findings | type == "array"' >/dev/null 2>&1 && \
   echo "$out" | jq -e '.todo | type == "array"' >/dev/null 2>&1; then
  pass "happy path → exit 0, JSON with scan_at + drift_findings + todo"
else
  fail "happy path broken" "rc=$rc, out=$out"
fi

# ============================================================================
# T9: required schema fields present
# ============================================================================
section "T9: required JSON schema fields"
required_fields=("scan_at" "overrides_observed" "drift_findings" "summary")
missing=0
for f in "${required_fields[@]}"; do
  if ! echo "$out" | jq -e --arg f "$f" 'has($f)' >/dev/null 2>&1; then
    fail "missing field $f" "required by ADR-0031 §Recovery procedure"
    missing=$((missing+1))
  fi
done
if [ "$missing" = "0" ]; then
  pass "all required fields present: ${required_fields[*]}"
fi

# ============================================================================
# T10: REPORT_PATH appends a line to file (no stdout corruption)
# ============================================================================
section "T10: REPORT_PATH appends without corrupting stdout"
report_tmp="$(mktemp -t d031-report.XXXXXX.log)"
out="$(REPO=atilcan65/AtilCalculator ROLE=orchestrator REPORT_PATH="$report_tmp" bash "$SCAN_SH" 2>&1)"
if [ -s "$report_tmp" ] && grep -Fq "Scan at" "$report_tmp" && \
   echo "$out" | jq -e '.scan_at' >/dev/null 2>&1; then
  pass "REPORT_PATH appended a scan line + stdout JSON intact"
else
  fail "REPORT_PATH broken" "report=$(cat "$report_tmp"), out=$out"
fi
rm -f "$report_tmp"

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: ${G}%d${D}\n" "$PASS"
printf "  FAIL: ${R}%d${D}\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}Some checks failed${D}\n"
  exit 1
fi

printf "\n${G}All checks passed${D}\n"
exit 0
