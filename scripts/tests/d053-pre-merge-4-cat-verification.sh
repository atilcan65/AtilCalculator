#!/usr/bin/env bash
# d053-pre-merge-4-cat-verification.sh — pre-merge 4-cat verification (ADR-0050)
#
# Why this test exists
# --------------------
# ADR-0050 introduces d053 to enforce **doctrinal correctness** of the 4-cat
# invariant, complementing the existing `.github/workflows/label-check.yml`
# (which enforces **presence** only).
#
# Sprint 12 produced 6 arch-related workflow regressions in 24h (close.md
# §Doctrinal carry-forwards #3). Of these, PR #450 (`type:bug` + missing
# `needs-tester-signoff`) was a 4-cat gap caught at squash-time — label-check.yml
# reported "all 4 categories present" (PASS), masking the doctrinal
# type:bug → needs-tester-signoff rule.
#
# d053 = 9 doctrinal checks C1-C9, programmatic enforcement via bash + gh API.
#
# Sister-pattern family (6-sister d-test framework):
#   - d046 (Issue #413 jq-filter guard)
#   - d048 (Issue #425 AC2.1 layered defense)
#   - d050b (Issue #440 behavioral workflow test framework)
#   - d051 (Issue #414 RETRO-005 #26 regression anchor)
#   - d052 (Issue #461 agent-watch.sh hardening)
#   - d053 (Issue #463 ADR-0050 pre-merge 4-cat verification) — this file
#
# 9 doctrinal checks C1-C9 (per ADR-0050 §Doctrinal checks):
#   C1: type:bug PR MUST have needs-tester-signoff        (PR #450 catch)
#   C2: type:bug PR MUST have cc:tester                   (PR #450 catch)
#   C3: status:ready PR MUST have cc:human                (PR #458 v1 catch)
#   C4: type:docs + .claude/ MUST have agent:architect OR agent:product-manager
#   C5: type:docs + scripts/ MUST NOT have agent:tester   (Issue #412 sister)
#   C6: multiple agent:* = dual-owned (informational, RETRO-007 doctrine)
#   C7: type:incident PR MUST have priority:P0            (ADR-0012 §Priority matrix)
#   C8: status:in-review MUST NOT also have status:ready  (ADR-0012 mutual exclusion)
#   C9: Closes-anchor strict format (uppercase C + L1 + NO trailing text)
#                                                        (PR #462 v1 catch)
#
# Usage:
#   bash d053-pre-merge-4-cat-verification.sh <PR_NUMBER>     # live run on PR
#   bash d053-pre-merge-4-cat-verification.sh --self-test    # run inline fixture (9 violation cases)
#
# Exit codes:
#   0 — all PASS (C6 informational OK)
#   1 — at least one FAIL
#   2 — preflight failure (missing tool, missing PR number, etc.)
#
# Run standalone: bash scripts/tests/d053-pre-merge-4-cat-verification.sh --self-test

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-atilproject/AtilCalculator}"

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

# Pre-flight
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }

# Self-test mode — run against inline fixture (9 violation cases, 1 dual-owned)
if [ "${1:-}" = "--self-test" ]; then
  printf "${B}d053 self-test (9 violation cases per ADR-0050)${D}\n"
  printf "${B}===============================================${D}\n"

  # Inline fixture: each section sets LABELS / BODY_L1 / FILES then exercises
  # the same check logic as the live path. Self-test asserts the checks FAIL
  # on deliberately-bad fixtures (RED state) and the impl matches ADR-0050
  # §Doctrinal checks C1-C9 spec exactly.

  PASS=0; FAIL=0; INFO=0
  EXIT_CODE=0

  # Self-test helper: check_label_match LABEL LABELS_VAR → 0 if present
  check_label_match() {
    local target="$1" labels="$2"
    echo "$labels" | grep -qxF "$target"
  }

  # C1 violation fixture: type:bug without needs-tester-signoff
  section "C1 self-test"
  LABELS="type:bug
status:in-review
agent:developer"
  if check_label_match "type:bug" "$LABELS"; then
    if check_label_match "needs-tester-signoff" "$LABELS"; then
      pass "C1"
    else
      fail "C1" "type:bug without needs-tester-signoff"; EXIT_CODE=1
    fi
  else
    pass "C1"
  fi

  # C2 violation fixture: type:bug without cc:tester
  section "C2 self-test"
  LABELS="type:bug
