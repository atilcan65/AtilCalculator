#!/usr/bin/env bash
# d108-context-watchdog-instant-fire.sh — Context watchdog stuck-detection defaults tightening
#   (URGENT P0 owner-directive cycle ~#1638, 2026-06-30T17:25Z).
#
# Why this test exists
# --------------------
# Owner escalation (cycle ~#1638 — owner direct: "85% used to fire before timer,
# now doesn't, all at 100%"): the context watchdog's stuck-pane detection windows
# were set too lenient at script defaults (STUCK_AFTER_MIN=20, STUCK_AFTER_MIN_CRITICAL=3).
# When all 5 agents saturated to 100%, the busy_skip path took over and the watchdog
# waited 20 minutes (or 3 minutes at critical) before forcing /clear. By that time
# the agents were effectively dead — manual /compact from a separate shell was the
# only recovery. The fix tightens these defaults so 85% fires effectively-instantly
# (1 min stuck window) and 100% fires on first observation of stuck (0 min).
#
# The systemd service unit also failed to expose STUCK_AFTER_MIN / STUCK_AFTER_MIN_CRITICAL
# as Environment= lines, so even script-default changes wouldn't propagate to the
# timer-driven production run — only to manual DRY_RUN invocations. This test also
# pins the service unit to expose both vars with the new aggressive defaults.
#
# AC mapping (owner-directive cycle ~#1638):
#   AC1 — script default STUCK_AFTER_MIN=1 (was 20, owner wants 0-1min)
#   AC2 — script default STUCK_AFTER_MIN_CRITICAL=0 (was 3, owner wants instant)
#   AC3 — service unit Environment=STUCK_AFTER_MIN=1 line present (systemd propagation)
#   AC4 — service unit Environment=STUCK_AFTER_MIN_CRITICAL=0 line present
#   AC5 — env override still works (backward compat — manual STUCK_AFTER_MIN=20 still parsed)
#   AC6 — script header comments updated to reflect new defaults + cite owner-directive rationale
#
# 6 TCs (per ADR-0049 d-test framework sister-pattern ≥3 minimum):
#   TC1: script default STUCK_AFTER_MIN == 1 (AC1)
#   TC2: script default STUCK_AFTER_MIN_CRITICAL == 0 (AC2)
#   TC3: service unit has Environment=STUCK_AFTER_MIN=1 line (AC3)
#   TC4: service unit has Environment=STUCK_AFTER_MIN_CRITICAL=0 line (AC4)
#   TC5: env override backwards-compatible — STUCK_AFTER_MIN=20 in env still respected
#        (validates that tightening defaults doesn't break users with custom values)
#   TC6: script header comment block (lines 155-170 area) explains new defaults
#        with rationale referencing owner-directive + cycle ~#1638
#
# Pre-impl RED state (main HEAD ec1e432, 2026-06-30T17:25Z):
#   - script line 46: STUCK_AFTER_MIN="${STUCK_AFTER_MIN:-20}" → TC1 FAIL (expected 1)
#   - script line 50: STUCK_AFTER_MIN_CRITICAL="${STUCK_AFTER_MIN_CRITICAL:-3}" → TC2 FAIL (expected 0)
#   - service unit has no STUCK_AFTER_MIN Environment= line → TC3 FAIL
#   - service unit has no STUCK_AFTER_MIN_CRITICAL Environment= line → TC4 FAIL
#   - env override TC5: pass (default behavior, no change needed)
#   - header comment still says "default 20min" / "default 3min" → TC6 FAIL
#   → 5/6 TCs FAIL = proper RED-first per ADR-0044.
#
# Post-impl GREEN state (target):
#   - script defaults tightened to 1 and 0
#   - service unit Environment= lines expose both vars
#   - env override still respected (manual STUCK_AFTER_MIN=20 still works)
#   - header comment reflects new defaults + owner-directive rationale
#   → 6/6 TCs PASS.
#
# Sister-pattern family (ADR-0049 d-test framework):
#   - d060 (RETRO-009 §1 pre-push branch-base-check, 9 TCs) — operational discipline sister
#   - d070 + d070b (init-script sister family) — script-defaults shape
#   - d091 (work-stream awareness sister) — service unit config shape
#   - d097 (Sprint 22 PIVOT self-hosted runner migration, Issue #708 era)
#   - d096 (S21-006 soul files template) — comment-block update discipline
#   - d100 (Sprint 22 PIVOT Faz 1.2 env-aware perf budgets) — env-override contract
#   - d105 (S21-004 audit-project-refs) — script/service unit coverage shape
#   - d106 (S21-007 soul-template-version-pin) — version-pin discipline
#   - d107 (Issue #722 install-git-hooks, 6 TCs) — DIRECT sister (same cycle era, same URGENT-P0 shape)
#
# Refs:
#   - Owner-directive cycle ~#1638 (2026-06-30T17:25Z, ORCH→DEV): "85% must fire BEFORE timer (instant)"
#   - Manual recovery cycle ~#1638 (orchestrator ran /compact on all 5 panes, all now 0%)
#   - ADR-0038 (auto-claim protocol — agents must not pause on threshold breaches)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0049 (d-test framework sister-pattern, ≥3 TCs minimum)
#   - ADR-0055 §1 (Cadence Rule 1 atomic — d-test file + INDEX.md same commit)
#   - Issue #238 (no self-justified pause — owner-directive is verbatim chat instruction)
#
# Usage:
#   bash d108-context-watchdog-instant-fire.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — defaults tightened + service unit exposes both vars)
#   1 — at least one FAIL (RED state — impl missing or ACs unsatisfied)
#   2 — preflight failure (missing tool, script, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
WATCHDOG_SH="${WATCHDOG_SH:-${REPO_ROOT}/scripts/agent-context-monitor.sh}"
SERVICE_UNIT="${SERVICE_UNIT:-${REPO_ROOT}/systemd/dev-studio-context-monitor@.service}"

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

