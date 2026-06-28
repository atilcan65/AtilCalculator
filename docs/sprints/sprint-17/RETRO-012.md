# RETRO-012 — Sprint 17 P1 Cluster Process Gaps (DRAFT, orchestrator lane)

> **Author:** @orchestrator (lane: docs/sprints/ per file ownership matrix)
> **Date:** 2026-06-28T17:48+03:00 = 14:48Z
> **Scope:** Sprint 17 P1 cluster close process observations + doctrine gaps surfaced
> **Lane:** `docs/sprints/sprint-17/RETRO-012.md` (orchestrator-owned territory per file ownership matrix)
> **Sister-pattern:** RETRO-011 (Sprint 16 codifications, `docs/retros/retro-011.md` PM lane, "final substantive retro" per owner directive) + RETRO-010 (`docs/retros/retro-010.md` PM lane, Sprint 15 codifications)
> **PM sponsor:** cmt 4826303998 (ProcessGap RETRO-012 candidate — PM cross-lane interest)
> **Owner ratification:** Pending (deferred per ADR-0031 owner gating; PM is sponsor, owner ratifies scope)
> **Forward-resolution:** This is a process-gap retro, NOT a codification retro. RETRO-011 remains the FINAL substantive retro for Sprint 16 codifications. RETRO-012 captures Sprint 17 P1 cluster process observations for archival in `docs/sprints/sprint-17/close.md` (PM lane per file ownership matrix).

## TL;DR

Sprint 17 P1 cluster (7 stories) closed via 7-PR parallel-ship pattern. **Process gaps surfaced**:

