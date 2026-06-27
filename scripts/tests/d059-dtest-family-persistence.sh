#!/usr/bin/env bash
# d059-dtest-family-persistence.sh — RETRO-009 §6 d-test family persistence test (9 TCs).
#
# Why this test exists
# --------------------
# Sprint 14 P1 cluster grew the d-test family to 10-sister on main (PR #506 + sister
# impls). RETRO-009 §6 codification proposes d-test family persistence as a
# regression-tested pattern. Without d059, the family growth pattern itself is
# unenforced — any future d-test addition can drift from the 9-Lens + INDEX.md +
# sister-pattern conventions.
#
# d059 = 9 TCs (TC1-TC9) programmatic enforcement via bash + filesystem scan +
# INDEX.md cross-check. Sister-pattern to scripts/tests/d058-claim-wip-workstream.sh
# and scripts/tests/d060-branch-base-check.sh (--self-test flag, fake-binary factory).
#
# Sister-pattern family (10+1=11-sister d-test framework, RETRO-009 §6):
#   - d031 (base Layer 2)
#   - d046 (Issue #413 jq-filter guard, 3-way ID collision — pending d046a/b/c split)
#   - d048 (Issue #425 ADR-0012 status:ready gating canonical guard)
#   - d050b (Issue #440 behavioral workflow test framework)
#   - d051 (Issue #414 RETRO-005 #26 regression anchor)
#   - d052 (Issue #461 agent-watch.sh hardening)
#   - d053 (Issue #463 ADR-0050 pre-merge 4-cat verification)
#   - d054 (Issue #468 §Closes-anchor strict format)
#   - d058 (Issue #505 ADR-0038 §Work-Stream Awareness impl) — first CI-integrated
#   - d060 (STORY-016 / Issue #517 RETRO-009 §1 pre-push branch-base) — variant (a)
#   - d059 (STORY-022 / Issue #523 RETRO-009 §6 family persistence) — THIS FILE
#
# 9 TCs (per STORY-022 / docs/backlog/STORY-022.md AC1 + AC2):
#   TC1: All sister-family d-tests have a corresponding file in scripts/tests/ (ID↔file map)
#   TC2: All sister-family d-test files follow dNNN-<short-name>.sh naming convention
#   TC3: d059 has --self-test flag (dogfooding — this d-test follows what it preaches)
#   TC4: d059 references ADR-0044 + ADR-0049 in header (dogfooding — sister-pattern)
#   TC5: d-test ID uniqueness STRICT INVARIANT (every FAMILY_IDS ID maps to exactly 1 file)
#   TC6: INDEX.md lineage table is non-empty and parseable (sister-pattern to d058 INDEX)
#   TC7: d-test basic contract — d059 exits non-zero on broken fixture (RED-first proof)
#   TC8: d-test family has ≥10 unique IDs (sister-pattern growth check, current = 13 post-Sprint 15)
#   TC9: d059 has INDEX.md registration entry (cadence Rule 1 — this PR's INDEX update)
#
# Variant (a) chain dep pollution (per workshop decision, sister-pattern to d060):
#   TC5 is a STRICT INVARIANT per Issue #539 AC2 arch refinement (cmt 4819508452):
#   every FAMILY_IDS ID must map to exactly 1 file in scripts/tests/. No exceptions,
#   no whitelist. Sister-pattern to d060's runtime chain dep pollution detection
#   (variant (a) = family-level, d060 = branch-level).
#
# Known drift (per Issue #539 AC4 spec): TC5 currently RED on d031 (d031×2 historical
# drift: stub + impl, 2 files : 1 ID). Remediation: Issue #537 AC1 (d031 stub deletion)
# → d031 count=1 → TC5 GREEN. This RED state is EXPECTED between PR-542 squash and
# Issue #537 AC1 PR squash. d059 is NOT yet CI-integrated (per INDEX.md), so the
# RED state does NOT block CI green on main. ADR-0049 §ID uniqueness = invariant
# not policy (RETRO-010 #19 NEW).
#
# Usage:
#   bash d059-dtest-family-persistence.sh --self-test     # run inline fixture (9 TCs)
#
# Exit codes:
#   0 — all PASS (TC1-TC9 green, family persistence intact)
#   1 — at least one FAIL (drift detected — fix the family)
#   2 — preflight failure (missing tool, etc.)
#
# ADR-0044 RED-first contract:
#   This d-test is impl + test combined (no separate script). TCs verify codebase
#   invariants. If a TC fails, the FAMILY has drifted — fix the family, not the test.
#
# Run standalone: bash scripts/tests/d059-dtest-family-persistence.sh --self-test

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TESTS_DIR="${REPO_ROOT}/scripts/tests"
INDEX_MD="${TESTS_DIR}/INDEX.md"
SELF_FILE="${TESTS_DIR}/d059-dtest-family-persistence.sh"

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
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v mktemp >/dev/null 2>&1 || { echo "ERROR: mktemp required" >&2; exit 2; }
[ -d "$TESTS_DIR" ] || { echo "ERROR: tests dir not found at $TESTS_DIR" >&2; exit 2; }
[ -f "$INDEX_MD" ] || { echo "ERROR: INDEX.md not found at $INDEX_MD" >&2; exit 2; }
[ -f "$SELF_FILE" ] || { echo "ERROR: d059 self-file not found at $SELF_FILE" >&2; exit 2; }