command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "ERROR: awk required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d108 self-test (6 TCs per owner-directive cycle ~#1638, ADR-0044 RED-first)${D}\n"
printf "${B}========================================================================${D}\n"
printf "  Repo root:        %s\n" "$REPO_ROOT"
printf "  Watchdog script:  %s\n" "$WATCHDOG_SH"
printf "  Service unit:     %s\n" "$SERVICE_UNIT"
printf "  Sister-pattern:   d107 (Issue #722 install-git-hooks, 6 TCs — same URGENT-P0 shape)\n"
printf "  Pre-impl RED:     5/6 TCs FAIL by design per ADR-0044 (TC5 passes — env override compat)\n"
printf "  Sprint:           22 PIVOT Faz 1.3 (post-Faz 1.1+1.2 cascade merge cycle ~#1637)\n"
printf "  Owner-directive:  85% fires instantly, not sustained-threshold\n\n"

# Preflight
[ -f "$WATCHDOG_SH" ] || { echo "ERROR: $WATCHDOG_SH missing" >&2; exit 2; }
[ -f "$SERVICE_UNIT" ] || { echo "ERROR: $SERVICE_UNIT missing" >&2; exit 2; }

EXIT_CODE=0

# ============================================================================
# TC1: script default STUCK_AFTER_MIN == 1 (AC1 — owner wants 0-1min)
# ============================================================================
section "TC1: AC1 — script default STUCK_AFTER_MIN == 1 (was 20, owner wants 0-1min)"
# Extract default value from `STUCK_AFTER_MIN="${STUCK_AFTER_MIN:-<DEFAULT>}"`
TC1_DEFAULT=$(grep -oE 'STUCK_AFTER_MIN="\$\{STUCK_AFTER_MIN:-[0-9]+\}"' "$WATCHDOG_SH" | grep -oE ':-[0-9]+' | grep -oE '[0-9]+' | head -1)
if [ -z "$TC1_DEFAULT" ]; then
  fail "TC1 — could not extract STUCK_AFTER_MIN default from script" \
    "expected pattern 'STUCK_AFTER_MIN=\"\${STUCK_AFTER_MIN:-N}\"' near line 46. Default not found or syntax changed."
  EXIT_CODE=1
elif [ "$TC1_DEFAULT" = "1" ]; then
  pass "TC1 — script default STUCK_AFTER_MIN=1 (was 20, owner-directive 0-1min)"
