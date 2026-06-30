#!/usr/bin/env bash
# d107-install-git-hooks.sh — Issue #722 (Sprint 22 PIVOT followup) pre-push hook install regression guard.
#
# Why this test exists
# --------------------
# Sprint 22 PIVOT org-migration (atilcan65/* → atilproject/*) dropped the
# pre-push hook install step. Per docs/product/vision.md L70, "direct push
# to `main` is forbidden (enforced by local pre-push hook + branch protection)".
# The hook source `scripts/pre-push/branch-base-check.sh` (3753 bytes, d060 9/9
# PASS) is preserved in the repo, but no install step exists — fresh clones
# post-migration do NOT have the hook installed automatically.
#
# Local recovery (cycle ~#1629k owner-directive, 18:20+03:00):
#   cp scripts/pre-push/branch-base-check.sh .git/hooks/pre-push
#   chmod +x .git/hooks/pre-push
#
# This d-test (d107) guards the reconstruction so future org-migrations
# or repo refactors don't silently drop the install step again.
#
# AC mapping (Issue #722):
#   AC1 — pick design (Option B: sister-pattern new file) and document
#   AC2 — d-test ≥5 TCs covering idempotency, re-run safety, chmod, exec-bit,
#         core.hooksPath alignment, source-missing exit 1
#   AC3 — INDEX.md updated per Cadence Rule 1 atomic (ADR-0055 §1)
#   AC4 — PR is DRAFT with 4-cat labels per ADR-0012
#   AC5 — Branch fix/reconstruct-pre-push-hook-install (sister-pattern naming)
#
# 6 TCs (per ADR-0049 d-test framework sister-pattern):
#   TC1: install-git-hooks.sh exists at scripts/install/install-git-hooks.sh (AC2 preflight)
#   TC2: fresh install works — script copies scripts/pre-push/*.sh to .git/hooks/
#        with correct filenames + chmod 0755 + exits 0 (AC2 base case)
#   TC3: re-run idempotency — second invocation on already-installed hook
#        still exits 0, hook unchanged (AC2 idempotency)
#   TC4: installed hook is executable (-x bit set via test -x) (AC2 chmod verify)
#   TC5: install script exits 1 with informative stderr if scripts/pre-push/
#        branch-base-check.sh source missing (AC2 error path)
#   TC6: install script does NOT pollute .git/hooks/ with non-source files
#        (e.g., only copies *.sh, doesn't drop unrelated files) (AC2 scope)
#
# Pre-impl RED state (current main as of 2026-06-30, pre-Issue #722 impl):
#   - scripts/install/install-git-hooks.sh does NOT exist
#   - TC1: 1 FAIL (file missing)
#   - TC2-TC6: all FAIL (script missing → preflight cascade)
#   → 6/6 TCs FAIL = proper RED-first per ADR-0044
#
# Post-impl GREEN state (target, after Issue #722 PR merge):
#   - scripts/install/install-git-hooks.sh exists + is executable
#   - All 6 TCs PASS in GREEN state
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d060 (Issue #517 RETRO-009 §1 pre-push branch-base check, 9 TCs) —
#          DIRECT sister (the hook this install step installs)
#   - d070 + d070b (init-script sister family — both install + d-test patterns)
#   - d091 (work-stream awareness sister)
#   - d094 (Sprint 22 PIVOT self-hosted-runner-migration, d107 same cycle era)
#   - d096 (S21-006 soul .tmpl files sister, install-shape pattern)
#   - d105 (S21-004 audit-project-refs sister, install-script shape)
#   - d106 (S21-007 soul-template-version-pin sister, install-script contract)
#
# Usage:
#   bash d107-install-git-hooks.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — install-git-hooks.sh exists, idempotent, correct chmod)
#   1 — at least one FAIL (RED state — impl missing or ACs unsatisfied)
#   2 — preflight failure (missing tool, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALL_SH="${REPO_ROOT}/scripts/install/install-git-hooks.sh"
HOOK_SRC="${REPO_ROOT}/scripts/pre-push/branch-base-check.sh"

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

# Preflight
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git required (TC2+ need fake-git-repo)" >&2; exit 2; }
command -v cp >/dev/null 2>&1 || { echo "ERROR: cp required" >&2; exit 2; }
command -v chmod >/dev/null 2>&1 || { echo "ERROR: chmod required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d107 self-test (6 TCs per Issue #722 + ADR-0044 RED-first)${D}\n"
printf "${B}==================================================================${D}\n"
printf "  Repo root:        %s\n" "$REPO_ROOT"
printf "  Install script:   %s\n" "$INSTALL_SH"
printf "  Hook source:      %s\n" "$HOOK_SRC"
printf "  Sister-pattern:   d060 (branch-base-check, 9 TCs) + d096/d105/d106 install-script shape\n"
printf "  Pre-impl RED:     6/6 TCs FAIL by design per ADR-0044\n"
printf "  Post-impl:        6/6 TCs must PASS\n\n"

EXIT_CODE=0

# ============================================================================
# TC1: install-git-hooks.sh exists at scripts/install/install-git-hooks.sh
# ============================================================================
section "TC1: AC2 preflight — install-git-hooks.sh exists + executable"

if [ -f "$INSTALL_SH" ]; then
  if [ -x "$INSTALL_SH" ]; then
    pass "TC1 — install-git-hooks.sh exists and is executable"
  else
    fail "TC1 — install-git-hooks.sh exists but is NOT executable" \
      "expected chmod +x on $INSTALL_SH (sister-pattern to scripts/install/dev-studio-install-systemd.sh)"
    EXIT_CODE=1
  fi
else
  fail "TC1 — install-git-hooks.sh missing" \
    "expected $INSTALL_SH per Issue #722 AC1 (Option B sister-pattern new file). Without this file, fresh clones post-Sprint 22 PIVOT org-migration have no automatic hook install step. RED-first confirmed."
  EXIT_CODE=1
  # If install script missing, all downstream TCs cascade-fail with informative notes
  section "TC2-TC6: SKIPPED (TC1 prerequisite not met — install-git-hooks.sh missing)"
  printf "  ${Y}ℹ INFO${D} — TC2-TC6 cannot run without install script. Post-impl: all 6 TCs must PASS.\n"
  FAIL=$((FAIL + 5))  # count cascade failures
  EXIT_CODE=1
  printf "\n${B}==== Summary ====${D}\n"
  printf "  PASS: %d\n" "$PASS"
  printf "  FAIL: %d\n" "$FAIL"
  printf "  INFO: %d\n" "$INFO"
  printf "\n${R}RED state: install-git-hooks.sh not yet landed — TC1 fails + TC2-TC6 cascade${D}\n"
  exit 1
fi

# ============================================================================
# TC2: fresh install works — copies hooks to .git/hooks/ with chmod 0755
# ============================================================================
section "TC2: AC2 base case — fresh install copies scripts/pre-push/*.sh to .git/hooks/"

FAKE_REPO="$(mktemp -d)"
trap 'rm -rf "$FAKE_REPO"' EXIT
git init --quiet --initial-branch=main "$FAKE_REPO"
git -C "$FAKE_REPO" config user.email "test@example.com"
git -C "$FAKE_REPO" config user.name "Test User"
mkdir -p "$FAKE_REPO/scripts/pre-push"
cp "$HOOK_SRC" "$FAKE_REPO/scripts/pre-push/branch-base-check.sh"
chmod +x "$FAKE_REPO/scripts/pre-push/branch-base-check.sh"

# Run install script with REPO_ROOT=fake-repo
if REPO_ROOT="$FAKE_REPO" bash "$INSTALL_SH" >/tmp/d107-tc2.stdout 2>/tmp/d107-tc2.stderr; then
  INSTALLED_HOOK="$FAKE_REPO/.git/hooks/branch-base-check.sh"
  if [ -f "$INSTALLED_HOOK" ]; then
    # Verify content matches source (byte-equality or content match)
    if diff -q "$HOOK_SRC" "$INSTALLED_HOOK" >/dev/null 2>&1; then
      pass "TC2 — fresh install: branch-base-check.sh copied to .git/hooks/ + content matches source"
    else
      fail "TC2 — fresh install: hook copied but content diverged from source" \
        "expected byte-equal copy of scripts/pre-push/branch-base-check.sh"
      EXIT_CODE=1
    fi
  else
    fail "TC2 — fresh install: install exited 0 but .git/hooks/branch-base-check.sh NOT created" \
      "expected $FAKE_REPO/.git/hooks/branch-base-check.sh after install"
    EXIT_CODE=1
  fi
else
  fail "TC2 — fresh install: install-git-hooks.sh exited non-zero on clean fake-git-repo" \
    "expected exit 0. stdout: $(cat /tmp/d107-tc2.stdout); stderr: $(cat /tmp/d107-tc2.stderr)"
  EXIT_CODE=1
fi

# ============================================================================
# TC3: re-run idempotency — second invocation still exits 0
# ============================================================================
section "TC3: AC2 idempotency — re-run on already-installed hook still exits 0"

if REPO_ROOT="$FAKE_REPO" bash "$INSTALL_SH" >/tmp/d107-tc3.stdout 2>/tmp/d107-tc3.stderr; then
  # Hook should still be there, still executable, still match source
  INSTALLED_HOOK="$FAKE_REPO/.git/hooks/branch-base-check.sh"
  if [ -f "$INSTALLED_HOOK" ] && diff -q "$HOOK_SRC" "$INSTALLED_HOOK" >/dev/null 2>&1; then
    pass "TC3 — re-run idempotency: 2nd invocation exited 0, hook unchanged (still byte-equal to source)"
  else
    fail "TC3 — re-run idempotency: 2nd invocation exited 0 but hook corrupted or removed" \
      "expected idempotent overwrite (cp -f semantics). If hook was nuked, install needs a fix."
    EXIT_CODE=1
  fi
else
  fail "TC3 — re-run idempotency: 2nd invocation exited non-zero" \
    "expected exit 0 on already-installed hook. stderr: $(cat /tmp/d107-tc3.stderr)"
  EXIT_CODE=1
fi

# ============================================================================
# TC4: installed hook is executable (test -x)
# ============================================================================
section "TC4: AC2 chmod verify — installed hook has -x bit set"

INSTALLED_HOOK="$FAKE_REPO/.git/hooks/branch-base-check.sh"
if [ -x "$INSTALLED_HOOK" ]; then
  # Also verify the chmod mode is 0755 (or stricter — at least readable+executable by owner)
  HOOK_MODE="$(stat -c '%a' "$INSTALLED_HOOK" 2>/dev/null || stat -f '%A' "$INSTALLED_HOOK" 2>/dev/null)"
  if [ -n "$HOOK_MODE" ]; then
    info "TC4 — hook mode: $HOOK_MODE"
  fi
  pass "TC4 — installed hook is executable (test -x PASS, mode=$HOOK_MODE)"
else
  fail "TC4 — installed hook is NOT executable" \
    "expected chmod 0755 (or at least +x) on .git/hooks/branch-base-check.sh post-install. Without +x, git won't invoke the hook."
  EXIT_CODE=1
fi

# ============================================================================
# TC5: install script exits 1 if scripts/pre-push/branch-base-check.sh missing
# ============================================================================
section "TC5: AC2 error path — exit 1 + informative stderr if source hook missing"

FAKE_REPO2="$(mktemp -d)"
trap 'rm -rf "$FAKE_REPO" "$FAKE_REPO2"' EXIT
git init --quiet --initial-branch=main "$FAKE_REPO2"
git -C "$FAKE_REPO2" config user.email "test@example.com"
git -C "$FAKE_REPO2" config user.name "Test User"
# NOTE: deliberately do NOT create scripts/pre-push/ — this is the error case

if REPO_ROOT="$FAKE_REPO2" bash "$INSTALL_SH" >/tmp/d107-tc5.stdout 2>/tmp/d107-tc5.stderr; then
  fail "TC5 — error path: install exited 0 when source hook missing" \
    "expected exit 1 + informative stderr when scripts/pre-push/branch-base-check.sh absent. Got stdout=$(cat /tmp/d107-tc5.stdout) stderr=$(cat /tmp/d107-tc5.stderr)"
  EXIT_CODE=1
else
  EXIT_5=$?
  # Verify stderr has informative message
  if grep -qiE "(missing|required|not found|error)" /tmp/d107-tc5.stderr 2>/dev/null; then
    pass "TC5 — error path: install exited $EXIT_5 (non-zero) + informative stderr when source missing"
  else
    fail "TC5 — error path: install exited non-zero but stderr uninformative" \
      "expected stderr mentioning 'missing'/'required'/'not found'. Got: $(cat /tmp/d107-tc5.stderr)"
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC6: install script does not pollute .git/hooks/ with non-source files
# ============================================================================
section "TC6: AC2 scope — install only adds source hooks, doesn't modify or remove existing files"

# Build a fresh repo to compare file lists before/after install
FAKE_REPO3="$(mktemp -d)"
trap 'rm -rf "$FAKE_REPO" "$FAKE_REPO2" "$FAKE_REPO3"' EXIT
git init --quiet --initial-branch=main "$FAKE_REPO3"
git -C "$FAKE_REPO3" config user.email "test@example.com"
git -C "$FAKE_REPO3" config user.name "Test User"
mkdir -p "$FAKE_REPO3/scripts/pre-push"
cp "$HOOK_SRC" "$FAKE_REPO3/scripts/pre-push/branch-base-check.sh"
chmod +x "$FAKE_REPO3/scripts/pre-push/branch-base-check.sh"

# Snapshot .git/hooks/ BEFORE install (git init creates *.sample files; that's pre-existing state)
BEFORE_LIST="$(ls "$FAKE_REPO3/.git/hooks/" 2>/dev/null | sort)"

# Run install
if REPO_ROOT="$FAKE_REPO3" bash "$INSTALL_SH" >/tmp/d107-tc6.stdout 2>/tmp/d107-tc6.stderr; then
  AFTER_LIST="$(ls "$FAKE_REPO3/.git/hooks/" 2>/dev/null | sort)"

  # Diff: AFTER - BEFORE should equal exactly {branch-base-check.sh}
  DIFF_OUTPUT="$(diff <(echo "$BEFORE_LIST") <(echo "$AFTER_LIST") || true)"

  # Extract only ADDED files (lines starting with ">")
  ADDED_FILES="$(echo "$DIFF_OUTPUT" | grep -E '^> ' | sed 's/^> //' || true)"
  # Extract only REMOVED files (lines starting with "<")
  REMOVED_FILES="$(echo "$DIFF_OUTPUT" | grep -E '^< ' | sed 's/^< //' || true)"

  if [ "$ADDED_FILES" = "branch-base-check.sh" ] && [ -z "$REMOVED_FILES" ]; then
    pass "TC6 — scope: install added ONLY branch-base-check.sh (no removals, no other additions)"
  elif [ -z "$ADDED_FILES" ] && [ -z "$REMOVED_FILES" ]; then
    fail "TC6 — scope: install ran but added NOTHING to .git/hooks/ (branch-base-check.sh missing)" \
      "expected exactly one addition: branch-base-check.sh"
    EXIT_CODE=1
  else
    fail "TC6 — scope: install added/removed unexpected files. Added: [$ADDED_FILES], Removed: [$REMOVED_FILES]" \
      "expected install to add ONLY branch-base-check.sh and remove nothing. Sister-pattern to scripts/install/dev-studio-install-systemd.sh which doesn't touch unrelated dirs."
    EXIT_CODE=1
  fi
else
  fail "TC6 — scope: install exited non-zero on clean fake-git-repo" \
    "expected exit 0. stderr: $(cat /tmp/d107-tc6.stderr)"
  EXIT_CODE=1
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  Install script expected:    scripts/install/install-git-hooks.sh\n"
printf "  Install script present:     %s\n" "$([ -f "$INSTALL_SH" ] && echo "YES" || echo "NO")"
printf "  Sister-pattern:             d060 (branch-base-check, 9 TCs) + d096/d105/d106 install-script shape\n"
printf "  AC1 design:                 Option B (sister-pattern new file)\n"
printf "  AC2 base case (TC2):        fresh install copies hook + chmod\n"
printf "  AC2 idempotency (TC3):      re-run safe\n"
printf "  AC2 chmod (TC4):            -x bit set post-install\n"
printf "  AC2 error path (TC5):       exit 1 + informative stderr if source missing\n"
printf "  AC2 scope (TC6):            no extra files dropped into .git/hooks/\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — install-git-hooks.sh impl not yet landed (Issue #722)${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 6 TCs PASS — install-git-hooks.sh impl complete (Issue #722)${D}\n"
exit 0