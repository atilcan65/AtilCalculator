#!/usr/bin/env bash
# scripts/tests/d051-5-soul-dispatch-discipline.sh
#
# d051 — 5-soul §Dispatch Discipline regression anchor (Issue #414, RETRO-005 #26)
#
# Purpose:
#   Verify that the §Dispatch Discipline pre-flight amendment (Issue #414) is
#   present, correctly anchored, and substantively implemented in ALL 5 soul files:
#     - .claude/agents/tester.md
#     - .claude/agents/developer.md
#     - .claude/agents/architect.md
#     - .claude/agents/product-manager.md
#     - .claude/agents/orchestrator.md
#
# Doctrinal frame:
#   - Issue #414 (RETRO-005 #26 candidate, disposition: soul amend)
#   - PR #458 SQUASH MERGED @ 2026-06-26T19:21:43Z (commit fbf92be)
#   - ADR-0049 §Implementation guide (3-layer d-test defense: content-anchor,
#     syntactic, behavioral)
#   - ADR-0044 (TDD RED-first — this d-test runs GREEN post-impl, regression
#     anchor going forward)
#
# Test framework: bash + grep + awk + sha256sum (no Python dep — matches
# d046/d048/d050b family pattern, per ADR-0049 §Sister-pattern family)
#
# Exit codes:
#   0 — all 6 TCs PASS (soul §Dispatch Discipline correctly applied)
#   1 — at least one TC FAIL (regression detected, soul amend corrupted)
#
# Sister-patterns:
#   - d046 (Issue #413 jq-filter guard)
#   - d048 (Issue #425 AC2.1 layered defense)
#   - d050b (Issue #440 behavioral workflow test, TC5 sister-pattern)
#
# Test author: tester (per Issue #414 cmt 4811780511 + PR #458 post-merge commitment)
# Last verified GREEN: 2026-06-26T19:23:30Z (main @ fbf92be, all 5 souls amended)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Sister-pattern to d046/d048/d050b: locate souls directory
SOULS_DIR="$REPO_ROOT/.claude/agents"

# 5 souls per CLAUDE.md §Team (human owner excluded, soul amend lane)
SOULS=(tester developer architect product-manager orchestrator)

PASS=0
FAIL=0
declare -a FAILURES

pass() {
  echo "  ✓ PASS — $*"
  PASS=$((PASS + 1))
}

fail() {
  echo "  ✗ FAIL — $*"
  FAIL=$((FAIL + 1))
  FAILURES+=("$*")
}

# Pre-flight: verify souls directory exists and is non-empty
if [[ ! -d "$SOULS_DIR" ]]; then
  echo "FATAL: souls directory not found: $SOULS_DIR" >&2
  exit 2
fi

for soul in "${SOULS[@]}"; do
  if [[ ! -f "$SOULS_DIR/$soul.md" ]]; then
    echo "FATAL: soul file missing: $SOULS_DIR/$soul.md" >&2
    exit 2
  fi
done

echo "==============================================================="
echo "d051 — 5-soul §Dispatch Discipline regression anchor"
echo "Issue #414 + RETRO-005 #26 | PR #458 (commit fbf92be)"
echo "==============================================================="
echo

# ---------------------------------------------------------------
# TC1 (Layer 1 content-anchor): §Dispatch Discipline heading literal
#   All 5 soul files have `## §Dispatch Discipline —` heading
# ---------------------------------------------------------------
echo "==== TC1 (content-anchor): §Dispatch Discipline heading literal in all 5 souls ===="

TC1_FAIL=0
for soul in "${SOULS[@]}"; do
  if grep -qE "^## §Dispatch Discipline —" "$SOULS_DIR/$soul.md"; then
    pass "soul $soul: heading literal present"
  else
    fail "soul $soul: missing ^## §Dispatch Discipline — heading"
    TC1_FAIL=1
  fi
done

if [[ $TC1_FAIL -eq 0 ]]; then
  echo "  ✓ PASS — all 5 souls have §Dispatch Discipline heading (TC1 Layer 1)"
