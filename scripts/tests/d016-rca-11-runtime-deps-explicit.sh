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
# v7 replaces this with Option B per merged test contract PR #166 (AP-23c
# "exactly one place" probe — pins in EXACTLY ONE place in the repo):
#   pyproject.toml:
#     [project.optional-dependencies]
#     web = ["fastapi==0.115.6", "uvicorn[standard]==0.32.1"]   # SINGLE SOURCE OF TRUTH
#     dev = ["fastapi", "uvicorn[standard]", ...]               # UN-pinned (dev tooling)
#   deploy-runner.sh step 2:
#     uv pip install -p .venv -e ".[web]"                        # pulls from [web]
#
# Test cases (T1..T8) — updated for Option B / merged AP-23c:
#   T1:  deploy-runner.sh uses `uv pip install -p "$REPO_DIR/.venv" -e ".[web]"` (Option B)
#   T2:  install uses FAIL-or-CREATE pattern (FAIL with exit 4 on non-zero)
#   T3:  pyproject.toml declares [web] extra with fastapi+uvicorn[standard] pins
#   T4:  pyproject.toml [dev] has fastapi/uvicorn UN-pinned (drift-detection per AP-23c)
#   T5:  header comment documents RCA-11 fix + Option B [web] extra rationale
#   T6:  --dry-run step 2 line mentions RCA-11 + [web] extra
#   T7:  restart_service() defense-in-depth check still uses exit 4 (parity)
#   T8:  AP-23c: pins in EXACTLY ONE place (pyproject [web] only, NOT in script)
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

section "T1: deploy-runner.sh uses 'uv pip install -p \$REPO_DIR/.venv -e \".[web]\"' (Option B)"
# Pattern: the v7 preflight must use Option B (-e ".[web]") — pins live in
# pyproject.toml [web] extra, script just references the extra name. This
# satisfies AP-23c "exactly one place" probe.
if grep -Eq 'uv pip install -p "\$REPO_DIR/\.venv" -e "\.\[web\]"' "$RUNNER_SH"; then
  pass "Option B pattern present (-e '.[web]' — single source of truth in pyproject [web])"
else
  fail "Option B pattern missing" "expected 'uv pip install -p \$REPO_DIR/.venv -e \".[web]\"' in step 2 preflight (Option B per merged test contract AP-23c)"
fi

section "T2: install uses FAIL-or-CREATE pattern (FAIL with exit 4 on non-zero)"
# Pattern: the install must use the same FAIL-or-CREATE pattern as RCA-7-4
# + RCA-9. If `uv pip install -e ".[web]"` exits non-zero, the script must
# fail with exit 4 (NOT log-only / NOT continue).
if after_match 'uv pip install -p "\$REPO_DIR/\.venv" -e "\.\[web\]"' 3 'fail .*4'; then
  pass "install failure exits with code 4 (FAIL-or-CREATE parity)"
else
  fail "install failure does not exit 4" "expected 'uv pip install -e \".[web]\"' followed by 'fail ... 4' (RCA-7-4 + RCA-9 + RCA-11 FAIL-or-CREATE pattern)"
fi

section "T3: pyproject.toml declares [web] extra with fastapi+uvicorn[standard] pins"
# Pattern: [project.optional-dependencies] must have a `web` key with both
# fastapi and uvicorn[standard] pins (single source of truth per AP-23c).
if grep -Eq '^\[project\.optional-dependencies\]' "$PYPROJECT_TOML" \
   && grep -Eq '^web = \[' "$PYPROJECT_TOML" \
   && grep -qE '"fastapi==0\.115\.6"' "$PYPROJECT_TOML" \
   && grep -qE '"uvicorn\[standard\]==0\.32\.1"' "$PYPROJECT_TOML"; then
  pass "[web] extra declared with fastapi+uvicorn[standard] pins (single source of truth)"
else
  fail "[web] extra missing or unpinned" "expected pyproject.toml [project.optional-dependencies] web = [..., 'fastapi==0.115.6', ..., 'uvicorn[standard]==0.32.1', ...]"
fi

