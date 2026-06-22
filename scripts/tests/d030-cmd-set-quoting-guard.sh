#!/usr/bin/env bash
# d030-cmd-set-quoting-guard.sh — regression for Issue #267
# (P0 watcher crash-loop: agent-watch.sh cmd_set calls missing JSON quotes)
#
# Why this test exists
# --------------------
# Issue #267: PR #247 (fix(state): cmd_set JSON contract per ADR-0034) made
# `scripts/agent-state.sh cmd_set` require JSON-parseable input. It validates
# the 3rd arg with `jq -e .` and exits 2 on plain strings. But the CALLER
# (`scripts/agent-watch.sh`) was not updated — it still passed raw timestamps
# like `2026-06-22T17:19:44Z` (without JSON quotes). All 4 systemd watcher
# services crash-looped with exit 2/INVALIDARGUMENT every 5-9s since 16:16:11Z.
# Total: ~440 crashes in 20 min before orchestrator hotfix (commit d0c999c).
#
# Fix: wrap value in JSON quotes — `\"$VAR\"` (bash unescapes to `"$VAR"`,
# which IS a valid JSON string).
#
# This regression test GUARDS future callers by greppping all `STATE_HELPER`
# set call sites and verifying the value arg is JSON-quoted. If anyone adds
# a new caller and forgets the `\"...\"` wrap, T1 fails RED before the
# watcher crashes in production.
#
# Test cases:
#   T1: All STATE_HELPER set callers in agent-watch.sh use JSON-quoted values
#       (greps each call site, verifies `\"...\"` wrap pattern; bare $VAR fails)
#   T2: Each STATE_HELPER set key is in the known allowlist
#       (catches typos like last_seen_uct vs last_seen_utc)
#   T3: No callers pass JSON arrays through cmd_set (d023 T10 bug class)
#       (catches the "store JSON array as string" regression — arrays must go
#       through inline jq atomic edit, NOT cmd_set)
#   T4: agent-watch.sh has at least one comment/header referencing ADR-0034
#       OR Issue #267 (catches "removed the doc, forgot the contract" regressions)
#   T5: Hotfix commit d0c999c (or descendant) referencing Issue #267 exists
#       (catches accidental reverts that lose the audit trail)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d030-cmd-set-quoting-guard.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH_SH="$SCRIPT_DIR/../agent-watch.sh"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;32m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; R=""; B=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 127
fi
if [ ! -r "$WATCH_SH" ]; then
  echo "ERROR: agent-watch.sh not found at $WATCH_SH" >&2; exit 127
fi

# ============================================================================
# T1: All STATE_HELPER set callers use JSON-quoted values
# ============================================================================
section "T1: STATE_HELPER set callers — JSON-quoted values (\"...\" wrap)"