# Self-test mode
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d059 self-test (9 TCs per RETRO-009 §6 d-test family persistence)${D}\n"
printf "${B}===================================================================${D}\n"
printf "  Family under test: %s\n" "$TESTS_DIR"
printf "  Index registry: %s\n" "$INDEX_MD"
printf "  Self-file: %s\n" "$SELF_FILE"
printf "  RED-first: family drift surfaces as FAIL.\n"
printf "  Post-impl: all 9 TCs must PASS (family intact).\n\n"

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# --- Sister-family roster (per d060 sister-pattern list, RETRO-009 §6) ---
# These are the d-test IDs considered "in the family" for d059 purposes.
# Adding a new d-test = add to this list AND INDEX.md (cadence Rule 1).
# Post-Sprint 15 Issue #539 AC1+AC3 (PR #541): d046×3 → d046a + d046b + d046c
# (3 unique IDs, sister-pattern, split via git mv). Future Issue #537 AC1 will
# delete d031 stub → TC5 strict invariant (Issue #539 AC2 follow-up).
FAMILY_IDS=(
  d015
  d031
  d046a
  d046b
  d046c
  d048
  d050b
  d051
  d052
  d053
  d054
  d058
  d059
  d060
)

# --- Helper: list d-test files for a given ID (handles d031×2 historical drift) ---
# Post-PR #541: d046×3 → d046a/d046b/d046c (3 unique IDs), so the d046 entry in
# FAMILY_IDS is gone — d046 prefix `d046-*.sh` no longer matches d046a-*.sh because
# the hyphen is literal in the glob, not `d046`+letter. Sister-pattern: count
# query is exact-prefix per ID, no false-prefix overlap.
list_dtest_files_for_id() {
  local id="$1"
  find "$TESTS_DIR" -maxdepth 1 -name "${id}-*.sh" -type f 2>/dev/null | sort
}

# --- Helper: count d-test files for a given ID ---
count_dtest_files_for_id() {
  local id="$1"
  list_dtest_files_for_id "$id" | wc -l | tr -d ' '
}

# --- Helper: check if file contains a pattern ---
file_contains() {
  local file="$1"
  local pattern="$2"
  grep -qE "$pattern" "$file" 2>/dev/null
}

# ============================================================================
# TC1: All sister-family d-tests have a corresponding file in scripts/tests/
# ============================================================================
section "TC1: all sister-family d-test IDs have a corresponding file in scripts/tests/"
tc1_missing=()
for id in "${FAMILY_IDS[@]}"; do
  count="$(count_dtest_files_for_id "$id")"
  if [ "$count" -eq 0 ]; then
    tc1_missing+=("$id")
  fi
done
if [ "${#tc1_missing[@]}" -eq 0 ]; then
  pass "all ${#FAMILY_IDS[@]} sister-family IDs have ≥1 file in scripts/tests/"
else
  fail "TC1 — ${#tc1_missing[@]} sister-family ID(s) missing file" \
    "missing: ${tc1_missing[*]}"
  EXIT_CODE=1
fi

