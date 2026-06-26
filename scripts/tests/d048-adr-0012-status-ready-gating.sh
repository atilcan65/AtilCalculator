#!/usr/bin/env bash
# d048-adr-0012-status-ready-gating.sh — Part 2 (status:ready auto-add gating) canonical
# content guard for .github/workflows/label-check.yml Layer 5.
#
# Why this test exists
# --------------------
# Per ADR-0012 §Cascade-strip scope-tightening Part 2 (PR #418 amend + PR #424
# clarification) + Issue #425 AC2.1: the workflow's `status:ready` auto-add MUST
# fire ONLY when the reviewer chain is fully cleared, not merely because an arch
# verdict was posted. The 3-row type table (docs / non-docs / chore+incident)
# governs which reviewer states are sufficient.
#
# Part 1 (PR #426, MERGED Sprint 10) handles the DAMAGE (cascade-strip breaks
# reviewer chain). Part 2 (Issue #425) handles the TRIGGER (premature
# status:ready add). Both required to fully close PR #393 canonical case.
#
# A future maintainer who:
#   - Removes the `type:docs` exemption (docs PRs would need tester signoff,
#     slowing PM aggregation per ADR-0021 docs PR convention)
#   - Removes the `needs-tester-signoff` gate for non-docs (premature ready,
#     re-introduces PR #393-style cascade)
#   - Removes the reversal handler (TC4 — once tester re-rejects, ready stays)
# would silently re-open the PR #393 root-cause variant.
#
# Sister references:
#   - ADR-0012 §Cascade-strip scope-tightening Part 2 (PR #418 + PR #424 amend)
#   - Issue #425 (this d-test's tracker, Sprint 11 P2 candidate)
#   - Issue #423 (Part 1 sister, MERGED via PR #426)
#   - PR #393 (canonical case — manual status:ready add broke reviewer chain)
#   - ADR-0021 (docs PR convention — PM aggregates status:ready, no tester
#     signoff required for type:docs)
#   - ADR-0044 (TDD red-first doctrine — this test runs RED pre-merge of #425)
#   - d046-peer-poke-canonical-parity.sh (sister test, same grep-verify shape)
#   - d046-expansion-adr-0044-literal-form.sh (sister test, multi-TC pattern)
#   - Issue #448 (TC8 sister-pattern to TC7, addLabels API regression anchor)
#
# Test cases (4 TCs per Issue #425 AC2.1 + 4 sister-pattern regression anchors):
#   T1 (TC1): type:docs + arch verdict only → status:ready auto-add PATH EXISTS
#             in Layer 5 (presence of addLabel('status:ready') gated on docs).
#   T2 (TC2): type:feature + arch verdict only → status:ready NOT auto-added.
#             Workflow must contain an explicit non-docs gate that requires
#             tester signoff before addLabel('status:ready') fires.
#   T3 (TC3): type:feature + arch + tester APPROVED → status:ready auto-add.
#             Workflow must contain a path where non-docs + both reviewer
#             states cleared → addLabel('status:ready').
#   T4 (TC4): needs-tester-signoff re-added → status:ready removed.
#             Workflow must contain a reversal handler on needs-tester-signoff
#             label-add event that calls removeLabel('status:ready').
#
# Exit code: 0 = all pass, 1 = at least one fail.
# Run standalone: bash scripts/tests/d048-adr-0012-status-ready-gating.sh
#
# RED state expected (per ADR-0044 TDD red-first): this test FAILS on
# post-Sprint-10 main because Layer 5 (Issue #425) has not shipped yet.
# Becomes GREEN after PR for Issue #425 merges with correct Layer 5 step.

set -uo pipefail

# Path resolution: git rev-parse --show-toplevel is portable (per Issue #370 §T2 + d043).
REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKFLOW="$REPO_ROOT/.github/workflows/label-check.yml"

if [ ! -f "$WORKFLOW" ]; then
  echo "ERROR: .github/workflows/label-check.yml not found at $WORKFLOW" >&2
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

