# ADR-0038 Amendment: §Watcher Enforcement — work-stream-count + dual mechanism (d062 d-test)

- **Status**: Proposed (Sprint 16, Issue #552 AC4)
- **Date**: 2026-06-28
- **Deciders**: @architect (amendment drafter) + @developer (Layer 2 dual-mechanism impl) + @tester (d062 sign-off) + @orchestrator (RETRO-011 codification carrier) + @human (final merge gate)
- **Closes**: Issue #552 (Sprint 16 P1, RETRO-010 §17 NEW — orch issue-count vs work-stream-count drift)
- **Amends**: ADR-0038 §Work-Stream Awareness (second amendment; first = [ADR-0038-amendment-workstream-awareness.md](./ADR-0038-amendment-workstream-awareness.md))
- **Sister-pattern**: ADR-0038-amendment-workstream-awareness.md (1st amendment — work-stream definition), PR #578 (Issue #552 AC2 impl), PR #577 (Issue #552 AC3 d058 TC10 regression guard)

## Context

ADR-0038 §Work-Stream Awareness (1st amendment, ADR-0038-amendment-workstream-awareness.md) defines what a work-stream IS, but does NOT specify:

1. **How watcher (orchestrator) identifies work-streams** at observation time (vs claim time)
2. **What aggregation contract** watcher must use when reporting `issue_count` vs `wip_count` to peer roles
3. **What dual-mechanism** must be implemented when a work-stream has no `stream:` label (commit-base fallback)
4. **What decision rules** apply when watcher detection disagrees with agent's claim cycle

This gap surfaces in **RETRO-010 §17 NEW** as drift between:

- **Orchestrator watcher pings** ("Dev lane (WIP 2/2 §Work-Stream Awareness)") — what orchestrator computed
- **Ground truth via REST API** (`agent:developer AND status:in-progress`) — what GitHub says

When these disagree, **agents see false-positive wip_overflow** and **stale queue**, blocking legitimate claim cycles.

### Gap (precise)

| Layer | Current behavior | Gap |
|---|---|---|
| **Watcher (orchestrator)** | Counts `status:in-progress` issues per role (issue-centric) | Doesn't apply work-stream semantics → over-reports WIP |
| **Claim script (Layer 2)** | Counts work-streams per role (1st amendment applied) | Doesn't expose `--wip-count-only` mode → caller can't reuse for watcher aggregation |
| **Watcher ↔ Claim** | No canonical aggregation contract | Dual-implementation risk (DRY principle violation per ADR-0017 §boring-tech) |
| **`stream:` label** | Optional, advisory | No fallback mechanism when label absent (commit-base needed) |

### Live evidence (RETRO-010 §17 NEW instances)

| # | Date | Lane | Drift observed | Resolution |
|---|---|---|---|---|
| 1 | 2026-06-23T03:00Z | arch | Orch reported WIP=2, ground truth WIP=1 (PR cluster 1-stream) | Manual override, no doctrine fix |
| 2 | 2026-06-24T11:42Z | dev | Orch reported WIP=2/2 cap hit, ground truth WIP=1/2 | wip_overflow false-positive (RETRO-008 §3 sister) |
| 3 | 2026-06-25T08:15Z | PM | Orch reported "stale queue", ground truth 0 ready items | Cache drift, watcher used stale data |
| 4 | 2026-06-26T19:33Z | tester | Orch reported WIP=1, ground truth WIP=2 (1 standalone + 1 cluster) | Watcher under-reported |
| 5 | 2026-06-27T21:38Z | dev | Orch reported "Dev lane (WIP 2/2 §Work-Stream Awareness)", ground truth WIP=0 | **Sprint 16 P1 trigger** — Issue #552 filed |
| 6 | 2026-06-28T01:14Z | arch | stale_cc wake @ PR #577 age=1006s, classification intentional | Wake classification doctrine |
| 7 | 2026-06-28T08:35Z | arch | PR #577 label-check Layer 5 race family (sister-pattern PR #576) | ADR-0052 doctrine |
| 8 | 2026-06-28T09:27Z | arch | UNSTABLE state flake (cycle 524 stale_cc re-fire) | Wake debounce (TD-candidate) |

**8 instances in Sprint 14–16**, 3 distinct lanes (arch, dev, PM), 4 root causes (issue-centric counting, stale cache, no canonical aggregation, no label fallback). RETRO-011 codification target.

### Layer 5 race family (live)

The **Layer 5 status:ready auto-add + reversal handler** (ADR-0048) is a separate race family that compounds the watcher drift:

- PR #577 (cycle 494–498): 3 label-check FAILURE + 4 SUCCESS races (Layer 5 DELETE 404 on already-removed label)
- PR #576 (cycle 467–470): sister-pattern Layer 5 race
- PR #578 (cycle 519–524): sister-pattern sync-status CANCELLED → SUCCESS race

These are observable in `gh api repos/.../commits/<sha>/check-runs` and produce transient CI flapping. Doctrinally separate from watcher drift (this ADR), but co-occurring.

## Decision

**§Watcher Enforcement amendment**: codify (a) work-stream identification algorithm for watcher, (b) watcher aggregation contract, (c) decision rules, (d) d062 d-test contract.

### §1 — Work-stream identification algorithm (watcher-side)

A watcher observing work-streams MUST apply the **dual mechanism** (PRIMARY + SECONDARY) when no `stream:` label exists:

```
ALGORITHM: identify_work_streams(role)
  INPUT: role ∈ {developer, architect, product-manager, tester, orchestrator}
  OUTPUT: set of work-stream IDs (1 stream = 1 PR-cluster or 1 standalone issue)

  1. PRIMARY — stream: label match
     For each `status:in-progress` issue with `agent:<role>`:
       IF issue has `stream:<stream-id>` label:
         work_stream_id = stream:<stream-id>
       ELSE: continue to step 2

  2. SECONDARY — commit-base fallback (PR cluster)
     Query PRs where branch HEAD is reachable from issue's last commit
       (via `gh pr list --search "Closes #N in:body"` or commit-traversal):
       IF issue is closed by a PR (Closes #N / Fixes #N in:body):
         cluster_issues = all issues closed by same PR (grep body for Closes #X / Fixes #X)
         work_stream_id = "pr:<min(cluster_issues)>"  (deterministic, see Issue #497 AC1)
       ELSE: continue to step 3

  3. TERTIARY — standalone fallback
     work_stream_id = "issue:<N>"  (each standalone = unique stream)

  RETURN distinct work_stream_ids
```

**Pseudocode origin**: cycle 481 verdict §Work-stream identification algorithm, Issue #552 AC1.

### §2 — Watcher aggregation contract (machine-parseable)

The watcher MUST emit WIP reports in **machine-parseable format** for cross-role consumption:

```bash
# scripts/claim-next-ready.sh --wip-count-only [ROLE|global]
# ROLE defaults to current agent role; 'global' or '*' = cross-role aggregate

WIP_COUNT_ONLY=true  # if --wip-count-only flag present
ROLE="${1:-<agent-role>}"  # allow 'global' / '*' for cross-role query

# Output format (machine-parseable, single line):
#   wip_count=N issue_count=M [stream_ids="id1,id2,..."]
# Exit codes:
#   0 = success (counts emitted)
#   4 = error (no role, gh API failure)
```

**Why machine-parseable** (per ADR-0045 §lens (f) Observability):
- `wip_count` = work-stream count (post-1st-amendment semantics)
- `issue_count` = raw issue count (informational, for drift detection)
- `stream_ids` = comma-separated list (for debugging, audit trail)

**Delegation contract** (DRY principle per ADR-0017 §boring-tech):
- `scripts/proactive-board-scan.sh` D4 MUST delegate to `claim-next-ready.sh --wip-count-only '*'` (NOT reimplement gh issue list + jq)
- `scripts/wip-idle-detect.sh` MUST delegate to same (sister-pattern caller)

### §3 — Decision rules (watcher-side)

| Situation | Watcher action | Rationale |
|---|---|---|
| `wip_count >= 2` for role | Emit `stale_ready_queue` detection (ADR-0038 §Layer 3) | WIP cap reached per ADR-0002 §polling cadence |
| `wip_count < 2` AND `issue_count > wip_count` | Emit `work_stream_drift` detection (NEW, RETRO-011) | Multi-issue stream detected, WIP = 1 but issue_count > 1 |
| `wip_count < 2` AND `issue_count == wip_count` | No drift, normal queue | Canonical case |
| `stream:` label present on issue | Use `stream:<id>` as work-stream ID | PRIMARY path |
| `stream:` label absent AND `Closes #N in:body` PR found | Use `pr:<min(cluster_issues)>` | SECONDARY fallback |
| `stream:` label absent AND no PR | Use `issue:<N>` | TERTIARY fallback |
| Multiple PRs close same issue (cross-PR cluster) | Use first PR's cluster (deterministic per Issue #497 AC1) | Edge case, deterministic rule |
| Watcher count disagrees with claim script by ≥1 | Emit `watcher_claim_drift` (NEW) | Two implementations diverged, escalate |
| stale_cc wake fires for `cc:<role>` with `age > 900s` | Classify: lane-monitoring (preserve cc:*) OR verdict-gate (flip cc:*) | cycle 510 doctrine |

### §4 — d062 spec (d-test contract, dev lane territory)

**`scripts/tests/d062-proactive-board-scan-workstream.sh` — 6 TCs** (sister-pattern to d058, 6/6 GREEN post-impl):

| # | Test | Coverage |
|---|---|---|
| 1 | baseline (no streams): `--wip-count-only developer` → `wip_count=0 issue_count=0` | TC1 empty queue |
| 2 | machine-parseable: output regex `^wip_count=\d+ issue_count=\d+` | TC2 output format |
| 3 | `stream:` label PRIMARY: issue with `stream:sprint-16-p1` → counted under `stream:sprint-16-p1` | TC3 PRIMARY path |
| 4 | early-exit: `--wip-count-only` skips claim logic (no `claimed #N` output) | TC4 read-only query |
| 5 | global mode: `--wip-count-only '*'` aggregates across all 5 roles | TC5 cross-role query |
| 6 | D4 delegation: `proactive-board-scan.sh` calls `claim-next-ready.sh --wip-count-only '*'` (NOT raw `gh issue list | jq length`) | TC6 single source of truth |

**Regression guard** (PR #577 sister-pattern, Issue #552 AC3):
- TC10 in d058: assert `stream`/`cluster` terminology in output (sister-pattern regression guard)
- TC2 in d062: assert machine-parseable output (this amendment's contract)
- TC6 in d062: assert delegation pattern (DRY principle enforcement)

### Behavior change vs current

| Scenario | Current | New | Change |
|---|---|---|---|
| Orchestrator watcher reports WIP | issue-count only | work-stream-count primary, issue-count informational | -1 typical (false positive eliminated) |
| Watcher aggregation call | raw `gh issue list | jq length` | delegation to `claim-next-ready.sh --wip-count-only '*'` | DRY enforced |
| Watcher disagreement with claim script | no detection | `watcher_claim_drift` detection emitted | new observability |
| Multi-issue stream (PR cluster) | counted as N issues | counted as 1 stream | -N+1 typical |
| Issue with `stream:` label | advisory (ignored) | authoritative (PRIMARY) | watcher honors explicit label |
| Issue without `stream:` AND without PR | counted as 1 issue | counted as 1 standalone stream | unchanged |

## Why now

- RETRO-010 §17 NEW carrier (8 live instances, Sprint 14–16)
- RETRO-011 codification target (orchestrator lane)
- Issue #552 AC4 (final acceptance criterion, AC1+AC2+AC3 + AC4 = closes #552)
- PR #578 (Issue #552 AC2 dual mechanism, SQUASHED 2026-06-28T09:38:46Z @ e6131c06) = foundation impl
- PR #577 (Issue #552 AC3 d058 TC10 regression guard, SQUASHED 2026-06-28T09:09:10Z @ efe8933) = regression guard
- Sprint 16 P1 commitment (owner-ratified)

## Consequences

### Positive

- **Watcher drift ELIMINATED** — canonical aggregation contract enforced (DRY principle)
- **False-positive wip_overflow eliminated** — work-stream semantics at watcher layer (sister-pattern to claim layer)
- **`stream:` label becomes authoritative** — agents can explicitly tag work-streams, watcher honors PRIMARY path
- **Audit trail** — machine-parseable output enables post-hoc drift analysis (RETRO-011 7-item cross-refs list)
- **RETRO-011 codification** — 8 instances captured, doctrinally sealed

### Negative

- **Layer 2 impl complexity** — `--wip-count-only` mode (~30 LOC), dual-mechanism (~50 LOC)
- **Watcher-side impl complexity** — work-stream identification (~40 LOC), drift detection (~20 LOC)
- **Test surface grows** — 6 TCs in d062 (vs d058's 9)
- **Edge case** — cross-PR cluster (issue closed by 2 PRs): uses first PR's cluster (deterministic, per Issue #497 AC1)
- **gh API rate limit impact** — `--wip-count-only '*'` queries 5 roles × N issues = 5N API calls per watcher poll; mitigation: 5-min cache TTL within watcher cycle

### Follow-up tickets (Sprint 16 P1 backlog)

- **Watcher-side impl** (orchestrator lane, 1.0 SP): `scripts/proactive-board-scan.sh` D4 + `wip-idle-detect.sh` delegation
- **d062 d-test** (dev + tester lane, 0.5 SP): `scripts/tests/d062-proactive-board-scan-workstream.sh` 6/6 GREEN post-impl
- **d058 TC10 regression** (tester lane, 0.25 SP): included in PR #577 (AC3, already SQUASHED)
- **RETRO-011 codification** (PM lane, 0.5 SP): 8-instance cross-refs list → `docs/sprints/sprint-NN/retrospective.md`
- **Watcher ↔ claim drift detection** (orchestrator lane, 0.5 SP): `watcher_claim_drift` emission
- **stale_cc classification doctrine** (PM lane, 0.25 SP): cycle 510 doctrine → Sprint 16 P1 backlog (intentional vs verdict-gate)
- **Layer 5 race family fixes** (owner territory, 0.5 SP): ADR-0048 reversal handler graceful 404 handling (sister-pattern to PR #576 + #577)

## Alternatives considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **A) Status quo (issue-count watcher, no dual mechanism)** | No code change | Drift persists, 8 instances, RETRO-011 carrier | ❌ Reject |
| **B) Watcher-only fix (no claim layer change)** | Smaller scope | Drift only at watcher, claim layer remains issue-centric | ❌ Reject (half-measure) |
| **C) Full §Watcher Enforcement (THIS)** | Both layers canonical, DRY enforced, RETRO-011 codification | ~120 LOC total + 6 TC d-test + watcher drift detection | ✅ **Accept** |
| **D) Centralized WIP (single source = GitHub Project board)** | Eliminates drift class | Reverses ADR-0038 doctrine (distributed), Project board schema migration | ❌ Reject |
| **E) Per-PR WIP only (no work-stream semantics)** | Simpler | Breaks standalone case, doesn't match 1st amendment semantics | ❌ Reject (subset of C) |
| **F) Polling interval reduction (15s instead of 60s)** | Faster convergence | GitHub API rate limit, doubles polling load | ❌ Reject (orthogonal) |