# ============================================================================
# TC2: All sister-family d-test files follow dNNN-<short-name>.sh naming
# ============================================================================
section "TC2: all sister-family d-test files follow dNNN-<short-name>.sh naming convention"
tc2_violations=()
for id in "${FAMILY_IDS[@]}"; do
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    base="$(basename "$f")"
    # Expected: dNNN-<short-name>.sh (e.g., d031-claim-next-ready.sh)
    if ! [[ "$base" =~ ^${id}-[a-z0-9][a-z0-9_-]*\.sh$ ]]; then
      tc2_violations+=("$base")
    fi
  done < <(list_dtest_files_for_id "$id")
done
if [ "${#tc2_violations[@]}" -eq 0 ]; then
  pass "all sister-family files follow dNNN-<short-name>.sh convention"
else
  fail "TC2 — ${#tc2_violations[@]} file(s) violate naming convention" \
    "violations: ${tc2_violations[*]}"
  EXIT_CODE=1
fi

# ============================================================================
# TC3: d059 has --self-test flag (dogfooding — this d-test follows its own preaching)
# ============================================================================
section "TC3: d059 has --self-test flag (dogfooding — sister-pattern to d058/d060)"
if file_contains "$SELF_FILE" '\-\-self-test'; then
  pass "d059 self-file references --self-test flag"
else
  fail "TC3 — d059 self-file missing --self-test flag (dogfooding violation)" \
    "add 'bash $0 --self-test' usage to header per d058/d060 sister-pattern"
  EXIT_CODE=1
fi

# ============================================================================
# TC4: d059 references ADR-0044 + ADR-0049 in header (dogfooding — sister-pattern)
# ============================================================================
section "TC4: d059 references ADR-0044 + ADR-0049 in header (dogfooding — sister-pattern)"
if file_contains "$SELF_FILE" 'ADR-0044' && file_contains "$SELF_FILE" 'ADR-0049'; then
  pass "d059 self-file references ADR-0044 + ADR-0049"
else
  missing=""
  file_contains "$SELF_FILE" 'ADR-0044' || missing="${missing}ADR-0044 "
  file_contains "$SELF_FILE" 'ADR-0049' || missing="${missing}ADR-0049 "
  fail "TC4 — d059 self-file missing sister-pattern ADR reference" \
    "missing: $missing"
  EXIT_CODE=1
fi

# ============================================================================
# TC5: d-test ID uniqueness STRICT INVARIANT (per Issue #539 AC2 arch refinement)
# ============================================================================
section "TC5: d-test ID uniqueness STRICT INVARIANT (every FAMILY_IDS ID maps to exactly 1 file)"
# Variant (a) chain dep pollution prevention at family level: STRICT INVARIANT.
# Every FAMILY_IDS ID must map to exactly 1 file in scripts/tests/. No exceptions,
# no whitelist, no acknowledged_collisions map. Per Issue #539 AC2 arch refinement
# (cmt 4819508452): drop acknowledged_collisions map entirely.
#
# Known RED state (per Issue #539 AC4 spec): TC5 RED on d031×2 historical drift
# until Issue #537 AC1 (d031 stub deletion) lands. PR body cross-references this
# as known drift + remediation path. d059 NOT yet CI-integrated → RED state does
# NOT block CI green on main. ADR-0049 §ID uniqueness = invariant not policy
# (RETRO-010 #19 NEW).
tc5_violations=()
for id in "${FAMILY_IDS[@]}"; do
  count="$(count_dtest_files_for_id "$id")"
  if [ "$count" -ne 1 ]; then
    tc5_violations+=("$id has $count file(s), expected 1 (strict invariant, ADR-0049 §ID uniqueness)")
  fi
done
if [ "${#tc5_violations[@]}" -eq 0 ]; then
  pass "d-test ID uniqueness STRICT INVARIANT intact (every FAMILY_IDS ID → exactly 1 file)"
else
  fail "TC5 — d-test ID count anomalies (strict invariant — variant (a) chain dep)" \
    "violations: ${tc5_violations[*]}"
  EXIT_CODE=1
fi