# grep_count: grep -c returns N\n which breaks integer comparison.
# Strip newline + default to 0 on empty match.
grep_count() {
  local n
  n=$(grep -cE "$1" "$WORKFLOW" 2>/dev/null | tr -d '\n' || true)
  [ -z "$n" ] && n=0
  printf '%d' "$n"
}
grep_count_fixed() {
  local n
  n=$(grep -cF "$1" "$WORKFLOW" 2>/dev/null | tr -d '\n' || true)
  [ -z "$n" ] && n=0
  printf '%d' "$n"
}

# ============================================================================
# T1 (AC2.1 TC1): type:docs auto-add path — Layer 5 contains addLabel gate
# conditional on type:docs presence + arch verdict cleared.
# ============================================================================
section "T1 (TC1): type:docs + arch verdict → status:ready auto-add PATH EXISTS in Layer 5"
# Canonical anchors any correct Layer 5 must include:
#   - reference to 'type:docs' label (in Layer 5 body, NOT just Layer 1 4-cat check)
#   - presence of 'addLabel' or 'addLabels' call
#   - 'status:ready' string as the target label
# Implementation may use 'type:docs', labels.includes('type:docs'),
# labels.some(...), or similar variants. We check for the 3 anchors within
# proximity (same file is sufficient since Layer 5 is added as a new step).
TC1_DOCS_REFS=$(grep_count "type:docs|type === 'docs'|isDocs|'docs'")
TC1_ADD_REFS=$(grep_count "addLabel|addLabels")
TC1_READY_REFS=$(grep_count "['\"]status:ready['\"]")
if [ "$TC1_DOCS_REFS" -ge 1 ] && [ "$TC1_ADD_REFS" -ge 1 ] && [ "$TC1_READY_REFS" -ge 1 ]; then
  pass "Layer 5 type:docs auto-add anchors present (docs_refs=$TC1_DOCS_REFS, addLabel_refs=$TC1_ADD_REFS, status:ready_refs=$TC1_READY_REFS)"
else
  fail "Layer 5 type:docs auto-add anchors MISSING (docs_refs=$TC1_DOCS_REFS, addLabel_refs=$TC1_ADD_REFS, status:ready_refs=$TC1_READY_REFS)" \
    "Per ADR-0012 §Cascade-strip scope-tightening Part 2 + ADR-0021: type:docs PRs need only arch verdict for status:ready auto-add. Any correct Layer 5 must include addLabel('status:ready') gated on type:docs presence."
fi

# ============================================================================
# T2 (AC2.1 TC2): non-docs gate — Layer 5 explicitly requires tester signoff
# for non-docs types BEFORE status:ready auto-add fires.
# ============================================================================
section "T2 (TC2): non-docs gate — needs-tester-signoff MUST be cleared before status:ready addLabel"
# Canonical anchors: workflow must reference 'needs-tester-signoff' (gate
# condition) AND 'type:docs' (exclusion reference). The combination ensures
# the non-docs path explicitly checks for tester signoff (vs the docs path
# which skips it per ADR-0021).
TC2_TESTER_REFS=$(grep_count_fixed "needs-tester-signoff")
if [ "$TC1_DOCS_REFS" -ge 1 ] && [ "$TC2_TESTER_REFS" -ge 2 ]; then
  pass "Layer 5 non-docs gate present (needs-tester-signoff_refs=$TC2_TESTER_REFS, must be >= 2: once as gate condition, once as TC4 reversal trigger)"
else
  fail "Layer 5 non-docs gate MISSING (needs-tester-signoff_refs=$TC2_TESTER_REFS)" \
    "Per ADR-0012 Part 2: non-docs PRs (feature/bug/refactor/chore/incident) require tester APPROVED verdict before status:ready auto-add. Any correct Layer 5 must reference needs-tester-signoff as a gate condition at least twice (gate + reversal)."
fi

