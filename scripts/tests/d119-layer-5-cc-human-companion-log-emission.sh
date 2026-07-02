#!/usr/bin/env bash
# d119-layer-5-cc-human-companion-log-emission.sh — Layer 5 cc:human companion-add log emission regression guard
#
# Why this test exists
# --------------------
# Issues #568 + #569 (PICKUP-156, captured 2026-06-27T22:38+03:00 per orchestrator,
# source: PR #565 arch verdict 🟡 suggestion #2 (cmt 4822488329) + suggestion #3):
#
#   Issue #569: When Layer 5 cc:human companion-add guard fires (re-add cc:human
#               on status:ready auto-add per ADR-0012 4-cat invariant), the action
#               is silent (no log emission). Per ADR-0045 lens d (debuggability)
#               + ADR-0056 sister-pattern (WARN-not-FAIL), silent-skip should emit
#               a structured warn/log.
#
#   Issue #568: The same companion-add does not emit a structured audit log per
#               ADR-0045 lens f (observability). Should emit actor + PR + timestamp
#               trail searchable via GitHub Actions logs grep.
#
# Threshold change (label-check.yml lines ~700-715):
#   PRE-FIX:  const labelsToAdd = ['status:ready'];
#             if (!hasLabel('cc:human')) {
#               labelsToAdd.push('cc:human');
#             }
#             // NO log emission when companion-add fires (silent-skip class)
#
#   POST-FIX: const labelsToAdd = ['status:ready'];
#             if (!hasLabel('cc:human')) {
#               core.warning(`[Layer 5] cc:human companion-add fired for PR #${number} (ADR-0045 lens d, ADR-0056 sister-pattern)`);
#               labelsToAdd.push('cc:human');
#               console.log(`[Layer 5 audit] cc:human companion-add: PR=#${number} actor=${context.sender?.login || 'unknown'} ts=${new Date().toISOString()} (ADR-0045 lens f audit trail)`);
#             }
#
# 5 TCs (≥3 baseline per ADR-0049 d-test framework sister-pattern):
#   TC1: preflight — .github/workflows/label-check.yml exists + readable + tooling available
#   TC2: AC1 — source contains `core.warning` emission near cc:human companion-add
#        block (Issue #569 silent-skip fail-loud per ADR-0056 sister-pattern)
#   TC3: AC2 — source contains structured `console.log` audit trail near companion-add
#        block (Issue #568 lens f observability)
#   TC4: AC3 — log emission is INSIDE `if (!hasLabel('cc:human'))` block, not orphaned
#        outside (d077 structural guard sister-pattern)
#   TC5: AC4 — log emission message mentions PR number (sister-pattern d109/d112/d118
#        context-aware "must contain PR# context")
#
# Sister-pattern:
#   - d069 (Layer 5 verdict-emoji gate — audit trail pattern sister)
#   - d076 (label-check state filter — regression guard baseline)
#   - d077 (Layer 5 misfire regression — orphan-guard sister for TC4)
#   - d109 (env-block regression guard — sister-pattern for TC5 "must contain PR# context")
#   - d118 (Issue #707 hysteresis — sister context-aware d-test pattern)
#
# Pre-impl RED state (main HEAD 38001b1 — log emission NOT yet added):
#   - TC1 PASS (label-check.yml exists)
#   - TC2 FAIL (no `core.warning` near cc:human companion-add block)
#   - TC3 FAIL (no `console.log` audit trail near companion-add block)
#   - TC4 PASS (companion-add block exists; just no log emission inside)
#   - TC5 FAIL (no PR number reference in log emission message — block doesn't exist)
#   → 2/5 PASS + 3/5 FAIL = proper RED-first per ADR-0044 (≥50% FAIL)
#
# Post-impl GREEN state (after Issue #569+#568 fix lands):
#   - All 5 TCs PASS
#   → 5/5 PASS in GREEN state.
#
# Usage:
#   bash d119-layer-5-cc-human-companion-log-emission.sh --self-test
#
# Exit codes:
#   0 — all 5 PASS (GREEN state — log emission landed)
#   1 — at least one FAIL (RED state — silent-skip class intact)
#   2 — preflight failure

set -uo pipefail

# Disable glob expansion (noglob) so fail()/pass() messages containing
# `*` (regex glob chars) are not interpreted.
set -f

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LABEL_CHECK="${REPO_ROOT}/.github/workflows/label-check.yml"

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

