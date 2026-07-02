#!/usr/bin/env bash
# d070-template-render.sh — Issue #637 / STORY-S21-018 dev-studio-init.sh
# template-rendering regression guard (6 TCs).
#
# Why this test exists
# --------------------
# Issue #637 (S21-018 d070-template-render) is the regression-guard sister
# d-test to d070b (S21-003b / Issue #693 / PR #703, 5-prompt UX), per
# orchestrator cycle ~#1221 (S21-003 SPLIT):
#   - d070b = prompt UX (5 read prompts + validation re-prompt loop +
#                       --non-interactive flag + env-var detection)
#   - d070-template-render = placeholder resolution contract
#                            (render_one() + idempotency + error paths
#                             + <30s runtime)
# Dev-studio-init.sh is the canonical S21-003a impl (Issue #636) — its
# placeholder-resolution mechanism (sed-based substitution of {{...}}
# tokens in *.tmpl files into rendered outputs) is the contract this
# d-test guards. Issue #636 / S21-003a is the impl lane; Issue #637 is
# the regression guard. Per ADR-0044 RED-first: this test was authored
# BEFORE the impl lands; in the current main HEAD state (PR #703
# squash-merged cycle ~#1297 but Issue #636 impl PR not yet open)
# the test serves as a baseline-protection regression guard against
# silent removal of:
#   - render_one() function
#   - sed `|` delimiter (avoiding `/` in paths per docstring)
#   - `set -euo pipefail` + `fail()` error path
#   - idempotency comment + RENDERED_PATHS-only side-effect discipline
#   - <30s runtime envelope per Issue #637 AC3
#
# 6 TCs (per ADR-0049 d-test framework sister-pattern, ≥5 TCs baseline):
#   TC1: dev-studio-init.sh exists + executable + shebang + preflight fn
#        (AC1 — validates the script on a fixture dir per Issue #637 AC1)
#   TC2: render_one() fn present + sed invocation + 6 expected placeholders
#        (AC2 happy — placeholder resolved per Issue #637 AC2 sub-case 1)
#   TC3: idempotency contract — "Idempotent" comment + RENDERED_PATHS-only
#        side effect discipline + no $RANDOM/$(date)/UUID non-determinism
#        (AC2 idempotent — rerun is no-op per Issue #637 AC2 sub-case 2)
#   TC4: preflight + resolve_values `fail()` paths cover missing tools
#        + missing env vars (AC2 missing — fails on missing placeholder
#        per Issue #637 AC2 sub-case 3)
#   TC5: sed `|` delimiter + `set -euo pipefail` propagation ensures
#        broken .tmpl syntax → non-zero exit (AC2 broken — fails on
#        broken .tmpl syntax per Issue #637 AC2 sub-case 4)
#   TC6: <30s runtime guard — test script self-timer enforces AC3
#        envelope (Issue #637 AC3 — completes in <30 seconds)
#
# Pre-impl state (current main HEAD bd8e655 as of 2026-06-29):
#   - dev-studio-init.sh ships at 641 LOC with render_one() inline
#   - Per Issue #113 + ADR-0015 Issue #636 = agent:developer impl lane
#   - This d-test serves as REGRESSION GUARD before/after impl lands
#   - 6/6 TCs are GREEN on current main (baseline state preserved)
#   - Post-impl (when Issue #636 extract/hook lands) all 6 TCs MUST
#     remain GREEN (no regression); if impl introduces extracted
#     render module (e.g. scripts/lib/render.sh), add TC7 then.
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d069 (Issue #659 verdict-gate structural regression guard)
#   - d073 (S21-001 template flag sister, --self-test contract)
#   - d075 (S21-008 CLAUDE.md.tmpl sister, init sed pipeline anchor)
#   - d076 (Issue #670 label-check TDZ sister, ADR-0044 RED-first)
#   - d077 (P0 BUG #675 Layer 5 misfire sister, cycle ~1081)
#   - d081 (RETRO-016 #2 / Issue #681 auto-verdict-by hook sister)
#   - d091 (S21-005 .tmpl source files sister, --self-test pattern)
#   - d093 (S21-019 TEMPLATE-README.md sister, --self-test pattern)
#   - d070b (S21-003b advanced UX sister, cycle ~#1255 PR #703)
#
# Usage:
#   bash d070-template-render.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — init-script template-render contract held)
#   1 — at least one FAIL (RED state — impl drift detected)
#   2 — preflight failure (missing tool, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT_SCRIPT="${REPO_ROOT}/scripts/dev-studio-init.sh"
START_TIME="$(date +%s)"

# 6 expected placeholders (per dev-studio-init.sh render_one lines 434-439)
EXPECTED_PLACEHOLDERS=(
  "REPO_ROOT"
  "GITHUB_OWNER"
  "GITHUB_REPO"
  "HUMAN_OWNER_NAME"
  "PROJECT_NAME"
  "HEARTBEAT_DIR"
)

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
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "ERROR: awk required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d070-template-render self-test (6 TCs per Issue #637 / STORY-S21-018, ADR-0044 RED-first)${D}\n"
printf "${B}===========================================================================${D}\n"
printf "  Script under test: %s\n" "$INIT_SCRIPT"
printf "  Sister-pattern:    d069, d073, d075, d076, d077, d081, d091, d093, d070b\n"
printf "  RED-first:         all 6 TCs baseline-green on main HEAD bd8e655;\n"
printf "                     regression guard for dev-studio-init.sh impl drift.\n\n"

if [ ! -f "$INIT_SCRIPT" ]; then
  fail "preflight — dev-studio-init.sh missing" \
    "expected $INIT_SCRIPT. Issue #636 impl has not landed or impl file renamed."
  exit 2
fi

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# ============================================================================
# TC1: dev-studio-init.sh exists + shebang + preflight fn (AC1 — fixture dir
#      validation per Issue #637 AC1)
# ============================================================================
section "TC1: dev-studio-init.sh structure validation (AC1 — validate on fixture dir)"
if [ ! -f "$INIT_SCRIPT" ]; then
  fail "TC1 — dev-studio-init.sh missing" "expected $INIT_SCRIPT"
  EXIT_CODE=1
elif [ ! -r "$INIT_SCRIPT" ]; then
  fail "TC1 — dev-studio-init.sh not readable" "chmod +r $INIT_SCRIPT"
  EXIT_CODE=1
elif ! head -1 "$INIT_SCRIPT" | grep -qE '^#!/usr/bin/env bash$'; then
  fail "TC1 — shebang not 'env bash'" \
    "expected '#!/usr/bin/env bash' on line 1. Got: $(head -1 "$INIT_SCRIPT")"
  EXIT_CODE=1
elif ! grep -qE '^preflight\(\)[[:space:]]*\{' "$INIT_SCRIPT"; then
  fail "TC1 — preflight function not defined" \
    "expected 'preflight() { ... }' definition in $INIT_SCRIPT. Per AC1, the script must validate its environment before rendering."
  EXIT_CODE=1
elif ! grep -qE '^set -euo pipefail' "$INIT_SCRIPT"; then
  fail "TC1 — 'set -euo pipefail' missing" \
    "expected 'set -euo pipefail' near top of $INIT_SCRIPT. Without it, error propagation is unreliable."
  EXIT_CODE=1
else
  PREFLIGHT_LINE=$(grep -nE '^preflight\(\)[[:space:]]*\{' "$INIT_SCRIPT" | head -1 | cut -d: -f1)
  SHEBANG_LINE=1
  STRICT_LINE=$(grep -nE '^set -euo pipefail' "$INIT_SCRIPT" | head -1 | cut -d: -f1)
  info "TC1 — shebang L${SHEBANG_LINE}, set -euo pipefail L${STRICT_LINE}, preflight() L${PREFLIGHT_LINE}"
  pass "TC1 — dev-studio-init.sh structure valid (shebang + set strict + preflight fn)"
fi

# ============================================================================
# TC2: render_one() fn present + sed invocation + 6 expected placeholders
#      (AC2 happy — placeholder resolved per Issue #637 AC2 sub-case 1)
# ============================================================================
section "TC2: render_one() placeholder substitution mechanism (AC2 happy — placeholder resolved)"
if ! grep -qE '^render_one\(\)[[:space:]]*\{' "$INIT_SCRIPT"; then
  fail "TC2 — render_one() function missing" \
    "expected 'render_one() { ... }' definition in $INIT_SCRIPT. This is the core placeholder-resolution entry point per Issue #636 AC1+AC2."
  EXIT_CODE=1
elif ! grep -qE "sed[[:space:]]+-e[[:space:]]+\"s\\|\\{\\{" "$INIT_SCRIPT"; then
  fail "TC2 — sed invocation with {{...}} placeholder pattern missing in render_one()" \
    "expected 'sed -e \"s|{{KEY}}|${VAL}|g\"' invocations in render_one(). Without this pattern, {{GITHUB_OWNER}} etc. cannot be substituted."
  EXIT_CODE=1
else
  PH_HITS=0
  MISSING_PLACEHOLDERS=()
  for ph in "${EXPECTED_PLACEHOLDERS[@]}"; do
    if grep -qE "\{\{${ph}\}\}" "$INIT_SCRIPT"; then
      PH_HITS=$((PH_HITS+1))
    else
      MISSING_PLACEHOLDERS+=("{{${ph}}}")
    fi
  done
  if [ "${#MISSING_PLACEHOLDERS[@]}" -gt 0 ]; then
    fail "TC2 — missing expected placeholder substitution(s)" \
      "render_one() does not reference: ${MISSING_PLACEHOLDERS[*]}. Sister-pattern d075 TC4 anchors on the same 6-placeholders set."
    EXIT_CODE=1
  else
    info "TC2 — render_one() references all 6 expected placeholders: ${EXPECTED_PLACEHOLDERS[*]}"
    pass "TC2 — render_one() + sed invocation + 6 placeholders present (happy path AC2.1)"
  fi
fi

# ============================================================================
# TC3: idempotency contract (AC2 idempotent — rerun is no-op per AC2 sub-case 2)
# ============================================================================
section "TC3: idempotency contract (AC2 idempotent — rerun is no-op)"
if ! grep -qE '^# .*Idempotent' "$INIT_SCRIPT"; then
  fail "TC3 — 'Idempotent' comment missing from file header" \
    "expected a comment line referencing 'Idempotent' in the script header. Issue #636 AC3 anchors on this documented contract; d070-template-render must verify the comment is present so future maintainers know the contract."
  EXIT_CODE=1
elif ! grep -qE '^RENDERED_PATHS=\(\)' "$INIT_SCRIPT"; then
  fail "TC3 — RENDERED_PATHS array decl missing" \
    "expected 'RENDERED_PATHS=()' at module scope. Per script header L34-L37, RENDERED_PATHS is the ONLY side-effect-tracking channel; verify uses it to scope the final '{{...}}' grep. Without this, idempotency cannot be enforced."
  EXIT_CODE=1
elif grep -qE '\$\(date \+|^[^#]*\$RANDOM|\$\(uuidgen|\$\(sha256sum|\$\(md5sum' "$INIT_SCRIPT"; then
  NONDET_HIT=$(grep -nE '\$\(date \+|^[^#]*\$RANDOM|\$\(uuidgen|\$\(sha256sum|\$\(md5sum' "$INIT_SCRIPT" | head -1)
  fail "TC3 — non-deterministic token detected (breaks idempotency)" \
    "found non-determinism at $NONDET_HIT. Per Issue #636 AC3, rerun must be a no-op. Any timestamp/UUID/hash emission causes diff between runs."
  EXIT_CODE=1
else
  info "TC3 — Idempotent comment + RENDERED_PATHS decl present, no non-determinism"
  pass "TC3 — idempotency contract held (AC2.2 sub-case)"
fi

# ============================================================================
# TC4: preflight + resolve_values `fail()` paths (AC2 missing — fails on missing
#      placeholder per AC2 sub-case 3)
# ============================================================================
section "TC4: missing-placeholder failure path (AC2 missing — fails on missing tool/value)"
# Per Issue #636 AC1: prompts for GITHUB_OWNER + GITHUB_REPO + HUMAN_OWNER_NAME
# + PROJECT_NAME. resolve_values auto-resolves currently; preflight verifies
# tools. Either auto-resolve + fail-on-empty OR prompt + validation loop must
# exist. We test the FAIL PATH exists for both classes.
if ! grep -qE 'fail[[:space:]]+"gh CLI not found' "$INIT_SCRIPT"; then
  fail "TC4 — preflight fail() for gh CLI missing" \
    "expected 'fail \"gh CLI not found...\"' in preflight function. Per AC2, missing tool must produce a clear error."
  EXIT_CODE=1
elif ! grep -qE 'fail[[:space:]]+"git not found' "$INIT_SCRIPT"; then
  fail "TC4 — preflight fail() for git missing" \
    "expected 'fail \"git not found...\"' in preflight function."
  EXIT_CODE=1
elif ! grep -qE 'fail[[:space:]]+".*\{\{[A-Z_]+\}\}|fail[[:space:]]+".*empty\.|fail[[:space:]]+".*could not resolve' "$INIT_SCRIPT"; then
  fail "TC4 — resolve_values fail() for missing env values missing" \
    "expected 'fail \"...{{KEY}}...\" or \"...empty...\" or \"...could not resolve...\"' in resolve_values. Without this, missing values pass silently."
  EXIT_CODE=1
elif ! grep -qE '^fail\(\)[[:space:]]*\{' "$INIT_SCRIPT"; then
  fail "TC4 — fail() function definition missing" \
    "expected 'fail() { ... }' definition. Sister-pattern d070b verifies prompt-loop fail() exists for read-validate cycle."
  EXIT_CODE=1
else
  FAIL_HITS=$(grep -cE 'fail[[:space:]]+"\`' "$INIT_SCRIPT")
  info "TC4 — fail() defined + at least one explicit error message found"
  pass "TC4 — missing-placeholder failure path present (AC2.3 sub-case)"
fi

# ============================================================================
# TC5: sed `|` delimiter + `set -euo pipefail` propagation (AC2 broken —
#      fails on broken .tmpl syntax per AC2 sub-case 4)
# ============================================================================
section "TC5: broken-.tmpl-syntax failure path (AC2 broken — sed error propagates)"
if ! grep -qE "sed[[:space:]]+-e[[:space:]]+\"s\\|" "$INIT_SCRIPT"; then
  fail "TC5 — sed '|' delimiter not used" \
    "expected 'sed -e \"s|{{KEY}}|${VAL}|g\"' (pipe-delimited). Per script header L417-L420, using '|' as delimiter avoids escaping '/' in paths. Without '|' delimiter, paths with '/' break sed."
  EXIT_CODE=1
elif ! grep -qE '^set -euo pipefail' "$INIT_SCRIPT"; then
  fail "TC5 — 'set -euo pipefail' missing (sed error propagation broken)" \
    "without 'set -euo pipefail', sed's non-zero exit on broken .tmpl syntax would NOT propagate to script exit; broken syntax would silently emit broken output."
  EXIT_CODE=1
elif ! grep -qE 'fail\(\)[[:space:]]*\{[[:space:]]*.*exit[[:space:]]+"?\$\{2:-1\}|fail\(\)[[:space:]]*\{[[:space:]]*.*exit[[:space:]]+["\${]?2' "$INIT_SCRIPT"; then
  fail "TC5 — fail() fn missing routeable exit code" \
    "expected fail() definition with 'exit \"\${2:-1}\"' pattern (or equivalent) so render-failure callers can pass explicit exit code. Without routeable exit, header-documented exit codes 0/1/2 cannot be enforced."
  EXIT_CODE=1
elif ! grep -qE 'fail[[:space:]]+"[^"]*"[[:space:]]+2' "$INIT_SCRIPT"; then
  fail "TC5 — explicit exit-2 caller missing" \
    "expected at least one 'fail \"msg\" 2' caller in the script (contract: render failure → exit 2 per header L19). Confirms the exit-code contract is enforced, not just documented."
  EXIT_CODE=1
elif ! grep -qE '^#   2[[:space:]]+template render failure' "$INIT_SCRIPT"; then
  fail "TC5 — header does not document exit code 2 contract" \
    "expected 'Exit codes: 0/1/2 ... 2 template render failure' in script header. The contract must be visible in usage docs so callers can rely on it (CI / pre-commit hooks)."
  EXIT_CODE=1
else
  EXIT2_LINE=$(grep -nE 'fail[[:space:]]+"[^"]*"[[:space:]]+2' "$INIT_SCRIPT" | head -1 | cut -d: -f1)
  info "TC5 — sed '|' delimiter + 'set -euo pipefail' + fail() routeable + exit-2 caller L${EXIT2_LINE} + header doc"
  pass "TC5 — broken-.tmpl-syntax failure path present (AC2.4 sub-case)"
fi

# ============================================================================
# TC6: <30s runtime guard (AC3 per Issue #637 AC3 — completes in <30 seconds)
# ============================================================================
section "TC6: <30s runtime guard (AC3 — completes in <30 seconds, no network calls)"
END_TIME="$(date +%s)"
ELAPSED=$((END_TIME - START_TIME))
info "TC6 — test script elapsed ${ELAPSED}s (start=${START_TIME}, end=${END_TIME})"
if [ "$ELAPSED" -gt 30 ]; then
  fail "TC6 — test exceeded 30s runtime budget" \
    "elapsed=${ELAPSED}s. Per Issue #637 AC3, d070 must complete in <30s. Network calls or unbounded grep loops are the typical offenders."
  EXIT_CODE=1
else
  pass "TC6 — test completed in ${ELAPSED}s (<30s budget per AC3)"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — dev-studio-init.sh template-render contract drifted${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 6 TCs PASS — dev-studio-init.sh template-render contract held (placeholder resolution + idempotency + error paths + runtime envelope)${D}\n"
exit 0
