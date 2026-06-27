# ADR-0038 Amendment: §Auto-Claim Protocol Work-Stream Awareness (d058 d-test)

- **Status**: Proposed (Sprint 14 P1 #6)
- **Date**: 2026-06-27
- **Deciders**: @architect (amendment drafter) + @developer (Layer 2 impl) + @tester (d058 sign-off) + @human (CI integration)
- **Closes**: Issue #497 (Sprint 14 P1 #6, §wip_overflow false positive fix)
- **Amends**: ADR-0038 §Layer 2 (WIP counting, claim-next-ready.sh lines 68-83)

## Context

ADR-0038 §Layer 2 (claim-next-ready.sh lines 68-83) computes WIP by ISSUE COUNT:

```bash
wip_count=$(gh issue list --label "agent:${ROLE}" --label "status:in-progress" --state open --json number --jq 'length')
```

This causes **false-positive wip_overflow** when a PR cluster closes multiple issues simultaneously:

- PR-A closes Issue #N + Issue #M
- Both #N + #M flipped to `status:in-progress` when PR-A opens
- WIP = 2 (both issues counted)
- Reality = 1 work-stream (the PR is the unit of work)

**RETRO-008 §3 captured** this as a wip_overflow false positive. Agent-watch.sh wip_overflow heuristic triggers on legitimate 2-issue concurrent work, blocking new claims. **3 LIVE INSTANCES** captured in Sprint 13–14.

### Gap

- Layer 2 WIP counting is **issue-centric**, not **work-stream-centric**
- A "work-stream" is a logical group of issues addressed together (typically via PR cluster)
- WIP semantics should match mental model: 1 PR = 1 stream, even if it closes N issues

### Live evidence

| Instance | Description | Impact |
|---|---|---|
| Sprint 13 PM lane | PM worked 2 issues in parallel via 1 PR | claim-next-ready.sh incorrectly blocked 3rd claim |
| Sprint 14 arch lane (current) | PR #502 + PR #503 both squash-ready, 2 issues in-progress | wip_overflow blocked Issue #497 claim until PR #502 squash |
| Sprint 13 dev lane | dev worked 2 bugs in single hotfix PR | claim blocked until one bug closed |

## Decision

**Layer 2 amendment**: WIP counted by **WORK-STREAM**, not by issue count. A work-stream = a logical group of issues linked by PR-cluster relationship.

### Work-stream definition

A work-stream is:

1. **PR cluster**: issues #N and #M are in the same work-stream if any PR has `Closes #N` AND `Closes #M` in its body
2. **Standalone issue**: an `status:in-progress` issue with no PR closing it = 1 work-stream

**WIP count** = number of distinct work-streams with at least one issue in `status:in-progress`.

### Algorithm (Layer 2 impl, dev lane ~30 LOC)

```bash
# 1. List all status:in-progress issues for role
in_progress=$(gh issue list --label "agent:${ROLE}" --label "status:in-progress" \
  --state open --json number)

# 2. For each issue, find PRs that close it (Closes #N / Fixes #N in:body)
# Build work-stream graph: issue → PR-cluster-id (uses min issue# in cluster as id)

declare -A issue_to_stream_id
declare -A seen_streams

for issue_num in $(echo "$in_progress" | jq -r '.[].number'); do
  closing_prs=$(gh pr list --state all --search "Closes #$issue_num in:body" \
    --json number,body --limit 5)
  
  if [ -z "$closing_prs" ] || [ "$(echo "$closing_prs" | jq 'length')" = "0" ]; then
    # Standalone issue = new work-stream (unique id = "issue:<N>")
    issue_to_stream_id[$issue_num]="issue:$issue_num"
    continue
  fi
  
  # PR cluster: extract all Closes #N / Fixes #N references from PR body
  pr_body=$(echo "$closing_prs" | jq -r '.[0].body')
  cluster_issues=$(echo "$pr_body" | grep -oiE '(Closes|Fixes) #[0-9]+' \
    | grep -oE '[0-9]+' | sort -un | head -10)
  
  # All cluster issues share one work-stream id (use min issue# as id)
  stream_id="pr:$(echo "$cluster_issues" | head -1)"
  for ci in $cluster_issues; do
    issue_to_stream_id[$ci]="$stream_id"
  done
done

# 3. Count distinct work-streams
wip_count=$(printf '%s\n' "${issue_to_stream_id[@]}" | sort -u | wc -l)
```

### Decision rules

1. **WIP = work-stream count, not issue count** (Layer 2 §WIP cap check)
2. **PR cluster detected via `gh pr list --search "Closes #N in:body"`** — robust to multi-line body, case-insensitive
3. **Standalone issue = 1 stream** — no PR yet
4. **A claim that joins an EXISTING work-stream** does NOT increase WIP (e.g., claiming #M when PR-A already closes #N + #M)
5. **A claim that starts a NEW work-stream** increases WIP by 1

### Edge cases (test matrix for d058)

| Case | Setup | WIP expected | Notes |
|---|---|---|---|
| TC1: PR-A closes #N + #M, both in-progress | 1 PR cluster | WIP=1 | the canonical case |
| TC2: PR-A closes #N, #M standalone in-progress | 1 PR + 1 standalone | WIP=2 | distinct streams |
| TC3: #N in-progress, no PR | 1 standalone | WIP=1 | standalone only |
| TC4: #N + #M in-progress, no PR, no relationship | 2 standalone | WIP=2 | separate streams |
| TC5: #N closed-by PR-A, #M closed-by PR-B | 2 PR clusters | WIP=2 | distinct PR-streams |
| TC6: PR-A closes #N + #M + #O, all in-progress | 1 PR cluster (3 issues) | WIP=1 | 3-issues-1-stream |
| TC7: #N in-progress, no PR, claimed fresh | 1 standalone | WIP=1 | claim-time check |
| TC8: WIP cap reached (1 stream already), standalone ready | 1 in-progress stream | WIP=1, no claim | cap holds at stream level |
| TC9: cross-PR cluster (issue closed by 2 PRs) | 1 issue, 2 PRs | WIP=1 | uses first PR's cluster, deterministic |

### Behavior change vs current

| Scenario | Current WIP | New WIP | Change |
|---|---|---|---|
| PR-A closes #N + #M, both in-progress | 2 | 1 | -1 (sister-pattern to RETRO-008 §3) |
| PM lane 2-issue concurrent work | 2 (false positive) | 1 (correct) | wip_overflow eliminated |
| Dev hotfix PR closes 2 bugs | 2 (false positive) | 1 (correct) | wip_overflow eliminated |
| Standalone #N in-progress | 1 | 1 | unchanged |

## Why now

- RETRO-008 §3 carrier (wip_overflow false positive)
- Sprint 14 P1 #6 commitment (Issue #497, owner-ratified 2026-06-27T07:25Z)
- 3 LIVE INSTANCES in Sprint 13–14 (PM, arch, dev lanes all hit)
- ADR-0038 §Layer 2 already has dep parser (line 142-150); work-stream parser is a natural extension

## Consequences

### Positive

- wip_overflow false positive ELIMINATED (PR cluster = 1 stream)
- Queue semantics match mental model (1 PR = 1 unit of work)
- Layer 3 (orchestrator stale detection, ADR-0038 §Layer 3) benefits from accurate WIP
- Sister-pattern to d031 d-test: d058 = 10th sister in d-test family (extends d046/d048/d050b/d051/d052/d053/d054/d056/d057)
- Claim cycle is faster (WIP slot frees earlier when 1 PR-cluster squash closes multiple issues)

### Negative

- Layer 2 impl complexity increases (~30 LOC for cluster detection)
- gh API rate limit impact: 1 search query per in-progress issue (mitigation: cache cluster results within claim cycle, 5-min TTL)
- Edge case: cross-PR cluster (issue closed by 2 PRs) — uses first PR's cluster (deterministic per Issue #497 AC1)
- Test surface grows: 9 TCs in d058 (vs d031's 4)

### Follow-up tickets

- **Layer 2 impl** (dev lane, 1.0 SP): scripts/claim-next-ready.sh work-stream awareness
- **d058 d-test** (dev + tester lane, 0.25-0.5 SP): scripts/tests/d058-claim-wip-workstream.sh, 9/9 cases per ADR-0044 RED-first
- **CI integration** (human-only territory): .github/workflows/lint-and-test.yml paths trigger for d058
- **d031 update** (tester lane, 0.25 SP): add TC5/TC6/TC7 to d031 to verify work-stream semantics integration
- **Adoption** (owner gate): no soul patch needed (claim-next-ready.sh change is internal)

## Alternatives considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **A) Status quo (issue-count WIP)** | No code change | wip_overflow false positive persists (RETRO-008 §3 carrier) | ❌ Reject |
| **B) Increase WIP cap to 4** | Simpler than work-stream counting | Defeats WIP cap purpose, agent overload risk | ❌ Reject |
| **C) Work-stream awareness (THIS)** | Matches mental model, eliminates false positive | ~30 LOC impl + 9 TC d-test | ✅ **Accept** |
| **D) Per-PR WIP (1 PR = 1 WIP slot regardless of cluster)** | Simpler | Same as work-stream for cluster case, but breaks standalone | ❌ Reject (subset of C) |
| **E) Orchestrator-managed WIP (centralized)** | Single source of truth | Reverses ADR-0038 doctrine (distributed) | ❌ Reject |

