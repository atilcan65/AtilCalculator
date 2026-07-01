# ADR-0047 — Cross-Repo Watcher Architecture (multi-REPO polling + orch cross-repo scan)

- **Status:** Proposed (Sprint 10 P2, Issue #377, RETRO-005 #4 candidate)
- **Date:** 2026-06-26
- **Deciders:** @architect (doctrine/spec), @developer (scripts/ implementation per file ownership matrix), @orchestrator (operational contract — `scripts/cross-repo-scan.sh` integration)
- **Supersedes:** — (extends ADR-0002 §Polling cadence + `scripts/agent-watch.sh` REPO defaulting with cross-repo awareness)
- **Related:** ADR-0002 (GitHub-Native Autonomy), ADR-0027 (deploy automation, sister cross-repo), ADR-0033 (dual-channel notify), ADR-0015 (atomic 4-flag handoff), Issue #377 (this ADR's trigger, RETRO-005 #4), Issue #374 (RETRO-005 #17 orch stale-state, sister), Issue #378 (RETRO-005 #18 PM plan-file-as-snapshot, sister), Issue #414 (RETRO-005 #26 tester stale-state, sister), Issue #296 (peer-poke discipline), PR #61 (dev-studio-template ADR-0047 — TEMPLATE sister; not this ADR — the template's ADR-0047 is a different number, see §Sister-ADR clarification below)

## Context

`scripts/agent-watch.sh <role>` defaults `REPO=AtilCalculator` (single-repo polling). Cross-repo PRs (e.g., `atilcan65/dev-studio-template`) are **invisible** to the watcher's normal polling loop. Per-agent queues only see cross-repo work when the orchestrator explicitly dispatches via `scripts/ping.sh <role>` (dual-channel, per ADR-0033).

**Observed gap** (PR #61, 2026-06-25T15:30:42Z — `atilcan65/dev-studio-template`, PR-T8+PR-T10+ADR-0047): tester's auto-watch did NOT see the cross-repo PR. Orchestrator had to dispatch explicitly via `scripts/ping.sh tester` ([ORCH→TEST] PR #61 review request). Tester responded APPROVED 2 min later — fast cycle thanks to explicit dispatch, but the **gap is real**:

- **SLA breach risk** if orchestrator forgets to dispatch → cross-repo PR sits in queue with no auto-wake
- **Agent-stall pattern** is plausible: tester queue is AtilCalc-only, cross-repo work accumulates silently
- **Scale-up pressure**: Sprint 7+ cross-repo work will grow (dev-studio-template parity, multi-repo agents per ADR-0027)

### Why this matters now

Sprint 6 follow-on includes dev-studio-template port candidates (#198, #293, future T-PRs). Sprint 7 cross-repo work is forecasted to grow with template-parity sprints. The single-repo watcher default is a forward-compat liability.

## Decision

**Adopt the hybrid approach (option 1 + option 3 from Issue #377 §Fix options)**:

### Part 1 — Multi-REPO watcher config (option 1)

Extend `scripts/agent-watch.sh` to support a comma-separated multi-repo REPO list, with two invocation forms:

**Flag form**: `scripts/agent-watch.sh <role> --repo owner/repo1,owner/repo2`

**Env form**: `export AGENT_WATCH_REPOS=owner/repo1,owner/repo2` (set in `.env` or per-role systemd unit)

**Default behavior** (back-compat preserved):
- If `--repo` is not passed AND `AGENT_WATCH_REPOS` is unset → REPO defaults to current repo (AtilCalculator)
- If `--repo` is passed OR `AGENT_WATCH_REPOS` is set → multi-repo polling; per-repo sub-query, results merged into single event stream

**Polling semantics** (per-repo):
- Each repo in the list is polled **independently** (separate `gh issue list` / `gh pr list` calls with the repo arg)
- Results are normalized to the existing event schema (`issue_assigned`, `pr_review_requested`, `pr_comment_mention`)
- The event stream is **de-duplicated by `id`** across repos (using the existing `processed_event_ids` mechanism per ADR-0002)
- The `url` field in the event carries the full repo path (e.g., `https://github.com/owner/repo1/issues/42`) so the receiving agent knows which repo to act on

### Part 2 — Orchestrator cross-repo scan (option 3)

Add `scripts/cross-repo-scan.sh` to the orchestrator's autonomy loop. This is a **separate script from `agent-watch.sh`** because:

- Orchestrator is the single point of cross-repo coordination (per ADR-0042 §Orchestrator role)
- `agent-watch.sh` is per-agent/per-role polling; orchestrator scan is a fleet-wide cross-repo poll
- The scan is run on a separate cadence (e.g., 5-15 min, slower than per-agent polling) to avoid rate-limit pressure

**Scan script responsibilities**:
- Read `AGENT_CROSS_REPOS` env var (orchestrator-owned config, default = known dev-studio repos)
- For each repo, query `gh pr list --state open --json number,title,labels,headRefName` (only PRs, not issues — issues stay per-agent polling)
- For each open PR, check if any 4-cat label (`agent:*`, `cc:*`) matches a known dev-studio role
- If yes, dispatch via `scripts/peer-poke.sh <role>` (dual-channel per ADR-0033) with the PR URL + label-driven role
- Emit `cross_repo_dispatch` structured log event for audit trail

**Cadence**:
- Default: 5 min (configurable via `CROSS_REPO_SCAN_INTERVAL_SEC` env var)
- Aligned with `agent-watch.sh` polling cadence (60s) on the high-frequency side, but cross-repo scan is lower-frequency (5 min) because cross-repo PRs are expected to be lower-volume

### Part 3 — Sister-ADR clarification

This ADR (ADR-0047 in `atilproject/AtilCalculator`) is **distinct** from `ADR-0047` in `atilcan65/dev-studio-template` (referenced in PR #61). The template's ADR-0047 is the **template sister-cross-link** (per PR #380 / commit 3750f91 in this repo). Per ADR-0027 §Sister-ADR pattern, the two ADRs are coordinated but independent:

- This ADR-0047 (AtilCalculator): **architecture** for cross-repo watcher
- Template ADR-0047 (dev-studio-template): **template-side instantiation** of the watcher pattern (concrete scripts + config)

They are linked via `§See also` cross-references in both directions.

## Rationale

**Why hybrid (option 1 + option 3), not pure options 1/2/3/4**:

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **1) Multi-REPO watcher config** | Per-agent auto-wake for cross-repo PRs; lowest-friction for agents; back-compat preserved (default = current repo) | Each agent configures its own multi-repo list (config drift risk); doesn't solve orchestrator's "fleet-wide cross-repo visibility" need | ✅ **Adopted (Part 1)** |
| **2) Cross-repo label-based routing** | Most flexible — labels route regardless of repo | Significant refactor of `agent-watch.sh` query logic; harder to reason about; doesn't match the existing `REPO=default` convention | ❌ Rejected — over-engineered, config drift risk |
| **3) Orchestrator cross-repo gate** | Centralized cross-repo coordination; orchestrator is the right role for fleet-wide visibility | Adds a separate script + cron; if orchestrator is down, cross-repo dispatch fails | ✅ **Adopted (Part 2)** |
| **4) Hybrid (1+3) (chosen)** | Per-agent auto-wake (low friction) + orch fleet-wide cross-repo scan (centralized visibility) | Two mechanisms to maintain; minor duplication of label-routing logic | ✅ **Adopted** — defense in depth, two failure modes are independent |
| **5) Pure option 1 only** | Simplest | Orchestrator loses cross-repo visibility (no fleet-wide audit) | ❌ Rejected — orch needs the scan for sprint coordination |
| **6) Pure option 3 only** | Centralized | All cross-repo dispatch is orchestrator-mediated; if orchestrator is slow, SLA risk | ❌ Rejected — agents should be able to opt-in to direct cross-repo polling |