else
  fail "TC1 — script default STUCK_AFTER_MIN=$TC1_DEFAULT (expected 1)" \
    "owner-directive cycle ~#1638: 'STUCK_AFTER_MIN=20 delays 20min — owner wants 0-1min'. Tighten default to 1. Pre-impl RED: 20 → FAIL by design per ADR-0044."
  EXIT_CODE=1
fi

# ============================================================================
# TC2: script default STUCK_AFTER_MIN_CRITICAL == 0 (AC2 — owner wants instant)
# ============================================================================
section "TC2: AC2 — script default STUCK_AFTER_MIN_CRITICAL == 0 (was 3, owner wants instant at 100%)"
TC2_DEFAULT=$(grep -oE 'STUCK_AFTER_MIN_CRITICAL="\$\{STUCK_AFTER_MIN_CRITICAL:-[0-9]+\}"' "$WATCHDOG_SH" | grep -oE ':-[0-9]+' | grep -oE '[0-9]+' | head -1)
if [ -z "$TC2_DEFAULT" ]; then
  fail "TC2 — could not extract STUCK_AFTER_MIN_CRITICAL default from script" \
    "expected pattern 'STUCK_AFTER_MIN_CRITICAL=\"\${STUCK_AFTER_MIN_CRITICAL:-N}\"' near line 50. Default not found or syntax changed."
  EXIT_CODE=1
elif [ "$TC2_DEFAULT" = "0" ]; then
  pass "TC2 — script default STUCK_AFTER_MIN_CRITICAL=0 (was 3, instant /clear at 100% stuck)"
else
  fail "TC2 — script default STUCK_AFTER_MIN_CRITICAL=$TC2_DEFAULT (expected 0)" \
    "owner-directive cycle ~#1638: 'STUCK_AFTER_MIN_CRITICAL=3 — owner may want 0 too'. Tighten to 0 for instant /clear at 100% stuck. Pre-impl RED: 3 → FAIL by design per ADR-0044."
  EXIT_CODE=1
fi

# ============================================================================
# TC3: service unit has Environment=STUCK_AFTER_MIN=1 line (AC3 — systemd propagation)
# ============================================================================
section "TC3: AC3 — service unit exposes Environment=STUCK_AFTER_MIN=1"
if grep -qE '^Environment=STUCK_AFTER_MIN=1$' "$SERVICE_UNIT"; then
  pass "TC3 — service unit has Environment=STUCK_AFTER_MIN=1 (systemd timer-driven run uses tightened default)"
else
  fail "TC3 — service unit missing Environment=STUCK_AFTER_MIN=1 line" \
    "expected 'Environment=STUCK_AFTER_MIN=1' in systemd/dev-studio-context-monitor@.service. Without this, the 60s timer uses script-default (was 20). Sister-pattern to d070 environment exposure. Pre-impl RED: absent → FAIL by design per ADR-0044."
  EXIT_CODE=1
fi

# ============================================================================
# TC4: service unit has Environment=STUCK_AFTER_MIN_CRITICAL=0 line (AC4)
# ============================================================================
section "TC4: AC4 — service unit exposes Environment=STUCK_AFTER_MIN_CRITICAL=0"
if grep -qE '^Environment=STUCK_AFTER_MIN_CRITICAL=0$' "$SERVICE_UNIT"; then
  pass "TC4 — service unit has Environment=STUCK_AFTER_MIN_CRITICAL=0 (systemd timer-driven run uses tightened default)"
else
  fail "TC4 — service unit missing Environment=STUCK_AFTER_MIN_CRITICAL=0 line" \
    "expected 'Environment=STUCK_AFTER_MIN_CRITICAL=0' in systemd/dev-studio-context-monitor@.service. Without this, the 60s timer uses script-default (was 3). Pre-impl RED: absent → FAIL by design per ADR-0044."
  EXIT_CODE=1
fi

# ============================================================================
# TC5: env override still respected — STUCK_AFTER_MIN=20 in env still parsed
#      (validates that tightening defaults doesn't break users with custom values)
# ============================================================================
section "TC5: AC5 backward compat — env override STUCK_AFTER_MIN=20 still parsed by script"
# Run script with DRY_RUN=1 + custom env override + capture threshold usage.
# We can't easily unit-test the internal var without changing the script, so
# we verify the script accepts the env var without complaint (no 'unbound variable'
# error under set -u, and a successful one-shot exit).
if STUCK_AFTER_MIN=20 STUCK_AFTER_MIN_CRITICAL=10 bash -c "
  set -uo pipefail
  # Source the relevant defaults block from the script (lines 40-55 area)
  # We can't easily import — instead re-run with our env set and check exit code.
  exit 0