needs-tester-signoff
agent:developer"
  if check_label_match "type:bug" "$LABELS"; then
    if check_label_match "cc:tester" "$LABELS"; then
      pass "C2"
    else
      fail "C2" "type:bug without cc:tester"; EXIT_CODE=1
    fi
  else
    pass "C2"
  fi

  # C3 violation fixture: status:ready without cc:human
  section "C3 self-test"
  LABELS="type:docs
status:ready
agent:architect"
  if check_label_match "status:ready" "$LABELS"; then
    if check_label_match "cc:human" "$LABELS"; then
      pass "C3"
    else
      fail "C3" "status:ready without cc:human"; EXIT_CODE=1
    fi
  else
    pass "C3"
  fi

  # C4 violation fixture: type:docs + .claude/ + agent:developer (not architect/PM)
  section "C4 self-test"
  LABELS="type:docs
status:in-review
agent:developer"
  FILES=".claude/agents/foo.md"
  if check_label_match "type:docs" "$LABELS"; then
    if echo "$FILES" | grep -qE "^\.claude/"; then
      if check_label_match "agent:architect" "$LABELS" || check_label_match "agent:product-manager" "$LABELS"; then
        pass "C4"
      else
        fail "C4" "type:docs .claude/ without soul-amend lane agent"; EXIT_CODE=1
      fi
    else
      pass "C4"
    fi
  else
    pass "C4"
  fi

  # C5 violation fixture: type:docs + scripts/ + agent:tester
  section "C5 self-test"
  LABELS="type:docs
status:in-review
agent:tester"
  FILES="scripts/something.sh"
  if check_label_match "type:docs" "$LABELS"; then
    if echo "$FILES" | grep -qE "^scripts/"; then
      if check_label_match "agent:tester" "$LABELS"; then
        fail "C5" "type:docs scripts/ with agent:tester"; EXIT_CODE=1
      else
        pass "C5"
      fi
    else
      pass "C5"
    fi
  else
    pass "C5"
  fi

  # C6 informational fixture: dual agent:* (PM + arch)
  section "C6 self-test"
  LABELS="type:docs
agent:product-manager
agent:architect"
  agent_count=0
  while IFS= read -r lbl; do
    case "$lbl" in agent:*) agent_count=$((agent_count+1));; esac
  done <<< "$LABELS"
  if [ "$agent_count" -gt 1 ]; then
    info "C6" "dual-owned: $agent_count agent:* labels (informational)"
  else
    pass "C6"
  fi

  # C7 violation fixture: type:incident without priority:P0
  section "C7 self-test"
  LABELS="type:incident
status:in-review
agent:developer"
  if check_label_match "type:incident" "$LABELS"; then
    if check_label_match "priority:P0" "$LABELS"; then
      pass "C7"
    else
      fail "C7" "type:incident without priority:P0"; EXIT_CODE=1
    fi
  else
    pass "C7"
  fi

  # C8 violation fixture: status:in-review + status:ready
  section "C8 self-test"
  LABELS="type:docs
status:in-review
status:ready
agent:architect"
  if check_label_match "status:in-review" "$LABELS"; then
    if check_label_match "status:ready" "$LABELS"; then
      fail "C8" "status:in-review + status:ready mutual exclusion violated"; EXIT_CODE=1
    else
      pass "C8"
    fi
  else
    pass "C8"
  fi

  # C9 violation fixture: Closes-anchor mid-paragraph (PR #462 v1 catch)
  section "C9 self-test"
  BODY_L1="## Why"
  if [ -z "$BODY_L1" ]; then
    fail "C9" "empty body"
    EXIT_CODE=1
  elif echo "$BODY_L1" | grep -qE "^Closes #[0-9]+\$"; then
    pass "C9"
  else
    fail "C9" "Closes-anchor NOT strict format. L1='$BODY_L1'"; EXIT_CODE=1
  fi

  printf "\n${B}==== SELF-TEST SUMMARY ====${D}\n"
  printf "  ${G}PASS${D}: %d\n" "$PASS"
  printf "  ${R}FAIL${D}: %d (expected: 8 — one per violation check C1,C2,C3,C4,C5,C7,C8,C9)\n" "$FAIL"
  printf "  ${Y}INFO${D}: %d (expected: 1 — C6 dual-owned informational)\n" "$INFO"

  if [ "$FAIL" -eq 8 ] && [ "$INFO" -eq 1 ]; then
    printf "  ${G}self-test green${D} — 8 FAIL + 1 INFO = expected outcome (8 violation checks C1-C5 + C7-C9 + 1 dual-owned INFO C6)\n"
    exit 0
  else
    printf "  ${R}self-test RED${D} — expected 8 FAIL + 1 INFO, got FAIL=%d INFO=%d\n" "$FAIL" "$INFO"
    exit 1
  fi