## Sprint 14 P1 #6 critical path

| Step | Owner | SP | Status |
|---|---|---|---|
| 1. ADR-0038 amendment (this PR) | @architect | 0.5 | DONE |
| 2. Layer 2 impl (work-stream parser) | @developer | 1.0 | TODO |
| 3. d058 d-test (9/9 cases) | @developer + @tester | 0.25-0.5 | TODO |
| 4. d031 update (TC5/6/7 work-stream integration) | @tester | 0.25 | TODO |
| 5. CI integration (d058 path trigger) | @human | 0.5 | TODO (owner merge) |
| **Total** | | **2.5-2.75 SP** | per Issue #497 PM draft REVISED |

## Cross-refs

- [ADR-0038 §Layer 2](./ADR-0038-auto-claim-protocol.md) (WIP cap check, lines 68-83 of claim-next-ready.sh)
- [ADR-0038 §Layer 3](./ADR-0038-auto-claim-protocol.md) (orchestrator stale detection, benefits from accurate WIP)
- [RETRO-008 §3 wip_overflow](../sprints/sprint-14/plan.md) (RETRO-008 carrier)
- [Issue #238](https://github.com/atilcan65/AtilCalculator/issues/238) (no self-justified pauses, doctrine origin)
- [Issue #497](https://github.com/atilcan65/AtilCalculator/issues/497) (Sprint 14 P1 #6 home, this amendment's AC1)
- [Issue #271](https://github.com/atilcan65/AtilCalculator/issues/271) (ADR-0038 parent, P1 doctrine gap)
- [Issue #222](https://github.com/atilcan65/AtilCalculator/issues/222) (RCA-19 dev idle 8h 42min, family)
- [ADR-0002](./ADR-0002-autonomy-loop.md) (autonomy loop, WIP limit doctrine)
- [ADR-0044](./ADR-0044-verdict-by-scope.md) (TDD RED-first, d058 contract)
- [ADR-0049](./ADR-0049-behavioral-workflow-test-framework.md) (d-test framework, sister-pattern)
- [ADR-0050](./ADR-0050-pre-merge-4-cat-verification.md) (d053 sister-pattern)
- [d031 d-test](../../scripts/tests/d031-claim-next-ready.sh) (current claim-next-ready.sh regression, sister-pattern to d058)

## 9-Lens attestation

| Lens | Status | Note |
|---|---|---|
| (a) Data flow | ✅ | gh issue list → gh pr list search → work-stream graph → WIP count |
| (b) Runtime preconditions | ✅ | gh + jq available, repo detected, 5-min cluster cache |
| (c) Canonical entry point | ✅ | single entry: claim-next-ready.sh → work-stream counting |
| (d) Silent-skip risk | NONE | explicit stream counting, no silent skip; all paths emit `wip_count`, `stream_count`, `cluster_issues` structured logs |
| (e) Idempotency | ✅ | re-running claim with same state = same WIP count (deterministic, cluster cache TTL=5min) |
| (f) Observability | ✅ | d058 emits `arch_wip_workstream_pass/fail` per claim cycle; claim comment includes stream count |
| (g) Security & privacy | N/A | no auth/authz/PII changes |
| (h) Workflow YAML SHA pin | N/A | no workflow changes in this amendment (CI integration is separate owner-merge) |
| (i) Platform hard constraints | N/A | no platform changes |
| (j) Auto-gen file refs + live-state | ✅ | references current scripts/claim-next-ready.sh lines 68-83, Issue #497, RETRO-008 §3 |
| (k) JS syntactic correctness | N/A | no actions/github-script |

— @architect, prepared 2026-06-27 for Issue #497 AC1 (Sprint 14 P1 #6 §wip_overflow false positive fix)