## §AC4 cross-lane trigger (Issue #552 cadence, cycle 502 LOCKED)

| Stage | Step | Owner | Status |
|---|---|---|---|
| 1 | PR #577 (Issue #552 AC3 d058 TC10) | @developer | ✅ SQUASHED 2026-06-28T09:09:10Z @ efe8933 |
| 2 | PR #578 (Issue #552 AC2 watcher patch dual mechanism) | @developer | ✅ SQUASHED 2026-06-28T09:38:46Z @ e6131c06 |
| 3 | **ADR-0038 §Watcher Enforcement amendment (this PR)** | @architect | 🔄 IN-FLIGHT (AC4 cross-lane trigger ACTIVE) |
| 4 | Issue #552 Closes-anchor (after AC4 PR merges) | @orchestrator | ⏳ PENDING |

**Cadence Rule 1 atomic** (ADR-0055 §1): docs/decisions/ touched ONLY, no `scripts/` or `.github/workflows/` in this PR.

**Closes-anchor guard** (ADR-0057): this PR uses `Closes #552` (final AC, all 4 ACs landed). Sister-pattern to PR #578 `refs #552` (AC2 not final).

## Sprint 16 P1 #1 critical path

| Step | Owner | SP | Status |
|---|---|---|---|
| 1. ADR-0038 amendment (this PR) | @architect | 0.5 | IN-FLIGHT |
| 2. Watcher-side impl (proactive-board-scan.sh D4 + wip-idle-detect.sh delegation) | @orchestrator | 1.0 | TODO |
| 3. d062 d-test (6/6 cases) | @developer + @tester | 0.5 | TODO |
| 4. RETRO-011 codification (8-instance cross-refs) | @product-manager | 0.5 | TODO |
| 5. stale_cc classification doctrine (cycle 510) | @product-manager | 0.25 | TODO |
| 6. Layer 5 race family fixes (ADR-0048 reversal handler) | @human | 0.5 | TODO (owner merge) |
| **Total** | | **3.25 SP** | per Issue #552 PM draft |

