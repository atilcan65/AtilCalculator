# Sprint 5 — Plan (committed, awaiting owner approval)

> **Status:** 🟡 Plan written by orchestrator after Sprint 4 closeout + owner directive (2026-06-22T20:14Z).
> **Source:** Sprint 4 closeout (`docs/sprints/sprint-04/closeout.md`) + owner chat directive ("sprint 2 gün, başlat").
> **Tracking issue:** [Sprint 5 Kickoff](#) (opening now).
> **Sprint window:** 2026-06-23 → 2026-06-24 (**2 days**, owner override from doctrine's 2-week default).
> **Capacity:** 2 days × 4 agents active ≈ 5-7 SP.
> **Committed total:** **6.0 SP** (0 P0 + 7 P1 + 1 retro, fits capacity; dev-heavy template port + Auto-Claim full impl). Refreshed 2026-06-22T21:48Z per developer review.
> **Mode:** 🚀 CONTINUOUS FLOW + 2-day check-in (carry-over from Sprint 4).
> **Owner approval:** ⏳ pending (this plan → kickoff issue → atilcan ping).

---

## Doctrine override (owner-directive, Sprint 4 retro candidate)

`.claude/CLAUDE.md` defaults to **2-week sprints**. Owner override at 2026-06-22T20:14Z: Sprint 5 = **2 days**. Rationale (per owner): "2 hafta falan da olmucak" (2 weeks won't happen). Sprint duration doctrine is **per-sprint flexible**, not rigid. **Sprint 4 retro action**: codify "sprint duration = owner-decision per sprint" in CLAUDE.md or leave as override-default.

---

## Sprint goal

**Close the Sprint 4 doctrine chain + land GAP KAPATMA template ports (post-#265 Option B migration).**

Sprint 4 closed 5 P0 doctrine issues (#276, #269, #233, #267, #251) + #265 (Watcher coverage, Option B) and shipped 3 PRs (#275 Layer 1, #270 RCA-19 wake, #277 Path B stub). Sprint 5 finishes the **Auto-Claim Protocol full impl** (replaces #277 stub), closes **Issue #238 sub-task 1** (#280 soul-reminder gap), and lands **6 GAP KAPATMA template ports** (template#51-#55, all migrated from AtilCalc backlog via #265 Option B).

**Sprint 5 is finish-line + cleanup, not new architecture.** All Sprint 4 doctrine items resolved at stub level; Sprint 5 replaces stubs with full impl + ports proven doctrine to template + closes the soul-patch gap.

---

## Committed scope (0 P0 + 7 P1 + 1 retro = 8 items, 6.0 SP)

**Refresh 2026-06-22T21:48Z** per developer review (PR #279 comment at 20:20Z):
- Removed **#265 WATCHER-COVERAGE** (P0, 2 SP) — CLOSED 2026-06-22T20:18Z (Option B: multi-repo watcher → TD-023 deferred).
- Migrated **#260 EVENT-LOG-PORT** → template#52 (no longer an AtilCalc story; SP 1 moved to template).
- Migrated **#263 ADR-PORT** → template#55 (revised 1 SP → 0.5 SP, file mirrors only).
- Added 3 missing template stories (per dev's review): **template#51 atomic-write** (0.5 SP), **template#53 label-guard** (0.25 SP), **template#54 regression** (1 SP, sequential dep).
- Added **#280 SOUL-REMINDER-GAP** (0.75 SP) from Sprint 5 carry (PR #282 retro candidate).

### P1 — Parallel tracks (5.5 SP, 7 stories)

| ID | Title | SP | Owner | Day | Notes |
|---|---|---|---|---|---|
| **AUTO-CLAIM-FULL** | #271 Doctrine Auto-Claim Protocol full impl (~80 LOC + ~15 LOC integration + 5 TC d031) — replaces PR #277 stub | 1.5 | developer (impl) + tester (d031 sign-off) | Day 1-2 | AtilCalc |
| **TEMPLATE-ATOMIC-WRITE** | template#51 — scripts/agent-state.sh atomic-write + d027 regression (was AtilCalc #259) | 0.5 | developer | Day 1 | Template port |
| **TEMPLATE-EVENT-LOG** | template#52 — scripts/event-log.sh + d023 (was #260) | 1 | developer | Day 1-2 | Template port (migrated from #260) |
| **TEMPLATE-LABEL-GUARD** | template#53 — post-restart-label-guard (was #261, PR branch exists) | 0.25 | developer | Day 1 | Template port |
| **TEMPLATE-REGRESSION** | template#54 — 6 regression tests (PR #50 partial 2/6; Sprint 5 = remaining 4, sequential dep on #51/#52/#53) | 1 | developer | Day 2 | Template port |
| **TEMPLATE-ADR-PORT** | template#55 — 5 doctrine ADRs (0024/0025/0026/0027/0030) — file mirrors (was #263, revised 1→0.5 SP) | 0.5 | developer | Day 1 | Template port |
| **SOUL-REMINDER-GAP** | #280 — §Forbidden Standby Modes soul reminder (Issue #238 sub-task 1 close-out, .claude/ human-only territory) | 0.75 | architect (spec) + human (apply) | Day 1-2 | PR #283 spec → owner applies patch |

### Meta — Sprint 5 retro (0.5 SP, 1 item)

| ID | Title | SP | Owner | Day |
|---|---|---|---|---|
| **SPRINT-4-RETRO** | Sprint 4 retro write-up (5 candidates: owner flip-flop, verdict-by taxonomy, watcher dedup ×2, WIP=5 closeout) + Sprint 5 mid-sprint reflection | 0.5 | orchestrator (write) + owner (approve) | Day 2 | PR #282 in review, retro.md drafted |

### Dev commitment (per developer review at PR #279, 2026-06-22T20:20Z)

- #271 Auto-Claim Protocol full impl (1.5 SP) — owns
- template#51 atomic-write + d027 (0.5 SP) — owns
- template#52 event-log.sh + d023 (1 SP) — owns
- template#53 label-guard (0.25 SP) — owns
- template#55 5 doctrine ADRs (0.5 SP) — owns
- template#54 PR #50 (1 SP remaining 4 tests as template infra lands) — owns

**Total dev: 4.75 SP** (tight but feasible in 2-day window). Template#54 is sequential dep on #51/#52/#53.

---

## ⚠️ Risks (compressed 2-day window, refresh 2026-06-22T21:48Z)

1. **#271 full impl may overrun 2 days.** Path B stub is on main (~80 LOC gap). If dev hits edge cases (WIP race conditions, dep parser), may slip to Sprint 6.
2. **template#54 sequential dependency.** template#54's 4 remaining tests depend on template#51/#52/#53 atomic-write + event-log + label-guard landing first. If any of those slip, template#54 slips.
3. **#280 soul-patch requires owner.** Architect provides spec (PR #283); owner must apply to 4 shared soul files (human-only territory per file ownership matrix). If owner doesn't apply, #280 stays open.
4. **No architect/tester review buffer.** Both are WIP=0 today. Sprint 5 dev has 6 impl PRs expected (template#51-55 + #271 + #280 spec) — review queue could pile up.
5. **Sprint duration override not codified.** If owner doesn't decide on "2-week vs 2-day" doctrine change in retro, Sprint 6 will face the same ambiguity.

---

## Definition of Done (Sprint 5, compressed)

A story is "Done" only if ALL of:
1. Acceptance criteria pass automated tests.
2. PR merged to `main` with owner approval.
3. CI green on `main` post-merge.
4. Docs updated (README, changelog, ADR if applicable).
5. Project card moved to Done by orchestrator.
6. No new P0/P1 bugs filed within 24h.

**Sprint 5 specific DoD addition:** Sprint 5 retro doc must be written + approved by owner by Day 2 EOD.

---

## Auto-ping (post-kickoff, refresh 2026-06-22T21:48Z)

`[ORCH→ALL] Sprint 5 day 1, see #278` (kickoff issue #278).
`[ORCH→DEV] #271 + template#51/#52/#53/#54/#55 ready/claimable — dev auto-claim protocol picks oldest first (or #271 since Sprint 4 P0 doctrine chain)`.
`[ORCH→ARCH] #280 spec is your lane (PR #283); plus Sprint 5 design-alignment review queue for dev PRs`.
`[ORCH→TESTER] Sprint 5 sign-off queue: PR #279 (Sprint 5 plan refresh), PR #282 (retro fix), PR #283 (soul-patch spec), plus Day 1-2 dev impl PRs`.

---

## Carry-over from Sprint 4 (resolved, closed, or deferred)

### ✅ Resolved in Sprint 4 (now on main)
- #275 ADR-0038 Layer 1 soul patch → 4 agent souls
- #270 RCA-19 status-transition wake fix → agent-watch.sh
- #277 Path B claim-next-ready.sh stub → scripts/

### ✅ Closed in Sprint 4
- #276 (Design-Drift), #269 (RCA-19 hidden dep), #233 (template port cascade), #267 (watcher crash-loop), #251 (§Forbidden Standby patch)
- #265 (Watcher coverage, closed 2026-06-22T20:18Z — Option B executed; multi-repo → TD-023)

### 🔄 Deferred to Sprint 5 (in scope)
- #271 (now `status:blocked`, Sprint 5 full impl — replaces stub)
- #280 (Sprint 5 carry from Sprint 4 retro — soul-reminder gap, 0.75 SP)

### 🟡 Deferred to Sprint 6+ (out of Sprint 5 scope)
- #272 GAP KAPATMA §Auto-Claim template port (depends on #271 → Sprint 5)
- #186 doctrine gap (cc:human label missing from flip table)
- #193, #194 Sprint 4 P2 backlog overflow items
- #198 #48.1 Sprint 2+3 template port candidates (post-validation)

### 🔄 Migrated to dev-studio-template (via #265 Option B, 2026-06-22T20:18Z)
- #260 → template#52 (event-log.sh + d023)
- #263 → template#55 (5 doctrine ADRs, revised 1→0.5 SP)
- Plus template#51/#53/#54 created from AtilCalc #259/#261/#262 (already in template backlog, now also pulled into Sprint 5)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
