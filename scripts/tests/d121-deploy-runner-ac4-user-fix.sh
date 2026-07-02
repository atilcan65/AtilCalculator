#!/usr/bin/env bash
# d121-deploy-runner-ac4-user-fix.sh — Issue #763 RCA-17 deploy-runner.sh AC4 user fix
#   (sister-pattern to d108 + d120 context-watchdog family; d-test framework per ADR-0049).
#
# Why this test exists
# --------------------
# Issue #763 (RCA-17, dispatched by orchestrator cycle ~#3328): deploy CI gate (DEPLOY-001
# workflow) failing 4 consecutive runs (exit 7) because scripts/deploy-runner.sh:497 hardcodes
# `sudo -u atilcan`. On the runner VM (192.168.1.197, self-hosted runner per ADR-0030), the only
# user is `gh-actions-runner` (uid 1000) — `atilcan` does not exist. `sudo -u atilcan` fails
# immediately with "unknown user" + audit plugin error, leaving `service_state` non-equal to
# `active`, triggering AC4 fail at exit 7.
#
# Fix: replace hardcoded `sudo -u atilcan` with `sudo -u "${ATC_SERVICE_USER:-$USER}"`. Env var
# with $USER fallback — defaults to current user (same-user scenario, e.g. runner VM where
# deploy-runner.sh and the service run as the same user), overridable for cross-user scenarios
# (e.g. prod atiltestweb where runner user `gh-actions-runner` runs the script but `atilcan`
# owns the service per RCA-16 lineage, PR #358-era).
#
# AC mapping (Issue #763):
#   AC1 — `sudo -u atilcan` no longer hardcoded at line 497
#   AC2 — env var fallback to $USER (default behavior)
#   AC3 — env var override works (ATC_SERVICE_USER=atilcan → sudo -u atilcan)
#   AC4 — bash syntax valid (bash -n)
#   AC5 — header comment block cites Issue #763 + RCA-17 lineage
#   AC6 — AC4 dry-run: preflight — file exists + readable + non-empty
#
# 6 TCs (per ADR-0049 d-test framework sister-pattern ≥3 minimum, d108/d120 used 5-9):
#   TC1: `sudo -u atilcan` not hardcoded (replaced with env var pattern) (AC1)
#   TC2: env var fallback to $USER — `ATC_SERVICE_USER:-$USER` pattern present (AC2)
#   TC3: env var override pattern matches `${ATC_SERVICE_USER:-$USER}` shape (AC3)
#   TC4: bash syntax valid — `bash -n scripts/deploy-runner.sh` exits 0 (AC4)
#   TC5: header comment block (lines 492-505 area) cites Issue #763 + RCA-17 (AC5)
#   TC6: preflight — file exists + readable + line 497 area has the fix applied (AC6)
#
# Pre-impl RED state (main HEAD 8d9540b, 2026-07-02T18:51Z):
#   - line 497: `sudo -u atilcan systemctl --user is-active` → TC1 FAIL (hardcoded)
#   - no env var pattern → TC2 FAIL
#   - no env var pattern → TC3 FAIL
#   - bash syntax OK (no change) → TC4 PASS
#   - comment block cites RCA-16 only (not RCA-17 / Issue #763) → TC5 FAIL
#   - file exists + line 497 has hardcoded user → TC6 PASS (preflight only)
#   → 2/6 TCs PASS = proper RED-first per ADR-0044 (≥1 FAIL required for RED state).
#
# Post-impl GREEN state (target):
#   - line 497: `sudo -u "${ATC_SERVICE_USER:-$USER}"` (env var with $USER fallback)
#   - bash syntax preserved
#   - comment block updated with RCA-17 lineage + Issue #763 cite
#   → 6/6 TCs PASS.
#
# Sister-pattern family (ADR-0049 d-test framework):
#   - d108 (Issue #722 era, context-watchdog instant-fire, 6 TCs) — script-defaults shape
#   - d120 (Issue #759 era, context-watchdog pct-change override, 9 TCs) — DIRECT sister (RCA-N cycle, agent_likely_stuck fix)
#   - d121 (this — RCA-17 deploy-runner AC4 user fix, 6 TCs)
#
# Refs:
#   - Issue #763 (RCA-17 dispatch from orchestrator cycle ~#3328, 2026-07-02T22:33Z)
#   - RCA-16 (PR #358-era, sudo -u atilcan wrapper introduced for cross-user prod scenario)
#   - ADR-0010 (uvicorn lifecycle owned by systemd user-service)
#   - ADR-0030 (self-hosted runner for LAN deploy — runner user is `gh-actions-runner`)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0049 (d-test framework sister-pattern, ≥3 TCs minimum)
#   - ADR-0055 §1 (Cadence Rule 1 atomic — d-test file + INDEX.md same commit)
#   - ADR-0057 (Closes anchor strict format)
#
# Usage:
#   bash d121-deploy-runner-ac4-user-fix.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — fix applied + ACs satisfied)
#   1 — at least one FAIL (RED state — impl missing or ACs unsatisfied)

