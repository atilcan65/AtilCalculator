#!/usr/bin/env bash
# d016-rca-11-runtime-deps-explicit.sh — regression test for Issue #164
# (RCA-11 — second auto-deploy after PR #161 v5/v6 merge FAILED at
# run #27864083208 because the v6 preflight ran `uv pip install -e .` which
# only installs pyproject.toml `dependencies = [...]` (mpmath==1.3.0), NOT
# the `[dev]` extras. fastapi + uvicorn were declared as [dev] extras so
# they were never installed into `.venv/bin/uvicorn`. The script then
# correctly FAILED at the defense-in-depth restart_service()
# `.venv/bin/uvicorn not found` check (exit 4 — RCA-9 regression prevented),
# but the root cause is a pyproject.toml design gap.)
#
# Bug-class defended against (RCA-11 root cause):
#   pyproject.toml:
#     dependencies = ["mpmath==1.3.0"]                                  # runtime
#     [project.optional-dependencies]
#     dev = ["fastapi==0.115.6", "uvicorn[standard]==0.32.1", ...]     # dev extras
#
#   v6 deploy-runner.sh step 2 ran:
#     uv pip install -p .venv -e .                                     # installs runtime ONLY
#     → .venv/bin/uvicorn never created
#     → defense-in-depth check in restart_service() fired (exit 4)
#     → correct failure mode, but the deploy still failed
#
#   v7 replaces this with an explicit install line AFTER the editable install:
#     uv pip install -p "$REPO_DIR/.venv" fastapi==0.115.6 'uvicorn[standard]==0.32.1'
#
# Test cases (T1..T8):
#   T1:  explicit fastapi+uvicorn install line exists in deploy-runner.sh
#   T2:  explicit install uses FAIL-or-CREATE pattern (FAIL with exit 4 on non-zero)
#   T3:  fastapi pin matches pyproject.toml [dev] extra (drift detection)
#   T4:  uvicorn[standard] pin matches pyproject.toml [dev] extra (drift detection)
#   T5:  header comment documents RCA-11 fix + new explicit install rationale
#   T6:  --dry-run step 2 line mentions RCA-11
#   T7:  restart_service() defense-in-depth check still uses exit 4 (parity)
#   T8:  exit code 4 documentation in header includes RCA-11 mention
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d016-rca-11-runtime-deps-explicit.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_SH="$SCRIPT_DIR/../deploy-runner.sh"
PYPROJECT_TOML="$SCRIPT_DIR/../../pyproject.toml"

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
if [ ! -r "$PYPROJECT_TOML" ]; then
  echo "ERROR: pyproject.toml not found at $PYPROJECT_TOML" >&2; exit 127
fi

# Helper: extract N lines after the FIRST match of a pattern, and check that
# result matches a second pattern. Avoids awk's quoting hell with `2>&1`.
after_match() {
  local p1="$1"; local n="$2"; local p2="$3"
  grep -A "$n" -m 1 -E "$p1" "$RUNNER_SH" | grep -Eq "$p2"
}

# ============================================================================
# Test cases T1..T8
# ============================================================================

section "T1: explicit fastapi+uvicorn install line exists in deploy-runner.sh"
# Pattern: the explicit install line must exist (RCA-11 fix signature).
if grep -Eq 'uv pip install -p "\$REPO_DIR/\.venv".*fastapi.*uvicorn\[standard\]' "$RUNNER_SH"; then
  pass "explicit uvicorn+fastapi install line present (RCA-11 v7 pattern)"
else
  fail "explicit uvicorn+fastapi install line missing" "expected 'uv pip install -p \$REPO_DIR/.venv fastapi==... uvicorn[standard]==...' after the editable install"
fi

section "T2: explicit install uses FAIL-or-CREATE pattern (FAIL with exit 4 on non-zero)"
# Pattern: the explicit install must use the same FAIL-or-CREATE pattern as
# RCA-7-4 / RCA-9. If `uv pip install fastapi+uvicorn` exits non-zero, the
# script must fail with exit 4 (NOT log-only / NOT continue).
if after_match 'fastapi==0\.115\.6' 3 'fail .*4'; then
  pass "explicit install failure exits with code 4 (FAIL-or-CREATE parity)"
else
  fail "explicit install failure does not exit 4" "expected 'fastapi==0.115.6' install line followed by 'fail ... 4' (RCA-11 v7 parity with RCA-7-4 + RCA-9)"
