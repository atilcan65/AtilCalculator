#!/usr/bin/env bash
# d060-branch-base-check.sh — RETRO-009 §1 regression test (9 TCs).
#
# Why this test exists
# --------------------
# Sprint 14 P1 cluster observed chain dep pollution in PR #509 (3 scripts/ files
# duplicated PR #506 squash @ 226b546). Manual fix required `git reset --hard
# origin/main` + `git cherry-pick` playbook. RETRO-009 §1 codification proposes
# tooling-level prevention: a pre-push hook that checks `git merge-base HEAD
# origin/main` and exits non-zero when origin/main is NOT an ancestor of HEAD
# (i.e., branch is missing squashed commits).
#
# d060 = 9 TCs (TC1-TC9) programmatic enforcement via bash + fake-git-repo
# fixture pattern. Sister-pattern to scripts/tests/d058-claim-wip-workstream.sh
# (--self-test flag, fake-binary factory).
#
# Sister-pattern family (10+1=11-sister d-test framework, RETRO-009 §6):
#   - d031 (base Layer 2)
#   - d046 (Issue #413 jq-filter guard)
#   - d048 (Issue #425 AC2.1 layered defense)
#   - d050b (Issue #440 behavioral workflow test framework)
#   - d051 (Issue #414 RETRO-005 #26 regression anchor)
#   - d052 (Issue #461 agent-watch.sh hardening)
#   - d053 (Issue #463 ADR-0050 pre-merge 4-cat verification)
#   - d054 (Issue #468 §Closes-anchor strict format)
#   - d058 (Issue #505 ADR-0038 §Work-Stream Awareness impl)
#   - d060 (STORY-016 / Issue #517 RETRO-009 §1 pre-push branch-base) — THIS FILE
#
# 9 TCs (per STORY-016 / docs/backlog/STORY-016.md AC2):
#   TC1: branch base matches origin/main HEAD → exit 0 (core happy path)
#   TC2: branch base stale (origin/main advanced) → exit 1, message present
#   TC3: chain dep pollution detected → exit 1, message present (PR #509 sister)
#   TC4: branch with merge commit → exit 0 (no false positive on merge commits)
#   TC5: branch with squash-merge referenced → exit 1 (chain dep detected)
#   TC6: detached HEAD → exit 0
#   TC7: empty stdin (no refs) → exit 0 (nothing to check)
#   TC8: detached HEAD with no origin/main → exit 2 (config error)
#   TC9: non-git directory → exit 2 (config error)
#
# Usage:
#   bash d060-branch-base-check.sh --self-test     # run inline fixture (9 TCs)
#
# Exit codes:
#   0 — all PASS (TC1-TC9 green, branch-base check impl'd)
#   1 — at least one FAIL (RED state — impl missing OR fixture bug)
#   2 — preflight failure (missing tool, etc.)
#
# RED-first discipline (ADR-0044):
#   Pre-impl: TC1, TC2, TC3, TC4, TC5 must FAIL (hook doesn't exist yet)
#   Post-impl: all 9 TCs must PASS
#
# Run standalone: bash scripts/tests/d060-branch-base-check.sh --self-test

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOOK_SH="${REPO_ROOT}/scripts/pre-push/branch-base-check.sh"

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
command -v git >/dev/null 2>&1 || { echo "ERROR: git required" >&2; exit 2; }
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
[ -f "$HOOK_SH" ] || { echo "ERROR: branch-base-check.sh not found at $HOOK_SH (impl not yet written)" >&2; exit 2; }

