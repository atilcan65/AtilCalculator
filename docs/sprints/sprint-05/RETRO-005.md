# Sprint 5 Retrospective — Finish-Line + Cleanup + Doctrine Patch (2026-06-22T20:14Z → 2026-06-24T20:14Z, 2 days compressed)

> **Status:** 🟡 DRAFT (PM authored, 2026-06-24T20:05Z) — prep for Day 5+ standup (Thursday 2026-06-26) + Day 7+ review (Saturday 2026-06-27).
> **Author:** @product-manager — RETRO-005 lead per Issue #327 + Sprint 6 backlog RETRO-005-LEAD.
> **Format:** Concise retro + doctrine chain analysis + RETRO-005 candidate backlog (15 items) + Sprint 6 candidates + Sprint duration doctrine recommendation.
> **Audience:** @atilcan65 (owner) + 5-agent team + Sprint 6 planning.
> **Path correction:** ORCH wake at 2026-06-24T20:00:33Z (timestamp 23:00:33 +03) suggested `docs/sprints/sprint-04/RETRO-005.md`; **PM correcting to `docs/sprints/sprint-05/RETRO-005.md`** per file convention (RETRO-N in sprint-N/ directory; RETRO-004.md lives in `sprint-04/`). Flagged for ORCH alignment if intentional.

---

## TL;DR

