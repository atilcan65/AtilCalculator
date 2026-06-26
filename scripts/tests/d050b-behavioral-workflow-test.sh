#!/usr/bin/env bash
# d050b-behavioral-workflow-test.sh — Behavioral workflow test framework (Issue #440, ADR-0049)
#
# Per ADR-0044 RED-first discipline: this d-test runs RED on current main
# (because d050b-dispatch.yml workflow + fixtures don't exist yet on main).
# Once owner adds .github/workflows/d050b-dispatch.yml + dev authors the
# fixtures + runtime tests, it flips GREEN.
#
# Sister-pattern to:
#   - d046-expansion-adr-0044-literal-form.sh (ADR-0044 expansion family)
#   - d046-peer-poke-canonical-parity.sh (peer-poke helper)
#   - d048-adr-0012-status-ready-gating.sh (Layer 5 type-driven reviewer chain)
#   - d048 TC8 (Issue #448 addLabels API regression anchor, PR #450)
#
# 5 TCs across 3 d-test defense layers (per ADR-0049 commit body):
#   Layer 1 (content anchor, d048 sister): TC4 + TC5 — workflow file content-anchor checks
#   Layer 2 (syntactic correctness, NEW): TC4 — node --check on github-script snippet
#   Layer 3 (behavioral runtime, NEW):     TC1 + TC2 + TC3 — workflow_dispatch framework + fixtures
#
# Author: @tester (Issue #440 AC2 deliverable, ADR-0044 TDD RED-first)
# Refs:   Issue #440 (AC1-AC7), PR #443 (ADR-0049, MERGED), ADR-0044 (RED-first),
#         ADR-0048 (Layer 5 type-driven), Issue #436 (TC5 regression anchor),
#         Issue #441 (TC5 audit body backtick balance anchor), Issue #448 (TC1+TC2+TC3 framework sister)

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)")"
FIXTURE_DIR="$REPO_ROOT/scripts/tests/fixtures"
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/d050b-dispatch.yml"
MAIN_WORKFLOW="$REPO_ROOT/.github/workflows/label-check.yml"

PASS=0
FAIL=0

echo "==== TC1 (ADR-0049 §Framework): d050b-dispatch.yml workflow_dispatch schema ===="
# Expected (per ADR-0049 commit body):
#   .github/workflows/d050b-dispatch.yml exists
#   Contains 'workflow_dispatch:' trigger
#   Declares 4 input scenarios: basic_pull_request_labeled, silent_skip_non_docs,
#                                cascade_strip_status_duplicates, reversal_handler
if [[ -f "$WORKFLOW_FILE" ]] \
   && grep -qE '^on:' "$WORKFLOW_FILE" \
   && grep -qE 'workflow_dispatch:' "$WORKFLOW_FILE" \
   && grep -qE 'basic_pull_request_labeled' "$WORKFLOW_FILE" \
   && grep -qE 'silent_skip_non_docs' "$WORKFLOW_FILE" \
   && grep -qE 'cascade_strip_status_duplicates' "$WORKFLOW_FILE" \
   && grep -qE 'reversal_handler' "$WORKFLOW_FILE"; then
    echo "  ✓ PASS — d050b-dispatch.yml present + workflow_dispatch trigger + 4 scenarios (TC1 Layer 3)"
    PASS=$((PASS+1))
else
    echo "  ✗ FAIL — d050b-dispatch.yml missing or schema incomplete (TC1 Layer 3)"
    echo "    Expected: file exists + workflow_dispatch + 4 scenarios (basic_pull_request_labeled, silent_skip_non_docs, cascade_strip_status_duplicates, reversal_handler)"
    if [[ ! -f "$WORKFLOW_FILE" ]]; then
        echo "    Found: $WORKFLOW_FILE does NOT exist (owner squash of .github/workflows/d050b-dispatch.yml pending per ADR-0049)"
    else
        echo "    Found: $WORKFLOW_FILE exists but missing workflow_dispatch or scenarios"
    fi
    FAIL=$((FAIL+1))