# ============================================================================
# T3 (AC2.1 TC3): non-docs + both cleared → addLabel('status:ready').
# Verified via combined anchor: needs-architect-review AND needs-tester-signoff
# both present in workflow (the gate condition for non-docs path).
# ============================================================================
section "T3 (TC3): non-docs + arch + tester cleared → status:ready auto-add PATH EXISTS"
# Canonical anchors: both reviewer-chain labels must appear in workflow
# (as gate conditions), AND status:ready must appear (as addLabel target).
# This proves the full pre-condition chain is encoded.
TC3_ARCH_REFS=$(grep_count_fixed "needs-architect-review")
if [ "$TC3_ARCH_REFS" -ge 1 ] && [ "$TC2_TESTER_REFS" -ge 1 ] && [ "$TC1_READY_REFS" -ge 1 ]; then
  pass "Layer 5 full path encoded (needs-architect-review_refs=$TC3_ARCH_REFS, needs-tester-signoff_refs=$TC2_TESTER_REFS, status:ready_refs=$TC1_READY_REFS)"
else
  fail "Layer 5 full path MISSING (arch_refs=$TC3_ARCH_REFS, tester_refs=$TC2_TESTER_REFS, ready_refs=$TC1_READY_REFS)" \
    "Per ADR-0012 Part 2: non-docs PR requires BOTH needs-architect-review and needs-tester-signoff to be cleared before status:ready auto-add. Any correct Layer 5 must reference all three labels."
fi

# ============================================================================
# T4 (AC2.1 TC4): reversal handler — needs-tester-signoff re-added →
# removeLabel('status:ready'). Workflow must contain BOTH a removeLabel call
# AND the needs-tester-signoff reference (distinguished from Layer 4 cascade-strip
# removeLabel by the GATE label being needs-tester-signoff, not status:* duplicate).
# ============================================================================
section "T4 (TC4): needs-tester-signoff re-added → removeLabel('status:ready') reversal PATH EXISTS"
# Canonical anchors: workflow must contain 'removeLabel' call AND
# 'needs-tester-signoff' reference (TC4 reversal handler). Layer 4 also
# contains removeLabel for duplicate status:*, but that targets status:* labels.
# TC4 is distinguished by the TRIGGER being needs-tester-signoff add (not
# status:* duplicate add).
TC4_REMOVE_REFS=$(grep_count "removeLabel|removeLabels")
if [ "$TC4_REMOVE_REFS" -ge 2 ] && [ "$TC2_TESTER_REFS" -ge 2 ]; then
  pass "Layer 5 reversal handler present (removeLabel_refs=$TC4_REMOVE_REFS >= 2: Layer 4 cascade-strip + Layer 5 reversal; needs-tester-signoff_refs=$TC2_TESTER_REFS >= 2)"
else
  fail "Layer 5 reversal handler MISSING (removeLabel_refs=$TC4_REMOVE_REFS, needs-tester-signoff_refs=$TC2_TESTER_REFS)" \
    "Per ADR-0012 Part 2: if needs-tester-signoff is re-added after tester APPROVED (e.g., dev pushes new commit, tester re-rejects), status:ready must be auto-removed. Layer 4's removeLabel targets status:* duplicates; Layer 5's removeLabel must target status:ready on needs-tester-signoff trigger."
fi

# ============================================================================
# T5 (P0 hotfix Issue #436, regression anchor for context.payload.action):
# Layer 5 must use context.payload.action (NOT context.event.action which is
# undefined on pull_request_target events — see actions/github-script docs).
# Anchor checks Layer 5 region (after L370) for context.payload.action and
# absence of bare context.event.action in runtime code (comments excluded).
# ============================================================================
section "T5 (Issue #436 P0): Layer 5 uses context.payload.action (NOT context.event.action)"
# Extract Layer 5 region (from L370 onward) to isolate from Layer 4 (which
# has the legacy context.event.action pattern at L337 — pre-existing, not
# in scope of this hotfix).
LAYER5_REGION="$(tail -n +370 "$WORKFLOW")"
# Positive anchor: context.payload.action must appear at least once.
TC5_PAYLOAD_HITS=$(printf '%s' "$LAYER5_REGION" | grep -cE "context\.payload\.action" 2>/dev/null || echo 0)
# Negative anchor: bare context.event.action in runtime code (excludes comments
# that mention the bug fix history). A bare .event.action in code is the bug.
# We count lines matching context.event.action that are NOT inside // comment
# and NOT inside /* */ block — approximation: grep for context.event.action
# OUTSIDE of comment-only lines (lines starting with whitespace + // or *).
TC5_BARE_EVENT_HITS=$(printf '%s\n' "$LAYER5_REGION" | grep -E "context\.event\.action" 2>/dev/null | grep -vE "^\s*(\*|//)" | wc -l | tr -d ' \n')
if [ "$TC5_PAYLOAD_HITS" -ge 1 ] && [ "$TC5_BARE_EVENT_HITS" = "0" ]; then
  pass "Layer 5 uses context.payload.action (payload_hits=$TC5_PAYLOAD_HITS, bare_event_hits=0)"