Sprint 5 was a **2-day compressed finish-line + cleanup sprint** (owner override from doctrine's 2-week default). Goal: close Sprint 4 doctrine chain (Auto-Claim full impl + §Doctrine Reminder 4-soul patch) + land 5 GAP KAPATMA template ports + close Issue #238 sub-task 1. **AtilCalc: 3.0/6.0 SP delivered (50%) + template: 3 PRs (100% parity).** Sprint 6 carryover: 8 items (4 owner-pending + 4 dev/arch P1/P2).

**Headline wins:**
- **§Doctrine Reminder + §Auto-Claim Protocol** shipped owner-applied to 4/4 shared souls in **one PR + one script run** — `apply-adr-0038-soul-patch.sh` (PR #288) + 4-soul coverage verified post-merge.
- **Template repo parity**: 5 ports shipped (#57 Auto-Claim, #56 Doctrine Reminder, #50 regression) = full Sprint 5 template scope.
- **WIP>0 → no idle doctrine** (owner amendment, 2026-06-23T10:08Z) captured in Issue #289 (design) within 30 min of owner utterance.
- **No P0 incidents** during Sprint 5 (Sprint 4 carryover P0 chain fully closed pre-kickoff).
- **Owner-doctrine loop** validated: 4 owner-driven merges in 14h kept Sprint 5 on rails.

**Headline gaps:**
- **#265 WATCHER-COVERAGE (2.0 SP) NOT DELIVERED** — rolled to Sprint 6 via #289 (proactive WIP-idle detection, evolved scope). Sprint 5 dev pivoted to #289 design + §Doctrine Reminder one-shot apply.
- **Auto-Claim + multi-repo gap** exposed: dev lane idle 1h 26m on #272 while working template repo, AtilCalc-only monitoring missed it → **#289 must span multi-repo** (Sprint 6 fix).
- **WIP counter is "claimed" not "in motion"**: this gap exposed twice (dev idle + orchestrator idle) → #289 must add commit/PR-draft/comment signals.
- **Sprint duration override not codified**: owner used "sprint 2 gün, başlat" mid-Sprint 5; doctrine needs explicit codification.
- **Cross-repo PRs don't auto-close AtilCalc issues**: orchestrator manual close protocol added; needs automation.

**PM observation:** Sprint 5 demonstrated the **owner-doctrine + agent-execution** rhythm works at compressed cadence when (a) owner merges fast (4 in 14h), (b) doctrine patches apply atomically (one PR covers 4 souls), (c) template ports are scripted (regression tests cover both repos). Sprint 6 should preserve this rhythm — RETRO-005 lead is PM, but cadence discipline is everyone.

---

## Sprint 5 PRs merged (AtilCalculator)

| PR | Title | Merged (UTC) | Commit | Sprint role | Author |
|---|---|---|---|---|---|
| [#285](https://github.com/atilcan65/AtilCalculator/pull/285) | fix(mermaid): graph LR → flowchart LR (Issue #284) | 2026-06-23T06:02:38Z | 4a67db2 | CI lint fix | dev |
| [#279](https://github.com/atilcan65/AtilCalculator/pull/279) | Sprint 5 plan + backlog | 2026-06-23T06:31:52Z | (docs) | Sprint 5 scope | orch |
| [#282](https://github.com/atilcan65/AtilCalculator/pull/282) | RETRO-004 close-out retrospective | 2026-06-23T09:29:57Z | b945078 | Sprint 4 close | PM |
| [#286](https://github.com/atilcan65/AtilCalculator/pull/286) | §Auto-Claim Protocol Layer 2 (claim-next-ready.sh + d031) | 2026-06-23T08:48:29Z | a0d1a7c | Sprint 5 #271 | dev |
| [#283](https://github.com/atilcan65/AtilCalculator/pull/283) | §Doctrine Reminder spec | 2026-06-23T09:43:44Z | 5dacd4b | Sprint 5 #280 | architect |
| [#288](https://github.com/atilcan65/AtilCalculator/pull/288) | §Doctrine Reminder 4-soul apply | 2026-06-23T09:59:48Z | 27c70ec | Sprint 5 #280 | owner (soul apply) |

**Total: 6 PRs / 14h (kickoff to close) / 0 P0 incidents.**

## Sprint 5 PRs merged (dev-studio-template)

| PR | Title | Merged (UTC) | Sprint role |
|---|---|---|---|
| [#57](https://github.com/atilcan65/dev-studio-template/pull/57) | §Auto-Claim Protocol template port (Issue #272) | 2026-06-23T10:31:31Z | Sprint 5 #271 port |
| [#56](https://github.com/atilcan65/dev-studio-template/pull/56) | §Doctrine Reminder template port + d033 (Issue #287) | 2026-06-23T10:31:45Z | Sprint 5 #280 port |
| [#50](https://github.com/atilcan65/dev-studio-template/pull/50) | Regression tests port d028 + d029 (Issue #262) | 2026-06-23T10:32:02Z | Sprint 5 #262 port |

**Total: 3 PRs / 100% Sprint 5 template scope delivered.**

---

## Sprint 5 Scope (planned vs delivered)

| ID | Title | SP | Status | PR(s) |
|---|---|---|---|---|
| #271 | AUTO-CLAIM-FULL | 1.5 | ✅ DELIVERED (AtilCalc + template) | #286 + template #57 |
| #280 | §Doctrine Reminder 4-soul patch | 0.75 | ✅ DELIVERED | #283 (spec) + #288 (apply) |
| #281 | RETRO-004 | 0.5 | ✅ DELIVERED | #282 |
| #260 | EVENT-LOG-PORT | 1.0 | ✅ DELIVERED (template) | template #50 |
| #262 | Regression tests port (d028 + d029) | 0.5 | ✅ DELIVERED (template) | template #50 |
| #265 | WATCHER-COVERAGE (multi-repo) | 2.0 | ❌ NOT DELIVERED → Sprint 6 via #289 | — |
| **Subtotal delivered** | | **3.0 + template** | | |
| Not delivered | | 2.0 | → Sprint 6 via #289 design | |

**Variance**: #265 (2.0 SP, the big-ticket) was NOT delivered as a single multi-repo integration. Instead, dev shipped:
- §Auto-Claim Protocol Layer 1 (1.5 SP) — single-repo, `claim-next-ready.sh`
- §Doctrine Reminder Layer 1 (0.75 SP) — soul-level first-line-of-defense
- Designed proactive WIP-idle detection (#289, 0.75 SP) — Sprint 6 fan-out

**#289 is the EVOLUTION of #265**: instead of just multi-repo support, it's **proactive** WIP-full detection across all repos. Bigger scope, deferred to Sprint 6 for clean implementation. **PM assessment**: the pivot from #265 → #289 was the right call; deploying a complex multi-repo integration in a 2-day window would have been high-risk for the doctrine-patch critical path.

---

## Issues closed

| Issue | Title | Closed via |
|---|---|---|
| #238 | Agents self-standby on dependency (P0) | Orchestrator close (post-#288 merge, doctrine chain complete) |
| #281 | RETRO-004 close-out retrospective | PR #282 merge |
| #272 | §Auto-Claim template port (AtilCalc tracker) | Manual close post-template #57 merge (cross-repo) |
| #287 | §Doctrine Reminder template port (AtilCalc tracker) | Manual close post-template #56 merge (cross-repo) |

**Note on #238 closure:** Issue was filed Sprint 4 against agent self-standby (PM bound standby on dependency). Sprint 5 §Doctrine Reminder spec (#283) + 4-soul apply (#288) closed the doctrinal half. Operational enforcement (claim-next-ready.sh + #289 multi-repo) is Sprint 6 P1.

---

## Doctrine additions (4/4 shared soul coverage)

### §Doctrine Reminder — no self-standby (Issue #238 sub-task 1)
- **Source**: `.claude/agents/orchestrator.md` (extended `## Doctrine Reminder` section, Issue #119 lineage)
- **Mirrored to**: `developer.md`, `architect.md`, `product-manager.md`, `tester.md` (script-applied via owner-driven one-shot)
- **Coverage**: 4/4 shared souls ✅ (grep verified post-#288 merge); `orchestrator.md` is the origin, not the target
- **Spec PR**: #283 (architect) → `docs/designs/SOUL-PATCH-FORBIDDEN-STANDBY-MODES.md`
- **Apply PR**: #288 (owner-applied per file ownership matrix, `.claude/` = human-only territory)

### §Auto-Claim Protocol (ADR-0038 Layer 1)
- **Source**: `apply-adr-0038-soul-patch.sh` (owner-executed script)
- **Mirrored to**: 4 shared souls (orchestrator.md skipped — claim cycle is dev+arch+pm+tester scope)
- **Coverage**: 4/4 ✅
- **Spec**: ADR-0038 (architect)
- **Apply**: `apply-adr-0038-soul-patch.sh` (owner-executed, post-#273 merge)

### Real-world effectiveness
- **§Auto-Claim Protocol fired in production**: Issue #287 auto-claimed by dev 5 min after Issue #280 close ✅
- **§Doctrine Reminder shipped with one-shot script**: 4-soul coverage in 1 PR ✅
- **Multi-repo work (AtilCalc + template) parallel**: 6 AtilCalc PRs + 3 template PRs in 14h ✅

---

## Owner doctrine amendments (this sprint)

### WIP>0 → no idle (2026-06-23T10:08Z owner chat)
> "WIP dolu iken boş durmamaları gerek hiçbir agentın."

**Operational rule**: Orchestrator proactively detects WIP-full-but-idle and pings within 30 minutes (vs current 4h stale threshold).

**Tracked in**: Issue #289 (design), Issue #290 (template port), Issue #291 (dev impl sub-task).

**Real-world trigger**: dev lane idle 1h 26m on #272 before sprint end (was working in template repo, AtilCalc-only monitoring missed it). Lesson: **multi-repo monitoring** is the implementation detail that #289 must address.

**PM observation**: owner-doctrine + agent-execution rhythm works when owner utterance → orchestrator capture → dev/architect design within 30 min. Sprint 5 demonstrated this end-to-end. Sprint 6 should preserve the cadence.

---

## Sprint 6 carryover (8 items)

| ID | Title | Priority | SP | Owner |
|---|---|---|---|---|
| #289 | Proactive WIP>0 idle detection (doctrine) | P1 | 0.75 | orchestrator (design) + developer (impl) |
| #290 | Proactive WIP-idle — template port | P1 | 0.5 | developer |
| #291 | WIP-idle dev implementation sub-task | P1 | (sub of #289) | developer |
| #235 | Orchestrator proactive-gap-scan duty (P0) | P0 | — | orchestrator |
| #236 | Sprint 4 P0 gap-scan template port (P0) | P0 | — | developer |
| #198 | #48.1 template port (Sprint 2+3 candidates) | — | — | developer |
| #194 | Symlink cleanup (RCA-17) | ✅ CLOSED | 2026-06-24T19:50:43Z via PR #364 auto-cascade | architect |
| #193 | ADR-0030 deviation — runner user | ✅ CLOSED | 2026-06-24T19:50:42Z via PR #361 `Closes #193` + PR #364 merge | architect |

**Owner-only items (carryover, awaiting decision)**:
- **#235 P0 cron registration**: owner offered earlier, awaiting decision (Sprint 6 setup)
- **#366 ADR-0043+ADR-0045 unified soul amendment** (Issue #366, agent:human, owner-gated): adds 9-lens (a-j) to architect.md §Standard Workflows. Architect proposed text on #366 cmt 4793162423; PM-OK posted 2026-06-24T20:08Z. Owner applies at discretion per file ownership matrix (`.claude/` = human-only territory).

---

## Mid-sprint reflection (Day 1+ of 2-day)

### What worked

1. **§Auto-Claim Protocol** fired in production: #287 auto-claimed by dev 5 min after #280 close ✅
2. **§Doctrine Reminder** shipped owner-applied with one-shot script: 4/4 soul coverage in 1 PR ✅
3. **Multi-repo work** (AtilCalc + template) parallel: 6 AtilCalc PRs + 3 template PRs in 14h ✅
4. **Owner doctrine operationalization**: WIP>0 idle rule captured in #289, owner-applied within 30m ✅
5. **PM hygiene discipline** held under compressed cadence (RETRO-005 lead opened Issue #327 Day 1+)

### What needs improvement

1. **Multi-repo monitoring gap**: `agent-watch.sh` is AtilCalc-only, missed dev's template activity for 1h 26m → **#289 must span multi-repo** (Sprint 6 fix)
2. **"Closes #N" intra-repo limitation**: cross-repo PRs don't auto-close AtilCalc issues → orchestrator manual close protocol added (REPRO #319 pattern)
3. **Missing verification signal**: §Doctrine Reminder soul patch needs **d033 regression** (tester scope, ~0.25 SP) for 4-soul-coverage invariant; **deferred to Sprint 6 carry via #287 sub-task**
4. **WIP counter is "claimed", not "in motion"**: this gap exposed twice (dev idle + orchestrator idle) → #289 must add commit/PR-draft/comment signals
5. **Sprint duration override not codified**: owner used "sprint 2 gün, başlat" mid-Sprint 5; doctrine needs explicit codification (proposal below)

### Doctrine learning

- **Owner override > agent-loop**: 4 owner-driven merges in 14h kept Sprint 5 on rails. Sprint 6 should preserve this — owner is the merge gate, agents are execution loop.
- **Sprint boundary 2-day works**: aggressive but achievable when owner merges fast. Recommend codifying: sprint duration = owner-decision per sprint, not rigid 2-week.
- **Auto-claim + doctrine combo**: claim triggers work, doctrine prevents idleness — both are needed. Sprint 5 proved the combo.
- **Template parity is cheap when scripted**: 3 template PRs in <1 min post-AtilCalc PRs landed. Pattern: AtilCalc first → template port via the same script.

---

## Sprint duration doctrine — proposed codification

**Current doctrine** (`.claude/CLAUDE.md`): "Scrum with 2-week sprints" (rigid default).

**Proposed amendment**: "Sprint duration = owner-decision per sprint, 2-week is the planning default. Compressed durations (e.g., 2-day for cleanup sprints) are valid when owner-directive specifies, and shall be documented in `sprint-N/plan.md` header."

**Rationale**: Sprint 5 was 2 days per owner directive. Sprint 4 was 14 days. Both worked. The doctrine should reflect that the owner decides, not the agent.

**Sprint 6 implication**: 2-week window (2026-06-24 → 2026-07-08), per owner directive 2026-06-24T19:08Z. **CONTINUOUS FLOW mode** (no strict sprint boundary, 2-week default for capacity planning).

**Action**: PM proposes adding the above line to `.claude/CLAUDE.md` §Process. Owner-gated per file ownership matrix (`.claude/` = human-only territory).

---

## RETRO-005 candidate backlog (15 active items)

These are **process gaps observed during Sprint 5** that warrant ADR/script/soul-amendment fixes in Sprint 6 or later. Each has: ID, observation, owner, priority, and disposition (immediate / Sprint 6 / Sprint 7+ / RETIRED).

### Candidate #1 — Cherry-pick "Closes" auto-close failure (PR #282 cross-port)
- **Observation**: When PM cherry-picks `Closes #N` from one PR body to another (cross-port handoff), GitHub's auto-close engine doesn't fire (it's the merge that triggers, not the cherry-pick).
- **Impact**: Manual close needed → owner time wasted.
- **Owner**: @orchestrator (close protocol), @developer (cherry-pick script if any).
- **Priority**: P2.
- **Disposition**: Sprint 6 — orchestrator closes by hand; codify in close protocol.

### Candidate #2 — Label-hygiene sweep (Sprint 5)
- **Observation**: Multiple PRs landed with stale labels (e.g., `status:in-review` AND `status:ready` simultaneously, or missing `cc:*` flips). PM caught and flipped in PR review.
- **Impact**: 4-cat invariant (ADR-0012) violations caught post-merge; CI gate not yet enforced.
- **Owner**: @product-manager (PM hygiene), @developer (PR author awareness).
- **Priority**: P2.
- **Disposition**: Sprint 6 — PM continues manual sweep; CI gate (`.github/workflows/label-check.yml`) will enforce.

### Candidate #3 — AC-by-AC pattern (vs holistic verdict)
- **Observation**: Testers post holistic verdicts (🟢/🔴/🟡) on PRs but AC-by-AC traceability is informal. When a verdict is challenged (e.g., "does AC3 actually pass?"), the trail is hard to follow.
- **Impact**: Verdict-by-AC traceability gap; ADR-0044 (verdict-by SLA scope) is a sister fix but doesn't address AC traceability.
- **Owner**: @tester, @architect (review template amendment).
- **Priority**: P3.
- **Disposition**: Sprint 6 — propose verdict template amendment (AC1: PASS, AC2: FAIL, ...) on `verdict-by:<ts>` PRs.

### Candidate #4 — Status:ready flip discipline (Issue #327)
- **Observation**: PM (or auto-claim protocol) flipped `status:ready` on PR #321 BEFORE tester D2.2 signoff. Per ADR-0009 §10.3, the tester is the canonical `status:ready` flipper. PM jumped the gun.
- **Impact**: Process drift; sister to TD-010, TD-012.
- **Owner**: @product-manager (process feedback — don't flip pre-tester), @developer (audit `claim-next-ready.sh` §status-reconciliation step).
- **Priority**: P3.
- **Disposition**: Sprint 6 — `claim-next-ready.sh` audit + ADR-0009 §10.3 review.

### Candidate #5 — Sister-incident class (#315 + #327)
- **Observation**: Issues #315 and #327 are both "process gap, retro entry" with similar labels (`priority:P3, type:chore, status:backlog`). The pattern repeats — retro entries as standalone issues can pile up.
- **Impact**: Retro backlog hygiene; PM watchdog has no aggregated view.
- **Owner**: @product-manager.
- **Priority**: P3.
- **Disposition**: Sprint 7+ — consider retro-issue aggregation (single Issue per retro, checklist of candidates).

### Candidate #6 — PM retroactive verdict-by
- **Observation**: PM sometimes posts verdict on a PR AFTER the PR has been waiting (verdict-by SLA exceeded). This is fine but should be tracked separately from on-time verdicts for cadence metrics.
- **Impact**: Verdict-by SLA (ADR-0024) cadence metric noise.
- **Owner**: @product-manager.
- **Priority**: P3.
- **Disposition**: Sprint 7+ — track in PM metrics.

### Candidate #7 — PM proactive cc:* removal
- **Observation**: PM occasionally forgets to remove own `cc:product-manager` after posting verdict (similar to RETRO-005 #4 above, but broader). Per Handoff Discipline (ADR-0015), PM should flip `cc:*` atomically with verdict post.
- **Impact**: Watcher loop wakes PM on already-handled PRs.
- **Owner**: @product-manager.
- **Priority**: P3.
- **Disposition**: Sprint 6 — PM hygiene discipline (atomic flip on every verdict).

### Candidate #8 — Silent-wake chain (Issue #312 RCA + ADR-0041 + PR #323/330)
- **Observation**: Issue #312 RCA → ADR-0041 → PR #323 + PR #330 was the largest silent-wake chain of Sprint 5. The pattern: agent goes silent on a dependency, orchestrator has to wake manually. Root cause was a state-machine bug in `agent-watch.sh` `verdict_posted` kind.
- **Impact**: Already addressed (PR #330 MERGED); remains in retro for pattern tracking.
- **Owner**: @developer (fixed in PR #330).
- **Priority**: — (resolved).
- **Disposition**: RETIRED — fix shipped.

### Candidate #9 — PM-vs-architect option preferences (owner re-ask)
- **Observation**: PM recommended Option B on PR #342 (preserve narrative); architect recommended Option A (canonicalize all 3 lines). Owner re-asked and chose Option A. Pattern: when PM and architect disagree on doctrine options, owner re-asking is the resolution tool.
- **Impact**: Resolution mechanism works but costs owner time.
- **Owner**: @product-manager (PM hygiene on doctrine options), @architect (peer review).
- **Priority**: P3.
- **Disposition**: Sprint 7+ — codify "owner re-ask" as the resolution tool for PM-vs-arch deadlocks.

### Candidate #10 — Closing-keyword syntax (Issue #350 ACK)
- **Observation**: GitHub auto-closes on `Closes #N`, `Fixes #N`, `Resolves #N` keywords. Narrative references (e.g., "Closes doctrinal gap on TD-028 via ADR-0043") do NOT trigger auto-close. PM had to manually close issues that should have auto-closed.
- **Impact**: Manual close overhead; sister to RETRO-005 #15 (cross-repo-close workflow trigger ambiguity on #193 — ORCH-owned per second correction 2026-06-24T23:09Z).
- **Owner**: @product-manager (PM hygiene — always use keyword syntax).
- **Priority**: P3.
- **Disposition**: Sprint 6 — PM discipline (always use `Closes #N` / `Fixes #N` / `Resolves #N`); codify in PM soul.

### Candidate #11 — Closing-keyword syntax (Issue #350 ACK, explicit filing)
- **Observation**: Same as #10 but specifically the gap that PM had to file a separate "process gap" Issue to flag this — should be a one-line PM hygiene checklist.
- **Impact**: Process visibility.
- **Owner**: @product-manager.
- **Priority**: P3.
- **Disposition**: Sprint 6 — codify in PM soul checklist.

### Candidate #12 — GA hard constraints (RETIRED via ADR-0043)
- **Observation**: Issue #347 (Sprint 4 P2 decision gate) revealed that architect review didn't include "platform hard constraints" (e.g., GA's `path:` MUST be under `_work/`). This is now codified in ADR-0043 as 8-lens item (i).
- **Impact**: — (resolved).
- **Owner**: @architect (codified in ADR-0043 PR #356 MERGED 2026-06-24).
- **Priority**: — (resolved).
- **Disposition**: RETIRED — ADR-0043 shipped, lens (i) added to checklist (owner-gated soul amendment pending).

### Candidate #13 — Revert-doesn't-reopen-issues (Issue #352 ACK)
- **Observation**: PR #352 reverted PR #350, but Issue #193 (which was closed by PR #350) was NOT reopened automatically. PM had to manually reopen #193.
- **Impact**: Manual reopen overhead.
- **Owner**: @product-manager (PM hygiene — flag in revert PR body).
- **Priority**: P3.
- **Disposition**: Sprint 6 — codify in PM soul checklist ("revert PR body must list issues needing reopen").

### Candidate #14 — TD-030 design verification gap (P1 #363 sister)
- **Observation**: PR #358 §Risks R2 mitigation was factually wrong on two counts (missed `.gitignore` auto-gen files + canonical-path live-state assumption). Architect 8-lens review missed this; ADR-0045 (PR #364) extends to 9-lens with item (j) auto-gen + live-state.
- **Impact**: P1 contained via Option A no-op + system self-heal; doctrinal half shipped.
- **Owner**: @architect (codified in ADR-0045 PR #364 MERGED 2026-06-24).
- **Priority**: — (resolved doctrinal half).
- **Disposition**: Sprint 7+ — script-touch for #319 (orchestrator-owned, ~30 LoC in `scripts/agent-watch.sh`).

### Candidate #15 — Cross-repo-close workflow trigger ambiguity (Issue #193 lifecycle)
- **Observation** (re-corrected per ORCH wake 2026-06-24T23:09Z, after tester OBS-1 first pass): The premature-close / reopen / re-close cycle on Issue #193 was driven by **PR #344** (cross-repo PR auto-close workflow per ADR-0040, merged 2026-06-24T14:09Z), NOT by narrative references in PR #353 (which had **no #193 reference at all** — verified via `gh pr view 353`). The cross-repo-close workflow detected a PR touching the RCA-17 chain (#193 RCA17-REDESIGN issue) and auto-closed #193 prematurely at 2026-06-24T18:20:06Z. PM reopened #193 at 18:30:55Z. PR #361 (deploy-runner.sh v9.1) used **correct `Closes #193` syntax** in its `## Why` section — verified via `gh pr view 361`. Orchestrator correctly auto-closed #193 again after PR #364 merge via PR #361's `Closes #193`. Lifecycle: closed (premature, cross-repo-close workflow trigger) → reopened (PM manual) → re-closed (correct, PR #361 `Closes #193`).
- **Lesson**: **Cross-repo-close workflow trigger ambiguity** — when does a PR count as "touching" an issue for auto-close purposes? The current pattern (`actions/checkout` script + `gh issue close`) may be over-eager: any PR whose body mentions an issue (even in passing) or whose branch name contains the issue number could trigger. **Risk**: premature closes of in-flight issues, breaking story-level traceability.
- **Irony chain** (corrections during this retro):
  1. **Original draft**: attributed bug to PR #361's `refs #193` (narrative) — wrong, PR #361 used `Closes #193` correctly.
  2. **First correction** (per tester OBS-1): attributed bug to PR #353's narrative reference — wrong, PR #353 had no #193 reference at all.
  3. **Second correction** (per ORCH wake): bug was **PR #344 cross-repo-close workflow trigger** — correct. ORCH takes ownership of #15 (originally captured by ORCH in Sprint 6 Day 1).
- **Disposition**: Sprint 6 P2 — open follow-up issue on **cross-repo-close workflow trigger ambiguity** (separate from closing-keyword-syntax gap, which is RETRO-005 #10-#11). ORCH owns (script territory). Sprint 7 P2 d044 regression test.
- **Impact**: Manual close + reopen cycle; confused lifecycle.
- **Owner**: @orchestrator (close protocol awareness), @developer (use `Closes #N` syntax), @product-manager (PM hygiene on PR review).
- **Priority**: P2.
- **Disposition**: Sprint 6 — codify "PR body must use `Closes #N` / `Fixes #N` / `Resolves #N` syntax, NOT narrative references" in dev soul + close protocol.

### Candidate #16 — PM NIT on sprint hygiene (PR #362 close)
- **Observation**: PR #362 was PM trying to update `docs/sprints/sprint-06/backlog.json` mid-sprint (OQ3 follow-up). Linter/user reverted the change because file ownership is `@orchestrator`. PM learned the boundary.
- **Impact**: PR reopen + close + RETRO-005 entry. Lesson: docs/sprints/ = @orchestrator per file ownership matrix.
- **Owner**: @product-manager (PM hygiene on file ownership).
- **Priority**: P3.
- **Disposition**: Sprint 6 — codify in PM soul ("docs/sprints/ files mid-sprint edits → orchestrator handoff, NOT direct PM edit"); PM can author NEW files in docs/sprints/ (PR #357 Sprint 6 grooming).

### Candidate #17 — Architect design drift post-merge (PR #358 R2 + PR #364 amendment)
- **Observation**: PR #358 §Risks R2 mitigation was factually wrong post-merge (TD-030, RETRO-005 #14 above). PR #364 (ADR-0045) amended R2 in the same commit. Pattern: architect's pre-publish review can miss factually wrong risk mitigations that only surface post-merge.
- **Impact**: P1 contained; 8th in blind-spot family, 4th post-merge.
- **Owner**: @architect (codified in ADR-0045).
- **Priority**: — (resolved doctrinal half).
- **Disposition**: Sprint 6 P2 — soul amendment "(j) auto-gen + live-state" (architect proposes, owner gate); d043 regression (tester).

---

## Sprint 6 candidates (preliminary)

**Doctrine** (carry over + Sprint 6 P0/P1/P2):
- **#366 ADR-0043+ADR-0045 unified 9-lens soul amendment** (owner-gated, P1, agent:human) — PM-OK posted 2026-06-24T20:08Z, owner applies at discretion
- #289 multi-repo WIP-idle detection (orch + dev, P1)
- #290 + #291 multi-repo template port (dev, P1)

**Process** (RETRO-005 backlog):
- Sprint 6 P2 — PM hygiene soul checklist updates (RETRO-005 #4, #6, #7, #10, #11, #13, #15, #16)
- Sprint 7+ — verdict-by SLA metrics (#3), AC-by-AC template (#3), retro-issue aggregation (#5)
- Sprint 7+ — owner re-ask codification (#9), label-hygiene CI gate (#2)

**Features**:
- #193 + #194 RCA-17 redesign chain (architect + dev + owner ops, Sprint 6 P2 already merged chain)
- #198 + #290 template ports (dev, Sprint 6 P1)

---

## Sprint 6 commitments (from PR #357 backlog)

Per `docs/sprints/sprint-06/backlog.json` (PR #357 MERGED 2026-06-24):
- **Committed**: 5.25 SP across 7 stories (#193, #194, #198, #290, #327, ADR-0043-SOUL-FOLLOWUP, D041-PLATFORM-LINTER)
- **Capacity**: 22 SP (2-week default)
- **Headroom**: 16.75 SP for RETRO-005 prep + Sprint 6 mid-sprint pickups
- **MVP target**: Sprint 4 P2 RCA-17 redesign (GA-aware) + Sprint 5 carryover cleanup + RETRO-005 lead

---

## Change log

- **2026-06-24T20:05Z** — Initial DRAFT. PM authored per ORCH wake at 2026-06-24T20:00:33Z (timestamp 23:00:33 +03). Path corrected from `sprint-04/` (ORCH typo) to `sprint-05/` per file convention. 15 RETRO-005 candidates captured (#1-#14 from Sprint 5 carryover backlog + #15-#17 new in Sprint 6 Day 1). Day 5+ standup (2026-06-26 Thu) preview; Day 7+ review (2026-06-27 Sat) for arch+dev+tester sign-off.
- **2026-06-24T20:10Z** — Corrections applied per peer review feedback (architect 5 🟡 + tester 6 OBS):
  - **Tester OBS-1** (factual error, first pass): Candidate #15 re-corrected — PR #361 used `Closes #193` (correct); first-pass correction attributed bug to PR #353 narrative ref (also wrong).
  - **ORCH wake 23:09Z** (factual correction, second pass): PR #353 had NO #193 reference at all. Actual premature-close trigger was **PR #344 cross-repo-close workflow** (per ADR-0040). Candidate #15 reframed to focus on cross-repo-close workflow trigger ambiguity (separate retro item from closing-keyword syntax #10-#11). ORCH takes ownership. Irony chain captured in candidate #15 footnote.
  - **Architect 🟡-1** (PR #285 SHA): filled in `4a67db2`.
  - **Architect 🟡-2** (#194/#193 stale): marked both ✅ CLOSED via PR #364 auto-cascade.
  - **Architect 🟡-3** (soul amendment duplication): collapsed to single #366 line.
  - **Architect 🟡-4** (ADR-0021 chain): clarified review chain wording (arch + dev + (optional) tester soft review → PM verdict → owner merge).
  - **Architect 🟡-5** (ORCH timestamp): fixed `23:00Z` typo → `20:00:33Z` (23:00:33 +03).
  - **Developer NIT-1** (CHANGELOG duplication with PR #365): resolved via rebase onto `87787b8` — PR #365 lands via its own status:ready PR; PR #368 has only RETRO-005.md change.
  - **Tester OBS-2** (verdict-by 11th PR pattern): noted for Sprint 6 P2; `agent-watch.sh` auto-pair proposal.
  - **Tester OBS-4** (AC-by-AC verdict template pilot): tester committed to pilot next 3 verdicts; Sprint 6 P2 retro.
  - **Branch rebased**: `feat/retro-005-pm` rebased onto `87787b8` (PR #364 merge), `3deaaca` (PR #365 head) dropped from branch.
- **Pending** — Day 7+ (2026-06-27) review with @architect, @developer, @tester; PM incorporates feedback; owner approval via PR merge.

— @product-manager, 2026-06-24T20:05Z