# Self-test mode
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d060 self-test (9 TCs per RETRO-009 §1 pre-push branch-base check)${D}\n"
printf "${B}==================================================================${D}\n"
printf "  Impl under test: %s\n" "$HOOK_SH"
printf "  Fixture: fake-git-repo factory (creates tmpdir git repo, simulates branches)\n"
printf "  RED-first: pre-impl TCs must FAIL.\n"
printf "  Post-impl: all 9 TCs must PASS.\n\n"

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# Test sandbox
TEST_TMPDIR="$(mktemp -d /tmp/d060-XXXXXX)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# --- fake-git-repo factory ---
# Usage: make_fake_repo <repo_dir> [branch_layout]
#   branch_layout:
#     "clean"             → main + feat/foo (clean base, no chain dep)
#     "stale"             → main + feat/foo (feat/foo branched from old main, main advanced)
#     "merge-commit"      → main + feat/foo with a merge commit on foo
#     "squash-ref"        → main + feat/foo where foo has a commit referencing a PR # squash
#     "detached"          → detached HEAD (no branch checked out)
#     "no-origin"         → no origin/main remote ref (config error)
#   Writes a flag file "$repo_dir/.layout" so the test can identify.
make_fake_repo() {
  local repo_dir="$1"
  local layout="${2:-clean}"

  mkdir -p "$repo_dir"
  cd "$repo_dir"
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test Dev"
  git config commit.gpgsign false

  case "$layout" in
    clean)
      # Initial commit on main
      echo "main-1" > README.md
      git add README.md
      git commit -q -m "main commit 1"
      # Create feat/foo branched from current main
      git checkout -q -b feat/foo
      echo "foo-1" >> README.md
      git commit -q -am "feat: foo commit"
      # Set up origin/main = current main
      git checkout -q main
      git update-ref refs/remotes/origin/main HEAD
      # HEAD is on main, origin/main = main HEAD
      ;;
    stale)
      # Branch feat/foo from OLD main
      echo "main-1" > README.md
      git add README.md
      git commit -q -m "main commit 1"
      git checkout -q -b feat/foo
      echo "foo-1" >> README.md
      git commit -q -am "feat: foo commit"
      # Now main advances (squash simulated): commit on main after branching
      git checkout -q main
      echo "main-2" >> README.md
      git commit -q -am "main commit 2 (squash)"
      git update-ref refs/remotes/origin/main HEAD
      # Switch back to feat/foo — its base is now stale
      git checkout -q feat/foo
      ;;
    merge-commit)
      # feat/foo and main modify DIFFERENT files to avoid merge conflict
      echo "main-1" > main.txt
      git add main.txt
      git commit -q -m "main commit 1"
      git checkout -q -b feat/foo
      echo "foo-1" > foo.txt
      git add foo.txt
      git commit -q -m "feat: foo commit (new file)"
      # Main advances with a different file
      git checkout -q main
      echo "main-2" >> main.txt
      git commit -q -am "main commit 2 (different file)"
      git checkout -q feat/foo
      # Merge main into foo (no conflict — different files)
      git merge -q main --no-ff -m "merge main into foo"
      # Update origin/main = current main HEAD
      git update-ref refs/remotes/origin/main refs/heads/main
      ;;
    squash-ref)
      # Branch feat/foo that contains a commit message referencing a squash PR
      echo "main-1" > README.md
      git add README.md
      git commit -q -m "main commit 1"
      git checkout -q -b feat/foo
      echo "foo-1" >> README.md
      git commit -q -am "feat: foo commit (Refs #509 squash)"
      git update-ref refs/remotes/origin/main refs/heads/main
      ;;
    detached)
      echo "main-1" > README.md
      git add README.md
      git commit -q -m "main commit 1"
      # Detached HEAD on main
      git checkout -q --detach HEAD
      git update-ref refs/remotes/origin/main refs/heads/main
      ;;
    no-origin)
      echo "main-1" > README.md
      git add README.md
      git commit -q -m "main commit 1"
      git checkout -q -b feat/foo
      # NO origin/main ref set
      ;;
    *)
      echo "ERROR: unknown layout: $layout" >&2
      return 1
      ;;
  esac

  echo "$layout" > "$repo_dir/.layout"
}

# --- run_hook helper ---
# Usage: run_hook <repo_dir> [stdin_data]
# Sets globals: HOOK_OUT, HOOK_RC
run_hook() {
  local repo_dir="$1"
  local stdin_data="${2:-}"

  # cd into the repo, pipe stdin (with trailing newline — git pre-push contract),
  # invoke hook directly. printf '%s' alone strips trailing newlines via $(...),
  # so we add a literal newline at the end to ensure bash `read` inside the
  # hook sees a complete line.
  HOOK_OUT="$(cd "$repo_dir" && printf '%s\n' "$stdin_data" | bash "$HOOK_SH" 2>&1)"
  HOOK_RC=$?
}

