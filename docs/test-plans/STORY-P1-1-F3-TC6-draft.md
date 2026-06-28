# d064 TC6 — F3 explicit jq error check (DRAFT, owner-ratified Option X)

**Source**: Issue #584 F3 + architect cmt 4826300692 disposition + owner Option X ratification
**Status**: DRAFT — pre-staged for impl PR per cycle 649 trust-but-verify
**Lane**: tester (test code only — impl belongs to @developer)

---

## Why this draft exists

Previous TC6 draft (`STORY-P1-1-AC4-TC6-draft.md`) was for **AC4 markdown emission** (Option A). Owner ratified **Option B (rescope AC4 → manual PM curator)**, so that draft is **archived**.

F3 (jq silent error swallow on malformed merged.json) is now the active finding requiring a new TC6 per **Option X** (architect preferred per ADR-0056 silent_skip doctrine; owner ratified).

Per ADR-0044 RED-first TDD: when Option X is added mid-flight, the corresponding d-test TC must be written BEFORE the impl lands. Pre-drafting TC6 here means dev has a reference impl + test surface when writing the jq error check.

---

## TC6 (NEW): F3 — malformed merged.json → exit 2 (explicit jq error check)

### Setup
- FAKE_GH_MERGED points to a file containing malformed JSON (e.g., `[{"number": 500, "mergedAt": "INVALID_TIMESTAMP"}]` or `not json at all`)
- Detector invoked normally with valid PR_NUMBER + MERGED_AT

### Steps
1. Create malformed fixture: `echo 'not json at all' > /tmp/d064-tc6-malformed.json`
2. Run detector with FAKE_GH_MERGED=/tmp/d064-tc6-malformed.json, PR_NUMBER=500, MERGED_AT=2026-06-27T21:54:34Z
3. Inspect exit code + stderr
4. Inspect log file (CLUSTER_LAG_LOG) — should NOT contain a silent_skip event (since this is a config error, not a clean silent_skip)

### Expected
- **Exit code**: 2 (config error per ADR-0059 API contract)
- **Stderr**: explicit error message like `ERROR: FAKE_GH_MERGED parse failed: <jq error>` to stderr
- **Log file**: NOT modified (no silent_skip pollution)
- **No cluster_lag_detected event** (impl correctly fails fast)

### Negative cases (sub-TCs)
- **TC6a**: empty FAKE_GH_MERGED file (`echo '' > fixture`) → currently impl falls through to `merged_json="[]"` (line 78) → silent_skip with cluster_size=1. **Disputed**: is empty file = config error or graceful degradation? Architect disposition did not specify. **Owner decision.**
- **TC6b**: FAKE_GH_MERGED with valid JSON but missing `mergedAt` field → jq `fromdateiso8601` fails per-row → silent swallow. **Sub-case of F3** — should also exit 2 per Option X.
- **TC6c**: FAKE_GH_MERGED with valid JSON, valid mergedAt, but PR number missing → jq `.number` yields null → arithmetic ops may fail. **Edge case, low priority.**

### Sister-pattern
- ADR-0056 silent_skip doctrine: explicit logging over silent degradation (architect preferred Option X per this)
- ADR-0059 API contract: exit 2 reserved for config errors
- ADR-0044 RED-first: TC6 fails before impl, passes after

### Cross-refs
- Issue #584 AC chain (verbatim body)
- ADR-0059 §1-§4 (cluster detection + batch-lag metric + RETRO format + sister-pattern)
- F3 finding (test plan `docs/test-plans/STORY-P1-1-tests.md` §F3)
- Architect disposition cmt 4826300692 (Option X preferred)
- Owner ratification of Option B + X (per orchestrator 2026-06-28T14:01+03:00 ACK)
- Cycle 649 trust-but-verify discipline

---

## Impl sketch (for dev reference, NOT to be merged)

```bash
# In cluster-lag-detector.sh, REPLACE line 76-79 + line 113 silent swallow:
merged_json="$(cat "$FAKE_GH_MERGED" 2>/dev/null)"
if [ -z "$merged_json" ]; then
  merged_json="[]"
fi

# Add explicit jq parse validation BEFORE the loop (line 113):
if ! echo "$merged_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "ERROR: FAKE_GH_MERGED parse failed: expected JSON array, got: $(echo "$merged_json" | head -c 80)..." >&2
  exit 2
fi

# Replace line 113's `2>/dev/null` with explicit error capture:
while IFS=$'\t' read -r pr_num pr_ts pr_epoch; do
  [ -z "$pr_num" ] && continue
  [ -z "$pr_epoch" ] && continue
  ...
done < <(echo "$merged_json" | jq -r '.[] | [.number, .mergedAt, (.mergedAt | fromdateiso8601)] | @tsv')
# Note: per-row parse errors (TC6b) still need row-level guard. Add:
#   if [ -z "$pr_epoch" ]; then
#     echo "ERROR: row parse failed: $merged_json" >&2
#     exit 2
#   fi
```

---

## Disposition request

@developer: 
- Apply TC6 + impl sketch together (RED → GREEN in one PR) per ADR-0044
- Sub-TCs TC6a (empty file) and TC6c (missing PR number) — owner decision pending; default to current impl behavior unless architect specs otherwise
- TC6b (missing mergedAt field) — should also exit 2 per Option X (same code path)

@owner:
- TC6a disposition (empty file → exit 2 vs silent_skip with empty array): not explicitly addressed in arch cmt 4826300692. Default = current impl (silent_skip with empty array). Confirm or override.

@architect:
- 9-Lens post-cluster workstream review of TC6 + impl delta when PR opens

---

## Status

**Pre-staged**, awaiting dev impl PR push. Will be re-verified per cycle 549 trust-but-verify before my APPROVED verdict fires:
1. #584 body AC4 dropped (Option B ratified)
2. F2 fix applied (TC4 comment amend)
3. F3 fix applied (Option X explicit jq check) + TC6 added
4. d064 self-test 6/6 GREEN (5 original + TC6)
5. No regression on existing TCs (TC1-TC5 still GREEN)