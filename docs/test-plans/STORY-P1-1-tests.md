# Test Plan: STORY-P1#1 — cluster-squash batch-lag detection (Sprint 17)

**Issue**: #584
**ADR**: ADR-0059 §1-§3
**Lane**: `scripts/post-squash/cluster-lag-detector.sh` (new file)
**Branch**: `story-p1-1-cluster-lag-detector-impl-clean` (impl shipped locally, PR not yet open)
**Tester**: @tester (sign-off owner)
**Date drafted**: 2026-06-28 (REPRIME cycle)

---

## Scope

### In scope
- `scripts/post-squash/cluster-lag-detector.sh` — bash detector, FAKE_GH_MERGED contract, JSON log emission
- `scripts/tests/d064-cluster-lag.sh` — 5 TC RED-first d-test (sister-pattern to d061-label-hygiene.sh)
- AC1: detector script exists + executable + bash syntax valid
- AC2: cluster-squash (≥3 PRs in window) detection
- AC3: structured log emission (cluster_lag_detected / silent_skip JSON events)
- AC5: companion d-test d064 validates detector behavior

### Out of scope
- **AC4 (markdown RETRO cluster-lag section generation)** — **NOT IMPLEMENTED in current impl. See §Findings F1 below.**
- Cross-repo watcher (out of scope, separate ADR candidate)
- Real-time alerts (post-hoc detection only)

---

## Test Cases

