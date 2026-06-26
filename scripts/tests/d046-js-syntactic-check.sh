#!/usr/bin/env bash
# d046-js-syntactic-check.sh — D046 family extension: node --check on
# actions/github-script snippets in .github/workflows/*.yml
#
# Why this test exists
# --------------------
# Per ADR-0049 amendment (PR #454, Issue #444, TD-031 follow-up): 9-Lens
# sub-check (k) JS syntactic correctness requires edit-time static check on
# github-script snippets. This d-test is the **automated runtime version**
# of lens (k) — catches typos (missing backticks, unclosed template
# literals, unbalanced parens, syntax errors that YAML linters miss).
#
# Sister-pattern to:
#   - d046-expansion-adr-0044-literal-form.sh (ADR-0046 §A literal-form guard)
#   - d046-peer-poke-canonical-parity.sh (peer-poke helper)
#   - d048-adr-0012-status-ready-gating.sh (TC7 backtick balance, PR #445 sister)
#   - d050b-behavioral-workflow-test.sh (Layer 2 syntactic correctness, NEW per ADR-0049)
#
# 4 TCs across 2 defense layers:
#   Layer 1 (extraction correctness):    TC1 — github-script snippet count matches inventory
#   Layer 2 (node --check correctness): TC2 — every extracted snippet passes node --check
#   Layer 3 (regression anchors):       TC3 — Issue #441 L337 backtick balance preserved
#                                        TC4 — d046 family regression: existing d046 tests still PASS
#
# Author: @tester (Issue #440 AC6/AC7, arch dispatch from PR #454 AC2)
# Refs:   ADR-0049 amendment (PR #454), Issue #444 (TD-031), Issue #440 (AC6/AC7),
#         Issue #441 (L337 backtick P0 regression), ADR-0048 §Live validation,
#         PR #445 (TC7 sister-pattern backtick balance)

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)")"
WORKFLOW_DIR="$REPO_ROOT/.github/workflows"

PASS=0
FAIL=0

# Expected github-script snippet inventory (sourced via grep, not hardcoded)
# Why not hardcoded: this d-test must be self-maintaining as new workflows
# land. The "expected count" is whatever grep finds at test-time.
extract_github_scripts() {
    local wf="$1"
    # awk heuristic: between `script: |` line and end-of-script
    # Output format: "@@LINE_<n>@@" header, then content lines, then "@@END@@" sentinel.
    # Why sentinel: colons in JS content (URLs, ternary, etc) break IFS=: parsing.
    awk '
        function indent(s) { match(s, /[^[:space:]]/); return RSTART - 1 }
        /^[[:space:]]*script:[[:space:]]*\|/ {
            if (in_script) { print "@@END@@" }
            in_script=1
            script_start=NR
            body_indent=-1
            print "@@LINE_" script_start "@@"
            next
        }
        in_script {
            if ($0 ~ /^[[:space:]]*$/) {
                print ""
                next
            }
            line_indent = indent($0)
            if (body_indent < 0) {
                body_indent = line_indent
                print
                next
            }
            if (line_indent < body_indent) {
                print "@@END@@"
                in_script=0
                body_indent=-1
                if ($0 ~ /script:[[:space:]]*\|/) {
                    in_script=1
                    script_start=NR
                    body_indent=-1
                    print "@@LINE_" script_start "@@"
                }
                next
            }
            print
        }
        END {
            if (in_script) { print "@@END@@" }
        }
    ' "$wf"
}