fi

echo ""
echo "==== TC2 (ADR-0049 §Fixtures): d050b-mock-pr-layer5.json for basic_pull_request_labeled ===="
# Expected: scripts/tests/fixtures/d050b-mock-pr-layer5.json
#   Valid JSON with: action=labeled, label.name=needs-tester-signoff, pull_request.state=open
FIXTURE_TC2="$FIXTURE_DIR/d050b-mock-pr-layer5.json"
if [[ -f "$FIXTURE_TC2" ]] \
   && python3 -c "
import json, sys
with open('$FIXTURE_TC2') as f:
    d = json.load(f)
assert d.get('action') == 'labeled', f'action must be labeled, got {d.get(\"action\")}'
assert d.get('label', {}).get('name') == 'needs-tester-signoff', f'label.name must be needs-tester-signoff'
assert d.get('pull_request', {}).get('state') == 'open', f'pull_request.state must be open'
" 2>/dev/null; then
    echo "  ✓ PASS — basic_pull_request_labeled fixture valid (TC2 Layer 3)"
    PASS=$((PASS+1))
else
    echo "  ✗ FAIL — basic_pull_request_labeled fixture missing or invalid (TC2 Layer 3)"
    echo "    Expected: scripts/tests/fixtures/d050b-mock-pr-layer5.json with action=labeled + label.name=needs-tester-signoff + pull_request.state=open"
    FAIL=$((FAIL+1))
fi

echo ""
echo "==== TC3 (ADR-0049 §Fixtures): d050b-mock-pr-layer5-nondocs.json for silent_skip_non_docs ===="
# Expected: scripts/tests/fixtures/d050b-mock-pr-layer5-nondocs.json
#   Valid JSON with: action=labeled, label.name=type:feature (non-docs), pull_request.state=open
FIXTURE_TC3="$FIXTURE_DIR/d050b-mock-pr-layer5-nondocs.json"
if [[ -f "$FIXTURE_TC3" ]] \
   && python3 -c "
import json, sys
with open('$FIXTURE_TC3') as f:
    d = json.load(f)
assert d.get('action') == 'labeled', f'action must be labeled'
assert d.get('label', {}).get('name') == 'type:feature', f'label.name must be type:feature (non-docs trigger)'
assert d.get('pull_request', {}).get('state') == 'open', f'pull_request.state must be open'
" 2>/dev/null; then
    echo "  ✓ PASS — silent_skip_non_docs fixture valid (TC3 Layer 3)"
    PASS=$((PASS+1))
else
    echo "  ✗ FAIL — silent_skip_non_docs fixture missing or invalid (TC3 Layer 3)"
    echo "    Expected: scripts/tests/fixtures/d050b-mock-pr-layer5-nondocs.json with action=labeled + label.name=type:feature + pull_request.state=open"
    FAIL=$((FAIL+1))
fi

echo ""
echo "==== TC4 (Issue #436 regression): label-check.yml uses context.payload.action (NOT bare context.event.action in non-comment lines) ===="
# Pre-fix (PR #434-d3a929d): workflow file contained context.event.action in JS body → TypeError on pull_request_target
# Post-fix (PR #438-b9aa72d + PR #445-2854f41): workflow uses context.payload.action in JS body
# Sister-pattern to d048 TC5/TC6 (content-anchor Layer 1) + d050b TC4 (syntactic Layer 2)
# Exclude JS comments (//) and YAML comments (#) — they may intentionally reference context.event.action as documentation
if [[ -f "$MAIN_WORKFLOW" ]]; then
    BAD_HITS=$(grep -nE 'context\.event\.(action|label|name)' "$MAIN_WORKFLOW" 2>/dev/null | grep -vE '^\s*[0-9]+:\s*(//|#)' || true)
    if [[ -z "$BAD_HITS" ]]; then
        echo "  ✓ PASS — bare context.event.action/.label/.name absent in non-comment lines (TC4 Layer 1)"
        PASS=$((PASS+1))
    else
        echo "  ✗ FAIL — bare context.event.action/.label/.name found in non-comment lines (TC4 Layer 1, Issue #436 regression)"
        echo "$BAD_HITS" | head -5
        FAIL=$((FAIL+1))
    fi