### TC1: Happy Path — single PR squash → silent_skip (ADR-0048 lens d compliance)
- **Setup**: Fresh log file, FAKE_GH_MERGED contains 1 PR (PR #500 @ T-0)
- **Steps**:
  1. Run detector with PR_NUMBER=500, MERGED_AT=2026-06-27T21:54:34Z
  2. Inspect log file
- **Expected**: exit 0, single JSON event with `event: "silent_skip"`, `reason` mentions cluster_size < 3
- **Covered by**: `d064-cluster-lag.sh` TC3 (✅ GREEN locally)
- **Verifies**: AC3 silent_skip log emission (ADR-0048 lens d mandatory)

### TC2: Cluster Detection — 4 PRs in tight window → cluster_lag_detected (LIVE INSTANCE Issue #508)
- **Setup**: FAKE_GH_MERGED contains 4 PRs spanning 326s (Issue #508 sister-pattern)
- **Steps**:
  1. Run detector with PR_NUMBER=509 @ 22:00:00Z as current PR
  2. Inspect log file
- **Expected**: exit 0, JSON event with `event: "cluster_lag_detected"`, `cluster_size: 4`, `cluster_id: "sprint-14-p1-2-cluster"`, `cluster_lag_seconds: 326`
- **Covered by**: `d064-cluster-lag.sh` TC2 + TC5 (✅ GREEN locally)
- **Verifies**: AC2 cluster detection, AC3 cluster_lag_detected event schema

### TC3: Edge Case — empty merged.json
- **Setup**: FAKE_GH_MERGED is empty file or `[]`
- **Steps**: Run detector, expect cluster_size=1 (just self) → silent_skip
- **Expected**: exit 0, silent_skip event
- **Covered by**: implicit (impl falls through to silent_skip when jq yields empty)
- **Verifies**: graceful degradation on missing siblings

### TC4: Edge Case — malformed MERGED_AT
- **Setup**: MERGED_AT="not-a-date"
- **Steps**: Run detector
- **Expected**: exit 2 (config error per ADR-0059 API contract)
- **Covered by**: NOT in d064 self-test; manual probe needed
- **Verifies**: error path, no silent corruption

### TC5: Edge Case — sibling PRs > window lookback
- **Setup**: FAKE_GH_MERGED has PRs at T-700s, T-650s, T-30s (only last one in 600s window)
- **Steps**: Run detector
- **Expected**: cluster_size=2 (current + last sibling) → silent_skip (threshold not met)
- **Covered by**: `d064-cluster-lag.sh` TC4 (✅ GREEN locally, but comment misleading — see F2)
- **Verifies**: 600s lookback boundary respected (no false-positive cluster)

### TC6: Edge Case — sibling PR equals current PR_NUMBER (self-loop guard)
- **Setup**: FAKE_GH_MERGED contains current PR_NUMBER as a sibling
- **Steps**: Run detector
- **Expected**: PR is skipped (no double-count) → cluster_size correct
- **Covered by**: impl line 103-105 (skip self), not in d-test fixture
- **Verifies**: idempotency on self-reference

### TC7: Negative — Missing env var
- **Setup**: unset PR_NUMBER
- **Steps**: Run detector
- **Expected**: exit 2, error message to stderr
- **Covered by**: impl lines 54-60 `: "${VAR:?...}"` guards
- **Verifies**: ADR-0059 API contract enforcement

### TC8: Negative — FAKE_GH_MERGED file unreadable
- **Setup**: path to nonexistent file
- **Steps**: Run detector
- **Expected**: exit 2
- **Covered by**: impl lines 71-74
- **Verifies**: file-not-found error path

### TC9: Negative — jq not installed (preflight)
- **Setup**: PATH excludes jq
- **Steps**: Run detector
- **Expected**: exit 2 with "jq required" message
- **Covered by**: impl line 67
- **Verifies**: preflight failure path

---

## Adversarial Probes

| Probe | Payload | Expected | Coverage |
|-------|---------|----------|----------|
| **Null byte in MERGED_AT** | `MERGED_AT=$'2026-06-27T21:54:34Z\x00extra'` | exit 2 (date parse fail) | NOT tested — manual |
| **Timezone non-UTC** | `MERGED_AT=2026-06-27T21:54:34+03:00` | UNKNOWN — `date -d` GNU-specific, may accept or fail | NOT tested — portability concern |
| **PR_NUMBER = 0** | `PR_NUMBER=0` | exit 0 (jq accepts 0 as number), cluster_size=1, silent_skip | NOT tested — boundary |
| **PR_NUMBER = -1** | `PR_NUMBER=-1` | exit 0, cluster_size=1, silent_skip | NOT tested — negative |
| **PR_NUMBER = "abc"** | `PR_NUMBER=abc` | exit 2 (jq parse fail on pr_numbers_json construction) | NOT tested |
| **Massive merged.json** | 10000 PRs | Linear scan O(N), no perf regression | NOT tested |
| **Concurrent invocations** | 2 detectors writing same log simultaneously | Race condition: log lines interleaved but no corruption (append-mode) | NOT tested |
| **JSON injection in cluster_id** | `CLUSTER_ID='"; DROP TABLE--'` | jq safe-quoted, no injection | jq -nc with --arg is safe ✅ |
| **Symbolic link FAKE_GH_MERGED** | `FAKE_GH_MERGED=/symlink-to-ssh://...` | jq reads file directly, no URL handling | NOT tested |

---

## Findings

### F1 (P1): AC4 — markdown RETRO cluster-lag section generation NOT IMPLEMENTED

**AC4 (verbatim)**: *"Script generates RETRO cluster-lag section per cluster-squash event (markdown format)"*

**Current impl** (`scripts/post-squash/cluster-lag-detector.sh`): emits only **JSON event** to `CLUSTER_LAG_LOG`. No markdown generation logic exists. No markdown file path env var, no markdown emission function, no markdown template.

**Impact**: AC4 not satisfied. Story cannot close as DoD-ready until either (a) AC4 is implemented, or (b) AC4 is rescoped/marked out-of-scope via owner decision.

**Recommendation**:
- Option A (impl adds AC4): detector emits `cluster_lag_detected` JSON event AND appends markdown section to `docs/sprints/sprint-NN/retro-cluster-lag.md` (or similar). Owner decides path.
- Option B (rescope): drop AC4 from STORY-P1#1, defer to STORY-P1#5+ (separate story for RETRO markdown tooling).

**Tester verdict stance**: Cannot sign off impl PR until AC4 disposition is decided. Auto-ping @developer + @architect for path.

### F2 (P3): d064 TC4 comment misleading — "60s threshold boundary" vs actual "600s lookback exclusion"

**TC4 comment (line 272)**: `# TC4: 60s threshold boundary — 2 PRs at 61s gap → silent_skip (false-positive guard)`

**Actual test logic**: PRs at 22:00:00, 22:00:30 (current), 22:01:01. Lookback from current_ts - 600s = 21:50:30. PR 512 at 22:01:01 is **outside** the 600s lookback (not "61s gap"). The test verifies 600s lookback boundary, not 60s threshold.

**Reason for drift**: ADR-0059 §1 says "60s window" but impl uses 600s lookback (script comment line 18-19 acknowledges this: "ADR-0059 §1 '60s window' phrasing imprecise — actual window = 600s lookback per d064 TC2 fixture codification").

**Disposition (per architect cmt 4826300692)**: ARCH disposition "F2 (P3): d064 TC4 comment misleading... Cosmetic doc fix, no impl change. **Tester amendment OK**."

**Fix (ready to apply, 1-line amend)**:
```diff
- # TC4: 60s threshold boundary — 2 PRs at 61s gap → silent_skip (false-positive guard)
+ # TC4: 600s lookback boundary (1 sibling outside 600s window) → silent_skip
```
Cosmetic doc fix, no code change required. ADR-0059 §1 amendment tracked Sprint 18+.

### F3 (P2): jq silent error swallow on malformed merged.json

**Impl line 113**: `done < <(echo "$merged_json" | jq -r '.[] | [.number, .mergedAt, (.mergedAt | fromdateiso8601)] | @tsv' 2>/dev/null)`

**Risk**: `2>/dev/null` swallows jq parse errors. If merged.json is malformed, sibling PRs silently vanish → cluster_size=1 → silent_skip. No operator-visible warning.

**Disposition (per architect cmt 4826300692)**: ARCH "Option X (add explicit jq error check before loop, exit 2 on parse error) — preferred per ADR-0056 silent_skip doctrine. Option Y (document silent degradation as by design in script header) — fallback. **Owner decision.**"

**Tester stance**: Defer to owner per ADR-0031. Architect prefers Option X (explicit check, exit 2 on parse error — sister-pattern to ADR-0056 silent_skip doctrine).

---

## Performance Concerns

- **Linear scan**: impl reads ALL merged PRs in JSON, filters by window in bash loop. O(N) per detector invocation. With ~5000 merged PRs in repo history, each invocation costs ~50ms jq parse + bash loop. Acceptable for GH Action sequential invocation.
- **Log file growth**: `CLUSTER_LAG_LOG` is append-only, never rotated. After ~1000 cluster_lag_detected events, log will be ~500KB. Should add logrotate config in Sprint 18+ cleanup.

---

## Regression Risk

- **Sister-pattern to label-hygiene.sh (Sprint 16 §3)**: Both write to log files in `/var/log/dev-studio/AtilCalculator/`. No conflict (different log files). Low.
- **d-test lineage**: d064 joins d061/d062/d063 as 17-sister cluster. Cross-test interaction: TC fixtures must NOT pollute each other's logs. d064 self-test uses `$TEST_TMPDIR` per TC — isolated ✅.
- **Production workflow integration**: detector expects `FAKE_GH_MERGED` env var (line 60) — workflow YAML must pass `gh pr list --state merged --json mergedAt,number` output as file. **NOT YET WIRED**. PR-author concern: workflow file in `.github/workflows/` is owner-only territory.

---

## d-test coverage matrix

| AC | Covered by d064 TC | Status (local) |
|----|---------------------|----------------|
| AC1 | TC1 (exists + executable + bash -n) | ✅ GREEN |
| AC2 | TC2 (4-PR cluster detect) | ✅ GREEN |
| AC3 cluster_lag_detected | TC2 (event schema) | ✅ GREEN |
| AC3 silent_skip | TC3 (single-PR squash) | ✅ GREEN |
| AC4 markdown generation | — | ❌ **NOT IMPLEMENTED** |
| AC5 d-test sister-pattern | TC1-TC5 (5 TCs RED-first) | ✅ GREEN |

---

## Tester verdict

**Local state**: 5/5 d064 TCs GREEN. Impl functionally correct for AC1, AC2, AC3, AC5.

**Architect disposition received** (cmt 4826300692, 2026-06-28T13:51Z):
- AC4 Option B (rescope) RECOMMENDED — manual PM curator step, no impl change
- F2 cosmetic fix approved (Tester amendment OK)
- F3 deferred to owner (Option X explicit check vs Option Y document-only)

**Sign-off blocker**: AC4 owner ratification per ADR-0031. Until owner ratifies Option B (or picks A/C), impl PR sign-off lane stays 🔴 CHANGES REQUESTED.

**Action**: Standing by for owner decision gate (Option A/B/C on AC4 + Option X/Y on F3). F2 fix ready to apply, will land with impl PR.