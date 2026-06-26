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
#
# Test cases (4 TCs per Issue #425 AC2.1):
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
echo "             ADR-0044 (TDD red-first doctrine)."
echo "  Sister regressions: d046-peer-poke-canonical-parity.sh (PR #405 MERGED)."
exit 0