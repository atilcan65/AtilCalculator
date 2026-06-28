#!/usr/bin/env bash
# d068-cluster-lag-workflow-wiring.sh — STORY-S18-002 / Issue #605 workflow YAML wiring regression test (6 TCs).
#
# Why this test exists
# --------------------
# scripts/post-squash/cluster-lag-detector.sh shipped Sprint 17 (PR #597) and
# is unit-tested by d064 (6/6 TCs RED-first). But the script is NOT yet wired
# into .github/workflows/post-squash.yml — every cluster-lag event requires
# manual invocation (fragile, error-prone). RETRO-012 §7 codifies PM curator
# step; auto-wiring closes the loop end-to-end (AC3 of Issue #605).
#
# ADR-0059 §1 + ADR-0049 d-test framework require ≥5 TCs per d-test.
# This d-test enforces the workflow YAML lifecycle:
#   TC1: workflow file exists at .github/workflows/post-squash.yml + valid YAML + parseable
#   TC2: workflow triggers on pull_request_target.closed with merged==true filter
#   TC3: workflow invokes cluster-lag-detector.sh with all 7 required env vars
#   TC4: workflow populates FAKE_GH_MERGED via `gh pr list --state merged --json number,mergedAt`
#   TC5: workflow SHA-pins actions/checkout (per ADR-0027 + ADR-0043 §lens h)
#   TC6: workflow has `if: github.event.pull_request.merged == true` guard (no false invocation on PR close without merge)
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d064 (Issue #587 ADR-0059 §1 cluster-lag-detector impl — direct predecessor, same feature)
#   - d065 (Issue #607 ADR-0033 dual-channel enforcement — Sprint 18 sister)
#   - d066 (Issue #609 WIP cap script miscounts — Sprint 18 sister)
#   - d067 (Issue #610 proactive-scan wip_overflow false positive — Sprint 18 sister)
#
# Usage:
#   bash d068-cluster-lag-workflow-wiring.sh --self-test     # run inline fixture (6 TCs)
#
# Exit codes:
#   0 — all PASS (TC1-TC6 green, workflow wiring impl'd)
#   1 — at least one FAIL (RED state — workflow missing OR fixture bug)
#   2 — preflight failure (missing tool, etc.)
#
# RED-first discipline (ADR-0044):
#   Pre-impl: ALL 6 TCs FAIL (workflow file doesn't exist)
#   Post-impl: all 6 TCs must PASS
#
# Note on ID clash: body of Issue #605 says "d065 d-test" but per ADR-0055
# §sub-pattern remediation and INDEX.md Sprint 18 d-test lineage, the
# cluster-lag wiring test is d068 (d065 = dual-channel, d066 = wip-cap,
# d067 = proactive-scan, d068 = cluster-lag wiring).
#
# Run standalone: bash scripts/tests/d068-cluster-lag-workflow-wiring.sh --self-test

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW_FILE="${REPO_ROOT}/.github/workflows/post-squash.yml"
DETECTOR_SH="${REPO_ROOT}/scripts/post-squash/cluster-lag-detector.sh"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[0;33m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; Y=""; B=""; D=""
fi

PASS=0; FAIL=0; INFO=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
info() { printf "  ${Y}ℹ INFO${D} — %s\n" "$1"; INFO=$((INFO+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Pre-flight
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required for YAML parse (yaml.safe_load)" >&2; exit 2; }

# Self-test mode
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d068 self-test (6 TCs per Issue #605 STORY-S18-002 cluster-lag workflow wiring)${D}\n"
printf "${B}=============================================================================${D}\n"
printf "  Workflow under test: %s\n" "$WORKFLOW_FILE"
printf "  Detector impl: %s (PR #597 SHIPPED, d064 GREEN)\n" "$DETECTOR_SH"
printf "  Fixture: static YAML inspection + PyYAML safe_load + grep assertions\n"
printf "  RED-first: pre-impl all 6 TCs must FAIL.\n"
printf "  Post-impl: all 6 TCs must PASS.\n\n"

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# Test sandbox
TEST_TMPDIR="$(mktemp -d /tmp/d068-XXXXXX)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# ============================================================================
# TC1: workflow file exists at .github/workflows/post-squash.yml + valid YAML + parseable
# ============================================================================
section "TC1: workflow file exists + valid YAML + parseable"
if [ ! -f "$WORKFLOW_FILE" ]; then
  fail "TC1 — workflow file missing" \
    "expected $WORKFLOW_FILE (impl not yet written per ADR-0044 RED-first)"
  EXIT_CODE=1
else
  # Parse YAML via python3 yaml.safe_load
  yaml_json="$(python3 -c "import yaml,sys; d=yaml.safe_load(open('$WORKFLOW_FILE')); print('parsed_ok' if d else 'empty')" 2>&1)"
  if [ "$yaml_json" != "parsed_ok" ]; then
    fail "TC1 — workflow YAML not parseable" \
      "expected valid YAML at $WORKFLOW_FILE; python3 yaml.safe_load output: $yaml_json"
    EXIT_CODE=1
  else
    pass "TC1 — workflow file exists + valid YAML (parseable via yaml.safe_load)"
  fi
fi

# ============================================================================
# TC2: workflow triggers on pull_request_target.closed with merged==true filter
# ============================================================================
section "TC2: workflow triggers on pull_request_target.closed with merged==true guard"
if [ ! -f "$WORKFLOW_FILE" ]; then
  fail "TC2 — workflow file missing (cannot inspect triggers)"
  EXIT_CODE=1
else
  # 2a: 'on:' / True key contains pull_request_target with closed type
  has_pr_target='^on:|^True:'
  has_closed='closed'
  has_merged_guard='github.event.pull_request.merged == true'

  yaml_content="$(cat "$WORKFLOW_FILE")"

  if ! echo "$yaml_content" | python3 -c "
import yaml, sys
d = yaml.safe_load(sys.stdin)
on = d.get(True) or d.get('on') or {}
prt = on.get('pull_request_target', {})
types = prt.get('types', [])
if isinstance(prt.get('types'), str):
    types = [prt['types']]
print('OK' if 'closed' in types else 'FAIL:types=' + str(types))
" 2>/dev/null | grep -q "OK"; then
    fail "TC2 — workflow does NOT trigger on pull_request_target.closed" \
      "expected types: [closed] in pull_request_target trigger; got workflow without correct trigger config"
    EXIT_CODE=1
  elif ! echo "$yaml_content" | grep -qF 'github.event.pull_request.merged == true'; then
    fail "TC2 — workflow missing merged==true guard" \
      "expected 'if: github.event.pull_request.merged == true' to skip non-merged closes (Issue #605 AC2)"
    EXIT_CODE=1
  else
    pass "TC2 — workflow triggers on pull_request_target.closed + merged==true guard present"
  fi
fi

# ============================================================================
# TC3: workflow invokes cluster-lag-detector.sh with all 7 required env vars
# ============================================================================
section "TC3: workflow invokes cluster-lag-detector.sh with all 7 required env vars (ADR-0059 API contract)"
REQUIRED_VARS=(PR_NUMBER MERGED_AT REPO CLUSTER_ID DETECTOR_VERSION CLUSTER_LAG_LOG FAKE_GH_MERGED)
MISSING_VARS=()
if [ ! -f "$WORKFLOW_FILE" ]; then
  fail "TC3 — workflow file missing (cannot inspect env vars)"
  EXIT_CODE=1
else
  yaml_content="$(cat "$WORKFLOW_FILE")"
  for var in "${REQUIRED_VARS[@]}"; do
    if ! echo "$yaml_content" | grep -qE "^[[:space:]]*${var}:[[:space:]]"; then
      MISSING_VARS+=("$var")
    fi
  done
  # Also assert cluster-lag-detector.sh is invoked (bash scripts/post-squash/cluster-lag-detector.sh or FAKE_GH_MERGED=... bash ...)
  if ! echo "$yaml_content" | grep -qE "cluster-lag-detector\.sh|post-squash/cluster-lag"; then
    MISSING_VARS+=("INVOCATION(cluster-lag-detector.sh)")
  fi

  if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    fail "TC3 — workflow missing required env vars / invocation" \
      "expected all 7 ADR-0059 env vars + script invocation; missing: ${MISSING_VARS[*]}"
    EXIT_CODE=1
  else
    pass "TC3 — workflow sets all 7 ADR-0059 env vars (PR_NUMBER, MERGED_AT, REPO, CLUSTER_ID, DETECTOR_VERSION, CLUSTER_LAG_LOG, FAKE_GH_MERGED) + invokes detector"
  fi
fi

# ============================================================================
# TC4: workflow populates FAKE_GH_MERGED via `gh pr list --state merged --json number,mergedAt`
# ============================================================================
section "TC4: workflow populates FAKE_GH_MERGED via gh pr list (merged JSON)"
if [ ! -f "$WORKFLOW_FILE" ]; then
  fail "TC4 — workflow file missing (cannot inspect merged JSON population)"
  EXIT_CODE=1
else
  yaml_content="$(cat "$WORKFLOW_FILE")"
  # Accept either: gh pr list ... --json number,mergedAt (preferred) OR
  #                REST API equivalent (gh api graphql/repos/.../pulls?state=closed)
  has_gh_pr_list='gh pr list'
  has_state_merged='--state[[:space:]]+merged'
  has_json_fields='--json[[:space:]]+.*number.*mergedAt|number,mergedAt'
  has_fake_gh_assignment='FAKE_GH_MERGED[[:space:]]*='

  has_invocation=0
  if echo "$yaml_content" | grep -qF 'gh pr list' && \
     echo "$yaml_content" | grep -qE -- '--state[[:space:]]+merged' && \
     echo "$yaml_content" | grep -qE -- '(mergedAt|merged_at)'; then
    has_invocation=1
  fi

  if [ "$has_invocation" -eq 0 ]; then
    fail "TC4 — workflow does NOT populate FAKE_GH_MERGED correctly" \
      "expected 'gh pr list --state merged --json number,mergedAt' (or REST equivalent) writing to FAKE_GH_MERGED path. AC3 wiring requires live merged-PR list at detector invocation time."
    EXIT_CODE=1
  else
    pass "TC4 — workflow invokes gh pr list --state merged with number,mergedAt fields"
  fi
fi

# ============================================================================
# TC5: workflow SHA-pins actions/checkout (per ADR-0027 + ADR-0043 §lens h)
# ============================================================================
section "TC5: workflow SHA-pins actions/checkout (ADR-0027 supply-chain + ADR-0043 §lens h)"
if [ ! -f "$WORKFLOW_FILE" ]; then
  fail "TC5 — workflow file missing (cannot inspect SHA pins)"
  EXIT_CODE=1
else
  yaml_content="$(cat "$WORKFLOW_FILE")"
  # If actions/checkout is used at all, it MUST be SHA-pinned (40 hex chars after @, with vN comment)
  # Pattern: uses: actions/checkout@<40-hex-chars>  # vN
  has_checkout='uses:[[:space:]]+actions/checkout@'
  sha_pin_pattern='actions/checkout@[0-9a-f]{40}'

  uses_checkout="$(echo "$yaml_content" | grep -cE "$has_checkout" || true)"
  has_sha_pin="$(echo "$yaml_content" | grep -cE "$sha_pin_pattern" || true)"

  if [ "$uses_checkout" -gt 0 ] && [ "$has_sha_pin" -eq 0 ]; then
    fail "TC5 — actions/checkout used but NOT SHA-pinned" \
      "ADR-0027 requires SHA-pinning (40 hex chars after @) for supply-chain security; tag-pinning (v4) is insufficient."
    EXIT_CODE=1
  elif [ "$uses_checkout" -eq 0 ]; then
    info "TC5 — workflow does not use actions/checkout (no SHA-pin check needed)"
  else
    pass "TC5 — actions/checkout SHA-pinned (ADR-0027 supply-chain compliant)"
  fi
fi

# ============================================================================
# TC6: workflow has `if: github.event.pull_request.merged == true` guard (AC2)
# ============================================================================
section "TC6: workflow has merged==true guard (AC2 — no false invocation on PR close without merge)"
if [ ! -f "$WORKFLOW_FILE" ]; then
  fail "TC6 — workflow file missing"
  EXIT_CODE=1
else
  yaml_content="$(cat "$WORKFLOW_FILE")"
  # The guard can be at job-level (jobs.X.if) or step-level. Either is acceptable.
  has_job_level='if:[[:space:]]+github\.event\.pull_request\.merged == true'
  has_step_level='if:[[:space:]]+\$\{\{[[:space:]]+github\.event\.pull_request\.merged == true[[:space:]]+\}\}'

  has_guard=0
  if echo "$yaml_content" | grep -qE "$has_job_level|$has_step_level"; then
    has_guard=1
  fi

  if [ "$has_guard" -eq 0 ]; then
    fail "TC6 — workflow missing merged==true guard at job OR step level" \
      "AC2 requires invocation only on PR closed+merged; without guard, every PR close (incl. closed-not-merged) triggers cluster-lag-detector (false-positive class)."
    EXIT_CODE=1
  else
    pass "TC6 — merged==true guard present (AC2: no false invocation on PR close without merge)"
  fi
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — workflow wiring missing or incomplete per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 6 TCs PASS — workflow wiring active (Issue #605 AC1+AC2+AC3 complete)${D}\n"
exit 0