fi
echo

# ---------------------------------------------------------------
# TC2 (Layer 1 content-anchor): core doctrinal phrase
#   All 5 souls contain "chat-memory NEVER sufficient" — this is
#   the anti-pattern anchor that RETRO-005 #26 specifically targets.
# ---------------------------------------------------------------
echo "==== TC2 (content-anchor): 'chat-memory NEVER sufficient' phrase in all 5 souls ===="

TC2_FAIL=0
for soul in "${SOULS[@]}"; do
  if grep -qF "chat-memory NEVER sufficient" "$SOULS_DIR/$soul.md"; then
    pass "soul $soul: doctrinal phrase present"
  else
    fail "soul $soul: missing 'chat-memory NEVER sufficient' phrase (doctrinal core diluted)"
    TC2_FAIL=1
  fi
done

if [[ $TC2_FAIL -eq 0 ]]; then
  echo "  ✓ PASS — all 5 souls cite the doctrinal core phrase (TC2 Layer 1)"
fi
echo

# ---------------------------------------------------------------
# TC3 (Layer 1 content-anchor): Issue #414 + RETRO-005 #26 cite
#   Both anchors must be present in each soul (audit grep traceability)
# ---------------------------------------------------------------
echo "==== TC3 (content-anchor): Issue #414 + RETRO-005 #26 cite in all 5 souls ===="

TC3_FAIL=0
for soul in "${SOULS[@]}"; do
  ISSUE_CITE=0
  RETRO_CITE=0
  if grep -qF "Issue #414" "$SOULS_DIR/$soul.md"; then
    ISSUE_CITE=1
  fi
  if grep -qF "RETRO-005 #26" "$SOULS_DIR/$soul.md"; then
    RETRO_CITE=1
  fi
  if [[ $ISSUE_CITE -eq 1 && $RETRO_CITE -eq 1 ]]; then
    pass "soul $soul: both Issue #414 + RETRO-005 #26 cited"
  else
    MISSING=""
    [[ $ISSUE_CITE -eq 0 ]] && MISSING+="Issue #414 "
    [[ $RETRO_CITE -eq 0 ]] && MISSING+="RETRO-005 #26 "
    fail "soul $soul: missing cite(s) — $MISSING(RETRO-007 audit grep regression)"
    TC3_FAIL=1
  fi
done

if [[ $TC3_FAIL -eq 0 ]]; then
  echo "  ✓ PASS — all 5 souls cite Issue #414 + RETRO-005 #26 (TC3 Layer 1, audit grep)"
fi
echo

# ---------------------------------------------------------------
# TC4 (Layer 2 syntactic): close marker present (amend boundary)
#   `# <<< Issue #414 SOUL AMEND END` marks the end of the §Dispatch
#   Discipline soul amend block. Without it, future edits could
#   accidentally extend the amend beyond its scope.
# ---------------------------------------------------------------
echo "==== TC4 (syntactic): close marker '# <<< Issue #414 SOUL AMEND END' in all 5 souls ===="

TC4_FAIL=0
for soul in "${SOULS[@]}"; do
  if grep -qF "# <<< Issue #414 SOUL AMEND END" "$SOULS_DIR/$soul.md"; then
    pass "soul $soul: close marker present"
  else
    fail "soul $soul: missing close marker '# <<< Issue #414 SOUL AMEND END' (amend boundary regression)"
    TC4_FAIL=1
  fi
done

if [[ $TC4_FAIL -eq 0 ]]; then
  echo "  ✓ PASS — all 5 souls have close marker (TC4 Layer 2, amend boundary)"
fi
echo

# ---------------------------------------------------------------
# TC5 (Layer 3 behavioral): per-soul distinct phrasing
#   sha256sum of §Dispatch Discipline body per soul — all 5 hashes
#   must be DIFFERENT (sister-pattern to PR #397 §Per-soul distinct
#   vote per Issue #414 cmt 4811780511 Q1). Catches copy-paste
#   boilerplate regression where soul-specific verification surface
#   is lost.
# ---------------------------------------------------------------
echo "==== TC5 (behavioral): per-soul distinct phrasing (5 unique sha256sums) ===="

