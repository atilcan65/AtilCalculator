#!/usr/bin/env bash
# d074-license-check.sh — STORY-S21-002 LICENSE File (MIT, parameterized copyright) — RED-first regression guard.
#
# Why this test exists
# --------------------
# Sprint 21 E1 (Template Repository Structure) S21-002 demands that the AtilCalculator
# template carry an explicit LICENSE file so that downstream users (via
# `gh repo create --template`) get unambiguous license terms on day one. License is
# the #1 thing open-source users check; missing LICENSE = all-rights-reserved by
# default under copyright law, which blocks adoption (per AC narrative).
#
# ADR-0001 §1 (Single-repo template) ratifies that AtilCalculator IS the template,
# so the LICENSE lives at THIS repo's root (not a separate template repo).
#
# 5 TCs (per ADR-0044 RED-first + ADR-0049 d-test framework sister-pattern):
#   TC1: LICENSE file exists at repo root
#   TC2: LICENSE contains MIT marker text (e.g., "Permission is hereby granted, free of charge")
#   TC3: LICENSE copyright line parameterized as `Copyright (c) {{YEAR}} {{HUMAN_OWNER_NAME}}`
#   TC4: TEMPLATE-README.md "License" section references the LICENSE file (markdown link)
#   TC5: gh api repos/<owner>/AtilCalculator/license returns spdx_id = "MIT"
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d065 (ADR-0033 dual-channel enforcement — direct sister, same week)
#   - d068 (cluster-lag workflow wiring)
#   - d073 (S21-001 template-flag — direct sister, same story batch)
#
# Pre-impl RED state (Issue #631 / current repo as of 2026-06-29):
#   - LICENSE file: MISSING (verified via `ls LICENSE*` → no match)
#   - pyproject.toml: declares `license = { text = "MIT" }` (partial signal only)
#   - TEMPLATE-README.md: MISSING ENTIRELY (Issue #631 AC3 verbatim — README polish split to S21-019)
#   - GH API /license: 404 (verified via `gh api repos/atilcan65/AtilCalculator/license`)
#   → All 5 TCs FAIL in RED state per ADR-0044.
#
# Post-impl GREEN state (target):
#   - LICENSE at root with full MIT text + parameterized copyright
#   - TEMPLATE-README.md created (or extended) with `## License` section linking `[MIT License](LICENSE)`
#     (per Issue #631 AC3 verbatim; sister story S21-019 owns TEMPLATE-README.md polish)
#   - GH API /license returns spdx_id="MIT"
#
# Usage:
#   bash d074-license-check.sh --self-test     # run inline fixture (5 TCs)
#
# Exit codes:
#   0 — all PASS (GREEN state — LICENSE shipped + readable + linked)
#   1 — at least one FAIL (RED state — LICENSE missing or incomplete)
#   2 — preflight failure (missing tool, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LICENSE_PATH="${REPO_ROOT}/LICENSE"
README_PATH="${REPO_ROOT}/TEMPLATE-README.md"
GH_REPO="${GH_REPO:-atilcan65/AtilCalculator}"

# MIT license canonical marker text (substring match)
# Source: https://opensource.org/licenses/MIT — the operative grant clause.
MIT_MARKER="Permission is hereby granted, free of charge"

# Parameterized copyright regex (per AC1):
#   `Copyright (c) {{YEAR}} {{HUMAN_OWNER_NAME}}`
# In an unrendered template, this should literally contain the {{YEAR}} and
# {{HUMAN_OWNER_NAME}} placeholders. In a rendered instantiation, those get
# substituted. The regex matches EITHER form (placeholder or substituted).
COPYRIGHT_REGEX='Copyright \(c\) (?:\{\{YEAR\}\}|[0-9]{4}) (?:\{\{HUMAN_OWNER_NAME\}\}|[A-Za-z ._-]+)'

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
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required (TC5 dependency)" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl required (TC5 fallback)" >&2; exit 2; }

# Self-test mode
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d074 self-test (5 TCs per STORY-S21-002 LICENSE File, ADR-0044 RED-first)${D}\n"
printf "${B}=========================================================================${D}\n"
printf "  Repo under test: %s\n" "$REPO_ROOT"
printf "  LICENSE path:    %s\n" "$LICENSE_PATH"
printf "  README path:     %s\n" "$README_PATH"
printf "  GH repo:         %s\n" "$GH_REPO"
printf "  Sister-pattern:  d073 (S21-001 template-flag — same story batch)\n"
printf "  RED-first:       pre-impl all 5 TCs must FAIL.\n\n"

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# ============================================================================
# TC1: LICENSE file exists at repo root
# ============================================================================
section "TC1: LICENSE file exists at repo root"
if [ ! -f "$LICENSE_PATH" ]; then
  fail "TC1 — LICENSE file missing at root" \
    "expected $LICENSE_PATH to exist (S21-002 AC1). Current state: file absent. RED-first confirmed."
  EXIT_CODE=1
else
  info "TC1 — LICENSE present at $LICENSE_PATH (size=$(stat -c%s "$LICENSE_PATH" 2>/dev/null || stat -f%z "$LICENSE_PATH") bytes)"
  pass "TC1 — LICENSE file exists at root"
fi

# ============================================================================
# TC2: LICENSE contains MIT marker text
# ============================================================================
section "TC2: LICENSE contains MIT marker text ($MIT_MARKER)"
if [ ! -f "$LICENSE_PATH" ]; then
  fail "TC2 — cannot check MIT marker (LICENSE file missing)" \
    "TC1 must pass before TC2 can run. See TC1 failure above."
  EXIT_CODE=1
