#!/usr/bin/env bash
# d120-context-watchdog-pct-change-override.sh — Context watchdog 85%+ pct_change
#   override regression guard (Issue #759 + sister-pattern to d108 owner-directive).
#
# Why this test exists
# --------------------
# Issue #759 (P0, owner-directive scope): `scripts/agent-context-monitor.sh`'s
# `agent_likely_stuck()` heuristic incorrectly returns "not stuck" when an agent's
# context pct is changing, EVEN AT 85%+. This causes REPRIME to be skipped until
# pct hits 100% (CRITICAL_PCT), at which point STUCK_AFTER_MIN_CRITICAL=0 kicks in
# for instant /clear. The d108 owner-directive cycle ~#1638 ("85% must fire BEFORE
# timer, not sustained-threshold") is therefore silently regressed by the pct_change
# heuristic override.
#
# Observed 2026-07-02: developer agent context reached 96% — heartbeat went stale
# (3+ hours without update; `developer.heartbeat` 21 bytes, 1 line, 18:01:49Z)
# but REPRIME was skipped every cycle because pct was changing.
#
# Fix: at pct >= THRESHOLD_PCT (default 85), agent_likely_stuck() MUST return 0
# (stuck) regardless of pct_change — the THRESHOLD_PCT override check is placed
# AFTER the age-elapsed check and BEFORE the legacy pct_change heuristic.
# Below THRESHOLD_PCT, the legacy "progress" heuristic (pct changing = not stuck)
# is preserved per ADR-0002 §Work-Stream Awareness (don't REPRIME active agents).
#
# Sister-pattern:
#   - d108 (Issue #725 watchdog defaults, 6 TCs — DIRECT sister, same cycle ~#1638
#     URGENT-P0 fix shape, owner-directive origin). d108 tightened STUCK_AFTER_MIN
#     and STUCK_AFTER_MIN_CRITICAL defaults; d120 closes the pct_change override
#     bypass that d108 didn't address.
#   - d069 + d076 + d077 (Layer 5 verdict-emoji / state-filter / misfire-orphan —
#     audit-trail sister-pattern)
#   - d109 (Issue #727 ci.yml env block, 6 TCs — env-override sister pattern)
#   - d112 (TD-046-extension conftest env-var precedence, 7 TCs — sister env-var
#     precedence pattern)
#   - d116 (TD-038 scripts/ lane drift, 5 TCs — same-script-lane sister per
#     ADR-0059 cluster-squash doctrine)
#   - d117 (ATILCALC_EVALUATE_PERSIST env-var gate, 6 TCs — env-var gate regression
#     guard sister-pattern)
#   - d118 (Issue #707 heartbeat_missed hysteresis, 5 TCs — sister two-tier
#     threshold pattern; d120's THRESHOLD_PCT override is the same "warn-tier vs
#     flag-tier" distinction applied to pct_change heuristic)
#   - d119 (Layer 5 cc:human companion-add log emission, 5 TCs — same Sprint 23
#     cluster, sister RED-first discipline)
#   ≥3 sister-pattern coverage per ADR-0049 §Sister-pattern met
#   (d108 + d109 + d117 + d118 + d119).
#
# d-test number slot rationale (Issue #113 label-authority + ADR-0055 §1):
#   d117=PR #742, d118=PR #756, d119=PR #758 — all taken. d120 = next free slot
#   post-d119. Sister-pattern precedent for slot rename: Issue #724 d094→d097
#   (renamed due to label collision); Issue #755 d113→d117 (architect slot
#   decision). Per Issue #113: labels = ownership, body text may be stale. Issue
#   #760 body originally proposed "d119 candidate" but d119 was already taken by
#   PR #758; d120 is the canonical slot allocation per label-authority.
#
# 9 TCs (1 preflight + 8 functional, ≥5 baseline per ADR-0049 d-test framework
# sister-pattern):
#   TC1: AC1 preflight — agent-context-monitor.sh exists + readable +
#        agent_likely_stuck() body locatable (no preflight = no test)
#   TC1-AC1: AC1 — source contains THRESHOLD_PCT early-return-0 override pattern
#        inside `agent_likely_stuck()` (the bug fix)
#   TC2-AC2: AC2 — THRESHOLD_PCT override is positioned AFTER the age-elapsed check
#        (must respect STUCK_AFTER_MIN window before forcing stuck at 85+)
#   TC3-AC3: AC3 — THRESHOLD_PCT override is positioned BEFORE the pct_change
#        heuristic (override MUST fire first; otherwise pct_change wins at 85+)
#   TC4-AC4: AC4 — legacy `if [ "$pct_change_epoch" -gt "$last_reprime_epoch" ]`
#        check STILL present in source (regression guard — heuristic must
#        remain active for pct < THRESHOLD_PCT)
#   TC5-AC5: AC5 — d108 regression: `STUCK_AFTER_MIN_CRITICAL="${STUCK_AFTER_MIN_CRITICAL:-0}"`
#        default preserved (sister-pattern regression guard)
#   TC6-AC6: AC6 — env-override backward compat: `THRESHOLD_PCT="${THRESHOLD_PCT:-85}"`
#        default present (env override via systemd drop-in still works)
#   TC7-AC7: AC7 — env-override backward compat: `STUCK_AFTER_MIN="${STUCK_AFTER_MIN:-1}"`
#        default preserved (d108 sister regression guard)
#   TC8-AC8: AC8 — comment rationale: source header / agent_likely_stuck() comment
#        block cites Issue #759 + cycle ~#owner-directive + 85% must fire BEFORE
#        timer (operator-grep-able per d109/d118 context-aware sister-pattern)
#
# Pre-impl RED state (current main HEAD b8256f4, 2026-07-02):
#   - TC1 preflight PASS: file exists + readable by design
#   - TC1-AC1 FAIL: no `if [ "$pct" -ge "$THRESHOLD_PCT" ]` early-return-0 pattern
#     exists in agent_likely_stuck() — bug present, pct_change override at 85+
#   - TC2-AC2 FAIL: same root cause as TC1-AC1 — no override means no "after age
#     check" ordering to verify
#   - TC3-AC3 FAIL: same root cause as TC1-AC1 — no override means no "before
#     pct_change" ordering to verify
#   - TC4-AC4 PASS: legacy pct_change heuristic intact (lines 189-197 in current
#     main HEAD)
#   - TC5-AC5 PASS: d108 STUCK_AFTER_MIN_CRITICAL default 0 preserved
#   - TC6-AC6 PASS: THRESHOLD_PCT=85 env override pattern present
#   - TC7-AC7 PASS: STUCK_AFTER_MIN=1 env override pattern present (d108 sister)
#   - TC8-AC8 FAIL: source comment block does NOT cite Issue #759 specifically
#     (lines 47 + 167 cite d108 cycle ~#1638 generic owner-directive, but not #759)
#   → 5/9 PASS + 4/9 FAIL = 50% RED per ADR-0044 (≥50% threshold met)
#
# Post-impl GREEN state (after Issue #759 fix lands):
#   - TC1..TC8 PASS: THRESHOLD_PCT override added at proper position (after age
#     check, before pct_change), legacy pct_change check preserved, env-override
#     defaults preserved, comment block updated with Issue #759 cite
#   → 9/9 PASS in GREEN state.
#
# Usage:
#   bash d120-context-watchdog-pct-change-override.sh --self-test
#
# Exit codes:
#   0 — all 9 PASS (GREEN state — Issue #759 fix landed)
#   1 — at least one FAIL (RED state — pct_change override missing or mis-ordered)
#   2 — preflight failure

