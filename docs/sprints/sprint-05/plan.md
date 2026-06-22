# Sprint 5 — Plan (committed, awaiting owner approval)

> **Status:** 🟡 Plan written by orchestrator after Sprint 4 closeout + owner directive (2026-06-22T20:14Z).
> **Source:** Sprint 4 closeout (`docs/sprints/sprint-04/closeout.md`) + owner chat directive ("sprint 2 gün, başlat").
> **Tracking issue:** [Sprint 5 Kickoff](#) (opening now).
> **Sprint window:** 2026-06-23 → 2026-06-24 (**2 days**, owner override from doctrine's 2-week default).
> **Capacity:** 2 days × 4 agents active ≈ 5-7 SP.
> **Committed total:** **5.5 SP** (1 P0 + 3 P1 + 1 retro, fits capacity).
> **Mode:** 🚀 CONTINUOUS FLOW + 2-day check-in (carry-over from Sprint 4).
> **Owner approval:** ⏳ pending (this plan → kickoff issue → atilcan ping).

---

## Doctrine override (owner-directive, Sprint 4 retro candidate)

`.claude/CLAUDE.md` defaults to **2-week sprints**. Owner override at 2026-06-22T20:14Z: Sprint 5 = **2 days**. Rationale (per owner): "2 hafta falan da olmucak" (2 weeks won't happen). Sprint duration doctrine is **per-sprint flexible**, not rigid. **Sprint 4 retro action**: codify "sprint duration = owner-decision per sprint" in CLAUDE.md or leave as override-default.

---

## Sprint goal

**Close the Sprint 4 doctrine chain + unblock GAP KAPATMA template port.**

Sprint 4 closed 5 P0 doctrine issues (#276, #269, #233, #267, #251) and shipped 3 PRs (#275 Layer 1, #270 RCA-19 wake, #277 Path B stub). Sprint 5 finishes the **Auto-Claim Protocol full impl** (replaces #277 stub), unblocks the **P0 BLOCKER Watcher coverage** (gap-blocking GAP KAPATMA review), and lands 2 GAP KAPATMA template ports.

**Sprint 5 is finish-line + cleanup, not new architecture.** All Sprint 4 doctrine items resolved at stub level; Sprint 5 replaces stubs with full impl + ports proven doctrine to template.

---

## Committed scope (1 P0 + 3 P1 + 1 retro = 5 items, 5.5 SP)

### P0 — Sprint 5 critical path (2 SP, 1 story)

| ID | Title | SP | Owner | Day |
|---|---|---|---|---|
| **WATCHER-COVERAGE** | #265 P0 BLOCKER — Watcher coverage for arch + test in template repo (currently they can't see template PRs, blocking GAP KAPATMA review) | 2 | developer (impl) + architect (RC) | Day 1 |

### P1 — Parallel tracks (3 SP, 3 stories)

| ID | Title | SP | Owner | Day |
|---|---|---|---|---|
| **AUTO-CLAIM-FULL** | #271 Doctrine Auto-Claim Protocol full impl (~80 LOC atomic claim helper + ~15 LOC agent-watch.sh integration + 5 TC d031) — replaces PR #277 stub | 1.5 | developer (impl) + tester (d031 sign-off) | Day 1-2 |
| **EVENT-LOG-PORT** | #260 GAP KAPATMA — template port scripts/event-log.sh + d023 integration | 1 | developer (template port) | Day 1-2 |
| **ADR-PORT** | #263 GAP KAPATMA — template port 5 doctrine ADRs (0024, 0025, 0026, 0027, 0030) | 1 | developer (template port) | Day 1-2 |

### Meta — Sprint 5 retro (0.5 SP, 1 item)

| ID | Title | SP | Owner | Day |
|---|---|---|---|---|
| **SPRINT-4-RETRO** | Sprint 4 retro write-up (5 candidates: owner flip-flop, verdict-by taxonomy, watcher dedup ×2, WIP=5 closeout) + Sprint 5 mid-sprint reflection | 0.5 | orchestrator (write) + owner (approve) | Day 2 |

---

## ⚠️ Risks (compressed 2-day window)

1. **#271 full impl may overrun 2 days.** Path B stub is on main (~80 LOC gap). If dev hits edge cases (WIP race conditions, dep parser), may slip to Sprint 6.
2. **#265 P0 BLOCKER may surface new gaps.** Watcher coverage fix has 2 SP estimate; template repo PRs are complex surface.
3. **No architect/tester review buffer.** Both are WIP=0 today. If they review-queue piles up on Day 1, Sprint 5 ends with merged-but-unreviewed PRs (owner merges without sign-off, repeats Sprint 4 pattern).
4. **Sprint duration override not codified.** If owner doesn't decide on "2-week vs 2-day" doctrine change in retro, Sprint 6 will face the same ambiguity.

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

## Auto-ping (post-kickoff)

`[ORCH→ALL] Sprint 5 day 1, see #issue` (kickoff issue TBD, opening now).
`[ORCH→DEV] #265 #271 #260 #263 ready/claimable — dev auto-claim protocol picks oldest first`.
`[ORCH→ARCH+TEST] Sprint 5 review queue: PRs expected on Day 1-2 from dev`.

---

## Carry-over from Sprint 4 (resolved, closed, or deferred)

### ✅ Resolved in Sprint 4 (now on main)
- #275 ADR-0038 Layer 1 soul patch → 4 agent souls
- #270 RCA-19 status-transition wake fix → agent-watch.sh
- #277 Path B claim-next-ready.sh stub → scripts/

### ✅ Closed in Sprint 4
- #276 (Design-Drift), #269 (RCA-19 hidden dep), #233 (template port cascade), #267 (watcher crash-loop), #251 (§Forbidden Standby patch)

### 🔄 Deferred to Sprint 5 (in scope)
- #271 (now `status:blocked`, Sprint 5 full impl — replaces stub)
- #265 (still `status:in-progress`, P0 BLOCKER)

### 🟡 Deferred to Sprint 6+ (out of Sprint 5 scope)
- #272 GAP KAPATMA §Auto-Claim template port (depends on #271 → Sprint 5)
- #186 doctrine gap (cc:human label missing from flip table)
- #193, #194 Sprint 4 P2 backlog overflow items
- #198 #48.1 Sprint 2+3 template port candidates (post-validation)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