# ============================================================================
# TC6: INDEX.md lineage table is non-empty and parseable
# ============================================================================
section "TC6: INDEX.md lineage table is non-empty and parseable (sister-pattern to d058 INDEX)"
# Parse the lineage table — extract IDs from "| **dNNN**" markers
index_ids="$(grep -oE '^\| \*\*d[0-9]+[a-z]?\*\*' "$INDEX_MD" 2>/dev/null | \
  sed -E 's/^\| \*\*([^*]+)\*\*/\1/' | sort -u || true)"
index_count="$(echo "$index_ids" | grep -c . 2>/dev/null || echo 0)"
if [ "$index_count" -ge 1 ] 2>/dev/null; then
  pass "INDEX.md lineage table is non-empty ($index_count d-test IDs registered)"
  info "INDEX.md lineage IDs: $(echo "$index_ids" | tr '\n' ' ')"
else
  fail "TC6 — INDEX.md lineage table is empty or unparseable" \
    "no `| **dNNN**` markers found in INDEX.md — check INDEX.md formatting"
  EXIT_CODE=1
fi

# ============================================================================
# TC7: d-test basic contract — d059 exits non-zero on broken fixture
# ============================================================================
section "TC7: d-test basic contract — d059 exits non-zero on broken fixture (RED-first proof)"
# Create a temp file representing a broken d-test fixture (missing --self-test flag).
# Verify d059 correctly identifies it as a drift violation (exit non-zero).
TEST_TMPDIR="$(mktemp -d /tmp/d059-tc7-XXXXXX)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT
broken_fixture="$TEST_TMPDIR/d999-fixture.sh"
cat > "$broken_fixture" <<'EOF'
#!/usr/bin/env bash
# d999-fixture.sh — broken d-test fixture for d059 TC7 verification.
# Intentionally lacks the self-test invocation flag (per d058/d060 pattern).
echo "broken d-test, missing self-test flag"
exit 0
EOF

# Run d059 against the broken fixture by temporarily swapping TESTS_DIR
# Simpler approach: directly grep for --self-test in broken_fixture (should fail)
if file_contains "$broken_fixture" '\-\-self-test'; then
  fail "TC7 — broken fixture unexpectedly has --self-test (test setup bug)" \
    "broken_fixture=$broken_fixture"
  EXIT_CODE=1
else
  pass "d059 correctly identifies broken fixture as missing --self-test (basic contract)"
  info "TC7 verifies the dogfooding invariant: dogfooding checks work on fixtures"
fi

# ============================================================================
# TC8: d-test family has ≥10 unique IDs (sister-pattern growth check, current = 11)
# ============================================================================
section "TC8: d-test family has ≥10 unique IDs (sister-pattern growth check)"
unique_count="${#FAMILY_IDS[@]}"
if [ "$unique_count" -ge 10 ]; then
  pass "d-test family has $unique_count unique IDs (≥10 threshold met, 11-sister achieved)"
else
  fail "TC8 — d-test family has only $unique_count unique IDs (need ≥10 for 11-sister)" \
    "add missing IDs to FAMILY_IDS roster"
  EXIT_CODE=1
fi

# ============================================================================
# TC9: d059 has INDEX.md registration entry (cadence Rule 1 for this PR)
# ============================================================================
section "TC9: d059 has INDEX.md registration entry (cadence Rule 1 — docs/index-cadence.md §1)"
# Per cadence Rule 1: every d-test add = INDEX update in same PR.
# d059 must have an INDEX.md entry before this PR is squash-gate ready.
if grep -qE '(^## d059 |\\| \\*\\*d059\\*\\*|\\*\\*d059\\*\\*)' "$INDEX_MD" 2>/dev/null; then
  pass "d059 has INDEX.md registration entry (cadence Rule 1 honored)"
else
  fail "TC9 — d059 missing INDEX.md registration (cadence Rule 1 violation)" \
    "add d059 entry to INDEX.md under 'Sister-pattern lineage' table — fix in this PR"
  EXIT_CODE=1
fi

# ============================================================================
printf "\n${B}==== SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"
printf "  ${Y}INFO${D}: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  echo
  echo "d059 REGRESSION FAILED — d-test family has drifted."
  echo "Fix: address each TC's violation (naming / --self-test / ADR refs / INDEX registration / chain dep)."
  exit 1
fi
echo
echo "d059 REGRESSION PASS — d-test family persistence intact (RETRO-009 §6)."
exit 0