# Standard helper: build pre-push stdin for a given local ref + sha
# Note: trailing newline is REQUIRED (sister-pattern to git pre-push contract;
# without it, `read` inside the hook sees EOF without a line terminator and
# skips the last ref line — bash read quirk).
make_push_stdin() {
  local local_ref="$1"
  local local_sha="$2"
  local remote_ref="$3"
  local remote_sha="$4"
  printf '%s %s %s %s\n' "$local_ref" "$local_sha" "$remote_ref" "$remote_sha"
}

# ============================================================================
# TC1: branch base matches origin/main HEAD → exit 0 (core happy path)
# ============================================================================
section "TC1: clean branch base (matches origin/main HEAD) → exit 0"
repo="$TEST_TMPDIR/tc1"
make_fake_repo "$repo" "clean"
cd "$repo"
local_sha="$(git rev-parse HEAD)"
run_hook "$repo" "$(make_push_stdin refs/heads/feat/foo $local_sha refs/heads/feat/foo 0000000000000000000000000000000000000000)"
if [ "$HOOK_RC" = "0" ]; then
  pass "clean branch base (feat/foo branched from current main) → exit 0"
else
  fail "TC1 — expected exit 0 for clean branch base" \
    "got rc=$HOOK_RC out=$HOOK_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC2: branch base stale (origin/main advanced) → exit 1, message present
# ============================================================================
section "TC2: stale branch base (origin/main advanced past branch point) → exit 1 + message"
repo="$TEST_TMPDIR/tc2"
make_fake_repo "$repo" "stale"
cd "$repo"
local_sha="$(git rev-parse HEAD)"
run_hook "$repo" "$(make_push_stdin refs/heads/feat/foo $local_sha refs/heads/feat/foo 0000000000000000000000000000000000000000)"
if [ "$HOOK_RC" = "1" ]; then
  if echo "$HOOK_OUT" | grep -qiE "stale|rebase|chain dep|behind"; then
    pass "stale branch base → exit 1 + informative message"
  else
    fail "TC2 — exit 1 but no informative message" \
      "expected message containing stale/rebase/chain dep/behind. out=$HOOK_OUT"
    EXIT_CODE=1
  fi
else
  fail "TC2 — expected exit 1 for stale branch base" \
    "got rc=$HOOK_RC out=$HOOK_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC3: chain dep pollution detected → exit 1, message present (PR #509 sister)
# ============================================================================
section "TC3: chain dep pollution (commit message references squash PR) → exit 1 + message"
repo="$TEST_TMPDIR/tc3"
make_fake_repo "$repo" "squash-ref"
cd "$repo"
local_sha="$(git rev-parse HEAD)"
run_hook "$repo" "$(make_push_stdin refs/heads/feat/foo $local_sha refs/heads/feat/foo 0000000000000000000000000000000000000000)"
if [ "$HOOK_RC" = "1" ]; then
  if echo "$HOOK_OUT" | grep -qiE "chain dep|rebase|pollution|behind"; then
    pass "chain dep pollution detected → exit 1 + informative message"
  else
    fail "TC3 — exit 1 but no chain dep message" \
      "expected message containing chain dep/rebase/pollution. out=$HOOK_OUT"
    EXIT_CODE=1
  fi
else
  fail "TC3 — expected exit 1 for chain dep pollution" \
    "got rc=$HOOK_RC out=$HOOK_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC4: branch with merge commit → exit 0 (no false positive on merge commits)
# ============================================================================
section "TC4: branch with merge commit → exit 0 (no false positive)"
repo="$TEST_TMPDIR/tc4"
make_fake_repo "$repo" "merge-commit"
cd "$repo"
local_sha="$(git rev-parse HEAD)"
run_hook "$repo" "$(make_push_stdin refs/heads/feat/foo $local_sha refs/heads/feat/foo 0000000000000000000000000000000000000000)"
if [ "$HOOK_RC" = "0" ]; then
  pass "branch with merge commit → exit 0 (no false positive)"
else
  fail "TC4 — expected exit 0 for branch with merge commit" \
    "got rc=$HOOK_RC out=$HOOK_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC5: branch with squash-merge referenced in commit → exit 1 (chain dep)