else
  fail "Layer 5 still has bare context.event.action (payload_hits=$TC5_PAYLOAD_HITS, bare_event_hits=$TC5_BARE_EVENT_HITS)" \
    "Issue #436 P0: context.event.action is undefined on pull_request_target (context.event is WebhookEvent metadata {name, payload}, not {action}). Canonical accessor is context.payload.action. Defensive fallback: 'context.payload.action || \"(batch)\"' or 'context.payload.action || \"opened\"'."
fi

# ============================================================================
# T5 (Issue #436 P0 + Issue #439 Path A scope expansion, regression anchor for
# context.payload.action): Layer 5 region (after L370) and Layer 4 cascade-strip
# audit body (around L337) must use context.payload.action (NOT context.event.action
# which is undefined on pull_request_target — see actions/github-script docs).
# Anchors both regions: positive (payload.action present) + negative (no bare
# event.action in runtime code, comments OK).
# ============================================================================
section "T5 (Issue #436 P0 + #439): context.payload.action used in Layer 4 + Layer 5 audit bodies"
LAYER5_REGION="$(tail -n +370 "$WORKFLOW")"
TC5_PAYLOAD_HITS=$(printf '%s' "$LAYER5_REGION" | grep -cE "context\.payload\.action" 2>/dev/null || echo 0)
TC5_BARE_EVENT_HITS=$(printf '%s\n' "$LAYER5_REGION" | grep -E "context\.event\.action" 2>/dev/null | grep -vE "^\s*(\*|//)" | wc -l | tr -d ' \n')
if [ "$TC5_PAYLOAD_HITS" -ge 1 ] && [ "$TC5_BARE_EVENT_HITS" = "0" ]; then
  pass "Layer 5 uses context.payload.action (payload_hits=$TC5_PAYLOAD_HITS, bare_event_hits=0)"
else
  fail "Layer 5 still has bare context.event.action (payload_hits=$TC5_PAYLOAD_HITS, bare_event_hits=$TC5_BARE_EVENT_HITS)" \
    "Issue #436 P0: context.event.action is undefined on pull_request_target (context.event is WebhookEvent metadata {name, payload}, not {action}). Canonical accessor is context.payload.action. Defensive fallback: 'context.payload.action || \"(batch)\"'."
fi

# ============================================================================
# T6 (Issue #439 P2, Path A scope expansion to Layer 4): Layer 4 cascade-strip
# audit body around L337 must use context.payload.action — Layer 4 fires BEFORE
# Layer 5 in the workflow, so a bare context.event.action there throws TypeError
# before Layer 5 even runs (CI label-check FAILURE ×5 on PR #438 pre-#439 fix).
# ============================================================================
section "T6 (Issue #439 P2): Layer 4 cascade-strip audit body uses context.payload.action"
# Extract Layer 4 audit body region (around L320-L360 — between Q5a fail-check
# and the auditBody construction).
LAYER4_AUDIT_REGION="$(sed -n '320,360p' "$WORKFLOW")"
TC6_PAYLOAD_HITS=$(printf '%s' "$LAYER4_AUDIT_REGION" | grep -cE "context\.payload\.action" 2>/dev/null || echo 0)
TC6_BARE_EVENT_HITS=$(printf '%s\n' "$LAYER4_AUDIT_REGION" | grep -E "context\.event\.action" 2>/dev/null | grep -vE "^\s*(\*|//)" | wc -l | tr -d ' \n')
if [ "$TC6_PAYLOAD_HITS" -ge 1 ] && [ "$TC6_BARE_EVENT_HITS" = "0" ]; then
  pass "Layer 4 cascade-strip audit body uses context.payload.action (payload_hits=$TC6_PAYLOAD_HITS, bare_event_hits=0)"