set -uo pipefail

# Disable glob expansion (noglob) so fail()/pass() messages containing
# `*` (regex glob chars) are not interpreted.
set -f

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MONITOR="${REPO_ROOT}/scripts/agent-context-monitor.sh"
AGENT_WATCH="${REPO_ROOT}/scripts/agent-watch.sh"

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

printf "${B}d120 self-test (9 TCs = 1 preflight + 8 functional per Issue #759 + d108 sister-pattern + ADR-0044 RED-first)${D}\n"
printf "${B}================================================================${D}\n"
printf "  Repo root:        %s\n" "$REPO_ROOT"
printf "  Monitor:          %s\n" "$MONITOR"
printf "  Agent-watch:      %s\n" "$AGENT_WATCH"
printf "  Sister-pattern:   d108 (DIRECT cycle ~#1638 URGENT P0 sister) + d109 + d117 + d118 + d119 + d069 + d076 + d077 + d112 + d116\n"
printf "  Pre-impl RED:     TC1-AC1 + TC2-AC2 + TC3-AC3 + TC8-AC8 FAIL by design per ADR-0044 (50%% RED)\n"
printf "  Post-impl:        all 8 TCs must PASS\n\n"

EXIT_CODE=0

# ============================================================================
# TC1: preflight — agent-context-monitor.sh exists + readable
# ============================================================================
section "TC1: preflight — agent-context-monitor.sh exists + readable + tooling available"