set -uo pipefail

# ============================================================================
# Self-test guard
# ============================================================================
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test"
  exit 2
fi

# ============================================================================
# Paths
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOY_SH="$PROJECT_ROOT/scripts/deploy-runner.sh"

# ============================================================================
# Helpers
# ============================================================================
EXIT_CODE=0
PASS_COUNT=0
FAIL_COUNT=0

section() { printf '\n=== %s ===\n' "$1"; }
pass() {
  printf '  ✅ PASS: %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}
fail() {
  printf '  ❌ FAIL: %s\n' "$1"
  if [ -n "${2:-}" ]; then
    printf '         %s\n' "$2"
  fi
  FAIL_COUNT=$((FAIL_COUNT + 1))
  EXIT_CODE=1
}

# ============================================================================
# TC6 (preflight first — file must exist + readable)
# ============================================================================
section "TC6: preflight — file exists + readable (AC6)"
if [ ! -f "$DEPLOY_SH" ]; then
  fail "TC6 — scripts/deploy-runner.sh not found at $DEPLOY_SH" \
    "expected scripts/deploy-runner.sh in repo root. Repo layout may have changed."
elif [ ! -r "$DEPLOY_SH" ]; then
  fail "TC6 — scripts/deploy-runner.sh not readable" \
    "check file permissions (should be 644 or similar)."
elif [ ! -s "$DEPLOY_SH" ]; then
  fail "TC6 — scripts/deploy-runner.sh is empty" \
    "expected non-empty script. Deploy script may have been corrupted."
else
  pass "TC6 — scripts/deploy-runner.sh exists + readable + non-empty ($(wc -l <"$DEPLOY_SH") lines)"
fi

# Skip remaining TCs if preflight fails
if [ "$EXIT_CODE" -ne 0 ] && [ "$FAIL_COUNT" -gt 0 ] && [ "$PASS_COUNT" -eq 0 ]; then
  section "=== Pre-flight failed; skipping remaining TCs ==="
  printf '\n[FAIL] d121 preflight RED state — %d PASS / %d FAIL\n' "$PASS_COUNT" "$FAIL_COUNT"
  exit "$EXIT_CODE"
fi

# ============================================================================
# TC1: `sudo -u atilcan` not hardcoded (replaced with env var pattern) (AC1)
# ============================================================================
section "TC1: AC1 — `sudo -u atilcan` not hardcoded in EXECUTABLE line (Issue #763 root cause)"
# Match the literal pattern `sudo -u atilcan` in the EXECUTABLE line only (line containing
# service_state=$(sudo -u ...). The comment block legitimately cites `sudo -u atilcan` in
# the RCA-16 historical reference — that reference is intentional traceability, not a bug.
TC1_EXEC_LINE=$(grep -nE '^\s*service_state=\$\(sudo -u ' "$DEPLOY_SH" | head -1)
if [ -z "$TC1_EXEC_LINE" ]; then
  fail "TC1 — could not find executable line matching \`service_state=\$(sudo -u ...)\`" \
    "line 497 area was restructured beyond recognition. Check scripts/deploy-runner.sh manually."
elif echo "$TC1_EXEC_LINE" | grep -qF 'sudo -u atilcan'; then
  TC1_LINE_NUM="${TC1_EXEC_LINE%%:*}"
  fail "TC1 — executable line still hardcodes \`sudo -u atilcan\`" \
    "Issue #763 root cause. Replace with env var pattern per fix spec. Pre-impl RED: hardcoded → FAIL by design per ADR-0044. See line ${TC1_LINE_NUM}."
else
  pass "TC1 — executable line uses env var pattern, not hardcoded \`sudo -u atilcan\`"
fi

# ============================================================================
# TC2: env var fallback to $USER (AC2)
# ============================================================================
section "TC2: AC2 — env var fallback to \$USER (ATC_SERVICE_USER:-USER pattern present)"
# Match the env var fallback pattern in the AC4 block. Pattern: ${ATC_SERVICE_USER:-$USER}
TC2_PATTERN='ATC_SERVICE_USER:-${USER}'  # shell-quoted: pattern uses literal $USER
TC2_PATTERN_COUNT=$(sed -n '490,510p' "$DEPLOY_SH" | grep -cF "ATC_SERVICE_USER:-\$USER" || true)
if [ "$TC2_PATTERN_COUNT" -ge 1 ]; then
  pass "TC2 — env var fallback pattern \`\${ATC_SERVICE_USER:-\$USER}\` present in AC4 block ($TC2_PATTERN_COUNT occurrence(s))"
else
  fail "TC2 — env var fallback pattern \`\${ATC_SERVICE_USER:-\$USER}\` NOT present in AC4 block" \
    "Fix spec requires env var with \$USER fallback. Pre-impl RED: 0 → FAIL by design per ADR-0044."
fi

# ============================================================================
# TC3: env var override pattern matches `${ATC_SERVICE_USER:-$USER}` shape (AC3)
# ============================================================================
section "TC3: AC3 — env var override shape matches fix spec (line 497 area)"
# Extract the executable service_state line and verify shape.
# Note: shell parameter expansion allows `:-${VAR}` or `:-$VAR` — both valid at end of pattern.
# We accept either form via flexible pattern match.
TC3_LINE=$(grep -nE '^\s*service_state=\$\(sudo -u ' "$DEPLOY_SH" | head -1)
if [ -z "$TC3_LINE" ]; then
  fail "TC3 — could not find executable line matching \`service_state=\$(sudo -u ...)\`" \
    "line 497 area was restructured beyond recognition. Check scripts/deploy-runner.sh manually."
elif echo "$TC3_LINE" | grep -qE 'ATC_SERVICE_USER:-\$\{?USER\}?'; then
  pass "TC3 — line matches fix spec: \`${TC3_LINE##*:}\`"
else
  fail "TC3 — line shape mismatch: \`${TC3_LINE##*:}\`" \
    "expected pattern \`service_state=\$(sudo -u \"\\\${ATC_SERVICE_USER:-\$USER}\" systemctl --user is-active ...)\` or equivalent (e.g. \`\\\${USER}\` braces optional at end). Pre-impl RED: hardcoded `sudo -u atilcan` → FAIL by design."
fi

# ============================================================================
# TC4: bash syntax valid (AC4)
# ============================================================================
section "TC4: AC4 — bash syntax valid (\`bash -n\` exits 0)"
if bash -n "$DEPLOY_SH" 2>/dev/null; then
  pass "TC4 — bash -n scripts/deploy-runner.sh exits 0 (syntax valid)"
else
  fail "TC4 — bash syntax error in scripts/deploy-runner.sh" \
    "fix introduced syntax error. Run \`bash -n scripts/deploy-runner.sh\` for details."
fi

# ============================================================================
# TC5: header comment block cites Issue #763 + RCA-17 (AC5)
# ============================================================================
section "TC5: AC5 — header comment block (lines 492-505 area) cites Issue #763 + RCA-17"
TC5_COMMENT_BLOCK=$(sed -n '492,505p' "$DEPLOY_SH")
if echo "$TC5_COMMENT_BLOCK" | grep -qF 'Issue #763' && echo "$TC5_COMMENT_BLOCK" | grep -qF 'RCA-17'; then
  pass "TC5 — comment block cites Issue #763 + RCA-17 (lineage traceable)"
else
  fail "TC5 — comment block missing Issue #763 or RCA-17 cite" \
    "Fix must update comment block (lines 495-496 area) to cite Issue #763 + RCA-17 lineage per ADR-0044 traceability discipline. Pre-impl RED: comment cites only RCA-16 → FAIL by design."
fi

# ============================================================================
# Summary
# ============================================================================
section "=== Summary ==="
printf '%d PASS / %d FAIL\n' "$PASS_COUNT" "$FAIL_COUNT"
if [ "$EXIT_CODE" -eq 0 ]; then
  printf '\n[GREEN] d121 RCA-17 deploy-runner AC4 user fix — all TCs pass\n'
else
  printf '\n[RED] d121 RCA-17 deploy-runner AC4 user fix — %d TC(s) failing\n' "$FAIL_COUNT"
fi

exit "$EXIT_CODE"