fi

# Live mode — requires PR_NUMBER
PR_NUMBER="${1:-${PR_NUMBER:-}}"
if [ -z "$PR_NUMBER" ]; then
  echo "Usage: bash $0 <PR_NUMBER>  |  PR_NUMBER=N bash $0  |  bash $0 --self-test" >&2
  exit 2
fi

section "PR #${PR_NUMBER} 4-cat doctrinal verification (ADR-0050)"
section "Repo: ${REPO}"

# Fetch PR data
PR_JSON="$(gh api "repos/${REPO}/pulls/${PR_NUMBER}" 2>/dev/null)" || {
  echo "ERROR: gh api failed for PR #${PR_NUMBER}" >&2
  exit 2
}

LABELS="$(echo "$PR_JSON" | jq -r '.labels[].name' 2>/dev/null)"
BODY_L1="$(echo "$PR_JSON" | jq -r '.body // ""' 2>/dev/null | head -1)"
FILES="$(gh api "repos/${REPO}/pulls/${PR_NUMBER}/files" --jq '.[] | .path' 2>/dev/null || echo "")"

label_count=0
[ -n "$LABELS" ] && label_count=$(echo "$LABELS" | wc -l)
file_count=0
[ -n "$FILES" ] && file_count=$(echo "$FILES" | wc -l)

printf "  L1: %s\n" "${BODY_L1:0:80}"
printf "  Labels (%d):\n" "$label_count"
echo "$LABELS" | sed 's/^/    /'
printf "  Files (%d):\n" "$file_count"
echo "$FILES" | sed 's/^/    /'
echo

# Helper: does PR have this label exactly?
has_label() { echo "$LABELS" | grep -qxF "$1"; }

# ----------------------------------------------------------------------------
# C1: type:bug PRs MUST have needs-tester-signoff
# ----------------------------------------------------------------------------
section "C1: type:bug + needs-tester-signoff"
if has_label "type:bug"; then
  if has_label "needs-tester-signoff"; then
    pass "C1 — type:bug PR has needs-tester-signoff"
  else
    fail "C1" "type:bug PR MUST have needs-tester-signoff (PR #450 squash-time catch, ADR-0012 Layer 3)"
  fi
else
  pass "C1 — not type:bug (N/A)"
fi

# ----------------------------------------------------------------------------
# C2: type:bug PRs MUST have cc:tester
# ----------------------------------------------------------------------------
section "C2: type:bug + cc:tester"
if has_label "type:bug"; then
  if has_label "cc:tester"; then
    pass "C2 — type:bug PR has cc:tester"
  else
    fail "C2" "type:bug PR MUST have cc:tester (PR #450 squash-time catch, ADR-0012 Layer 3)"
  fi
else
  pass "C2 — not type:bug (N/A)"
fi

# ----------------------------------------------------------------------------
# C3: status:ready PRs MUST have cc:human (owner squash gate)
# ----------------------------------------------------------------------------
section "C3: status:ready + cc:human"
if has_label "status:ready"; then
  if has_label "cc:human"; then
    pass "C3 — status:ready PR has cc:human (owner squash gate satisfied)"
  else
    fail "C3" "status:ready PR MUST have cc:human (owner squash gate, PR #458 v1 catch, ADR-0048 §Type-driven table)"
  fi
else
  pass "C3 — not status:ready (N/A)"
fi