if [ -f "$MONITOR" ]; then
  if [ -r "$MONITOR" ]; then
    pass "TC1 — preflight OK — $MONITOR exists and is readable"
  else
    fail "TC1 — agent-context-monitor.sh exists but is NOT readable"
    EXIT_CODE=1
    printf "\n${R}RED state: cannot read source — TC2-TC8 SKIPPED${D}\n"
    exit 1
  fi
else
  fail "TC1 — agent-context-monitor.sh missing"
  section "TC2-TC8: SKIPPED (TC1 prerequisite not met)"
  FAIL=$((FAIL + 7))
  printf "\n${B}==== Summary ====${D}\n"
  printf "  PASS: %d\n" "$PASS"
  printf "  FAIL: %d\n" "$FAIL"
  printf "\n${R}RED state: source file not present${D}\n"
  exit 1
fi

# Extract the agent_likely_stuck() function body region: from `agent_likely_stuck() {`
# to the next `^}` line (or the next top-level function/block marker).
START_LINE="$(grep -n '^agent_likely_stuck()' "$MONITOR" | head -1 | cut -d: -f1)"
if [ -z "$START_LINE" ]; then
  fail "internal — could not locate agent_likely_stuck() function in $MONITOR"
  EXIT_CODE=1
  BLOCK_FOUND=false
else
  BLOCK_FOUND=true
  # Extract a 35-line window starting from the function declaration
  STUCK_BODY="$(sed -n "${START_LINE},$((START_LINE + 34))p" "$MONITOR")"
  info "agent_likely_stuck() region: lines ${START_LINE}-$((START_LINE + 34))"
fi

# ============================================================================
# TC1: AC1 — source contains THRESHOLD_PCT early-return-0 override pattern
# ============================================================================
section "TC1-AC1: source contains THRESHOLD_PCT early-return-0 override inside agent_likely_stuck() (Issue #759 bug fix)"

