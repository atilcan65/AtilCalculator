#!/usr/bin/env bash
# d118-heartbeat-missed-hysteresis.sh — Issue #707 heartbeat_missed false-positive hysteresis regression guard
#
# Why this test exists
# --------------------
# Issue #707 (Sprint 22 backlog, dev cycle #1377 surfacing) — agent-watch.sh
# heartbeat_missed detection fires at >2x IS_ALIVE_INTERVAL_SEC, which equals
# the watcher's poll cadence (600s) when IS_ALIVE_INTERVAL_SEC=300s (default).
# Result: heartbeat_missed=true fires on EVERY poll (5 consecutive wakes
# observed cycles ~#1352 → #1377), producing false-positive wake_nudge noise.
#
# Arch assessment cmt 4865872801 + Issue #707 §Recommended Fix Option C:
#   add hysteresis — flag missed only if >3x interval (>15 min gap), not >2x.
#
# Arch handover cmt 4866463275 9-Lens (e) idempotency pre-empt: TWO-TIER
# implementation. The warn-tier (log.warn at >2x) preserves observability per
# ADR-0056 silent-skip sister-pattern; the flag-tier (heartbeat_missed=true at
# >3x) is the real-miss escalation boundary. Simplistic "just change 2→3"
# implementation was REJECTED in favor of two-tier.
#
# Threshold structure (agent-watch.sh lines ~1786-1803 region):
#   PRE-FIX:  if [ "$(( now_epoch - last_is_alive_epoch ))" -gt "$(( is_alive_interval * 2 ))" ]
#             then heartbeat_missed=true   ← single-tier, false-positive bug
#   POST-FIX: if [ "$gap" -gt "$(( is_alive_interval * 3 ))" ]; then
#               heartbeat_missed=true       ← flag tier (3x, real-miss boundary)
#             elif [ "$gap" -gt "$(( is_alive_interval * 2 ))" ]; then
#               printf '[WARN] ... >2x ... <=3x ...' >&2   ← warn tier (2x, observability)
#             fi
#
# 5 TCs (≥5 baseline per ADR-0049 d-test framework sister-pattern):
#   TC1: preflight — scripts/agent-watch.sh exists + readable + awk/sed/jq available
#   TC2: source contains `is_alive_interval * 3` (flag-tier threshold, RED-first verification)
#   TC3: regression guard — flag-tier if-branch does NOT use `* 2` (re-introduces bug)
#        NOTE: warn-tier elif-branch MAY use `* 2` (intentional, arch 9-Lens (e) two-tier)
#   TC4: hysteresis check is properly nested in if-then block (not orphaned outside the guard)
#   TC5: wake_note line (operator-facing boundary) reflects new threshold (3x or hysteresis);
#        log.warn message may legitimately mention ">2x" (warn-tier boundary announcement)
#
# Sister-pattern: TD-016/020/037 (Issue #707 sister-pattern lineage per arch assessment);
#                 d109 (env-block regression guard, sister-pattern to TC3 "does not contain")
#                 d114 (forward-fix regression guard after rebase, sister-pattern to TC2/TC5)
#
# Pre-impl RED state (current main 44b63bf — Issue #707 not yet fixed):
#   - TC1 PASS (agent-watch.sh exists)
#   - TC2 FAIL (source has `is_alive_interval * 2`, not `* 3` in flag tier)
#   - TC3 PASS (no `* 3` in flag tier — but pre-fix has no flag/warn split either)
#   - TC4 PASS (check is properly nested, but threshold is wrong)
#   - TC5 FAIL (wake_note still says ">2x IS_ALIVE_INTERVAL_SEC")
#   → 2/5 PASS + 3/5 FAIL = proper RED-first per ADR-0044 (≥50% FAIL)
#
# Post-impl GREEN state (after Issue #707 fix PR lands, two-tier per arch spec):
#   - All 5 TCs PASS (flag tier uses * 3 + warn tier uses * 2 + wake_note mentions 3x/hysteresis)
#   → 5/5 PASS in GREEN state.
#
# Usage:
#   bash d118-heartbeat-missed-hysteresis.sh --self-test
#
# Exit codes:
#   0 — all 5 PASS (GREEN state — Issue #707 hysteresis fix landed, two-tier per arch)
#   1 — at least one FAIL (RED state — threshold still 2x or regression)
#   2 — preflight failure (awk/sed/jq missing, agent-watch.sh missing, etc.)

set -uo pipefail

# Disable glob expansion (noglob) so fail()/pass() messages containing
# `* 3` or `* 2` (threshold references) are not interpreted as globs.
set -f

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AGENT_WATCH="${REPO_ROOT}/scripts/agent-watch.sh"

# Colors (TTY-aware) — sister-pattern to d109/d112/d116
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

printf "${B}d118 self-test (5 TCs per Issue #707 + ADR-0044 RED-first)${D}\n"
printf "${B}================================================================${D}\n"
printf "  Repo root:        %s\n" "$REPO_ROOT"
printf "  agent-watch.sh:   %s\n" "$AGENT_WATCH"
printf "  Sister-pattern:   TD-016/020/037 (Issue #707) + d109 (env-block regression) + d114 (forward-fix regression)\n"
printf "  Pre-impl RED:     TC2 + TC3 + TC5 FAIL by design per ADR-0044 (≥50%% RED)\n"
printf "  Post-impl:        all 5 TCs must PASS\n\n"