fi

section "T3: fastapi pin matches pyproject.toml [dev] extra (drift detection)"
# Pattern: pin in deploy-runner.sh must match pin in pyproject.toml [dev].
# Drift = Sprint 4 Option B `web` extra amendment will catch this, but until
# then d015 defends against accidental divergence.
script_fastapi=$(grep -oE 'fastapi==[0-9]+\.[0-9]+\.[0-9]+' "$RUNNER_SH" | head -1 || true)
pyproject_fastapi=$(grep -oE 'fastapi==[0-9]+\.[0-9]+\.[0-9]+' "$PYPROJECT_TOML" | head -1 || true)
if [[ -n "$script_fastapi" && "$script_fastapi" == "$pyproject_fastapi" ]]; then
  pass "fastapi pin matches pyproject.toml ($script_fastapi == $pyproject_fastapi)"
else
  fail "fastapi pin drift detected" "script=$script_fastapi pyproject=$pyproject_fastapi — update one to match the other (Sprint 4 Option B: consolidate into [web] extra)"
fi

section "T4: uvicorn[standard] pin matches pyproject.toml [dev] extra (drift detection)"
script_uvicorn=$(grep -oE "uvicorn\[standard\]==[0-9]+\.[0-9]+\.[0-9]+" "$RUNNER_SH" | head -1 || true)
pyproject_uvicorn=$(grep -oE "uvicorn\[standard\]==[0-9]+\.[0-9]+\.[0-9]+" "$PYPROJECT_TOML" | head -1 || true)
if [[ -n "$script_uvicorn" && "$script_uvicorn" == "$pyproject_uvicorn" ]]; then
  pass "uvicorn[standard] pin matches pyproject.toml ($script_uvicorn == $pyproject_uvicorn)"
else
  fail "uvicorn[standard] pin drift detected" "script=$script_uvicorn pyproject=$pyproject_uvicorn — update one to match the other (Sprint 4 Option B: consolidate into [web] extra)"
fi

section "T5: header comment documents RCA-11 fix + new explicit install rationale"
if grep -Eq 'RCA-11' "$RUNNER_SH" \
   && grep -Eq 'explicit.*uv pip install.*fastapi.*uvicorn' "$RUNNER_SH" \
   && grep -Eq 'web.*extra.*ADR-0027' "$RUNNER_SH"; then
  pass "header documents RCA-11 + explicit install rationale + Sprint 4 follow-up"
else
  fail "header missing RCA-11 + explicit install rationale" "expected 'RCA-11', 'explicit uv pip install fastapi+uvicorn', and 'web extra' / ADR-0027 reference in header comment"
fi

section "T6: --dry-run step 2 line mentions RCA-11"
if grep -Eq 'step 2:.*RCA-11' "$RUNNER_SH"; then
  pass "dry-run step 2 line references RCA-11"
else
  fail "dry-run step 2 line does not reference RCA-11" "expected 'step 2: ... (RCA-11)' in --dry-run output"
fi

section "T7: restart_service() defense-in-depth check still uses exit 4 (parity)"
if after_match 'uvicorn.*not found or not executable' 3 'fail .*4'; then
  pass "restart_service() existence check fails with exit 4 (parity with preflight)"
else
  fail "restart_service() existence check does not use exit 4" "expected 'fail ... 4' (defense-in-depth parity); was exit 3 in v5"
fi

section "T8: exit code 4 documentation in header includes RCA-11 mention"
# Pattern: header exit code 4 documentation (spans 3 lines for both RCA-9 and
# RCA-11) must reference RCA-11 — otherwise future readers won't know RCA-11
# is in the preflight exit-code-4 category. The actual line layout is:
#   #   4  — preflight failure (RCA-9: uv missing, venv creation failed, or
#   #        `uv pip install` failed; RCA-11: explicit uvicorn+fastapi install
#   #        failed; owner must intervene manually)
# So we grep -A 3 lines after the "4 — preflight failure" anchor.
if after_match '^#   4  — preflight failure' 3 'RCA-11'; then
  pass "header exit code 4 documentation spans RCA-11"
else
  fail "header exit code 4 documentation missing RCA-11" "expected 'RCA-11' within 3 lines after '#   4  — preflight failure ...' anchor"
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