| # | Gap | Cycle | Severity | Status |
|---|---|---|---|---|
| 1 | Arch AC mapping drift (AC4 markdown generation gap, AC split mid-flight) | 647 | P1 | RESOLVED (5-of-5 lane consensus, AC4 rescope per Option B) |
| 2 | Squash-pending tolerance doctrine (PR #591 squash gate armed despite Lint & Test flake history) | 567 | P2 | DOCTRINE EMERGED (operationalized in cycle 549 trust-but-verify pattern) |
| 3 | Stale-state correction discipline (Issue #584 double agent:* labels, atomic 4-flag handoff drift) | 530 | P2 | RECURRING — see Issue #113 labels>body doctrine |
| 4 | Cross-user GraphQL rate limit (gh pr ready + gh pr edit blocked, same user ID 269754789 shared across agents + owner) | (NEW) | P2 | WORKAROUND — REST API + owner web UI path |
| 5 | Proactive-scan wip_overflow false positive (lanes at 2/2 cap = ADR-0038 ceiling, NOT overflow) | (NEW) | P3 | TUNING NEEDED — synthetic wake fires on cap, not overflow |
| 6 | Per-role WIP cap script miscounts (counts all `agent:*` items regardless of `status:*`) | (NEW) | P3 | TUNING NEEDED — script should respect status filter |
| 7 | PM curator step (cluster-squash retro markdown generation per ADR-0059 §3) | (NEW) | P2 | DESIGNED — PM curator cmt 4826303998, activates post-squash cascade |

**Tier 1 (1 candidate)**: Sprint 17 P1 cluster ProcessGap codification — close.md carrier
**Tier 2 (3 candidates)**: Squad-level process doctrine updates
**Tier 3 (3 candidates)**: Script-tuning backlog, owner triage

## Sprint 17 P1 cluster ledger (7/7 SHIPPED + CLOSED ✅)

| # | Story | PR | Squash SHA | Closer | Closes |
|---|---|---|---|---|---|
| 1 | STORY-P1#3 dev soul amendments (RETRO-010 + RETRO-011 codifications) | #589 | 87c2976 | owner | #586 AC2 |
| 2 | STORY-P1#3 tester soul amendments | #590 | 13365ee | owner | #586 AC3 |
| 3 | STORY-P1#3 PM soul amendments | #593 | 5815810 | owner | #586 AC1 |
| 4 | ADR-0059 cluster-squash batch-lag detection + STORY-P1-1 design | #595 | 78295e1 | owner | #584 (design), #586 AC5 |
| 5 | d064 cluster-lag sister-pattern (NEW d-test) | #596 | 2fae093 | owner | #587 (refs, not closes) |
| 6 | d063 stale-cc deadlock-breaker (NEW d-test) | #591 | e99c06b | owner | #585 |
| 7 | STORY-P1#1 cluster-lag-detector.sh impl | #597 | (squash-pending, dual-🟢) | owner click | #584 (Closes anchor), #587 (cascade via d064 GREEN on main) |

**Cluster timeline**:
- Issue #584 opened: 2026-06-28T10:46:55Z
- Cluster kickoff: 2026-06-28T10:48Z (arch auto-claim)
- First PR merged (PR #589): 2026-06-28T11:46Z
- Last PR merged before #597: 2026-06-28T14:00:04Z (PR #591 squash)
- PR #597 squash-pending: 2026-06-28T14:48Z (current state)
- Cluster elapsed: 4h 0m as of 14:48Z

## Tier 1 — Cluster ProcessGap codification (close.md carrier)

### §1 — Arch AC mapping drift (cycle 647, RETRO-011 deferred)

**Observed**: Arch design for STORY-P1#1 (PR #595) included 5 ACs (AC1, AC2, AC3, AC4, AC5) per ADR-0059 §1-§3. During impl, AC4 (markdown generation gap — "PM curator step documentation") was discovered to be a parallel concern that needed its own lane endorsement. AC4 disposition cycle (cmt 4826300692) surfaced as a 5-of-5 lane consensus (arch + dev + tester + PM + orchestrator) → Option B (rescope AC4 to F3 explicit jq check) + Option X (F3 jq error check).

**Pattern**: AC mapping drift in arch slice = design doc AC list vs impl AC list diverge mid-flight. Caught by tester review (cmt 4826367793), resolved by 5-of-5 lane consensus on disposition (no human escalation needed).

**Codification candidate**: Add §AC mapping verification doctrine to `.claude/agents/architect.md` — "before ADR ratification, re-query impl branch AC list, mirror design doc AC1..ACn 1:1, flag any drift". Already proposed in cmt 4826303998 (PM cross-lane support) and arch slice (cycle 647).

**Resolution**: Arch landed the disposition cmt, dev implemented Option B, tester verified via d064 GREEN path, PM curator commitment extracted (cmt 4826303998). All 5 lanes converged without owner escalation.

**Forward action**: When PM fires curator step post-squash, AC4 deliverable lands in `docs/sprints/sprint-17/close.md` per RETRO-011 lane pattern (PM-owned territory, not here).

## Tier 2 — Squad-level process doctrine updates

### §2 — Squash-pending tolerance doctrine (cycle 567, operationalized via cycle 549)

**Observed**: PR #591 had Lint & Test flake (test_arithmetic_p99 162ms vs 50ms budget) that re-diagnosed as pre-existing perf budget flake (same code PASSED on main HEAD at 13:10:25Z). Initial framing as "RED-first blocker" was incorrect; cycle 549 trust-but-verify pattern re-ran the test and confirmed flake.

**Pattern**: When a flake surfaces near a squash gate, the orchestrator's job is to **re-diagnose** (re-run, compare to main HEAD) before flagging the squash gate as blocked. The squash-pending tolerance doctrine (cycle 567) holds: "if re-run passes on same code, treat as flake, do not block squash".

**Codification candidate**: Add §Flake re-diagnosis protocol to `.claude/agents/orchestrator.md` — "before flagging squash gate as blocked by CI failure, re-run once; if same code passes on re-run, treat as flake, do not block".

### §3 — Stale-state correction discipline (cycle 530, Issue #113)

**Observed**: Issue #584 carried double `agent:*` labels (agent:architect from initial PM assignment @ 10:46:55Z, agent:developer added @ 13:00:30Z during impl handoff) without removing the prior agent label. Atomic 4-flag handoff (ADR-0015) was drifted — only 2 of 4 flags flipped.

**Pattern**: When an issue transitions between agent phases (design → impl, impl → review, review → done), the agent handoff MUST remove the prior agent:* AND cc:* labels, not just add the new ones. The 4-cat invariant (ADR-0012) requires EXACTLY ONE agent:* per issue at all times.

**Codification candidate**: Add §Atomic handoff verification to `.claude/agents/orchestrator.md` — "after any handoff label flip, orchestrator MUST verify single agent:* and zero stale cc:* labels via REST GET; cycle 530 correction doctrine applies".

**Issue #113 doctrine reminder**: "labels > body" — labels are the contract, body is descriptive. Per the doctrine, the atomic handoff MUST be enforced at label level, not body level.

### §4 — Cross-user GraphQL rate limit workaround

**Observed**: gh pr ready + gh pr edit (label mutations) require GraphQL `markPullRequestReadyForReview` mutation. When same user ID (269754789) hits 5000/5000 hourly limit (shared across all agents + owner), gh CLI returns "GraphQL: API rate limit already exceeded". PATCH /pulls/{N} {draft:false} is a no-op for the draft flag.

**Pattern**: Cross-user rate limit blocks gh CLI label operations but does NOT block REST API (separate core limit, 5000/hr). Workaround paths:
- REST DELETE for label removal (works when GraphQL blocked)
- Owner web UI click for gh pr ready + squash (only path that bypasses rate limit entirely)
- Wait for reset (hourly window, ~1 hour)

**Codification candidate**: Add §Rate-limit escape hatch to `.claude/agents/orchestrator.md` — "when GraphQL rate-limited, fall back to REST API for label edits and ping owner for web UI path; do not block on rate limit, work locally per Issue #238".

## Tier 3 — Script-tuning backlog (owner triage)

### §5 — Proactive-scan wip_overflow false positive

**Observed**: `scripts/proactive-board-scan.sh` flags `wip_overflow` when lane count > N (presumably 2 per ADR-0038 cap). But when 2 lanes (dev, PM) are at exactly 2/2 cap, scan fires wip_overflow count:3 — this is the cap, not overflow.

**Resolution**: Update scan logic to flag OVERFLOW (count > cap), not AT-CAP (count == cap). Owner territory — `.github/workflows/` per file ownership matrix requires owner approval.

### §6 — Per-role WIP cap script miscounts

**Observed**: `scripts/wip-cap-check.sh` counts ALL `agent:*` issues regardless of `status:*` label. PM at WIP 2/2 cap because of #582 + #583, but both are owner-gated (status:in-progress but no PM action possible). Script reports cap but lane is functionally idle.

**Resolution**: Update script to filter `status:in-progress` AND `agent:<role>`, or add `status:blocked` exemption for owner-gated items. Owner territory.

### §7 — PM curator step (cluster-squash retro markdown generation)

**Observed**: Per ADR-0059 §3 + cmt 4826303998, PM is curator for cluster-squash retro markdown. PM reads `cluster-lag.log` JSON output, generates §Cluster-lag markdown section per cluster-squash event, injects into retro or close.md. Cadence: per RETRO ceremony, not real-time.

**Pattern**: PM curator step is the "ceremonial consumer" of cluster-squash detection. Without PM curator activation, the retro markdown never gets written even if d064 is GREEN on main.

**Resolution**: PM curator commitment extracted (cmt 4826303998). Activates post-squash (PR #597 → Issue #584 close → PM curator trigger fires). Close.md carrier path: PM-authored, `docs/sprints/sprint-17/close.md`.

## Cross-refs

- **ADR-0012** — Required Label Set on Issue/PR Creation (4-cat invariant)
- **ADR-0015** — Atomic 4-flag handoff
- **ADR-0031** — Owner override (sprint scope + squash gate)
- **ADR-0038** — Per-role WIP cap 2/2
- **ADR-0044** — RED-first TDD
- **ADR-0045** — 9-Lens (arch pre-publish gate)
- **ADR-0048** — Type-driven verdict gate matrix
- **ADR-0056** — Explicit jq error check (F3 disposition Option X)
- **ADR-0059** — Cluster-squash batch-lag detection (doctrinal home)
- **Issue #113** — labels > body doctrine
- **Issue #238** — rate limit = API throttling NOT work pause
- **Issue #584** — STORY-P1#1 doctrinal home
- **Issue #585** — STORY-P1#2 d063 sister doctrinal home (closed via PR #591)
- **Issue #586** — STORY-P1#3 soul amendment cluster doctrinal home (closed via PR #589/#590/#593)
- **Issue #587** — STORY-P1#4 d-test doctrinal home (closes cascade via d064 GREEN on main)
- **PR #591** — d063 stale-cc deadlock-breaker (squashed e99c06b)
- **PR #597** — cluster-lag-detector.sh impl (squash-pending, dual-🟢, owner click)
- **Cycle 530** — Stale-state correction
- **Cycle 549** — Trust-but-verify (PR #591 flake re-diagnosis)
- **Cycle 567** — Squash-pending tolerance
- **Cycle 647** — Arch AC mapping drift
- **RETRO-009** — Sprint 14 codifications (`docs/retros/retro-009.md`)
- **RETRO-010** — Sprint 15 codifications (`docs/retros/retro-010.md`)
- **RETRO-011** — Sprint 16 codifications (`docs/retros/retro-011.md`, "final substantive retro")
- **cmt 4826303998** — PM curator commitment + ProcessGap RETRO-012 candidate
- **cmt 4826367793** — Tester APPROVED cmt on PR #597 (F3 TC6 added)
- **cmt 4826384857** — Arch FINAL 🟢 cmt on PR #597

## Forward-resolution

- **Owner ratification**: Pending. Owner reviews RETRO-012 scope, decides whether to ratify as Sprint 17 close.md input.
- **PM curator activation**: Post-squash cascade. PM reads this RETRO + cluster-lag.log, generates close.md section.
- **Sprint 17 close.md** (`docs/sprints/sprint-17/close.md`, PM lane, owner ratifies) is the canonical landing pad for RETRO-012 + PM curator output + cluster-lag observations.

— @orchestrator, 2026-06-28T17:48+03:00, RETRO-012 draft (Sprint 17 P1 cluster ProcessGap retro, orchestrator lane, owner ratifies)