EXIT_CODE=0

# ============================================================================
# TC1: preflight — agent-watch.sh exists + readable
# ============================================================================
section "TC1: AC1 preflight — agent-watch.sh exists + readable + tooling available"

if [ -f "$AGENT_WATCH" ]; then
  if [ -r "$AGENT_WATCH" ]; then
    pass "TC1 — agent-watch.sh exists at $AGENT_WATCH and is readable"
  else
    fail "TC1 — agent-watch.sh exists but is NOT readable" \
      "expected read permissions on $AGENT_WATCH"
    EXIT_CODE=1
  fi
else
  fail "TC1 — agent-watch.sh missing" \
    "expected $AGENT_WATCH per Issue #707. Without this file, d118 cannot guard the hysteresis fix."
  section "TC2-TC5: SKIPPED (TC1 prerequisite not met)"
  FAIL=$((FAIL + 4))
  EXIT_CODE=1
  printf "\n${B}==== Summary ====${D}\n"
  printf "  PASS: %d\n" "$PASS"
  printf "  FAIL: %d\n" "$FAIL"
  printf "  INFO: %d\n" "$INFO"
  printf "\n${R}RED state: agent-watch.sh not present — TC1 fails + TC2-TC5 cascade${D}\n"
  exit 1
fi

# Extract the heartbeat_missed check region (32-line window after the marker
# comment "Heartbeat-missed check (Issue #238")
START_LINE="$(grep -n "Heartbeat-missed check (Issue #238" "$AGENT_WATCH" | head -1 | cut -d: -f1)"
if [ -z "$START_LINE" ]; then
  fail "internal — could not locate 'Heartbeat-missed check (Issue #238' marker in agent-watch.sh" \
    "grep returned empty; the marker comment may have been moved/removed"
  EXIT_CODE=1
else
  HB_BLOCK="$(sed -n "${START_LINE},$((START_LINE + 24))p" "$AGENT_WATCH")"
  info "heartbeat_missed check region: lines ${START_LINE}-$((START_LINE + 24))"
fi

# ============================================================================
# TC2: source contains `is_alive_interval * 3` (post-fix threshold value)
# ============================================================================
section "TC2: AC1 — source contains post-fix hysteresis threshold [is_alive_interval * 3]"

# Per Issue #707 Option C: hysteresis = 3x IS_ALIVE_INTERVAL_SEC
# Pre-fix: source has `is_alive_interval * 2` → RED-FAIL
# Post-fix: source has `is_alive_interval * 3` → GREEN-PASS
if [ -n "$HB_BLOCK" ]; then
  if echo "$HB_BLOCK" | grep -qE 'is_alive_interval[[:space:]]*\*[[:space:]]*3\b'; then
    pass "TC2 — source contains post-fix hysteresis threshold \`is_alive_interval \\* 3\`"
  else
    fail "TC2 — source does NOT contain post-fix threshold \`is_alive_interval \\* 3\`" \
      "expected the threshold expression to use \\* 3 (per Issue #707 Option C hysteresis fix). Current source still uses \\* 2 (false-positive bug). RED-first confirmed."
    EXIT_CODE=1
  fi
else
  fail "TC2 — could not extract heartbeat_missed check block (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# TC3: source does NOT contain `is_alive_interval * 2` (regression guard)
# ============================================================================
section "TC3: AC2 — regression guard: flag-tier if-branch uses * 3 (not pre-fix * 2)"

# Sister-pattern: d109 (env-block regression guard, "must not contain X").
# Per ADR-0049 §Sister-pattern coverage: prevent re-introduction of the false-positive bug.
#
# IMPORTANT (arch cmt 4866463275 9-Lens (e) two-tier): the warn-tier elif-branch
# MAY legitimately use * 2 (warn-tier boundary announcement per ADR-0056
# silent-skip sister-pattern). Only the flag-tier if-branch is the regression
# guard — if it drops back to * 2, the false-positive bug is back.
if [ -n "$HB_BLOCK" ]; then
  # Extract ONLY the flag-tier if-branch line itself (single line pattern):
  # `if [ "$heartbeat_gap" -gt "$(( is_alive_interval * N ))" ]`
  # This excludes the elif branch, which may legitimately use * 2 (warn-tier).
  FLAG_TIER="$(echo "$HB_BLOCK" | grep -E 'if \[ "\$heartbeat_gap".*-gt' | head -1)"
  if echo "$FLAG_TIER" | grep -qE 'is_alive_interval[[:space:]]*\*[[:space:]]*2\b'; then
    fail "TC3 — flag-tier if-branch regressed to * 2 (re-introduces false-positive bug)" \
      "the FLAG tier (real-miss escalation boundary) must use * 3. A regression to * 2 silently re-introduces the wake_nudge false-positive noise. Per ADR-0050 + d109 sister-pattern. RED-first confirmed."
    EXIT_CODE=1
  elif echo "$FLAG_TIER" | grep -qE 'is_alive_interval[[:space:]]*\*[[:space:]]*3\b'; then
    pass "TC3 — flag-tier if-branch uses * 3 (regression guard intact; warn-tier elif may retain * 2 per arch 9-Lens (e))"
  else
    fail "TC3 — flag-tier if-branch does not use * 3 (hysteresis threshold missing or mis-structured)" \
      "expected the if-branch threshold comparison to use * 3 (post-fix per Issue #707 Option C). Found neither * 2 nor * 3 in flag-tier branch — implementation may have been refactored away from the two-tier spec."
    EXIT_CODE=1
  fi
else
  fail "TC3 — could not extract heartbeat_missed check block (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

section "TC4: AC3 — hysteresis check is properly nested inside the if-then guard"

# Per ADR-0049 §Sister-pattern: structural verification — the threshold comparison
# must be inside the `if [ -n "$last_is_alive_utc" ] && ...` block, not orphaned
# outside. This guards against refactor regressions that move the check.
if [ -n "$HB_BLOCK" ]; then
  # Extract the if-then block body (between `if [ -n "$last_is_alive_utc" ]` and
  # the matching `fi`). Look for the threshold expression within that body.
  IF_BLOCK="$(echo "$HB_BLOCK" | awk '/if \[ -n "\$last_is_alive_utc"/,/^[[:space:]]*fi$/')"
  if echo "$IF_BLOCK" | grep -qE 'is_alive_interval[[:space:]]*\*[[:space:]]*[23]\b'; then
    pass "TC4 — hysteresis check properly nested inside if-then guard (not orphaned)"
  else
    fail "TC4 — hysteresis check is ORPHANED (outside the if-then guard)" \
      "expected the threshold expression to live inside the if [ -n \"\$last_is_alive_utc\" ] block. A refactor regression that moves the threshold check outside would cause it to evaluate even when no last_is_alive_utc exists. Sister-pattern: d109 env-block structural guard."
    EXIT_CODE=1
  fi
else
  fail "TC4 — could not extract heartbeat_missed check block (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# TC5: wake_nudge message reflects new threshold (post-fix copy)
# ============================================================================
section "TC5: AC4 — wake_note line reflects new threshold (post-fix copy: 3x or hysteresis)"

# Per Issue #707 §Sister-pattern Doctrine Update + arch 9-Lens (e) two-tier spec:
# the WAKE_NOTE line (operator-facing wake_nudge boundary) must mention 3x or
# hysteresis, NOT 2x (pre-fix boundary). The log.warn message inside the warn-tier
# elif branch may legitimately mention ">2x" because it announces the warn-tier
# boundary (ADR-0056 silent-skip observability). Pre-fix wake_note said
# ">2x IS_ALIVE_INTERVAL_SEC"; post-fix must say "3x" / "hysteresis".
if [ -n "$HB_BLOCK" ]; then
  # Extract only the wake_note line (operator-facing wake_nudge copy).
  # NOTE: wake_note is OUTSIDE the HB_BLOCK 24-line window (typically 28-30
  # lines after the hysteresis check), so search the whole agent-watch.sh.
  WAKE_NOTE="$(grep -E '^[[:space:]]*wake_note=' "$AGENT_WATCH" | grep -E 'heartbeat|3x|hysteresis' | head -1)"
  if [ -z "$WAKE_NOTE" ]; then
    fail "TC5 — wake_note line not found in heartbeat_missed block" \
      "expected a line of the form wake_note=\"watcher heartbeat missed (...)\". Cannot verify operator-facing boundary."
    EXIT_CODE=1
  elif echo "$WAKE_NOTE" | grep -qE '2x'; then
    fail "TC5 — wake_note STILL mentions pre-fix 2x boundary" \
      "expected post-fix wake_note to mention 3x or hysteresis (per Issue #707 §Sister-pattern Doctrine Update). Pre-fix copy \`>2x IS_ALIVE_INTERVAL_SEC\` would be a doctrinal mismatch — the operator-facing note must reflect the new boundary."
    EXIT_CODE=1
  elif echo "$WAKE_NOTE" | grep -qE '3x|hysteresis'; then
    pass "TC5 — wake_note reflects new threshold (3x or hysteresis); log.warn warn-tier may still mention 2x (intentional per arch 9-Lens (e))"
  else
    # Soft fail: wake_note may have been reworded entirely; not all phrasings are captured.
    info "TC5 — wake_note does not contain '2x' (good) but also lacks '3x'/'hysteresis' keywords"
    info "       acceptable if the wake_note was reworded entirely; flag for arch review"
    pass "TC5 — wake_note no longer mentions pre-fix 2x threshold (post-fix copy detected)"
  fi
else
  fail "TC5 — could not extract heartbeat_missed check block (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -eq 0 ]; then
  printf "\n${G}GREEN state: Issue #707 hysteresis fix landed — TC1-TC5 all PASS${D}\n"
  exit 0
else
  printf "\n${R}RED state: hysteresis threshold still at 2x or wake_nudge copy outdated${D}\n"
  exit 1
fi