# Per Issue #759: the fix adds an override at pct >= THRESHOLD_PCT that returns 0
# (stuck) BEFORE the pct_change heuristic. Without this override, REPRIME is
# skipped until pct=100 (instant /clear via STUCK_AFTER_MIN_CRITICAL).
if [ "$BLOCK_FOUND" = "true" ]; then
  # Verify the THRESHOLD_PCT override if-block: `if [ "$pct" -ge "$THRESHOLD_PCT" ]`
  # is present in agent_likely_stuck(). For the early-return semantics (which
  # is the spec purpose — bypass pct_change at 85+), we use awk to detect a
  # `return 0` line within the same `if`-block (bounded by matching `fi`).
  # This is more accurate than the previous multiline regex (which used literal
  # `\n` and silently failed on spec-correct multi-line fixes).
  THRESHOLD_LINE="$(echo "$STUCK_BODY" | grep -nE 'if \[\s*"\$pct"\s+-ge\s+"\$THRESHOLD_PCT"\s*\]' | head -1 | cut -d: -f1)"
  if [ -n "$THRESHOLD_LINE" ]; then
    # Extract from THRESHOLD_LINE to next `fi` line at same-or-deeper indent
    BLOCK_END="$(echo "$STUCK_BODY" | awk -v start="$THRESHOLD_LINE" '
      NR > start && /^[[:space:]]*fi[[:space:]]*(#.*)?$/ { print NR; exit }
    ')"
    if [ -n "$BLOCK_END" ]; then
      OVERRIDE_BODY="$(echo "$STUCK_BODY" | sed -n "${THRESHOLD_LINE},${BLOCK_END}p")"
    else
      # Could not find matching fi — fall back to next 5 lines (covers `then\\n  return 0\\nfi` patterns)
      OVERRIDE_BODY="$(echo "$STUCK_BODY" | sed -n "${THRESHOLD_LINE},$((THRESHOLD_LINE + 5))p")"
    fi
    if echo "$OVERRIDE_BODY" | grep -qE 'return 0'; then
      pass "TC1-AC1 — source contains THRESHOLD_PCT override with \`return 0\` in same if-block (lines ${THRESHOLD_LINE}..${BLOCK_END:-?}, Issue #759 fix verified)"
    else
      fail "TC1-AC1 — THRESHOLD_PCT check present (line ${THRESHOLD_LINE}) but \`return 0\` is NOT in the override branch" \
           "expected: \`if [ \"\$pct\" -ge \"\$THRESHOLD_PCT\" ]; then\` ... \`return 0\` ... \`fi\`. Issue #759 fix requires both the threshold check AND a \`return 0\` in the override branch — just adding the check without the early return does NOT bypass the pct_change heuristic. RED-first confirmed."
      EXIT_CODE=1
    fi
  else
    fail "TC1-AC1 — source does NOT contain THRESHOLD_PCT override if-pattern" \
         "expected inside agent_likely_stuck(): \`if [ \"\$pct\" -ge \"\$THRESHOLD_PCT\" ]; then return 0; fi\`. Per Issue #759, the pct_change heuristic currently overrides the 85%+ threshold — REPRIME is skipped at pct=96 even though the agent is past the threshold. RED-first confirmed."
    EXIT_CODE=1
  fi
else
  fail "TC1-AC1 — could not extract agent_likely_stuck() body (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# TC2: AC2 — THRESHOLD_PCT override is AFTER the age-elapsed check
# ============================================================================
section "TC2-AC2: THRESHOLD_PCT override is positioned AFTER the age-elapsed check (window respected)"

# Per Issue #759 design: the override MUST come after `[ "$age" -lt "$stuck_sec" ]`
# check so the STUCK_AFTER_MIN window is honored first. A naive fix that puts
# the override at the top of the function would REPRIME every agent whose context
# reaches 85% even if they just hit the threshold — defeating the 1-min stuck
# window for borderline cases (potential false positive).
if [ "$BLOCK_FOUND" = "true" ]; then
  THRESHOLD_LINE="$(echo "$STUCK_BODY" | grep -nE 'if \[\s*"\$pct"\s+-ge\s+"\$THRESHOLD_PCT"\s*\]' | head -1 | cut -d: -f1)"
  # Age check may be either short-circuit (`[ "$age" -lt "$stuck_sec" ] && return 1`)
  # or if-then (`if [ "$age" -lt "$stuck_sec" ]; then return 1; fi`). The previous
  # regex required an `if` prefix which silently failed on the actual short-circuit
  # pattern in source. Accept either — the structural check is line-ordering only.
  AGE_LINE="$(echo "$STUCK_BODY" | grep -nE '\[\s*"\$age"\s+-lt\s+"\$stuck_sec"\s*\]' | head -1 | cut -d: -f1)"
  if [ -n "$THRESHOLD_LINE" ] && [ -n "$AGE_LINE" ]; then
    if [ "$THRESHOLD_LINE" -gt "$AGE_LINE" ]; then
      pass "TC2-AC2 — THRESHOLD_PCT override (line ${THRESHOLD_LINE}) is positioned AFTER age check (line ${AGE_LINE}) — STUCK_AFTER_MIN window honored"
    else
      fail "TC2-AC2 — THRESHOLD_PCT override (line ${THRESHOLD_LINE}) is positioned BEFORE age check (line ${AGE_LINE})" \
           "Issue #759 fix MUST place the override AFTER the age-elapsed check (\`[ \"\$age\" -lt \"\$stuck_sec\" ] && return 1\` or \`if [ \"\$age\" -lt \"\$stuck_sec\" ]; then return 1; fi\`) so the STUCK_AFTER_MIN window is respected first. Putting the override at the top would cause false positives at borderline pct=85 cases."
      EXIT_CODE=1
    fi
  elif [ -z "$THRESHOLD_LINE" ]; then
    fail "TC2-AC2 — THRESHOLD_PCT override not present (TC1 cascade)" \
         "Issue #759 fix requires the THRESHOLD_PCT override check, which is missing. RED-first confirmed."
    EXIT_CODE=1
  else
    fail "TC2-AC2 — could not locate age-elapsed check" \
         "expected pattern \`[ \"\$age\" -lt \"\$stuck_sec\" ]\` (short-circuit OR if-then). The age-elapsed check is missing from the agent_likely_stuck() body — this is a SOURCE structure regression, not just a fix-positional issue."
    EXIT_CODE=1
  fi
else
  fail "TC2-AC2 — could not extract agent_likely_stuck() body (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# TC3: AC3 — THRESHOLD_PCT override is BEFORE the pct_change heuristic
# ============================================================================
section "TC3-AC3: THRESHOLD_PCT override is positioned BEFORE the pct_change heuristic (override fires first)"

# Per Issue #759 design: the override MUST come before the legacy
# `if [ "$pct_change_epoch" -gt "$last_reprime_epoch" ]` check. If the override
# is placed AFTER pct_change, the legacy heuristic still wins at 85+ and the
# bug is silently preserved. This is the structural-fix verification — without
# it, the override code is present but never executes at 85+.
if [ "$BLOCK_FOUND" = "true" ]; then
  THRESHOLD_LINE="$(echo "$STUCK_BODY" | grep -nE 'if \[\s*"\$pct"\s+-ge\s+"\$THRESHOLD_PCT"\s*\]' | head -1 | cut -d: -f1)"
  PCT_CHANGE_LINE="$(echo "$STUCK_BODY" | grep -nE 'if \[\s*"\$pct_change_epoch"\s+-gt\s+"\$last_reprime_epoch"\s*\]' | head -1 | cut -d: -f1)"
  if [ -n "$THRESHOLD_LINE" ] && [ -n "$PCT_CHANGE_LINE" ]; then
    if [ "$THRESHOLD_LINE" -lt "$PCT_CHANGE_LINE" ]; then
      pass "TC3-AC3 — THRESHOLD_PCT override (line ${THRESHOLD_LINE}) is positioned BEFORE pct_change heuristic (line ${PCT_CHANGE_LINE}) — override fires first at 85+"
    else
      fail "TC3-AC3 — THRESHOLD_PCT override (line ${THRESHOLD_LINE}) is positioned AFTER pct_change (line ${PCT_CHANGE_LINE})" \
           "Issue #759 fix MUST place the override BEFORE \`if [ \"\$pct_change_epoch\" -gt \"\$last_reprime_epoch\" ]\`. If the override is after pct_change, the legacy heuristic still wins at 85+ and the bug is silently preserved — the code is present but never executes."
      EXIT_CODE=1
    fi
  elif [ -z "$THRESHOLD_LINE" ]; then
    fail "TC3-AC3 — THRESHOLD_PCT override not present (TC1 cascade)" \
         "Issue #759 fix requires the override check. RED-first confirmed."
    EXIT_CODE=1
  else
    fail "TC3-AC3 — could not locate legacy pct_change heuristic (regression guard TC4 prerequisite cascade)"
    EXIT_CODE=1
  fi
else
  fail "TC3-AC3 — could not extract agent_likely_stuck() body (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# TC4: AC4 — legacy pct_change heuristic STILL present (regression guard)
# ============================================================================
section "TC4-AC4: legacy pct_change heuristic STILL present in agent_likely_stuck() (regression guard for pct < THRESHOLD_PCT)"

# Per Issue #759 design: the legacy "progress" heuristic MUST be preserved for
# pct < THRESHOLD_PCT (active agent with growing context but not at threshold).
# A naive fix that REMOVES the pct_change check entirely would REPRIME every
# active agent on every poll cycle — defeating ADR-0002 §Work-Stream Awareness
# (don't REPRIME active agents).
if [ "$BLOCK_FOUND" = "true" ]; then
  if echo "$STUCK_BODY" | grep -qE 'if \[\s*"\$pct_change_epoch"\s+-gt\s+"\$last_reprime_epoch"\s*\].*then'; then
    pass "TC4-AC4 — legacy pct_change heuristic intact (regression guard — heuristic preserved for pct < THRESHOLD_PCT)"
  else
    fail "TC4-AC4 — legacy pct_change heuristic REMOVED" \
         "expected: \`if [ \"\$pct_change_epoch\" -gt \"\$last_reprime_epoch\" ]; then return 1; fi\` MUST remain for pct < THRESHOLD_PCT. Per ADR-0002 §Work-Stream Awareness, active agents (pct growing but below threshold) are not stuck. Removing the heuristic causes false positives on every poll."
    EXIT_CODE=1
  fi
else
  fail "TC4-AC4 — could not extract agent_likely_stuck() body (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# TC5: AC5 — d108 sister-pattern regression guard: STUCK_AFTER_MIN_CRITICAL=0 default
# ============================================================================
section "TC5-AC5: STUCK_AFTER_MIN_CRITICAL=0 default preserved (d108 URGENT P0 owner-directive sister regression guard)"

# Per d108 (cycle ~#1638 owner-directive): STUCK_AFTER_MIN_CRITICAL default = 0
# (instant /clear at pct=100). The Issue #759 fix MUST NOT regress this default.
# At pct=100, the CRITICAL_PCT branch (line ~181-183) sets threshold_min to
# STUCK_AFTER_MIN_CRITICAL, so the default = 0 means stuck_sec=0, age check
# passes immediately, then THRESHOLD_PCT override fires → return 0.
if grep -qE '^STUCK_AFTER_MIN_CRITICAL="\${STUCK_AFTER_MIN_CRITICAL:-0}"' "$MONITOR"; then
  pass "TC5-AC5 — STUCK_AFTER_MIN_CRITICAL default = 0 preserved (d108 sister regression guard holds)"
else
  fail "TC5-AC5 — STUCK_AFTER_MIN_CRITICAL default is NOT 0" \
         "expected: \`STUCK_AFTER_MIN_CRITICAL=\"\${STUCK_AFTER_MIN_CRITICAL:-0}\"\`. Per d108 (cycle ~#1638 URGENT P0 owner-directive \"85% must fire BEFORE timer\"), the CRITICAL_PCT default = 0 min is the instant-/clear path. If Issue #759 fix regressed this default, pct=100 would no longer fire instantly."
  EXIT_CODE=1
fi

# ============================================================================
# TC6: AC6 — env-override backward compat: THRESHOLD_PCT default = 85
# ============================================================================
section "TC6-AC6: THRESHOLD_PCT default = 85 preserved (env-override backward compat)"

# Per d108 sister-pattern + Issue #759 design: THRESHOLD_PCT env-override via
# \`${VAR:-DEFAULT}\` pattern MUST remain. The default 85 is the owner-directive
# threshold; users can override via systemd drop-in
# (\`~/.config/systemd/user/dev-studio-context-monitor@%i.service.d/override.conf\`)
# per d108 sister-pattern. If the env-override pattern is replaced with a
# hardcoded 85, future tuning requires script edits instead of config-only changes.
if grep -qE '^THRESHOLD_PCT="\${THRESHOLD_PCT:-85}"' "$MONITOR"; then
  pass "TC6-AC6 — THRESHOLD_PCT env-override pattern (default 85) preserved (systemd drop-in backward compat)"
else
  fail "TC6-AC6 — THRESHOLD_PCT env-override pattern missing or changed" \
       "expected: \`THRESHOLD_PCT=\"\${THRESHOLD_PCT:-85}\"\`. Per d108 sister-pattern + Issue #759 design, env-override via systemd drop-in must remain backward-compatible. Hardcoded 85 would break project-specific tuning."
  EXIT_CODE=1
fi

# ============================================================================
# TC7: AC7 — env-override backward compat: STUCK_AFTER_MIN default = 1
# ============================================================================
section "TC7-AC7: STUCK_AFTER_MIN default = 1 preserved (d108 sister regression guard, TC2 of d108)"

# Per d108 (cycle ~#1638 owner-directive): STUCK_AFTER_MIN default = 1 (was 20,
# owner wants 0-1min). The Issue #759 fix MUST NOT regress this default.
# Sister-pattern to TC5 (STUCK_AFTER_MIN_CRITICAL=0).
if grep -qE '^STUCK_AFTER_MIN="\${STUCK_AFTER_MIN:-1}"' "$MONITOR"; then
  pass "TC7-AC7 — STUCK_AFTER_MIN default = 1 preserved (d108 sister regression guard holds)"
else
  fail "TC7-AC7 — STUCK_AFTER_MIN default is NOT 1" \
       "expected: \`STUCK_AFTER_MIN=\"\${STUCK_AFTER_MIN:-1}\"\`. Per d108 (URGENT P0 owner-directive), default 1min is the threshold for pct >= THRESHOLD_PCT but pct < CRITICAL_PCT. If Issue #759 fix regressed this default, agents at 85-99% would wait 20 min (legacy default) before REPRIME."
  EXIT_CODE=1
fi

# ============================================================================
# TC8: AC8 — comment rationale cites Issue #759 + owner-directive
# ============================================================================
section "TC8-AC8: source comment block cites Issue #759 + owner-directive rationale (operator-grep-able, d109/d118 sister-pattern)"

# Per d109/d118 context-aware sister-pattern: comment blocks MUST contain
# issue/PR references + owner-directive rationale so operators can grep the
# source for context. For Issue #759: the comment block MUST specifically
# cite "Issue #759" / "#759" (NOT just generic d108 "owner-directive" reference
# which already exists at lines 47 + 167 — those cite cycle ~#1638, not #759).
# Future maintainers grepping for Issue #759 context need to find a hit.
COMMENT_FOUND=false
if [ "$BLOCK_FOUND" = "true" ]; then
  # Look for Issue #759 cite inside the agent_likely_stuck() function body OR
  # in the immediate preceding comment block (lines 155-180 region).
  CONTEXT_REGION="$(sed -n "155,${START_LINE}p" "$MONITOR")"
  if echo "$CONTEXT_REGION $STUCK_BODY" | grep -qE 'Issue.*#759|#759|Issue 759'; then
    COMMENT_FOUND=true
    pass "TC8-AC8 — comment block cites Issue #759 specifically — operator-grep-able per d109/d118 sister-pattern (distinguishes from d108 cycle ~#1638 generic owner-directive cite)"
  fi
fi
if [ "$COMMENT_FOUND" = "false" ]; then
  fail "TC8-AC8 — comment block does NOT specifically cite Issue #759" \
       "expected: comment block (lines 155-180 region OR inside agent_likely_stuck()) MUST contain \`Issue #759\` (or \`#759\` / \`Issue 759\`). Per d109/d118 context-aware sister-pattern, regression-guards without issue-specific rationale are silent — operators grepping the source for \"#759\" cannot find context. Note: lines 47 + 167 already cite d108 cycle ~#1638 generic owner-directive, but those don't reference Issue #759 specifically. RED-first confirmed."
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
  printf "\n${G}GREEN state: Issue #759 THRESHOLD_PCT override landed — TC1 + TC1-AC1..TC8-AC8 all 9 PASS${D}\n"
  exit 0
else
  printf "\n${R}RED state: Issue #759 pct_change override missing or mis-ordered${D}\n"
  exit 1
fi