# ============================================================================
section "TC5: branch commit message references squash → exit 1 (chain dep detected)"
repo="$TEST_TMPDIR/tc5"
make_fake_repo "$repo" "squash-ref"
cd "$repo"
# Verify fixture has the squash-ref marker
if ! git log --format=%s | grep -q "Refs #509 squash"; then
  fail "TC5 — fixture setup failed (squash-ref marker missing)" \
    "fixture setup bug, not impl bug"
  EXIT_CODE=1
else
  local_sha="$(git rev-parse HEAD)"
  run_hook "$repo" "$(make_push_stdin refs/heads/feat/foo $local_sha refs/heads/feat/foo 0000000000000000000000000000000000000000)"
  if [ "$HOOK_RC" = "1" ]; then
    pass "squash-merge referenced → exit 1 (chain dep detected)"
  else
    fail "TC5 — expected exit 1 for squash-merge reference" \
      "got rc=$HOOK_RC out=$HOOK_OUT"
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC6: detached HEAD → exit 0 (no branch context, but not a chain dep)
# ============================================================================
section "TC6: detached HEAD → exit 0 (no branch context, allowed)"
repo="$TEST_TMPDIR/tc6"
make_fake_repo "$repo" "detached"
cd "$repo"
local_sha="$(git rev-parse HEAD)"
run_hook "$repo" "$(make_push_stdin refs/heads/main $local_sha refs/heads/main 0000000000000000000000000000000000000000)"
if [ "$HOOK_RC" = "0" ]; then
  pass "detached HEAD → exit 0 (no branch context, allowed)"
else
  fail "TC6 — expected exit 0 for detached HEAD" \
    "got rc=$HOOK_RC out=$HOOK_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC7: empty stdin (no refs) → exit 0 (nothing to check)
# ============================================================================
section "TC7: empty stdin (no refs being pushed) → exit 0"
repo="$TEST_TMPDIR/tc7"
make_fake_repo "$repo" "clean"
run_hook "$repo" ""
if [ "$HOOK_RC" = "0" ]; then
  pass "empty stdin → exit 0 (nothing to check)"
else
  fail "TC7 — expected exit 0 for empty stdin" \
    "got rc=$HOOK_RC out=$HOOK_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC8: detached HEAD with no origin/main → exit 2 (config error)
# ============================================================================
section "TC8: detached HEAD + no origin/main → exit 2 (config error)"
repo="$TEST_TMPDIR/tc8"
make_fake_repo "$repo" "no-origin"
cd "$repo"
# Force detached HEAD
git checkout -q --detach HEAD 2>/dev/null || true
# Remove origin/main ref if it accidentally exists
git update-ref -d refs/remotes/origin/main 2>/dev/null || true
local_sha="$(git rev-parse HEAD)"
run_hook "$repo" "$(make_push_stdin refs/heads/feat/foo $local_sha refs/heads/feat/foo 0000000000000000000000000000000000000000)"
if [ "$HOOK_RC" = "2" ]; then
  pass "no origin/main → exit 2 (config error, sister-pattern to d031 TC7)"
else
  fail "TC8 — expected exit 2 for no origin/main" \
    "got rc=$HOOK_RC out=$HOOK_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC9: non-git directory → exit 2 (config error)
# ============================================================================
section "TC9: non-git directory → exit 2 (config error)"
repo="$TEST_TMPDIR/tc9"
mkdir -p "$repo"
# No git init → non-git directory
local_sha="0000000000000000000000000000000000000000"
run_hook "$repo" "$(make_push_stdin refs/heads/feat/foo $local_sha refs/heads/feat/foo 0000000000000000000000000000000000000000)"
if [ "$HOOK_RC" = "2" ]; then
  pass "non-git directory → exit 2 (config error)"
else
  fail "TC9 — expected exit 2 for non-git directory" \
    "got rc=$HOOK_RC out=$HOOK_OUT"
  EXIT_CODE=1
fi

# ============================================================================
printf "\n${B}==== SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"
printf "  ${Y}INFO${D}: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  echo
  echo "d060 REGRESSION FAILED — branch-base-check.sh contract violated."
  echo "Fix: ensure hook impl honors clean base, stale detection, chain dep detection, merge commit tolerance, detached HEAD, empty stdin, config errors."
  exit 1
fi
echo
echo "d060 REGRESSION PASS — branch-base-check.sh (RETRO-009 §1) contract honored."
exit 0