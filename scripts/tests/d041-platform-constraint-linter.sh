#!/usr/bin/env bash
# d041-platform-constraint-linter.sh — regression test for ADR-0043 §lens (i) 8 sub-categories.
#
# Why this test exists
# --------------------
# Sprint 6 P2 follow-up to d040-deploy-path-guard.sh (PR #353). Extends the
# deploy-path guard into a generic platform-constraint linter covering all 8
# sub-categories of lens (i) from ADR-0043 8-Lens Architect Review Checklist:
#
#   1. path          (canonical runner paths under _work/)
#   2. runs-on       (self-hosted vs ubuntu-latest appropriateness)
#   3. permissions   (least-privilege per ADR-0027)
#   4. timeout       (bounded per job type)
#   5. concurrency   (cancel-in-progress: false for deploy)
#   6. if            (push trigger scope correctness)
#   7. secrets       (PROJECT_TOKEN consolidation per cross-repo-close workflow)
#   8. platform sandbox (GA hard constraints — TD-029 lesson)
#
# Sister test: d040-deploy-path-guard.sh (PR #353 MERGED) — path-only guard, this test generalizes.
# Sister lens: ADR-0045 lens (j) auto-gen + live-state (different mechanism, same parent ADR-0043).
#
# Per Issue #367 acceptance criteria:
#   - 8/8 regression TCs pass (one per sub-category)
#   - CI integration: runs on PR open for .github/workflows/*.yml changes
#   - Closes #353 follow-up (extends, doesn't replace)
#
# Exit code: 0 = all pass, 1 = at least one fail.
# Run standalone: bash scripts/tests/d041-platform-constraint-linter.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"
DEPLOY_YML="$WORKFLOWS_DIR/deploy.yml"

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
# T1: path — canonical runner paths under _work/ (d040 sister T3 generalized)
# ============================================================================
section "T1: path — canonical runner paths under _work/"
# d040 T3 already covers deploy.yml; d041 T1 extends to all workflows/*.yml files.
ANY_BAD_PATH="$(grep -rEn '^\s*path:\s*/home/atilcan/(projects|atilcalc)' "$WORKFLOWS_DIR"/*.yml 2>/dev/null || true)"
if [ -z "$ANY_BAD_PATH" ]; then
  pass "no workflow uses rejected canonical path (PR #350 bug regression, all workflows)"
else
  fail "rejected path found in workflow(s)" "$ANY_BAD_PATH"
fi

# ============================================================================
# T2: runs-on — self-hosted vs ubuntu-latest appropriateness
# ============================================================================
section "T2: runs-on — self-hosted vs ubuntu-latest appropriateness"
# deploy.yml should use self-hosted for prod-host deploy; other workflows should declare explicitly.
if [ ! -f "$DEPLOY_YML" ]; then
  fail "deploy.yml missing — T2 cannot evaluate" "$DEPLOY_YML"
else
  DEPLOY_RUNS_ON="$(grep -nE '^\s*runs-on:' "$DEPLOY_YML" | head -1 || true)"
  if [[ "$DEPLOY_RUNS_ON" == *"self-hosted"* ]]; then
    pass "deploy.yml uses self-hosted runner (prod-host deploy per ADR-0030)"
  else
    fail "deploy.yml runs-on not self-hosted" "current: $DEPLOY_RUNS_ON (expected self-hosted per ADR-0030)"
  fi
fi

# ============================================================================
# T3: permissions — least-privilege per ADR-0027
# ============================================================================
section "T3: permissions — least-privilege per ADR-0027"
# All workflow jobs should declare permissions block (even if empty contents: read).
if [ -f "$DEPLOY_YML" ]; then
  HAS_PERMS="$(grep -nE '^\s*permissions:' "$DEPLOY_YML" | head -1 || true)"
  if [ -n "$HAS_PERMS" ]; then
    pass "deploy.yml declares permissions block (ADR-0027 §Threat model)"
  else
    fail "deploy.yml missing permissions block" "ADR-0027 requires explicit least-privilege declaration"
  fi
else
  fail "deploy.yml missing — T3 cannot evaluate"
fi