else
  fail "Layer 4 cascade-strip audit body still has bare context.event.action (payload_hits=$TC6_PAYLOAD_HITS, bare_event_hits=$TC6_BARE_EVENT_HITS)" \
    "Issue #439 P2: Layer 4 fires BEFORE Layer 5 in workflow order; bare context.event.action at L337 throws TypeError on PR opened events, breaking label-check for ALL non-docs PRs (PR #438 first victim ×5 FAILURE). Same canonical fix as Issue #436."
fi

# ============================================================================
# T7 (Issue #441 P0 regression anchor): audit body lines have balanced
# template-literal backticks. Catches the L337 regression that PR #438 hotfix
# introduced (missing outer-close backtick before trailing comma →
# SyntaxError on pull_request_target audit body construction).
#
# Per Issue #441 §Required fix AC2: backtick-balance anchor check on L337, L476,
# L517. Each Trigger line is a template literal: 1 outer-open + 6 escaped pairs
# (3 inner markdown code spans) + 1 outer-close = 2 unescaped + 6 escaped.
#
# Sister regression anchor to TC5/TC6: content-anchor grep catches the symptom
# (context.event.action gone, context.payload.action present) but NOT the
# iatrogenic syntax error introduced by the fix itself. Behavioral test
# (Issue #440 d050b, Sprint 12 P0 promotion) catches BOTH via JS execution;
# TC7 catches the structural balance pre-execution (lighter weight, hotfix-safe).
# ============================================================================
section "T7 (Issue #441 P0): audit body Trigger lines have balanced template-literal backticks"
EXPECTED_ESCAPED=6
EXPECTED_UNESCAPED=2
TRIGGER_LINES=(337 476 517)
TC7_FAILED=0
TC7_OK=0
for line_num in "${TRIGGER_LINES[@]}"; do
  # Use Python to do reliable backslash+backtick counting (bash backtick handling is fragile).
  read -r escaped unescaped total <<< "$(python3 -c "
with open('$WORKFLOW') as f:
    lines = f.readlines()
line = lines[${line_num} - 1]
escaped = line.count('\\\\\`')
total_bt = line.count('\`')
unescaped = total_bt - escaped
print(escaped, unescaped, total_bt)
")"
  if [ "$escaped" = "$EXPECTED_ESCAPED" ] && [ "$unescaped" = "$EXPECTED_UNESCAPED" ]; then
    pass "L${line_num} backtick balance OK (escaped=$escaped, unescaped=$unescaped, total=$total)"
    TC7_OK=$((TC7_OK + 1))
  else
    fail "L${line_num} backtick imbalance (escaped=$escaped, unescaped=$unescaped, total=$total, expected: escaped=$EXPECTED_ESCAPED unescaped=$EXPECTED_UNESCAPED)" \
      "Issue #441 P0 regression anchor: audit body Trigger lines must be balanced template literals. Expected: 1 outer-open + 6 escaped pairs (3 inner) + 1 outer-close = 2 unescaped + 6 escaped. L337 regression: missing outer-close backtick before trailing comma → JS SyntaxError 'Unexpected token **' on pull_request_target eval."
    TC7_FAILED=$((TC7_FAILED + 1))
  fi
done
# Summary note for TC7 (pass/fail counters already incremented by pass/fail helpers)
if [ "$TC7_OK" -eq "${#TRIGGER_LINES[@]}" ]; then
  :  # all good
fi