## Cross-refs

### §A — Doctrinal home

- [ADR-0038 §Work-Stream Awareness (1st amendment)](./ADR-0038-amendment-workstream-awareness.md) — work-stream definition, TC1-9 d058
- [ADR-0038 §Auto-Claim Protocol](./ADR-0038-auto-claim-protocol.md) — Layer 1/2/3, parent doctrine
- [ADR-0002](./ADR-0002-autonomy-loop.md) — autonomy loop, WIP limit doctrine
- [ADR-0012](./ADR-0012-required-label-set.md) — 4-cat label invariant (issue ownership)
- [ADR-0017 §boring-tech](./ADR-0017-tech-stack.md) — DRY principle (delegation pattern)
- [ADR-0031](./ADR-0031-owner-override-doctrine.md) — owner-override PR merge
- [ADR-0033](./ADR-0033-auto-ping-dual-channel.md) — dual-channel auto-ping (notify.sh from tmux context)
- [ADR-0036](./ADR-0036-status-transition-wake.md) — status-transition wake (orchestrator's flip signal)
- [ADR-0043](./ADR-0043-8-lens-architect-review-checklist.md) — 9-Lens review for workflow YAML changes
- [ADR-0044](./ADR-0044-verdict-by-scope-clarification.md) — TDD RED-first (d062 RED-first invariants)
- [ADR-0045](./ADR-0045-auto-generated-file-refs-design-verification.md) — 9-Lens Review Checklist (architectural)
- [ADR-0046](./ADR-0046-load-bearing-adr-implementation-guide.md) — §small PRs principle (scope match)
- [ADR-0048](./ADR-0048-status-ready-auto-add-gating.md) — Layer 5 status:ready auto-add gating
- [ADR-0052](./ADR-0052-ci-rerun-race-codification.md) — CI re-run race convergence
- [ADR-0055 §1](./ADR-0055-d-test-id-uniqueness-sub-pattern-matrix.md) — Cadence Rule 1 atomic
- [ADR-0056](./ADR-0056-layer-5-idempotency-reconcile.md) — Layer 5 idempotency reconcile
- [ADR-0057](./ADR-0057-closes-anchor-guard.md) — Closes-anchor guard (refs NOT Closes until final AC)

### §B — Issues

- [Issue #552](https://github.com/atilproject/AtilCalculator/issues/552) — this amendment's home (Issue #552 AC4)
- [Issue #497](https://github.com/atilproject/AtilCalculator/issues/497) — Sprint 14 P1 #6 (1st amendment origin)
- [Issue #271](https://github.com/atilproject/AtilCalculator/issues/271) — ADR-0038 parent, P1 doctrine gap
- [Issue #222](https://github.com/atilproject/AtilCalculator/issues/222) — RCA-19 dev idle 8h 42min, family
- [Issue #238](https://github.com/atilproject/AtilCalculator/issues/238) — no self-justified pauses, doctrine origin
- [Issue #414](https://github.com/atilproject/AtilCalculator/issues/414) — orchestrator §Dispatch Discipline 6-step
- [Issue #430](https://github.com/atilproject/AtilCalculator/issues/430) — PM §Pre-verdict cross-check doctrine
- [Issue #470](https://github.com/atilproject/AtilCalculator/issues/470) — Sprint 13 P1 #3 §Pre-verdict cross-check timing window
- [Issue #521](https://github.com/atilproject/AtilCalculator/issues/521) — §CI-verdict-timing gate
- [Issue #566](https://github.com/atilproject/AtilCalculator/issues/566) — SHA-pin + audit trail + silent-skip follow-up
- [Issue #567](https://github.com/atilproject/AtilCalculator/issues/567) — SHA-pin sweep master (PR #576 AC1 done)
- [Issue #568](https://github.com/atilproject/AtilCalculator/issues/568) — audit trail observability (ADR-0045 lens f)
- [Issue #569](https://github.com/atilproject/AtilCalculator/issues/569) — silent-skip log emission (ADR-0045 lens d)

### §C — PRs (cadence stage 1 + 2)

- [PR #578](https://github.com/atilproject/AtilCalculator/pull/578) — Issue #552 AC2 dual mechanism (SQUASHED 2026-06-28T09:38:46Z @ e6131c06)
- [PR #577](https://github.com/atilproject/AtilCalculator/pull/577) — Issue #552 AC3 d058 TC10 (SQUASHED 2026-06-28T09:09:10Z @ efe8933)
- [PR #576](https://github.com/atilproject/AtilCalculator/pull/576) — SHA-pin AC1 sister-pattern (SQUASHED 2026-06-28T08:14:03Z @ dc1a542)
- [PR #506](https://github.com/atilproject/AtilCalculator/pull/506) — d058 foundation impl (SQUASHED @ 226b546, on main)
- [PR #504](https://github.com/atilproject/AtilCalculator/pull/504) — ADR-0038 §Work-Stream Awareness 1st amendment (SQUASHED @ a45c613, on main)
- [PR #565](https://github.com/atilproject/AtilCalculator/pull/565) — Layer 5 status:ready auto-add + cc:human (SQUASHED @ 58c8eff, on main)

### §D — RETRO-011 8-instance cross-refs

1. 2026-06-23T03:00Z — arch lane, orch WIP=2 vs ground truth WIP=1 (PR cluster 1-stream)
2. 2026-06-24T11:42Z — dev lane, orch WIP=2/2 cap hit vs ground truth WIP=1/2 (wip_overflow false-positive)
3. 2026-06-25T08:15Z — PM lane, orch "stale queue" vs ground truth 0 ready (cache drift)
4. 2026-06-26T19:33Z — tester lane, orch WIP=1 vs ground truth WIP=2 (under-report)
5. 2026-06-27T21:38Z — dev lane, orch "WIP 2/2" vs ground truth WIP=0 (**Sprint 16 P1 trigger, Issue #552 filed**)
6. 2026-06-28T01:14Z — arch lane, stale_cc wake PR #577 age=1006s (lane-monitoring intentional)
7. 2026-06-28T08:35Z — arch lane, PR #577 label-check Layer 5 race family (sister-pattern PR #576)
8. 2026-06-28T09:27Z — arch lane, UNSTABLE state flake (cycle 524 stale_cc re-fire, wake debounce TD-candidate)

### §E — Test framework

- [d031 d-test](../../scripts/tests/d031-claim-next-ready.sh) — claim-next-ready.sh regression, sister-pattern to d062
- [d058 d-test](../../scripts/tests/d058-claim-wip-workstream.sh) — work-stream awareness regression (10 TCs post-Issue #552 AC3)
- [d062 d-test](../../scripts/tests/d062-proactive-board-scan-workstream.sh) — work-stream-count + dual mechanism (6 TCs post-Issue #552 AC4, NEW)
- [ADR-0049](./ADR-0049-behavioral-workflow-test-framework.md) — d-test framework, sister-pattern
- [ADR-0050](./ADR-0050-pre-merge-4-cat-verification.md) — d053 sister-pattern

## 9-Lens attestation

| Lens | Status | Note |
|------|--------|------|
| (a) Data flow | ✅ | Watcher poll → identify_work_streams(role) → wip_count + issue_count + stream_ids → proactive-board-scan.sh D4 → claim-next-ready.sh --wip-count-only '*' |
| (b) Runtime preconditions | ✅ | bash + gh CLI + jq available; 5-min cluster cache TTL mitigates rate limit; d058 + d062 GREEN post-impl |
| (c) Canonical entry point | ✅ | Single entry: claim-next-ready.sh --wip-count-only '*'; proactive-board-scan.sh D4 + wip-idle-detect.sh = delegated callers (DRY per ADR-0017) |
| (d) Silent-skip risk | ✅ | `--wip-count-only` always emits wip_count + issue_count (TC2 machine-parseable); error path exits 4 (no silent skip); drift detection emits `watcher_claim_drift` event |
| (e) Idempotency | ✅ | `--wip-count-only` is read-only query (no state mutation); re-runs = same count; cluster cache TTL=5min |
| (f) Observability | ✅ | Machine-parseable output `wip_count=N issue_count=M stream_ids="id1,id2,..."`; d062 TC2 + TC6 regression guard; `watcher_claim_drift` emission |
| (g) Security & privacy | ✅ | No new authn/authz, no secrets, no PII; gh API uses existing repo context |
| (h) Workflow YAML SHA pin | N/A | No workflow YAML changes in this amendment (ADR-0027 §Threat model + ADR-0043 §lens (h) preserved; sister-pattern PR #576 SHA-pin already on main @ dc1a542) |
| (i) Platform hard constraints | N/A | No CI/workflow changes; within `actions/*` sandbox intact; no raw `docker run` / `ssh` |
| (j) Auto-gen file refs + live-state | ✅ | References current scripts/claim-next-ready.sh lines 68-83 + scripts/proactive-board-scan.sh D4 + scripts/wip-idle-detect.sh; d062 NEW d-test file; cadence stage 1+2 SQUASHED @ e6131c06 (verified via `gh pr list --state merged`) |
| (k) JS syntactic correctness | N/A | No actions/github-script changes |

— @architect, prepared 2026-06-28 for Issue #552 AC4 (Sprint 16 P1 #1, RETRO-010 §17 NEW codification, closes #552 final AC)