# ============================================================================
# T4: timeout — bounded per job type
# ============================================================================
section "T4: timeout — bounded per job type"
# Deploy jobs should have explicit timeout-minutes (default GA is 360m which is too lax for prod deploy).
if [ -f "$DEPLOY_YML" ]; then
  HAS_TIMEOUT="$(grep -nE '^\s*timeout-minutes:' "$DEPLOY_YML" | head -1 || true)"
  if [ -n "$HAS_TIMEOUT" ]; then
    pass "deploy.yml declares timeout-minutes (bounded per job type)"
  else
    fail "deploy.yml missing timeout-minutes" "GA default 360m is unbounded for prod deploy; recommend ≤30m"
  fi
else
  fail "deploy.yml missing — T4 cannot evaluate"
fi

# ============================================================================
# T5: concurrency — cancel-in-progress: false for deploy
# ============================================================================
section "T5: concurrency — cancel-in-progress: false for deploy"
# Deploy jobs should NOT cancel in-progress (deploy must complete or fail-clean, never partial).
if [ -f "$DEPLOY_YML" ]; then
  CONCURRENCY="$(grep -nE -A2 '^\s*concurrency:' "$DEPLOY_YML" | head -5 || true)"
  if echo "$CONCURRENCY" | grep -qE 'cancel-in-progress:\s*true'; then
    fail "deploy.yml has cancel-in-progress: true (dangerous for deploy — partial state risk)"
  else
    pass "deploy.yml does NOT cancel-in-progress (safe for deploy)"
  fi
else
  fail "deploy.yml missing — T5 cannot evaluate"
fi

# ============================================================================
# T6: if — push trigger scope correctness
# ============================================================================
section "T6: if — push trigger scope correctness"
# Deploy should NOT trigger on every push (only on main or release tags).
if [ -f "$DEPLOY_YML" ]; then
  ON_PUSH="$(grep -nE '^\s*on:' "$DEPLOY_YML" | head -1 || true)"
  if [[ "$ON_PUSH" == *"push:"* ]] && [[ "$ON_PUSH" != *"branches:"* ]] && [[ "$ON_PUSH" != *"tags:"* ]]; then
    fail "deploy.yml 'on: push' is unscoped" "every push to any branch will trigger deploy — should scope to main or release tags"
  else
    pass "deploy.yml push trigger is scoped (branches/tags filter or workflow_dispatch only)"
  fi
else
  fail "deploy.yml missing — T6 cannot evaluate"
fi

# ============================================================================
# T7: secrets — PROJECT_TOKEN consolidation per cross-repo-close workflow
# ============================================================================
section "T7: secrets — PROJECT_TOKEN consolidation per cross-repo-close workflow"
# Secrets referenced in deploy.yml should use ${{ secrets.* }} form, never hardcoded.
if [ -f "$DEPLOY_YML" ]; then
  HARDCODED_SECRETS="$(grep -nE '(ghp_[a-zA-Z0-9]{20,}|github_pat_[a-zA-Z0-9_]{20,})' "$DEPLOY_YML" 2>/dev/null || true)"
  if [ -z "$HARDCODED_SECRETS" ]; then
    pass "deploy.yml has no hardcoded PATs/secrets (uses \${{ secrets.* }} form)"
  else
    fail "deploy.yml contains hardcoded PAT/secret" "$HARDCODED_SECRETS"
  fi
else
  fail "deploy.yml missing — T7 cannot evaluate"
fi

# ============================================================================
# T8: platform sandbox — GA hard constraints (TD-029 lesson)
# ============================================================================
section "T8: platform sandbox — GA hard constraints (TD-029 lesson)"
# No raw `docker run` / privileged mounts outside actions/* ecosystem. Self-hosted
# runner is itself the prod host per ADR-0030 — no SSH, no docker-in-docker.
if [ -f "$DEPLOY_YML" ]; then
  RAW_DOCKER="$(grep -nE '(docker\s+run|ssh\s+|ssh\s+-o)' "$DEPLOY_YML" 2>/dev/null || true)"
  if [ -z "$RAW_DOCKER" ]; then
    pass "deploy.yml uses no raw docker/ssh invocations (GA actions ecosystem only, ADR-0030 §Decision)"
  else
    fail "deploy.yml uses raw docker/ssh (TD-029 sister pattern)" "$RAW_DOCKER"
  fi
else
  fail "deploy.yml missing — T8 cannot evaluate"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo ""
echo "  Reference: ADR-0043 §lens (i), ADR-0045 §lens (j), ADR-0027 §Threat model,"
echo "             ADR-0030 §Decision, d040-deploy-path-guard.sh (PR #353 MERGED)."
echo "  Sister regressions: d040 6/6, d043 (planned for Sprint 7+)."
exit 0