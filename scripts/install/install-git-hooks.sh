#!/usr/bin/env bash
# scripts/install/install-git-hooks.sh — Sprint 22 PIVOT followup (Issue #722)
#
# Idempotently installs all scripts/pre-push/*.sh into the local .git/hooks/
# directory with chmod 0755. Reconstructs the install step dropped during
# the Sprint 22 PIVOT atilcan65/* → atilproject/* org-migration.
#
# Sister-pattern to scripts/install/dev-studio-install-systemd.sh (idempotent,
# prints ✅/❌ status, exit 1 on preflight failure).
# Sister d-test: scripts/tests/d107-install-git-hooks.sh (6 TCs, RED-first per ADR-0044).
#
# Why this exists
# ---------------
# Per docs/product/vision.md L70, "direct push to `main` is forbidden (enforced
# by local pre-push hook + branch protection)". The hook source
# `scripts/pre-push/branch-base-check.sh` (3753 bytes, d060 9/9 PASS per
# RETRO-009 §1) is preserved in the repo, but the install step was dropped
# during Sprint 22 PIVOT org-migration. Without this script, fresh clones
# post-migration have NO automatic hook install.
#
# Usage:
#   bash scripts/install/install-git-hooks.sh
#   REPO_ROOT=/path/to/repo bash scripts/install/install-git-hooks.sh
#
# Exit codes:
#   0 — all hooks installed successfully (idempotent — safe to re-run)
#   1 — preflight failure (source hook missing, not a git repo, etc.)
#
# Env vars:
#   REPO_ROOT   override repo root (default: auto-detect from script location)
#
# Refs:
#   - Issue #722 (this issue)
#   - RETRO-009 §1 (pre-push chain dep pollution origin)
#   - d060 (sister d-test for the hook itself)
#   - d107 (sister d-test for THIS install script)
#   - ADR-0044 (RED-first TDD)
#   - ADR-0049 (d-test framework, ≥3 TCs minimum)
#   - ADR-0055 §1 (Cadence Rule 1 atomic — d-test file + INDEX.md same commit)

set -euo pipefail

# --- repo root detection (sister-pattern to dev-studio-install-systemd.sh L23) ---
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SRC_DIR="$REPO_ROOT/scripts/pre-push"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

# --- color/output (sister-pattern to dev-studio-install-systemd.sh L33-42) ---
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  C_GREEN="$(tput setaf 2)"; C_YELLOW="$(tput setaf 3)"; C_RED="$(tput setaf 1)"
  C_BOLD="$(tput bold)"; C_RESET="$(tput sgr0)"
else
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""; C_RESET=""
fi
log() { printf '%s[install-git-hooks]%s %s\n' "$C_BOLD" "$C_RESET" "$*"; }
ok()  { printf '%s[install-git-hooks]%s %s%s%s\n' "$C_BOLD" "$C_RESET" "$C_GREEN" "$*" "$C_RESET"; }
warn(){ printf '%s[install-git-hooks]%s %s%s%s\n' "$C_BOLD" "$C_RESET" "$C_YELLOW" "$*" "$C_RESET"; }
fail(){ printf '%s[install-git-hooks]%s %s%s%s\n' "$C_BOLD" "$C_RESET" "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

# --- preflight ---
log "preflight checks for repo: $REPO_ROOT"
log "  source dir: $SRC_DIR"
log "  hooks dir:  $HOOKS_DIR"

[ -d "$SRC_DIR" ] || fail "source dir missing: $SRC_DIR (required — branch-base-check.sh + sister hooks)"
[ -d "$HOOKS_DIR" ] || fail "hooks dir missing: $HOOKS_DIR (not a git repo? run 'git init' first)"

# --- discover source hooks ---
shopt -s nullglob
HOOKS=( "$SRC_DIR"/*.sh )
shopt -u nullglob

if [ "${#HOOKS[@]}" -eq 0 ]; then
  warn "no hooks found in $SRC_DIR (no *.sh files) — nothing to install"
  ok "install-git-hooks: 0 hook(s) installed (idempotent, no-op)"
  exit 0
fi

# --- install loop (idempotent: cp -f overwrites) ---
INSTALLED=0
for src in "${HOOKS[@]}"; do
  name="$(basename "$src")"
  dest="$HOOKS_DIR/$name"
  cp -f "$src" "$dest"
  chmod 0755 "$dest"
  ok "installed $name → $dest (chmod 0755)"
  INSTALLED=$((INSTALLED + 1))
done

ok "install-git-hooks: $INSTALLED hook(s) installed (idempotent — safe to re-run)"
exit 0