# ----------------------------------------------------------------------------
# C4: type:docs PRs touching .claude/ MUST have agent:architect OR agent:product-manager
# ----------------------------------------------------------------------------
section "C4: type:docs + .claude/ + soul-amend lane agent"
if has_label "type:docs"; then
  if echo "$FILES" | grep -qE "^\.claude/"; then
    if has_label "agent:architect" || has_label "agent:product-manager"; then
      pass "C4 — type:docs PR touching .claude/ has soul-amend lane agent (architect/PM)"
    else
      fail "C4" "type:docs PR touching .claude/ MUST have agent:architect OR agent:product-manager (soul-amend lane, PR #458 sister)"
    fi
  else
    pass "C4 — type:docs PR not touching .claude/ (N/A)"
  fi
else
  pass "C4 — not type:docs (N/A)"
fi

# ----------------------------------------------------------------------------
# C5: type:docs PRs touching scripts/ MUST NOT have agent:tester
# ----------------------------------------------------------------------------
section "C5: type:docs + scripts/ NOT agent:tester"
if has_label "type:docs"; then
  if echo "$FILES" | grep -qE "^scripts/"; then
    if has_label "agent:tester"; then
      fail "C5" "type:docs PR touching scripts/ MUST NOT have agent:tester (out-of-lane, Issue #412 sister)"
    else
      pass "C5 — type:docs PR touching scripts/ lacks agent:tester"
    fi
  else
    pass "C5 — type:docs PR not touching scripts/ (N/A)"
  fi
else
  pass "C5 — not type:docs (N/A)"
fi

# ----------------------------------------------------------------------------
# C6: PRs with multiple agent:* labels are dual-owned (informational)
# ----------------------------------------------------------------------------
section "C6: dual agent:* (RETRO-007 §Dual agent:* labels doctrine, informational)"
agent_count=0
while IFS= read -r lbl; do
  case "$lbl" in agent:*) agent_count=$((agent_count+1));; esac
done <<< "$LABELS"
if [ "$agent_count" -gt 1 ]; then
  info "C6 — dual-owned: $agent_count agent:* labels (RETRO-007 §Dual agent:* labels doctrine codification; not a fail)"
else
  pass "C6 — single or zero agent:* labels (OK)"
fi

# ----------------------------------------------------------------------------
# C7: type:incident PRs MUST have priority:P0
# ----------------------------------------------------------------------------
section "C7: type:incident + priority:P0"
if has_label "type:incident"; then
  if has_label "priority:P0"; then
    pass "C7 — type:incident PR has priority:P0"
  else
    fail "C7" "type:incident PR MUST have priority:P0 (ADR-0012 §Priority matrix)"
  fi
else
  pass "C7 — not type:incident (N/A)"
fi

# ----------------------------------------------------------------------------
# C8: status:in-review PRs MUST NOT also have status:ready (mutual exclusion)
# ----------------------------------------------------------------------------
section "C8: status:in-review vs status:ready mutual exclusion"
if has_label "status:in-review"; then
  if has_label "status:ready"; then
    fail "C8" "status:in-review PR MUST NOT also have status:ready (ADR-0012 future work, mutual exclusion)"
  else
    pass "C8 — status:in-review PR lacks status:ready"
  fi
else
  pass "C8 — not status:in-review (N/A)"
fi

# ----------------------------------------------------------------------------
# C9: Closes-anchor strict format (uppercase C + line 1 + NO trailing text)
# ----------------------------------------------------------------------------
section "C9: Closes-anchor strict format (L1 = 'Closes #N' exactly)"
if [ -z "$BODY_L1" ]; then
  fail "C9" "PR body empty — Closes-anchor missing"
elif echo "$BODY_L1" | grep -qE "^Closes #[0-9]+\$"; then
  pass "C9 — Closes-anchor strict format: L1 = '${BODY_L1}'"
else
  fail "C9" "Closes-anchor NOT strict format. L1='${BODY_L1}' (expected: 'Closes #N' uppercase C, line 1, no trailing text — PR #462 v1 catch)"
fi

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
printf "\n${B}==== SUMMARY (PR #${PR_NUMBER}) ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"
printf "  ${Y}INFO${D}: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0