# ============================================================================
# T8 (Issue #448 P0 regression anchor): Layer 5 success block uses the
# addLabels (PLURAL) Octokit method with array param shape (labels: [...]).
#
# Per Issue #448 RCA: github.rest.issues.addLabel (singular) is not a
# function — it does not exist in the @actions/github Octokit library.
# The correct method is github.rest.issues.addLabels (PLURAL). Additionally,
# the param shape must be `labels: ['name']` (array), not `name: 'name'`
# (singular), per the REST API spec for POST /repos/{owner}/{repo}/issues/
# {issue_number}/labels (which expects a labels array in the body).
#
# Atomic-flip-trigger manifestation: rapid removeLabel + addLabel sequence
# hits the broken API call BEFORE the if-guard can short-circuit. Re-evaluation
# path (single labeled event) hits the guard FIRST and skips the broken call.
#
# Sister-pattern to TC7: lighter-weight static anchor. d050b (Sprint 12 P0)
# is the long-term behavioral safety net for the CLASS of bug.
# ============================================================================
section "T8 (Issue #448 P0): Layer 5 addLabels (plural) method + array param shape"
# Extract Layer 5 region (after L370) to focus on the success block.
LAYER5_REGION="$(tail -n +370 "$WORKFLOW")"
read -r TC8_SINGULAR_METHOD TC8_PLURAL_METHOD TC8_LABELS_ARRAY TC8_NAME_SINGULAR <<< "$(python3 -c "
import re
region = open('$WORKFLOW').read().split('\n')[369:]
region_str = '\n'.join(region)
# Use leading-dot anchor to match only API calls (e.g., github.rest.issues.addLabel()
# NOT text mentions in comments like '// then addLabel(\\'status:ready\\')')
singular_method = len(re.findall(r'\.addLabel\(', region_str))
plural_method = len(re.findall(r'\.addLabels\(', region_str))
# Line-scoped param shape check: only inspect lines containing addLabels( call.
# removeLabel() legitimately uses name: 'status:ready' (single-label removal API),
# so we MUST scope the param check to addLabels( call lines only.
# Pre-fix state note (arch 🟡 OBS): addlabels_call_lines IS EMPTY pre-fix
# because the workflow still calls addLabel (singular), not addLabels (plural).
# This is INTENTIONAL — TC8 fails pre-fix via the singular_method count, NOT
# via the param shape check. Post-fix, addlabels_call_lines has 1 entry and
# labels_array_correct=name_singular_wrong=both checked. The empty-list iteration
# via any(...) returns False for both, contributing to the FAIL signal.
addlabels_call_lines = [l for l in region if '.addLabels(' in l]
labels_array_correct = any(re.search(r'labels:\s*\[', l) for l in addlabels_call_lines)
name_singular_wrong = any(re.search(r\"name:\s*['\\\"]status:ready['\\\"]\", l) for l in addlabels_call_lines)
print(singular_method, plural_method, int(labels_array_correct), int(name_singular_wrong))
")"
if [ "$TC8_SINGULAR_METHOD" = "0" ] && [ "$TC8_PLURAL_METHOD" -ge 1 ] && [ "$TC8_LABELS_ARRAY" = "1" ] && [ "$TC8_NAME_SINGULAR" = "0" ]; then
  pass "Layer 5 addLabels API correct (singular_method=$TC8_SINGULAR_METHOD, plural_method=$TC8_PLURAL_METHOD, labels_array=$TC8_LABELS_ARRAY, name_singular=$TC8_NAME_SINGULAR)"
else
  fail "Layer 5 addLabels API broken (singular_method=$TC8_SINGULAR_METHOD, plural_method=$TC8_PLURAL_METHOD, labels_array=$TC8_LABELS_ARRAY, name_singular=$TC8_NAME_SINGULAR)" \
    "Issue #448 P0: github.rest.issues.addLabel (singular) is not a function. Correct Octokit method is addLabels (plural) with array param shape labels: ['status:ready'] (NOT name: 'status:ready'). Atomic-flip-trigger TypeError breaks label-check for all PRs hitting the rapid removeLabel + addLabel sequence."
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
echo "  Reference: ADR-0012 §Cascade-strip scope-tightening Part 2 (PR #418 + PR #424),"
echo "             Issue #425 (this d-test tracker), Issue #423 (Part 1 sister),"
echo "             PR #393 (canonical case), ADR-0021 (docs PR convention),"
echo "             ADR-0044 (TDD red-first doctrine),"
echo "             Issue #441 (TC7 sister-pattern to TC5/TC6, regression anchor),"
echo "             Issue #448 (TC8 sister-pattern to TC7, addLabels API regression anchor)."
echo "  Sister regressions: d046-peer-poke-canonical-parity.sh (PR #405 MERGED)."
exit 0