echo "==== TC1 (extraction): github-script snippet inventory across .github/workflows/*.yml ===="
# Find all workflows using actions/github-script
WORKFLOWS_WITH_SCRIPT=$(grep -lE 'actions/github-script' "$WORKFLOW_DIR"/*.yml 2>/dev/null || true)
if [[ -z "$WORKFLOWS_WITH_SCRIPT" ]]; then
    echo "  ✗ FAIL — no workflows use actions/github-script (inventory empty, d-test cannot run)"
    FAIL=$((FAIL+1))
else
    TOTAL_SNIPPETS=0
    EXTRACTED_SNIPPETS=0
    for wf in $WORKFLOWS_WITH_SCRIPT; do
        # Count occurrences of "uses: actions/github-script"
        COUNT=$(grep -cE 'uses: actions/github-script' "$wf")
        TOTAL_SNIPPETS=$((TOTAL_SNIPPETS + COUNT))
        # Count @@LINE_N@@ sentinels in extraction output (one per snippet)
        EXTRACTED=$(extract_github_scripts "$wf" | grep -c '^@@LINE_')
        EXTRACTED_SNIPPETS=$((EXTRACTED_SNIPPETS + EXTRACTED))
    done
    if [[ $TOTAL_SNIPPETS -eq $EXTRACTED_SNIPPETS ]] && [[ $TOTAL_SNIPPETS -gt 0 ]]; then
        echo "  ✓ PASS — $TOTAL_SNIPPETS uses:actions/github-script occurrences matched by $EXTRACTED_SNIPPETS extracted snippets (TC1 Layer 1)"
        PASS=$((PASS+1))
    else
        echo "  ✗ FAIL — uses:actions/github-script count=$TOTAL_SNIPPETS, extracted count=$EXTRACTED_SNIPPETS (extraction heuristic broken)"
        FAIL=$((FAIL+1))
    fi
fi

echo ""
echo "==== TC2 (node --check): every extracted snippet is syntactically valid JS ===="
# Per ADR-0049 amendment rationale: node --check is the edit-time static check
# for lens (k). Catches: missing backticks (Issue #441), unclosed template
# literals, unbalanced parens, syntax errors that YAML linters miss.
if [[ -z "$WORKFLOWS_WITH_SCRIPT" ]]; then
    echo "  ✗ FAIL — no workflows to check (TC2 cannot run)"
    FAIL=$((FAIL+1))
else
    TMPDIR_CHECK=$(mktemp -d)
    trap 'rm -rf "$TMPDIR_CHECK"' EXIT
    SYNTAX_ERRORS_FILE="$TMPDIR_CHECK/errors.txt"
    TOTAL_CHECKED=0
    touch "$SYNTAX_ERRORS_FILE"
    for wf in $WORKFLOWS_WITH_SCRIPT; do
        WF_BASE=$(basename "$wf" .yml)
        CURRENT_LINE=""
        CURRENT_CONTENT=""
        IN_BLOCK=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^@@LINE_([0-9]+)@@$ ]]; then
                CURRENT_LINE="${BASH_REMATCH[1]}"
                CURRENT_CONTENT=""
                IN_BLOCK=1
                continue
            fi
            if [[ "$line" == "@@END@@" ]]; then
                # Flush this snippet to a temp file and node --check it
                if [[ -n "$CURRENT_LINE" ]] && [[ $IN_BLOCK -eq 1 ]]; then
                    TMPJS="$TMPDIR_CHECK/${WF_BASE}_L${CURRENT_LINE}.js"
                    # Pre-process: replace GitHub Actions ${{ ... }} expressions with
                    # JS string placeholder (these are evaluated at workflow time, not JS time)
                    PROCESSED_CONTENT=$(echo "$CURRENT_CONTENT" | sed -E 's/\$\{\{[^}]*\}\}/"GH_ACTION_EXPR"/g')
                    # Wrap in async IIFE so top-level `await` parses (sister-pattern:
                    # github-script runtime is implicitly async)
                    {
                        echo ';(async () => {'
                        echo "$PROCESSED_CONTENT"
                        echo '})();'
                    } > "$TMPJS"
                    if ! node --check "$TMPJS" 2>"$TMPDIR_CHECK/err.txt"; then
                        echo "FAIL $wf:L$CURRENT_LINE" >> "$SYNTAX_ERRORS_FILE"
                        cat "$TMPDIR_CHECK/err.txt" | head -3 | sed 's/^/      /' >> "$SYNTAX_ERRORS_FILE"
                    fi
                    TOTAL_CHECKED=$((TOTAL_CHECKED+1))
                fi
                IN_BLOCK=0
                CURRENT_LINE=""
                CURRENT_CONTENT=""
                continue
            fi
            if [[ $IN_BLOCK -eq 1 ]]; then
                CURRENT_CONTENT="${CURRENT_CONTENT}${line}"$'\n'
            fi
        done < <(extract_github_scripts "$wf")
    done
    SYNTAX_ERRORS=$(wc -l < "$SYNTAX_ERRORS_FILE" 2>/dev/null | tr -d ' ' || echo 0)
    if [[ "${SYNTAX_ERRORS:-0}" -eq 0 ]] && [[ $TOTAL_CHECKED -gt 0 ]]; then
        echo "  ✓ PASS — $TOTAL_CHECKED snippets all pass node --check (TC2 Layer 2)"
        PASS=$((PASS+1))
    elif [[ $TOTAL_CHECKED -eq 0 ]]; then
        echo "  ✗ FAIL — no snippets extracted (TC2 cannot run)"
        FAIL=$((FAIL+1))
    else
        echo "  ✗ FAIL — $SYNTAX_ERRORS of $TOTAL_CHECKED snippets have syntax errors (TC2 Layer 2, lens (k) regression)"
        cat "$SYNTAX_ERRORS_FILE" | head -10 | sed 's/^/    /'
        FAIL=$((FAIL+1))
    fi
fi

echo ""
echo "==== TC3 (Issue #441 regression): label-check.yml audit body closing backtick balanced ===="
# Pre-fix (PR #438-b9aa72d): audit body closing backtick missing → SyntaxError on template-literal evaluation
# Post-fix (PR #445-2854f41): backtick balance verified
# Sister-pattern to d048 TC7 + d050b TC5
LABEL_CHECK="$WORKFLOW_DIR/label-check.yml"
if [[ -f "$LABEL_CHECK" ]]; then
    # Extract audit body sections (between <!-- adr-0012- and -->) and check each has even backtick count
    UNBALANCED=0
    TOTAL_BLOCKS=0
    in_block=0
    BLOCK=""
    while IFS= read -r line; do
        if [[ "$line" =~ \<!--\ adr-0012- ]]; then
            BLOCK=""
            TOTAL_BLOCKS=$((TOTAL_BLOCKS+1))
            in_block=1
            continue
        fi
        if [[ $in_block -eq 1 ]]; then
            if [[ "$line" =~ --\> ]]; then
                BT_COUNT=$(echo -n "$BLOCK" | grep -o '`' | wc -l)
                if [[ $((BT_COUNT % 2)) -ne 0 ]]; then
                    UNBALANCED=$((UNBALANCED+1))
                fi
                in_block=0
                BLOCK=""
            else
                BLOCK="${BLOCK}${line}"$'\n'
            fi
        fi
    done < "$LABEL_CHECK"
    if [[ $UNBALANCED -eq 0 ]] && [[ $TOTAL_BLOCKS -gt 0 ]]; then
        echo "  ✓ PASS — all $TOTAL_BLOCKS audit body blocks have balanced backticks (TC3 Layer 3, Issue #441 regression anchor)"
        PASS=$((PASS+1))
    else
        echo "  ✗ FAIL — $UNBALANCED of $TOTAL_BLOCKS audit body blocks have unbalanced backticks (TC3 Layer 3, Issue #441 regression)"
        FAIL=$((FAIL+1))
    fi
else
    echo "  ✗ FAIL — label-check.yml not found (TC3 cannot run)"
    FAIL=$((FAIL+1))
fi

echo ""
echo "==== TC4 (d046 family regression): existing d046 tests still PASS ===="
# Backstop: this extension must not break sister d046 tests
# Per ARCH 🟡 OBS (PR #457 arch verdict): glob-based discovery + skip-with-warning
# if family is empty, instead of hardcoded array. Excludes self to avoid recursion.
SELF_NAME="$(basename "$0")"
D046_FILES=()
while IFS= read -r f; do
    [[ "$(basename "$f")" == "$SELF_NAME" ]] && continue
    D046_FILES+=("$f")
done < <(find "$REPO_ROOT/scripts/tests" -maxdepth 1 -name 'd046-*.sh' -type f 2>/dev/null | sort)
if [[ ${#D046_FILES[@]} -eq 0 ]]; then
    echo "  ⚠ SKIP — no d046 sister-tests found (TC4 family regression anchor N/A, informational)"
    PASS=$((PASS+1))
    # Continue to summary
elif [[ ${#D046_FILES[@]} -gt 0 ]]; then
    ALL_PRESENT=1
    for f in "${D046_FILES[@]}"; do
        if [[ ! -f "$f" ]]; then
            ALL_PRESENT=0
            echo "    Missing: $f"
        fi
    done
    if [[ $ALL_PRESENT -eq 1 ]]; then
        # Run each d046 test and capture exit code
        PASS_COUNT=0
        for f in "${D046_FILES[@]}"; do
            if bash "$f" >/dev/null 2>&1; then
                PASS_COUNT=$((PASS_COUNT+1))
            fi
        done
        if [[ $PASS_COUNT -eq ${#D046_FILES[@]} ]]; then
            echo "  ✓ PASS — all ${#D046_FILES[@]} d046 sister-tests PASS (TC4 Layer 3, family regression anchor)"
            PASS=$((PASS+1))
        else
            echo "  ✗ FAIL — $PASS_COUNT of ${#D046_FILES[@]} d046 sister-tests PASS (TC4 Layer 3, family regression)"
            FAIL=$((FAIL+1))
        fi
    else
        echo "  ✗ FAIL — d046 sister-test files missing (TC4 Layer 3 cannot run)"
        FAIL=$((FAIL+1))
    fi
fi

echo ""
echo "==== Summary ===="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo ""
echo "Reference: ADR-0049 amendment (PR #454), Issue #444 (TD-031), Issue #440 (AC6/AC7),"
echo "           Issue #441 (L337 backtick P0), ADR-0048 §Live validation,"
echo "           PR #445 (d048 TC7 sister-pattern)."
echo "Sister-pattern: d046-expansion-adr-0044-literal-form.sh,"
echo "                d046-peer-poke-canonical-parity.sh,"
echo "                d048-adr-0012-status-ready-gating.sh (TC7 backtick),"
echo "                d050b-behavioral-workflow-test.sh (Layer 2 syntactic)."

if [[ $FAIL -eq 0 ]]; then
    exit 0
else
    exit 1
fi