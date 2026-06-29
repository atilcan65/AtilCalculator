#!/usr/bin/env bash
# d076-label-check-state-filter.sh — RETRO-016 / Bug #670 — label-check workflow
# closed-state bypass regression guard.
#
# Why this test exists
# --------------------
# Per ADR-0015 §3, the label-check workflow is supposed to **bypass closed
# issues and PRs** ("Label Check workflow kapalı (closed) issue'ları ignore
# eder, bu bypass güvenlidir."). The cascade-strip step (line 264+) and the
# Layer 5 step (line 388+) of `.github/workflows/label-check.yml` already
# implement this guard with `if (issueState === 'closed') { ... return }`.
#
# BUT the **primary** step — `Verify required label categories` at line 54+ —
# does NOT implement the same closed-state bypass. Combined with the trigger
# types `[opened, reopened, labeled, unlabeled]` (which DO fire on closed
# issues when a label is added/removed), this means the workflow fails on
# closed issues every time someone adjusts labels post-close (RETRO-016).
#
# ADR-0049 d-test framework sister-pattern: ≥5 TCs + --self-test contract,
# bash + python yaml (workflow YAML inspection) + grep.
#
# 6 TCs (per ADR-0044 RED-first + ADR-0049 d-test framework sister-pattern):
#   TC1: workflow file exists + valid YAML (parse via yaml.safe_load)
#   TC2: trigger types include labeled + unlabeled (baseline — bug surface)
#   TC3: PR 'closed' event is NOT in pull_request_target.types (no-op)
#   TC4: Issue 'closed' event is NOT in issues.types (no-op)
#   TC5: label-check job HAS a closed-state bypass (job-level `if` OR
#        in-script `if (issueState === 'closed') { return }`)
#   TC6: layered sister — cascade-strip + Layer 5 carry the same guard
#        (consistency: bypass applied uniformly, not only in primary step)
#
# Pre-impl RED state (Issue #670 / current main as of 2026-06-29):
#   - TC1 PASS (file exists, YAML valid)
#   - TC2 PASS (labeled/unlabeled in trigger — surfaces bug)
#   - TC3 PASS ('closed' not in PR types — workflow doesn't start on close)
#   - TC4 PASS ('closed' not in issue types — workflow doesn't start on close)
#   - TC5 FAIL (label-check step L54 has no closed-state guard)
#   - TC6 PASS (cascade-strip + Layer 5 carry the guard)
#   → RED on TC5: bug confirmed, fix needed in primary step
#
# Post-impl GREEN state (target, after owner-approved workflow fix):
#   - All 6 TCs PASS
#   - TC5: label-check step includes the guard
#
# Usage:
#   bash d076-label-check-state-filter.sh --self-test     # run inline fixture (6 TCs)
#
# Env vars (override defaults):
#   LABEL_CHECK_YML  path to label-check.yml (default: REPO_ROOT/.github/workflows/label-check.yml)
#   REPO_ROOT        path to the repo (default: parent of this script's parent)
#
# Exit codes:
#   0 — all PASS (GREEN state — closed-state guard present in primary step)
#   1 — at least one FAIL (RED state — bug unfixed in label-check primary step)
#   2 — preflight failure (missing tool, workflow file missing, YAML invalid, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
LABEL_CHECK_YML="${LABEL_CHECK_YML:-${REPO_ROOT}/.github/workflows/label-check.yml}"

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

# Pre-flight: tools + workflow reachable
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required for yaml.safe_load (TC1)" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required for TC2-TC6" >&2; exit 2; }
[ -d "${REPO_ROOT}" ] || { echo "ERROR: REPO_ROOT invalid: ${REPO_ROOT}" >&2; exit 2; }

