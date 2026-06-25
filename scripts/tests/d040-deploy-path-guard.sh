#!/usr/bin/env bash
# d040-deploy-path-guard.sh — regression test for P0 incident #351.
#
# Why this test exists
# --------------------
# PR #350 added `path: /home/atilcan/projects/AtilCalculator` to
# `.github/workflows/deploy.yml` (Option C, RCA-17 follow-up). GitHub
# Actions has a hard safety check: `path:` must be a subdirectory of the
# runner's `_work/` root. Our canonical path was OUTSIDE that root, so
# checkout failed with:
#
#   ##[error]Repository path '/home/atilcan/projects/AtilCalculator' is
#   not under '/home/atilcan/actions-runner/_work/AtilCalculator/AtilCalculator'
#
# P0 incident #351 was filed, PR #352 reverted the change (commit
# `a419f0f`). Sprint 4 P2 (#193, #194) deferred to Sprint 5 P1 with
# revised design (Option B' = `path:` under `_work/`).
#
# This guard prevents re-introduction of the bad pattern (defense-in-depth
# against TD-028 sister blind-spot family — architect's Option C design
# didn't account for GA's path constraint).
#
# Test cases:
#   T1: deploy.yml exists at .github/workflows/deploy.yml
#   T2: deploy.yml does NOT contain the rejected value
#       `path: /home/atilcan/projects/AtilCalculator`
#   T3: If `path:` is set under `actions/checkout.with`, the path must
#       be under `/home/atilcan/actions-runner/_work/` (GA safety check)
#   T4: `actions/checkout` is SHA-pinned (ADR-0027 §Threat model)
#   T5: deploy.yml is valid YAML (parses with python yaml.safe_load)
#   T6: deploy.yml does NOT contain the Option C narrative
#       ("Option C (RCA-17 follow-up, Issue #194)") that introduced the bug
#
# Reference: P0 incident #351, PR #350 (revert target), PR #352 (revert),
#            commit `a419f0f`, Sprint 4 P2 deferred to Sprint 5 P1.

set -uo pipefail

# Path resolution: git rev-parse --show-toplevel is portable (works when this
# script is symlinked or copied outside canonical location). The earlier
# source-path idiom (cd $(dirname $0)) fails in those cases. Per Issue #370
# §T2 + d043 enforcement.
REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT_DIR="$REPO_ROOT/scripts/tests"
DEPLOY_YML="$REPO_ROOT/.github/workflows/deploy.yml"

if [ ! -f "$DEPLOY_YML" ]; then
  echo "ERROR: deploy.yml not found at $DEPLOY_YML" >&2
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
# T1: deploy.yml exists
# ============================================================================
section "T1: deploy.yml exists at .github/workflows/deploy.yml"
if [ -f "$DEPLOY_YML" ]; then
  pass "deploy.yml present"
else
  fail "deploy.yml missing"
  exit 1
fi

# ============================================================================
# T2: rejected `path:` value absent
# ============================================================================
section "T2: rejected 'path: /home/atilcan/projects/AtilCalculator' absent"
if grep -nE '^\s*path:\s*/home/atilcan/projects/AtilCalculator\s*$' "$DEPLOY_YML" >/dev/null 2>&1; then
  fail "rejected path value found in deploy.yml" \
       "the GA-rejected path: /home/atilcan/projects/AtilCalculator — must be removed (PR #350 bug)"
else
  pass "rejected path value NOT present (PR #350 bug regression guarded)"
fi

# ============================================================================
# T3: any `path:` under actions/checkout must be under _work/ (GA constraint)
# ============================================================================
section "T3: any actions/checkout path: must be under runner _work/ root"
# Extract the Checkout step's `with:` block (between "with:" and next "- name:" or top-level key)
# Use python for robust YAML parsing — fail loud if yaml is broken (T5 catches that).
PATH_LINE="$(python3 - <<PYEOF 2>/dev/null
import yaml
with open("$DEPLOY_YML") as f:
    data = yaml.safe_load(f)
jobs = data.get("jobs", {})
for job_name, job in jobs.items():
    for step in job.get("steps", []):
        if "checkout" in step.get("name", "").lower() or "actions/checkout" in step.get("uses", ""):
            with_block = step.get("with", {})
            if "path" in with_block:
                print(with_block["path"])
                break
PYEOF
)"
if [ -z "$PATH_LINE" ]; then
  pass "no path: configured under actions/checkout (GA default = runner _work/ root, satisfies safety check)"
elif [[ "$PATH_LINE" == /home/atilcan/actions-runner/_work/* ]]; then
  pass "actions/checkout path '$PATH_LINE' is under runner _work/ root (satisfies GA safety check)"
else
  fail "actions/checkout path '$PATH_LINE' is NOT under /home/atilcan/actions-runner/_work/" \
       "GA will reject this checkout with: Repository path ... is not under /home/atilcan/actions-runner/_work/..."
fi

# ============================================================================
# T4: actions/checkout is SHA-pinned
# ============================================================================
section "T4: actions/checkout is SHA-pinned (ADR-0027 §Threat model)"
CHECKOUT_USES="$(grep -nE '^\s*uses:\s*actions/checkout@' "$DEPLOY_YML" | head -1 || true)"
if [ -z "$CHECKOUT_USES" ]; then
  fail "no actions/checkout found in deploy.yml"
elif echo "$CHECKOUT_USES" | grep -qE 'actions/checkout@[0-9a-f]{40}'; then
  pass "actions/checkout is SHA-pinned (40-char hex) — ADR-0027 §Threat model satisfied"
elif echo "$CHECKOUT_USES" | grep -qE 'actions/checkout@v[0-9]+'; then
  fail "actions/checkout uses moving tag, not SHA pin" \
       "ADR-0027 §Threat model requires SHA pinning for supply-chain defense. Current: $CHECKOUT_USES"
else
  fail "actions/checkout uses neither SHA pin nor moving tag" "current: $CHECKOUT_USES"
fi

# ============================================================================
# T5: deploy.yml is valid YAML
# ============================================================================
section "T5: deploy.yml is valid YAML (parses with python yaml.safe_load)"
if python3 -c "import yaml; yaml.safe_load(open('$DEPLOY_YML'))" 2>/dev/null; then
  pass "deploy.yml parses as valid YAML"
else
  fail "deploy.yml fails YAML parse" "python yaml.safe_load error above"
fi

# ============================================================================
# T6: Option C narrative absent (defense-in-depth vs TD-028 sister blind-spot)
# ============================================================================
section "T6: Option C narrative absent (TD-028 sister blind-spot guard)"
if grep -nE 'Option C \(RCA-17 follow-up, Issue #194\)' "$DEPLOY_YML" >/dev/null 2>&1; then
  fail "Option C narrative re-introduced" \
       "the architect's Option C comment block (PR #350) was the blind-spot — it didn't account for GA's path constraint. Remove the narrative to prevent the same blind-spot recurring."
else
  pass "Option C narrative NOT present (TD-028 sister blind-spot guarded)"
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
echo "  Reference: P0 #351, PR #350 (revert target), PR #352 (revert, commit a419f0f)."
echo "  Sprint 4 P2 deferred to Sprint 5 P1 with revised design (Option B')."
exit 0