section "T4: pyproject.toml [dev] has fastapi/uvicorn UN-pinned (AP-23c drift-detection)"
# AP-23c requires pins in EXACTLY ONE place. The [web] extra has them.
# The [dev] extra must have un-pinned 'fastapi' and 'uvicorn[standard]'
# (NOT 'fastapi==0.115.6' or 'uvicorn[standard]==0.32.1') so that AP-23c
# probe (which checks for the exact pin string) passes.
if ! grep -Eq '"fastapi==0\.115\.6"' "$PYPROJECT_TOML" \
   || ! grep -Eq '"uvicorn\[standard\]==0\.32\.1"' "$PYPROJECT_TOML"; then
  fail "pyproject.toml missing pin strings" "expected both 'fastapi==0.115.6' and 'uvicorn[standard]==0.32.1' to be present (T3 covers where)"
fi
# Count occurrences of the exact pin strings in the [dev] section. Extract
# the [dev] section: from 'dev = [' to the next ']' line.
dev_section=$(awk '/^dev = \[/,/^\]/' "$PYPROJECT_TOML")
if echo "$dev_section" | grep -qE '"fastapi==0\.115\.6"' \
   || echo "$dev_section" | grep -qE '"uvicorn\[standard\]==0\.32\.1"'; then
  fail "[dev] extra has pinned fastapi/uvicorn — AP-23c violation" "expected [dev] to have un-pinned 'fastapi' and 'uvicorn[standard]' (drift-detection per AP-23c); pins live in [web] only"
else
  pass "[dev] has fastapi/uvicorn UN-pinned (AP-23c satisfied)"
fi

section "T5: header comment documents RCA-11 fix + Option B [web] extra rationale"
if grep -Eq 'RCA-11' "$RUNNER_SH" \
   && grep -Eq 'web.*extra' "$RUNNER_SH" \
   && grep -Eq 'Option B' "$RUNNER_SH" \
   && grep -Eq 'single source of truth' "$RUNNER_SH"; then
  pass "header documents RCA-11 + Option B + [web] extra + single source of truth"
else
  fail "header missing RCA-11 + Option B documentation" "expected 'RCA-11', 'Option B', '[web] extra', and 'single source of truth' in header comment"
fi

section "T6: --dry-run step 2 line mentions RCA-11 + [web] extra"
if grep -Eq 'step 2:.*RCA-11' "$RUNNER_SH" \
   && grep -Eq 'step 2:.*\[web\]' "$RUNNER_SH"; then
  pass "dry-run step 2 line references RCA-11 + [web] extra"
else
  fail "dry-run step 2 line does not reference [web] extra" "expected 'step 2: ... -e .[web] ... (RCA-11 [web] extra ...)' in --dry-run output"
fi

section "T7: restart_service() defense-in-depth check still uses exit 4 (parity)"
if after_match 'uvicorn.*not found or not executable' 3 'fail .*4'; then
  pass "restart_service() existence check fails with exit 4 (parity with preflight)"
else
  fail "restart_service() existence check does not use exit 4" "expected 'fail ... 4' (defense-in-depth parity); was exit 3 in v5"
fi

section "T8: AP-23c compliance — pins in EXACTLY ONE place (pyproject [web] only, NOT in script)"
# AP-23c probe (merged test contract, Issue #164 RCA-11): "The exact string
# `fastapi==0.115.6` OR `uvicorn[standard]==0.32.1` appears in EXACTLY ONE
# place in the repo — either in `pyproject.toml` (Option B) OR in
# `scripts/deploy-runner.sh` (Option A), but NOT both."
#
# Option B implementation: pins in pyproject [web] ONLY. deploy-runner.sh
# uses `-e ".[web]"` (no pin string in script).
script_pin_count=$(grep -cE 'fastapi==0\.115\.6|uvicorn\[standard\]==0\.32\.1' "$RUNNER_SH" || true)
if [[ "$script_pin_count" -eq 0 ]]; then
  pass "deploy-runner.sh has ZERO pin strings (AP-23c satisfied — pins in pyproject [web] only)"
else
  fail "deploy-runner.sh has $script_pin_count pin string(s) — AP-23c violation" "expected 0 pin strings in script (pins live in pyproject [web] only per Option B / AP-23c)"
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