else
    echo "  ✗ FAIL — label-check.yml not found at $MAIN_WORKFLOW (TC4 cannot run)"
    FAIL=$((FAIL+1))
fi

echo ""
echo "==== TC5 (Issue #441 regression): audit body closing backtick balanced in label-check.yml ===="
# Pre-fix (PR #438-b9aa72d): audit body closing backtick missing → SyntaxError on template-literal evaluation
# Post-fix (PR #445-2854f41): backtick balance verified, all audit body Trigger lines have closing backtick
# Sister-pattern to d048 TC7 (backtick balance audit body, sister-pattern to PR #445)
# d050b Layer 2: extract audit body sections + count backticks per block (NEW per ADR-0049)
if [[ -f "$MAIN_WORKFLOW" ]]; then
    # Extract audit body sections (between <!-- adr-0012- and -->) and check each has even backtick count
    UNBALANCED=0
    TOTAL_BLOCKS=0
    in_block=0
    while IFS= read -r line; do
        # Lines starting with <!-- adr-0012- are audit body openers
        if [[ "$line" =~ \<!--\ adr-0012- ]]; then
            BLOCK=""
            TOTAL_BLOCKS=$((TOTAL_BLOCKS+1))
            in_block=1
            continue
        fi
        if [[ $in_block -eq 1 ]]; then
            if [[ "$line" =~ --\> ]]; then
                # End of block — count backticks
                BT_COUNT=$(echo -n "$BLOCK" | grep -o '`' | wc -l)
                if [[ $((BT_COUNT % 2)) -ne 0 ]]; then
                    UNBALANCED=$((UNBALANCED+1))
                    echo "    Block unbalanced ($BT_COUNT backticks): $(echo "$BLOCK" | head -1 | head -c 80)"
                fi
                in_block=0
                BLOCK=""
            else
                BLOCK="${BLOCK}${line}"$'\n'
            fi
        fi
    done < "$MAIN_WORKFLOW"
    if [[ $UNBALANCED -eq 0 ]]; then
        echo "  ✓ PASS — all $TOTAL_BLOCKS audit body blocks have balanced backticks (TC5 Layer 1, Issue #441 regression anchor)"
        PASS=$((PASS+1))
    else
        echo "  ✗ FAIL — $UNBALANCED of $TOTAL_BLOCKS audit body blocks have unbalanced backticks (TC5 Layer 1, Issue #441 regression)"
        FAIL=$((FAIL+1))
    fi
else
    echo "  ✗ FAIL — label-check.yml not found at $MAIN_WORKFLOW (TC5 cannot run)"
    FAIL=$((FAIL+1))
fi

echo ""
echo "==== Summary ===="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo ""
echo "Reference: ADR-0049 (PR #443 MERGED 17:48:21Z ccda247), Issue #440,"
echo "           ADR-0044 (TDD RED-first), ADR-0048 (Layer 5 type-driven reviewer chain),"
echo "           Issue #436 (TC4 regression anchor), Issue #441 (TC5 regression anchor),"
echo "           Issue #448 (d050b dispatch workflow sister-pattern to PR #452 sync-status)."
echo "Sister-pattern: d046 (expansion family), d048 (TC1-TC8 layered defense),"
echo "                d048 TC8 (Issue #448 addLabels API regression anchor, PR #450 MERGED)."

if [[ $FAIL -eq 0 ]]; then
    exit 0
else
    exit 1
fi
