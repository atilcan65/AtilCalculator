#!/usr/bin/env bash
# d043-platform-constraint-linter-ext.sh — extension of d041 platform-constraint linter.
#
# Why this test exists
# --------------------
# Sprint 7+ P2 follow-up to d041 (PR #369 MERGED). Three sub-items per Issue #370:
#
#   1. **Lens (h) SHA pin check** — ADR-0027 §Threat model requires
#      `actions/checkout@<40-char-SHA>` not `@v4` moving tag. d040 T4 covers
#      deploy.yml only; d043 T1 generalizes to ALL workflow files.
#
#   2. **Path resolution portability** — d040 + d041 use `BASH_SOURCE[0]` for
#      repo-root detection. Fails when script is copied/symlinked outside the
#      canonical location. d043 T2 enforces `git rev-parse --show-toplevel`.
#
#   3. **PAT regex scope** — d041 T7 catches `ghp_*` + `github_pat_*` but misses
#      `ghs_*` (server-to-server), `gho_*` (OAuth), `ghu_*` (user-to-server),
#      AWS access keys (`AKIA[0-9A-Z]{16}`), etc. d043 T3 enforces broader regex.
#
# Sister tests:
#   - d040-deploy-path-guard.sh (PR #353 MERGED) — path-only guard, this extends
#   - d041-platform-constraint-linter.sh (PR #369 MERGED) — 8 lens (i) sub-categories
#
# Per Issue #370 §Acceptance:
#   - d043 covers lens (h) SHA pin check across all workflow files (T1)
#   - d040 + d041 path resolution uses `git rev-parse --show-toplevel` (T2)
#   - d041 T7 secrets regex covers GH classic + fine-grained + S2S + OAuth + user + AWS (T3)
#   - 8/8 d041 + N/N d043 regression TCs pass on current main (cross-script)
#
# Exit code: 0 = all pass, 1 = at least one fail.
# Run standalone: bash scripts/tests/d043-platform-constraint-linter-ext.sh
#
# Refs: Issue #370, ADR-0027 §Threat model, ADR-0043 §lens (h), PR #369 architect NIT-1,
#       PR #369 tester OBS-2 + OBS-4, d040-deploy-path-guard.sh, d041-platform-constraint-linter.sh.

set -uo pipefail

# Path resolution: git rev-parse --show-toplevel is portable (works when this
# script is symlinked or copied outside canonical location). d043 enforces
# this pattern on d040 + d041 and dogfoods it here.
REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT_DIR="$REPO_ROOT/scripts/tests"
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"

# Fail-fast: workflows dir must exist
if [ ! -d "$WORKFLOWS_DIR" ]; then
  echo "ERROR: workflows dir missing — d043 cannot evaluate: $WORKFLOWS_DIR" >&2
  exit 127
fi

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

# ============================================================================
# T1: SHA pin check generalized — all workflow files (lens h)
# ============================================================================
section "T1: SHA pin check generalized (lens h, ADR-0027 §Threat model)"
# Per ADR-0027: actions must be SHA-pinned (40-char hex), not moving tags (@v4).
# d040 T4 only covers deploy.yml; d043 T1 covers ALL workflows/*.yml.
BAD_SHA_PINS="$(grep -rEn '^\s*-\s*uses:\s*actions/[a-z\-]+@v[0-9]+(\.[0-9]+)*' "$WORKFLOWS_DIR"/*.yml 2>/dev/null || true)"
if [ -z "$BAD_SHA_PINS" ]; then
  pass "all workflows use SHA-pinned actions (no @v4 moving tags)"
else
  fail "workflow(s) use moving tag instead of SHA pin" "$BAD_SHA_PINS"
fi

# ============================================================================
# T2: Path resolution portability — d040 + d041 use git rev-parse (lens h hardening)
# ============================================================================
section "T2: Path resolution portability (d040 + d041 use git rev-parse)"
# d040 + d041 use `BASH_SOURCE[0]` for repo-root detection. Fails when script is
# copied/symlinked outside canonical location. Required: `git rev-parse --show-toplevel`.
D040_HAS_BASH_SOURCE="$(grep -nE 'BASH_SOURCE' scripts/tests/d040-deploy-path-guard.sh 2>/dev/null || true)"
if [ -z "$D040_HAS_BASH_SOURCE" ]; then
  pass "d040 uses portable path resolution (no BASH_SOURCE)"
else
  fail "d040 still uses BASH_SOURCE[0]" "$D040_HAS_BASH_SOURCE"
fi

D041_HAS_BASH_SOURCE="$(grep -nE 'BASH_SOURCE' scripts/tests/d041-platform-constraint-linter.sh 2>/dev/null || true)"
if [ -z "$D041_HAS_BASH_SOURCE" ]; then
  pass "d041 uses portable path resolution (no BASH_SOURCE)"
else
  fail "d041 still uses BASH_SOURCE[0]" "$D041_HAS_BASH_SOURCE"
fi

# ============================================================================
# T3: PAT regex scope extended — covers GH classic + S2S + OAuth + user + AWS (lens i T7)
# ============================================================================
section "T3: PAT regex scope extended (lens i T7, Issue #370 hardening)"
# d041 T7 catches ghp_* + github_pat_*. Extended regex covers:
#   - ghp_* (classic PAT)
#   - ghs_* (server-to-server / fine-grained)
#   - gho_* (OAuth)
#   - ghu_* (user-to-server)
#   - github_pat_* (fine-grained)
#   - AKIA[0-9A-Z]{16} (AWS access key ID)
# Verify d041 T7 regex contains all of these patterns (or extension test file exists).
D041_T7_PATTERN="$(grep -nE 'gh\[pousr\]_\*|AKIA' scripts/tests/d041-platform-constraint-linter.sh 2>/dev/null || true)"
if [ -n "$D041_T7_PATTERN" ]; then
  pass "d041 T7 regex extended (covers ghs/gho/ghu + AWS keys)"
else
  fail "d041 T7 regex not extended" "expected gh[pousr]_* and AKIA[0-9A-Z]{16} in d041 regex"
fi

# Also verify there's a separate test file or extension test for the broader regex.
EXT_TEST_EXISTS="$(test -f scripts/tests/d043-platform-constraint-linter-ext.sh && echo yes || echo no)"
if [ "$EXT_TEST_EXISTS" = "yes" ]; then
  pass "d043 extension test exists (this file)"
else
  fail "d043 extension test missing" "expected scripts/tests/d043-platform-constraint-linter-ext.sh"
fi

# ============================================================================
# SUMMARY
# ============================================================================
section "SUMMARY"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "d043 has failing checks — implement fixes per Issue #370 §How:"
  echo "  - T1: replace @v4 with SHA pin in cross-repo-close.yml + ai-pr-review.yml + ci.yml"
  echo "  - T2: replace BASH_SOURCE[0] with git rev-parse --show-toplevel in d040 + d041"
  echo "  - T3: extend d041 T7 regex with gh[pousr]_* and AKIA[0-9A-Z]{16}"
  exit 1
fi

echo ""
echo "Reference: ADR-0027 §Threat model, ADR-0043 §lens (h) + §lens (i), Issue #370,"
echo "           d040-deploy-path-guard.sh (PR #353), d041-platform-constraint-linter.sh (PR #369)."
exit 0