# Preflight (ADR-0049 sister-pattern — preflight checks first)
command -v awk >/dev/null 2>&1 || { echo "ERROR: awk required for source inspection" >&2; exit 2; }
command -v sed >/dev/null 2>&1 || { echo "ERROR: sed required for source inspection" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required for source inspection" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d119 self-test (5 TCs per Issue #569 + #568 + ADR-0044 RED-first)${D}\n"
printf "${B}================================================================${D}\n"
printf "  Repo root:        %s\n" "$REPO_ROOT"
printf "  label-check.yml:  %s\n" "$LABEL_CHECK"
printf "  Sister-pattern:   d069 (Layer 5 verdict-emoji gate) + d076 (state filter) + d077 (misfire regression orphan-guard) + d109 (env-block regression) + d118 (Issue #707 hysteresis context-aware)\n"
printf "  Pre-impl RED:     TC2 + TC3 + TC5 FAIL by design per ADR-0044 (≥50%% RED)\n"
printf "  Post-impl:        all 5 TCs must PASS\n\n"

EXIT_CODE=0

# ============================================================================
# TC1: preflight — label-check.yml exists + readable
# ============================================================================
section "TC1: AC1 preflight — label-check.yml exists + readable + tooling available"

if [ -f "$LABEL_CHECK" ]; then
  if [ -r "$LABEL_CHECK" ]; then
    pass "TC1 — label-check.yml exists at $LABEL_CHECK and is readable"
  else
    fail "TC1 — label-check.yml exists but is NOT readable"
    EXIT_CODE=1
  fi
else
  fail "TC1 — label-check.yml missing"
  section "TC2-TC5: SKIPPED (TC1 prerequisite not met)"
  FAIL=$((FAIL + 4))
  EXIT_CODE=1
  printf "\n${B}==== Summary ====${D}\n"
  printf "  PASS: %d\n" "$PASS"
  printf "  FAIL: %d\n" "$FAIL"
  printf "  INFO: %d\n" "$INFO"
  printf "\n${R}RED state: label-check.yml not present${D}\n"
  exit 1
fi

# Extract the cc:human companion-add block region: 30-line window after
# `// Issue #564 §32 LIVE INSTANCE #8: status:ready auto-add MUST also add cc:human`
START_LINE="$(grep -n "Issue #564.*LIVE INSTANCE #8.*status:ready auto-add MUST also add cc:human" "$LABEL_CHECK" | head -1 | cut -d: -f1)"
if [ -z "$START_LINE" ]; then
  fail "internal — could not locate cc:human companion-add marker in label-check.yml"
  EXIT_CODE=1
  BLOCK_FOUND=false
else
  BLOCK_FOUND=true
  # Extract a 25-line window starting from the marker comment
  COMPANION_BLOCK="$(sed -n "${START_LINE},$((START_LINE + 24))p" "$LABEL_CHECK")"
  info "cc:human companion-add block region: lines ${START_LINE}-$((START_LINE + 24))"
fi

# ============================================================================
# TC2: AC1 — source contains `core.warning` near cc:human companion-add (Issue #569)
# ============================================================================
section "TC2: AC1 — core.warning emission present near cc:human companion-add block (Issue #569 silent-skip fail-loud)"

# Per Issue #569 (PICKUP-156, ADR-0045 lens d + ADR-0056 sister-pattern): the
# cc:human companion-add must emit `core.warning` (NOT just `core.info` — per
# ADR-0056 §Layer 5 cascade contract WARN-not-FAIL).
if [ "$BLOCK_FOUND" = "true" ]; then
  if echo "$COMPANION_BLOCK" | grep -qE 'core\.warning.*cc:human.*companion-add'; then
    pass "TC2 — source contains \`core.warning\` emission near cc:human companion-add block (Issue #569 silent-skip fail-loud satisfied)"
  else
    fail "TC2 — source does NOT contain \`core.warning\` emission near cc:human companion-add block" \
      "expected \`core.warning(\`...[Layer 5] cc:human companion-add fired for PR #\` within the companion-add block. Per Issue #569 (ADR-0045 lens d silent-skip debuggability + ADR-0056 sister-pattern), the companion-add is currently silent-skip — operator cannot detect when it fires. RED-first confirmed."
    EXIT_CODE=1
  fi
else
  fail "TC2 — could not extract cc:human companion-add block (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# TC3: AC2 — source contains structured `console.log` audit trail (Issue #568)
# ============================================================================
section "TC3: AC2 — console.log audit trail present near cc:human companion-add block (Issue #568 lens f observability)"

# Per Issue #568 (PICKUP-156, ADR-0045 lens f observability): the companion-add
# must emit a structured audit trail with PR number + actor + ISO timestamp.
if [ "$BLOCK_FOUND" = "true" ]; then
  if echo "$COMPANION_BLOCK" | grep -qE 'console\.log.*\[Layer 5 audit\].*cc:human.*companion-add.*PR=#.*actor=.*ts='; then
    pass "TC3 — source contains structured \`console.log\` audit trail (PR=# + actor + ts=) per Issue #568 lens f"
  else
    fail "TC3 — source does NOT contain structured \`console.log\` audit trail near cc:human companion-add block" \
      "expected \`console.log(\`...[Layer 5 audit] cc:human companion-add: PR=#\`...\${...number...}... actor=... ts=...ISO timestamp...\`\` within the block. Per Issue #568 (ADR-0045 lens f observability), audit trail must contain PR + actor + ISO timestamp for post-run grep searchability. RED-first confirmed."
    EXIT_CODE=1
  fi
else
  fail "TC3 — could not extract cc:human companion-add block (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# TC4: AC3 — log emission is INSIDE if-block, not orphaned (d077 sister-pattern)
# ============================================================================
section "TC4: AC3 — log emission is properly nested inside if (!hasLabel('cc:human')) block (not orphaned)"

# Per ADR-0049 §Sister-pattern: structural verification. Both `core.warning` and
# `console.log` must be INSIDE the `if (!hasLabel('cc:human'))` block — not orphaned
# outside (which would cause log emission even when cc:human already present, leading
# to spurious audit noise — silent-pollution class).
if [ "$BLOCK_FOUND" = "true" ]; then
  # Extract the if-block body: from `if (!hasLabel('cc:human'))` to matching `}`
  IF_BODY="$(echo "$COMPANION_BLOCK" | awk '/if \(!hasLabel\(.{0,5}cc:human.{0,5}\)\)/,/^[[:space:]]*\}$/')"
  if echo "$IF_BODY" | grep -qE 'core\.warning.*cc:human.*companion-add'; then
    if echo "$IF_BODY" | grep -qE 'console\.log.*\[Layer 5 audit\].*cc:human.*companion-add'; then
      pass "TC4 — both core.warning + console.log properly nested inside if (!hasLabel('cc:human')) block (not orphaned; d077 structural sister-pattern holds)"
    else
      fail "TC4 — console.log emission is ORPHANED (outside if-block)" \
        "expected \`console.log\` to live INSIDE \`if (!hasLabel('cc:human'))\` block. A refactor that moves it outside would cause audit noise on every Layer 5 fire, not just companion-add fires. d077 structural-orphan guard sister-pattern."
      EXIT_CODE=1
    fi
  else
    fail "TC4 — core.warning emission is ORPHANED (outside if-block)" \
      "expected \`core.warning\` to live INSIDE \`if (!hasLabel('cc:human'))\` block. A refactor that moves it outside would cause WARN spam even when cc:human already present (silent-pollution class). d077 structural-orphan guard sister-pattern."
    EXIT_CODE=1
  fi
else
  fail "TC4 — could not extract cc:human companion-add block (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# TC5: AC4 — log emission mentions PR number (d109/d118 sister-pattern)
# ============================================================================
section "TC5: AC4 — log emission message contains PR number reference (sister-pattern d109/d118)"

# Per d109/d118 sister-pattern: regression-guard messages must contain PR# context
# so operator can grep the workflow logs for a specific PR number. Per Issue #569
# PR-number reference + ADR-0045 §Lens d/f observability.
if [ "$BLOCK_FOUND" = "true" ]; then
  # Look for both core.warning + console.log messages and verify each contains PR #
  WARN_HAS_PR=false
  LOG_HAS_PR=false
  if echo "$COMPANION_BLOCK" | grep -E 'core\.warning.*cc:human' | grep -qE 'PR #\$\{number\}|PR #|PR=\$\{number\}|PR=#\$\{number\}'; then
    WARN_HAS_PR=true
  fi
  if echo "$COMPANION_BLOCK" | grep -E 'console\.log.*\[Layer 5 audit\]' | grep -qE 'PR=#\$\{number\}|PR=#|PR=\$\{number\}|PR #\$\{number\}'; then
    LOG_HAS_PR=true
  fi
  if [ "$WARN_HAS_PR" = "true" ] && [ "$LOG_HAS_PR" = "true" ]; then
    pass "TC5 — both core.warning AND console.log emission messages contain PR number reference (operator-grep-able, d109/d118 sister-pattern holds)"
  elif [ "$WARN_HAS_PR" = "false" ]; then
    fail "TC5 — core.warning emission does NOT contain PR number reference" \
      "expected the warning message to include \`PR #\${number}\` so operator can grep the workflow logs for a specific PR. Per d109/d118 sister-pattern. Regression: a future refactor that removes PR# context would silently regress grep-ability."
    EXIT_CODE=1
  else
    fail "TC5 — console.log audit trail does NOT contain PR number reference" \
      "expected the audit trail message to include \`PR=#\${number}\` so operator can grep the workflow logs. Per d109/d118 sister-pattern + Issue #568 lens f."
    EXIT_CODE=1
  fi
else
  fail "TC5 — could not extract cc:human companion-add block (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -eq 0 ]; then
  printf "\n${G}GREEN state: Issue #569 + #568 silent-skip fail-loud + audit trail landed — TC1-TC5 all PASS${D}\n"
  exit 0
else
  printf "\n${R}RED state: cc:human companion-add log emission missing or misstructured${D}\n"
  exit 1
fi