### Alternatives considered (deferred)

- **Cross-repo label-sync via webhook**: a webhook receiver that fires when a PR is opened in any watched repo and dispatches via `peer-poke.sh`. Rejected for Sprint 10 P2 (deferred to Sprint 11+ if needed) because it requires webhook infrastructure + receiver service. Script-based polling is simpler and matches the existing `agent-watch.sh` cadence pattern.
- **`gh search` API for cross-repo**: `gh search issues --repo owner/repo1 --repo owner/repo2` is a single API call vs N calls. Rejected because `gh search` rate limits are tighter (30 req/min vs 5000 req/hr for `gh issue list`); per-repo calls are more predictable.

## Consequences

### Positive

- **Closes the cross-repo dispatch gap** (Issue #377, RETRO-005 #4) — agents get auto-wake for cross-repo PRs
- **Centralized orch visibility** — orchestrator's `cross-repo-scan.sh` provides fleet-wide cross-repo audit trail
- **Back-compat preserved** — single-repo setups work without config change (REPO defaults to current repo)
- **Sister-ADR pattern** — links to template ADR-0047 for coordinated rollout
- **Defense in depth** — two independent mechanisms (per-agent polling + orch scan) cover different failure modes

### Negative / tradeoffs

- **Two mechanisms to maintain** — `agent-watch.sh --repo` flag + `scripts/cross-repo-scan.sh`. Documentation must cover both.
- **Config drift risk** — each agent's `.env` (or systemd unit) can have a different `AGENT_WATCH_REPOS` list. Mitigated by defaulting to current repo if unset, and by the orchestrator scan as a fallback.
- **Rate limit pressure** — per-agent polling N repos + orch scan M repos = (N+1)×M API calls per cadence. Mitigated by lower-frequency cross-repo scan (5 min vs 60s) and per-repo event de-dup.
- **Event stream de-dup** — events from the same PR across multiple watchers need canonical de-dup. The `processed_event_ids` mechanism (ADR-0002) is repo-aware only if the event `id` includes the repo; need to extend event schema.

### Follow-up tickets

- [ ] `scripts/agent-watch.sh` `--repo` flag + `AGENT_WATCH_REPOS` env var implementation (Sprint 10 P2, @developer-owned code per file ownership matrix)
- [ ] `scripts/cross-repo-scan.sh` new script (Sprint 10 P2, @orchestrator-owned spec, @developer-owned code)
- [ ] d-test for multi-REPO polling (3 TCs minimum: single-repo default, multi-repo via flag, multi-repo via env var)
- [ ] d-test for cross-repo scan (2 TCs minimum: dispatch on label match, no-dispatch on no-match)
- [ ] Event schema extension: `id` includes repo path for cross-repo de-dup
- [ ] Sister-ADR cross-link: ADR-0047 (this file) ↔ template ADR-0047 (dev-studio-template)
- [ ] Owner approval per file ownership matrix: `scripts/` = developer territory (arch-owned spec, dev-owned code, per file ownership matrix in CLAUDE.md)

## Acceptance criteria

- [ ] ADR-0047 merged to main
- [ ] `scripts/agent-watch.sh` supports `--repo owner/repo1,owner/repo2` flag (per-role polling across multiple repos)
- [ ] `scripts/agent-watch.sh` honors `AGENT_WATCH_REPOS` env var (multi-repo config)
- [ ] Back-compat: single-repo default behavior preserved (no config = current repo only)
- [ ] `scripts/cross-repo-scan.sh` added to orchestrator autonomy loop
- [ ] Orchestrator scan cadence default 5 min, configurable via `CROSS_REPO_SCAN_INTERVAL_SEC`
- [ ] d-test for cross-repo PR auto-wake (regression test, 3+ TCs)
- [ ] d-test for orchestrator cross-repo scan (regression test, 2+ TCs)
- [ ] Event schema `id` includes repo path for cross-repo de-dup
- [ ] No regression in single-repo polling (existing d-tests pass)
- [ ] Sister-ADR cross-link: this ADR ↔ template ADR-0047 (dev-studio-template)

## References

- Issue #377 (this ADR's trigger, RETRO-005 #4 candidate)
- Issue #374 (RETRO-005 #17 orch stale-state, sister-pattern)
- Issue #378 (RETRO-005 #18 PM plan-file-as-snapshot, sister)
- Issue #414 (RETRO-005 #26 tester stale-state, sister)
- Issue #296 (peer-poke discipline, related)
- PR #61 (dev-studio-template ADR-0047 — TEMPLATE sister, observed gap)
- PR #380 / commit 3750f91 (template ADR-0047 sister-cross-link, AtilCalculator-side)
- ADR-0002 (GitHub-Native Autonomy, polling cadence)
- ADR-0027 (deploy automation, sister cross-repo pattern)
- ADR-0033 (dual-channel notify, peer-poke.sh)
- ADR-0015 (atomic 4-flag handoff)
- ADR-0042 (orchestrator role, cross-repo scan operational contract)
- File ownership matrix: CLAUDE.md §File ownership matrix (`docs/decisions/` = @architect, `scripts/` = @developer)

## See also

- **ADR-0012** (PR #418, Sprint 10 P1 combined) — Required Label Set, 4-cat invariant. Sister to this ADR; provides the label-driven routing contract that this ADR's multi-repo polling consumes (`agent:*` + `cc:*` labels route across repos per the same 4-cat rules). The two ADRs are P1 + P2 in the Sprint 10 plan and land together.

- **Template ADR-0047** (`atilcan65/dev-studio-template`, sister-repo) — Template-side instantiation of the cross-repo watcher pattern. Linked via PR #380 / commit 3750f91 (sister-cross-link, AtilCalculator-side).

---

🤖 Architect ADR draft @ 2026-06-26T10:55Z — Sprint 10 P2 candidate, drafted after PR #418 (Sprint 10 P1 combined) arch verdict