elif ! grep -qF "$MIT_MARKER" "$LICENSE_PATH"; then
  fail "TC2 — LICENSE does not contain MIT marker text" \
    "expected substring '$MIT_MARKER' (the operative MIT grant clause) in $LICENSE_PATH. Either LICENSE is missing, wrong license, or corrupted."
  EXIT_CODE=1
else
  pass "TC2 — LICENSE contains MIT marker text"
fi

# ============================================================================
# TC3: LICENSE copyright line parameterized (or rendered)
# ============================================================================
section "TC3: LICENSE copyright line matches $COPYRIGHT_REGEX"
if [ ! -f "$LICENSE_PATH" ]; then
  fail "TC3 — cannot check copyright line (LICENSE file missing)" \
    "TC1 must pass before TC3 can run."
  EXIT_CODE=1
elif ! grep -qE "$COPYRIGHT_REGEX" "$LICENSE_PATH"; then
  fail "TC3 — LICENSE copyright line missing or not parameterized" \
    "expected regex '$COPYRIGHT_REGEX' to match a line in $LICENSE_PATH. Per AC1, line must be parameterized as 'Copyright (c) {{YEAR}} {{HUMAN_OWNER_NAME}}' (or substituted at instantiation time)."
  EXIT_CODE=1
else
  COPYRIGHT_LINE="$(grep -E "$COPYRIGHT_REGEX" "$LICENSE_PATH" | head -1)"
  info "TC3 — copyright line found: $COPYRIGHT_LINE"
  pass "TC3 — LICENSE copyright line parameterized (or rendered) per AC1"
fi
# ============================================================================
# TC4: TEMPLATE-README.md "License" section references the LICENSE file
# Per Issue #631 AC3 verbatim (PM Q6 adjudication 2026-06-29; canonical = Issue #631)
# ============================================================================
section "TC4: TEMPLATE-README.md 'License' section references LICENSE file"
if [ ! -f "$README_PATH" ]; then
  fail "TC4 — TEMPLATE-README.md missing (cannot verify License section reference)" \
    "expected $README_PATH to exist (per Issue #631 AC3). Current state: file absent. RED-first confirmed. Sister story S21-019 owns TEMPLATE-README.md polish."
  EXIT_CODE=1
elif ! grep -qE "^##[[:space:]]+License" "$README_PATH"; then
  fail "TC4 — TEMPLATE-README.md has no '## License' section" \
    "expected a top-level '## License' heading in $README_PATH. Per Issue #631 AC3, this section must reference the LICENSE file."
  EXIT_CODE=1
elif ! grep -qE "\[[^]]*[Ll]icense[^]]*\]\([^)]*LICENSE[^)]*\)" "$README_PATH"; then
  fail "TC4 — TEMPLATE-README.md '## License' section does NOT reference LICENSE file via markdown link" \
    "expected a markdown link to LICENSE (e.g., '[MIT License](LICENSE)') in the License section. File does not exist yet — RED-first confirmed."
  EXIT_CODE=1
else
  LICENSE_REF="$(grep -E "\[[^]]*[Ll]icense[^]]*\]\([^)]*LICENSE[^)]*\)" "$README_PATH" | head -1)"
  info "TC4 — License section reference: $LICENSE_REF"
  pass "TC4 — TEMPLATE-README.md License section references LICENSE file via markdown link"
fi

# ============================================================================
# TC5: gh api repos/<owner>/AtilCalculator/license returns spdx_id = "MIT"
# ============================================================================
section "TC5: gh api .../license returns spdx_id = MIT (GitHub UI sidebar signal)"
# Try gh CLI first; fall back to curl with GITHUB_TOKEN if gh fails
LICENSE_JSON="$(gh api "repos/${GH_REPO}/license" 2>/dev/null || true)"
if [ -z "$LICENSE_JSON" ]; then
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    info "TC5 — gh CLI failed, falling back to curl with GITHUB_TOKEN"
    LICENSE_JSON="$(curl -sSL -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/${GH_REPO}/license" 2>/dev/null || true)"
  else
    fail "TC5 — gh api returned empty (LICENSE not detected by GitHub)" \
      "expected gh api repos/${GH_REPO}/license to return spdx_id=MIT. Currently GitHub returns 404 (LICENSE file missing at root). RED-first confirmed."
    EXIT_CODE=1
  fi
fi

if [ -n "$LICENSE_JSON" ]; then
  SPDX_ID="$(echo "$LICENSE_JSON" | grep -oE '"spdx_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"spdx_id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || true)"
  if [ "$SPDX_ID" = "MIT" ]; then
    info "TC5 — GH API returned spdx_id=$SPDX_ID (license name visible in UI sidebar)"
    pass "TC5 — GH API /license returns spdx_id=MIT (AC2 satisfied)"
  elif [ -z "$SPDX_ID" ]; then
    fail "TC5 — GH API returned no spdx_id (LICENSE file missing or unrecognized)" \
      "response: $(echo "$LICENSE_JSON" | head -c 200). Per AC2, GitHub UI sidebar must show license name."
    EXIT_CODE=1
  else
    fail "TC5 — GH API returned spdx_id=$SPDX_ID (expected MIT)" \
      "AC1 specifies MIT license. Got spdx_id=$SPDX_ID — either wrong license or rendering issue."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — LICENSE missing or incomplete per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 5 TCs PASS — LICENSE shipped, MIT-tagged, README-referenced, GH UI detected${D}\n"
exit 0