# Find all callers. Pattern: "STATE_HELPER" set "ROLE" KEY VALUE...
# We capture the line number, key, and value for each match.
caller_count=0
caller_pass=0
caller_fail_lines=()
while IFS=: read -r lineno rest; do
  caller_count=$((caller_count + 1))
  # Extract the 4th positional arg (value). Pattern: STATE_HELPER" set "ROLE" KEY VALUE
  # Use awk for robustness on quoted args.
  value="$(echo "$rest" | awk '
    {
      # Split on whitespace. parts[1..3] = STATE_HELPER / set / ROLE
      # (each may have surrounding " quotes from the source file).
      # parts[4] = KEY (unquoted in source).
      # parts[5..] = VALUE tokens (each may have surrounding " quotes).
      # We strip outer " from the joined value to get the bash-literal text.
      n = split($0, parts, " ")
      if (n < 5) { print ""; next }
      val = ""
      for (i = 5; i <= n; i++) {
        if (parts[i] ~ /^>/) break
        val = (val == "" ? parts[i] : val " " parts[i])
      }
      # Strip leading/trailing " (added by awk split when source has them)
      sub(/^"/, "", val)
      sub(/"$/, "", val)
      print val
    }
  ')"
  # Acceptable value forms:
  #   1. JSON-quoted string: \"$VAR\"  (matches the file's literal text)
  #   2. JSON null literal: null
  #   3. Numeric literal: ^[0-9]+$ or ^[0-9]+\.[0-9]+$
  # Reject: bare $VAR (would be passed unquoted to cmd_set → exit 2)
  if [[ "$value" =~ ^\\\".*\\\"$ ]] || \
     [[ "$value" == "null" ]] || \
     [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    caller_pass=$((caller_pass + 1))
  else
    caller_fail_lines+=("L$lineno: value=$value")
  fi
done < <(grep -nE '"\$STATE_HELPER"[[:space:]]+set[[:space:]]+"\$ROLE"' "$WATCH_SH" | grep -vE '^[0-9]+:#')

if [ "$caller_count" -eq 0 ]; then
  fail "no STATE_HELPER set callers found" "expected at least 1 caller in agent-watch.sh; if file was rewritten, update d030"
elif [ "$caller_pass" -eq "$caller_count" ]; then
  pass "all $caller_count callers use JSON-quoted values (no bare \$VAR)"
else
  fail "found bare-variable callers" "$(printf '%s\n' "${caller_fail_lines[@]}")"
fi

# ============================================================================
# T2: Each STATE_HELPER set key is in the known allowlist
# ============================================================================
section "T2: STATE_HELPER set keys — typed allowlist (no typos)"

ALLOWED_KEYS_REGEX='^(last_seen_utc|last_heartbeat_utc|pr_merged_last_seen_utc|pr_labeled_last_seen_utc|last_synthetic_scan_utc|last_is_alive_utc|polled_at_utc|proactive_sweep_last_utc|burst_until_utc)$'

key_pass=0
key_fail_lines=()
key_count=0
while IFS=: read -r lineno rest; do
  key_count=$((key_count + 1))
  key="$(echo "$rest" | awk '{ print $4 }')"
  if [[ "$key" =~ $ALLOWED_KEYS_REGEX ]]; then
    key_pass=$((key_pass + 1))
  else
    key_fail_lines+=("L$lineno: key=$key (not in allowlist)")
  fi
done < <(grep -nE '"\$STATE_HELPER"[[:space:]]+set[[:space:]]+"\$ROLE"' "$WATCH_SH" | grep -vE '^[0-9]+:#')

if [ "$key_count" -eq 0 ]; then
  fail "no STATE_HELPER set callers found" "expected at least 1 caller in agent-watch.sh"
elif [ "$key_pass" -eq "$key_count" ]; then
  pass "all $key_count keys are in the known allowlist (no typos)"
else
  fail "found unknown keys" "$(printf '%s\n' "${key_fail_lines[@]}")"
fi

# ============================================================================
# T3: No STATE_HELPER set caller passes a JSON array as a string
# ============================================================================
section "T3: No callers pass JSON array through cmd_set (d023 T10 bug class)"
# Bug class: cmd_set with '["a","b"]' (JSON-quoted ARRAY) → cmd_set stores as
# JSON string, not array. d023 T10 documents this. The fix is to NOT use
# cmd_set for processed_event_ids — use inline jq atomic edit instead.
# Per d023 T10 grep: agent-watch.sh should NOT have any
# `"$STATE_HELPER" set "$ROLE" processed_event_ids` calls.
if grep -nE '"\$STATE_HELPER"[[:space:]]+set[[:space:]]+"\$ROLE"[[:space:]]+processed_event_ids' "$WATCH_SH" >/dev/null 2>&1; then
  bad_line="$(grep -nE '"\$STATE_HELPER"[[:space:]]+set[[:space:]]+"\$ROLE"[[:space:]]+processed_event_ids' "$WATCH_SH" | head -1)"
  fail "found cmd_set caller for processed_event_ids" "REGRESSION: $bad_line — use inline jq atomic edit (per d023 T10 + PR #224 v2 fix), NOT cmd_set"
else
  pass "no cmd_set callers for processed_event_ids (inline jq atomic edit in use)"
fi

# ============================================================================
# T4: agent-watch.sh references ADR-0034 OR Issue #267 (audit trail)
# ============================================================================
section "T4: agent-watch.sh references ADR-0034 / Issue #267 (audit trail)"
# Catches "removed the doc comment, forgot the contract" regressions. Looks
# for any reference to ADR-0034 (the JSON contract) or #267 (the hotfix).
# Acceptable in code comments, header, or even string literals.
if grep -Eq 'ADR-0034|Issue #267|#267' "$WATCH_SH"; then
  pass "agent-watch.sh references ADR-0034 / Issue #267 (audit trail intact)"
else
  fail "no ADR-0034 / #267 reference in agent-watch.sh" "expected comment referencing the JSON contract (ADR-0034) or the hotfix (Issue #267) — prevents 'forgot the contract' regressions"
fi

# ============================================================================
# T5: Hotfix commit references Issue #267 (catches accidental reverts)
# ============================================================================
section "T5: Hotfix commit d0c999c (or descendant) referencing Issue #267"
# The orchestrator-applied hotfix (commit d0c999c) added a commit message
# referencing Issue #267. If someone reverts/rewrites the hotfix without
# referencing the issue, T5 catches it.
if git log --all --oneline --grep="#267" 2>/dev/null | head -1 | grep -q .; then
  commit_ref="$(git log --all --oneline --grep='#267' 2>/dev/null | head -1)"
  pass "hotfix commit found: $commit_ref"
else
  fail "no commit references Issue #267" "expected at least one commit message with '#267' — orchestrator hotfix should be traceable"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo
  echo "Issue #267 REGRESSION FAILED — agent-watch.sh cmd_set callers not all JSON-quoted."
  echo "Fix: wrap every value arg in \\\"...\\\" (bash unescapes to JSON-quoted string)."
  echo "     Per ADR-0034, cmd_set requires JSON input — bare \$VAR exits 2 / INVALIDARGUMENT."
  exit 1
fi
echo
echo "Issue #267 REGRESSION PASS — all cmd_set callers JSON-quoted, no crash-loop."
exit 0