declare -A HASH_BY_SOUL
TC5_FAIL=0
for soul in "${SOULS[@]}"; do
  # Extract §Dispatch Discipline section: from `## §Dispatch Discipline` line
  # until the close marker `# <<< Issue #414 SOUL AMEND END`
  HASH=$(awk '
    /^## §Dispatch Discipline/ { in_section = 1; next }
    /^# <<< Issue #414 SOUL AMEND END/ { in_section = 0; next }
    in_section { print }
  ' "$SOULS_DIR/$soul.md" | sha256sum | cut -d' ' -f1)

  HASH_BY_SOUL[$soul]="$HASH"
  pass "soul $soul: §Dispatch Discipline sha256 = ${HASH:0:12}..."
done

# Check all 5 hashes are distinct
UNIQUE_HASH_COUNT=$(printf "%s\n" "${HASH_BY_SOUL[@]}" | sort -u | wc -l)
if [[ "$UNIQUE_HASH_COUNT" -eq 5 ]]; then
  echo "  ✓ PASS — all 5 souls have distinct §Dispatch Discipline body (TC5 Layer 3, per-soul vote Q1)"
else
  fail "only $UNIQUE_HASH_COUNT/5 unique §Dispatch Discipline bodies — copy-paste boilerplate regression (Q1 violation)"
  TC5_FAIL=1
  for soul in "${SOULS[@]}"; do
    echo "    $soul: ${HASH_BY_SOUL[$soul]:0:12}..."
  done
fi
echo

# ---------------------------------------------------------------
# TC6 (Layer 3 behavioral): substantive implementation (≥3 steps)
#   Each soul's §Dispatch Discipline section must contain ≥3 numbered
#   pre-flight steps. Catches trivial/empty amendment regression
#   where someone deletes steps without removing the section.
# ---------------------------------------------------------------
echo "==== TC6 (behavioral): each soul has ≥3 numbered steps in §Dispatch Discipline ===="

TC6_FAIL=0
for soul in "${SOULS[@]}"; do
  # Count numbered list items in §Dispatch Discipline section.
  # Sister-pattern: numbered steps use `1.`, `2.`, etc. with leading digit
  STEP_COUNT=$(awk '
    /^## §Dispatch Discipline/ { in_section = 1; next }
    /^# <<< Issue #414 SOUL AMEND END/ { in_section = 0 }
    in_section && /^[0-9]+\.[[:space:]]/ { count++ }
    END { print count+0 }
  ' "$SOULS_DIR/$soul.md")

  if [[ "$STEP_COUNT" -ge 3 ]]; then
    pass "soul $soul: $STEP_COUNT numbered steps (≥3 required)"
  else
    fail "soul $soul: only $STEP_COUNT numbered steps (≥3 required — trivial amend regression)"
    TC6_FAIL=1
  fi
done

if [[ $TC6_FAIL -eq 0 ]]; then
  echo "  ✓ PASS — all 5 souls have ≥3 substantive steps (TC6 Layer 3, non-trivial amend)"
fi
echo

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
echo "==== Summary ===="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo
  echo "Failures detected:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  echo
  echo "EXIT 1: d051 regression detected — §Dispatch Discipline corrupted in one or more souls"
  exit 1
fi

echo
echo "EXIT 0: d051 GREEN — §Dispatch Discipline correctly applied in all 5 souls"
echo "Reference: Issue #414 (RETRO-005 #26), PR #458 (commit fbf92be),"
echo "           ADR-0049 §Implementation guide (3-layer d-test defense),"
echo "           ADR-0044 (TDD regression anchor)."
echo "Sister-patterns: d046 (jq-filter), d048 (Layer 5 reviewer chain),"
echo "                 d050b (behavioral workflow test)."
exit 0