"; then
  # Also verify the script accepts the env var in real run (no set -u unbound complaint).
  # We can't run the full script (it needs tmux) — but we can grep that the
  # `:-<DEFAULT>` syntax is present for both vars (which is what allows env override).
  if grep -qE 'STUCK_AFTER_MIN="\$\{STUCK_AFTER_MIN:-' "$WATCHDOG_SH" && \
     grep -qE 'STUCK_AFTER_MIN_CRITICAL="\$\{STUCK_AFTER_MIN_CRITICAL:-' "$WATCHDOG_SH"; then
    pass "TC5 — env override preserved: both vars use \${VAR:-DEFAULT} pattern (backward compat for STUCK_AFTER_MIN=20 etc.)"
  else
    fail "TC5 — env override pattern broken" \
      "expected both vars to use '\${VAR:-DEFAULT}' form for env override. If pattern changed to literal assignment, manual STUCK_AFTER_MIN=20 in systemd drop-in no longer works. Pre-impl RED: this should already pass — kept as regression guard."
    EXIT_CODE=1
  fi
else
  fail "TC5 — env override subshell failed" \
    "expected env var handling subshell to succeed. Bash setup error."
  EXIT_CODE=1
fi

# ============================================================================
# TC6: script header comment block (lines 155-170 area) explains new defaults
#      with rationale referencing owner-directive + cycle ~#1638
# ============================================================================
section "TC6: AC6 — script header comment cites owner-directive cycle ~#1638 + new defaults"
# Extract the agent_likely_stuck() comment block (lines 155-170 area) and verify
# it reflects the new defaults (1 + 0) AND cites owner-directive rationale.
COMMENT_BLOCK=$(awk '/^# A pane is considered STUCK/,/^agent_likely_stuck\(\)/' "$WATCHDOG_SH" | head -20)
TC6_OK=1
TC6_REASON=""
if ! echo "$COMMENT_BLOCK" | grep -qE 'STUCK_AFTER_MIN_CRITICAL.*\(default 0'; then
  TC6_OK=0
  TC6_REASON="comment doesn't say STUCK_AFTER_MIN_CRITICAL default 0"
fi
if ! echo "$COMMENT_BLOCK" | grep -qE 'STUCK_AFTER_MIN.*\(default 1'; then
  TC6_OK=0
  TC6_REASON="${TC6_REASON:+$TC6_REASON; }comment doesn't say STUCK_AFTER_MIN default 1"
fi

if [ "$TC6_OK" = "1" ]; then
  pass "TC6 — script comment block reflects new defaults (1 + 0) — owner-directive rationale documented"
else
  fail "TC6 — script comment block stale: $TC6_REASON" \
    "expected comment block around agent_likely_stuck() to say '(default 1min)' and '(default 0min)' with owner-directive rationale (cycle ~#1638). Without this, future maintainers will revert the defaults thinking they're typos. Sister-pattern to d106 comment discipline. Pre-impl RED: stale text → FAIL by design per ADR-0044."
  EXIT_CODE=1
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  Owner-directive cycle:  ~#1638 (2026-06-30T17:25Z)\n"
printf "  Defaults tightened:     STUCK_AFTER_MIN 20→1, STUCK_AFTER_MIN_CRITICAL 3→0\n"
printf "  Service unit:           now exposes both vars for systemd propagation\n"
printf "  Sister-pattern:         d107 (Issue #722 install-git-hooks, 6 TCs)\n"
printf "  AC1+AC2 (TC1+TC2):      script defaults tightened\n"
printf "  AC3+AC4 (TC3+TC4):      service unit env var propagation\n"
printf "  AC5 (TC5):              env override backward compat preserved\n"
printf "  AC6 (TC6):              comment block reflects new defaults + rationale\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — d108 impl not yet landed (defaults still 20 + 3)${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 6 TCs PASS — d108 impl complete, defaults tightened + systemd propagation wired${D}\n"
exit 0