# Self-test mode
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d076 self-test (6 TCs per RETRO-016 / Bug #670 label-check closed-state bypass, ADR-0044 RED-first)${D}\n"
printf "${B}==================================================================================================${D}\n"
printf "  Repo root:        %s\n" "$REPO_ROOT"
printf "  Workflow file:    %s\n" "$LABEL_CHECK_YML"
printf "  Sister-pattern:   d068 (cluster-lag workflow wiring) + d057 (sync-status silent-skip) + d055 (Layer 5)\n"
printf "  Spec ref:         ADR-0015 §3 (closed-issues bypass), ADR-0012 (4-cat invariant)\n"
printf "  Bug ref:          Issue #670 (P1, area:workflows, agent:human)\n"
printf "  RED-first:        pre-impl TC5 FAIL (label-check step L54 lacks guard), post-impl GREEN\n\n"

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# ============================================================================
# TC1: workflow file exists + valid YAML (parse via yaml.safe_load)
# ============================================================================
section "TC1: workflow file exists + valid YAML (yaml.safe_load baseline)"
if [ ! -f "${LABEL_CHECK_YML}" ]; then
  fail "TC1 — workflow file missing: ${LABEL_CHECK_YML}" \
    "expected .github/workflows/label-check.yml on disk. Sister-pattern d068 baseline. RED-first confirmed."
  EXIT_CODE=1
else
  YAML_OK="$(python3 -c "import yaml,sys; yaml.safe_load(open('${LABEL_CHECK_YML}')); print('OK')" 2>&1)"
  if [ "${YAML_OK}" = "OK" ]; then
    info "TC1 — workflow YAML parses cleanly (yaml.safe_load OK)"
    pass "TC1 — workflow file exists + valid YAML"
  else
    fail "TC1 — workflow YAML parse failed" \
      "yaml.safe_load error: ${YAML_OK}. Sister-pattern d068 baseline — broken YAML blocks all subsequent TCs."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC2: trigger types include labeled + unlabeled (baseline — bug surface)
# ============================================================================
section "TC2: trigger types include labeled + unlabeled (baseline — bug surface per RETRO-016)"
if [ ! -f "${LABEL_CHECK_YML}" ]; then
  fail "TC2 — cannot check triggers (workflow file missing)" \
    "TC1 prerequisite not met."
  EXIT_CODE=1
else
  # YAML 1.1 parses 'on' as boolean True. yaml.safe_load returns {True: ...}.
  PR_TYPES="$(python3 -c "import yaml; d=yaml.safe_load(open('${LABEL_CHECK_YML}')); on=d.get('on', d.get(True, {})); print(','.join(on.get('pull_request_target',{}).get('types',[])))" 2>/dev/null | tr -d '[:space:]')"
  ISSUE_TYPES="$(python3 -c "import yaml; d=yaml.safe_load(open('${LABEL_CHECK_YML}')); on=d.get('on', d.get(True, {})); print(','.join(on.get('issues',{}).get('types',[])))" 2>/dev/null | tr -d '[:space:]')"
  HAS_LABEL_P="$(echo "${PR_TYPES}" | tr ',' '\n' | grep -cx 'labeled' 2>/dev/null | head -1 | tr -d '[:space:]')"
  [ -z "${HAS_LABEL_P}" ] && HAS_LABEL_P=0
  HAS_UNLABEL_P="$(echo "${PR_TYPES}" | tr ',' '\n' | grep -cx 'unlabeled' 2>/dev/null | head -1 | tr -d '[:space:]')"
  [ -z "${HAS_UNLABEL_P}" ] && HAS_UNLABEL_P=0
  HAS_LABEL_I="$(echo "${ISSUE_TYPES}" | tr ',' '\n' | grep -cx 'labeled' 2>/dev/null | head -1 | tr -d '[:space:]')"
  [ -z "${HAS_LABEL_I}" ] && HAS_LABEL_I=0
  HAS_UNLABEL_I="$(echo "${ISSUE_TYPES}" | tr ',' '\n' | grep -cx 'unlabeled' 2>/dev/null | head -1 | tr -d '[:space:]')"
  [ -z "${HAS_UNLABEL_I}" ] && HAS_UNLABEL_I=0

  if [ "${HAS_LABEL_P}" -eq 1 ] && [ "${HAS_UNLABEL_P}" -eq 1 ] && [ "${HAS_LABEL_I}" -eq 1 ] && [ "${HAS_UNLABEL_I}" -eq 1 ]; then
    info "TC2 — triggers include labeled+unlabeled for both PR (${PR_TYPES}) and issues (${ISSUE_TYPES})"
    pass "TC2 — labeled+unlabeled in triggers (this IS the bug surface: closed issues get label-checks when labels change post-close)"
  else
    info "TC2 — triggers do NOT include labeled+unlabeled (PR=${PR_TYPES}, issues=${ISSUE_TYPES}); bug surface absent"
    fail "TC2 — triggers missing labeled/unlabeled (PR has_labeled=${HAS_LABEL_P}, has_unlabeled=${HAS_UNLABEL_P}; issues has_labeled=${HAS_LABEL_I}, has_unlabeled=${HAS_UNLABEL_I})" \
      "If triggers are tightened (removed labeled/unlabeled), the bug is fixed at the trigger level and TC5's guard is redundant. Update this test to match the chosen fix path. Expected: triggers carry labeled+unlabeled (preserves agent fix-back loop) AND TC5 guard prevents failure on closed state."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC3: PR 'closed' event is NOT in pull_request_target.types
# ============================================================================
section "TC3: PR 'closed' event is NOT in pull_request_target.types (no-op invariant)"
if [ ! -f "${LABEL_CHECK_YML}" ]; then
  fail "TC3 — cannot check PR triggers (workflow file missing)" \
    "TC1 prerequisite not met."
  EXIT_CODE=1
else
  HAS_CLOSED_P="$(echo "${PR_TYPES:-}" | tr ',' '\n' | grep -cx 'closed' 2>/dev/null | head -1 | tr -d '[:space:]')"
  [ -z "${HAS_CLOSED_P}" ] && HAS_CLOSED_P=0
  if [ "${HAS_CLOSED_P}" -eq 0 ]; then
    info "TC3 — PR 'closed' NOT in trigger types (${PR_TYPES:-empty})"
    pass "TC3 — PR 'closed' event absent from pull_request_target.types (no-op at trigger level)"
  else
    fail "TC3 — PR 'closed' event IS in trigger types (got: ${PR_TYPES})" \
      "expected 'closed' absent from pull_request_target.types. If present, the workflow fires on close — even with TC5 guard, that's wasted CI. Tighten trigger to types=[opened,reopened,labeled,unlabeled] only."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC4: Issue 'closed' event is NOT in issues.types
# ============================================================================
section "TC4: Issue 'closed' event is NOT in issues.types (no-op invariant)"
if [ ! -f "${LABEL_CHECK_YML}" ]; then
  fail "TC4 — cannot check issue triggers (workflow file missing)" \
    "TC1 prerequisite not met."
  EXIT_CODE=1
else
  HAS_CLOSED_I="$(echo "${ISSUE_TYPES:-}" | tr ',' '\n' | grep -cx 'closed' 2>/dev/null | head -1 | tr -d '[:space:]')"
  [ -z "${HAS_CLOSED_I}" ] && HAS_CLOSED_I=0
  if [ "${HAS_CLOSED_I}" -eq 0 ]; then
    info "TC4 — Issue 'closed' NOT in trigger types (${ISSUE_TYPES:-empty})"
    pass "TC4 — Issue 'closed' event absent from issues.types (no-op at trigger level)"
  else
    fail "TC4 — Issue 'closed' event IS in trigger types (got: ${ISSUE_TYPES})" \
      "expected 'closed' absent from issues.types. Same fix as TC3 — tighten trigger to omit 'closed'."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC5: label-check job HAS a closed-state bypass (job-level `if` OR in-script guard)
#       THIS IS THE PRIMARY BUG (RETRO-016 / Issue #670)
# ============================================================================
section "TC5: label-check job has closed-state bypass — 'Verify required label categories' step L54+ (RETRO-016 bug)"
if [ ! -f "${LABEL_CHECK_YML}" ]; then
  fail "TC5 — cannot inspect job content (workflow file missing)" \
    "TC1 prerequisite not met."
  EXIT_CODE=1
else
  # Extract the script: block of the verify step. yaml.safe_load multi-line scalar → str.
  # Two acceptable patterns:
  #   (a) Job-level `if:` excluding closed state (e.g., `if: github.event.issue.state == 'open'`)
  #   (b) In-script early-return: `if (issueState === 'closed')`  OR  `if (target.state === 'closed')`
  #
  # Pattern (b) is what cascade-strip (L264) and Layer 5 (L388) already use.
  VERIFY_SCRIPT="$(python3 -c "
import yaml
d = yaml.safe_load(open('${LABEL_CHECK_YML}'))
jobs = d.get('jobs', {})
for job_name, job in jobs.items():
    if job_name != 'label-check':
        continue
    for step in job.get('steps', []):
        if step.get('name', '') == 'Verify required label categories':
            print(step.get('with', {}).get('script', ''))
" 2>/dev/null)"
  JOB_IF="$(python3 -c "
import yaml
d = yaml.safe_load(open('${LABEL_CHECK_YML}'))
jobs = d.get('jobs', {})
for job_name, job in jobs.items():
    if job_name != 'label-check':
        continue
    if_conds = []
    for step in job.get('steps', []):
        if 'if' in step:
            if_conds.append(step['if'])
    job_if = job.get('if', '')
    if job_if:
        if_conds.append(job_if)
    print('\n'.join(if_conds))
" 2>/dev/null)"

  # Check pattern (b): in-script guard
  IN_SCRIPT_GUARD="$(echo "${VERIFY_SCRIPT}" | grep -cE "(issueState|target\\.state)\\s*===\\s*['\"]closed['\"]" 2>/dev/null | head -1 | tr -d '[:space:]')"
  [ -z "${IN_SCRIPT_GUARD}" ] && IN_SCRIPT_GUARD=0
  # Check pattern (a): job/step-level `if` excluding closed state
  IF_GUARD="$(echo "${JOB_IF}" | grep -cE "state\\s*===\\s*['\"]open['\"]" 2>/dev/null | head -1 | tr -d '[:space:]')"
  [ -z "${IF_GUARD}" ] && IF_GUARD=0
  # Also accept broader patterns: target.state !== 'closed', or issue.state != closed
  IN_SCRIPT_GUARD_BROAD="$(echo "${VERIFY_SCRIPT}" | grep -cE "state\\s*[!=]==?\\s*['\"](closed|open)['\"]" 2>/dev/null | head -1 | tr -d '[:space:]')"
  [ -z "${IN_SCRIPT_GUARD_BROAD}" ] && IN_SCRIPT_GUARD_BROAD=0

  if [ "${IN_SCRIPT_GUARD}" -gt 0 ] || [ "${IF_GUARD}" -gt 0 ] || [ "${IN_SCRIPT_GUARD_BROAD}" -gt 0 ]; then
    info "TC5 — closed-state guard present (in-script guard: ${IN_SCRIPT_GUARD} match(es); job/step-level guard: ${IF_GUARD} match(es))"
    pass "TC5 — label-check primary step bypasses closed state (RETRO-016 fix in place)"
  else
    fail "TC5 — label-check primary step LACKS closed-state bypass (RETRO-016 bug unfixed)" \
      "expected either: (a) job-level if: 'state == open', or (b) in-script 'if (issueState / target.state === \"closed\") { return }' (sister-pattern to cascade-strip L267 and Layer 5 L393). Without it, the workflow fails on label/unlabel events fired on closed issues. Owner-approved fix required per file ownership matrix (.github/workflows/ is human-only territory). See Issue #670 / RETRO-016."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC6: layered sister — cascade-strip + Layer 5 carry the same guard (consistency)
# ============================================================================
section "TC6: layered sister — cascade-strip + Layer 5 carry the same closed-state guard (consistency)"
if [ ! -f "${LABEL_CHECK_YML}" ]; then
  fail "TC6 — cannot inspect cascade-strip/Layer 5 (workflow file missing)" \
    "TC1 prerequisite not met."
  EXIT_CODE=1
else
  # Sister-pattern: the other steps that touch labels should ALSO have the guard.
  # Both cascade-strip (L267) and Layer 5 (L393) use `issueState === 'closed'` pattern.
  GUARD_TOTAL="$(grep -cE "issueState\\s*===\\s*['\"]closed['\"]" "${LABEL_CHECK_YML}" 2>/dev/null | head -1 | tr -d '[:space:]')"
  [ -z "${GUARD_TOTAL}" ] && GUARD_TOTAL=0
  # Cascade-strip step has exactly 1 occurrence; Layer 5 has 1 occurrence; total = 2.
  # After TC5 fix lands, total = 3 (cascade-strip + Layer 5 + label-check primary).
  if [ "${GUARD_TOTAL}" -ge 2 ]; then
    info "TC6 — cascade-strip + Layer 5 carry closed-state guard (combined issueState===closed count: ${GUARD_TOTAL})"
    pass "TC6 — sister steps carry closed-state guard (consistency: cascade-strip + Layer 5; label-check adds itself via TC5)"
  else
    fail "TC6 — sister steps missing closed-state guard (combined count: ${GUARD_TOTAL})" \
      "expected cascade-strip step and Layer 5 step to each carry the guard (sister-pattern consistency, total ≥ 2). If only 0 or 1 occurrence, the fix scope is incomplete — the bug may resurrect in those steps. RED-first confirmed."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "${FAIL}" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — label-check primary step lacks closed-state bypass per RETRO-016 / Issue #670 ADR-0015 §3 violation${D}\n" "${FAIL}"
  exit 1
fi

printf "\n${G}GREEN state: all 6 TCs PASS — label-check closed-state bypass in place (owner-approved fix lands when Issue #670 is closed)${D}\n"
exit 0
