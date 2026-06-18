# Sprint 1 Retrospective — Foundation (2026-06-17 → 2026-07-01, 14 days)

> **Status:** ✅ Sprint 1 P0 burn-down complete (6/6). Retro authored 2026-06-18 (day 2 of Sprint 1 calendar window; P0 work closed pre-schedule).
> **Author:** @orchestrator (Claude Code)
> **Format:** concise retro — what shipped, what didn't, what hurt, what to change
> **Audience:** @atilcan65 (owner) + the 5-agent team + future Sprint 2+

---

## TL;DR

Sprint 1 **delivered the foundation Sprint 2 needs**: pure-Python engine with Decimal precision (STORY-002), keyboard-first web shell on LAN (STORY-003a/b), VM hardening dev deliverable (STORY-001), front-end framework decision (STORY-004, ADR-0018), and three doctrine gaps closed (Issue #10 verdict discipline, ADR-0019 R-3 HTTP API contract, TD-009 per-agent worktrees). **6/6 P0 stories shipped** in ~30 hours of elapsed time across ~3 calendar days of heavy merges.

**Biggest wins:** (1) ADR-driven design-first culture took root (5 ADRs authored in Sprint 1), (2) worktree isolation killed the "concurrent commit collision" class of bugs outright, (3) the auto-ping + autonomy loop pairing works — Sprint 1 had zero human-relay-message asks after the first day.

**Biggest hurt:** (1) **PR #62 chronic re-fire loop** (68 phantom wakes from TD-010 root cause — tester APPROVED missing `status:in-review` removal), (2) my own repeated doctrine bug on atomic status transitions (fixed via atomic-flip discipline, see "Doctrine bugs" below), (3) PM's agent-watch.sh doesn't include issue-level events (PM-watcher gap, still open as tech debt).

**Sprint 2 readiness:** plan.md + backlog.json on main, 25 SP feature + 6 SP architect pre-work + 10 SP buffer = 41 SP capacity-fit for a 35-45 SP target. Carry-over: 3 issues (#46, #65, #48 — see below). **Architect pre-work is the biggest forward-risk** — R-5 (persistence) + R-2 (frontend) + ADR-0019 amendment are gating 3 of 6 Sprint 2 stories.

---

## What shipped (Sprint 1 inventory)

### Stories (6/6 P0)

| Story | PR(s) merged | Result |
|---|---|---|
| **STORY-001** VM hardening | #40 (dev script + runbook + tests) + #41 (plan actuals + CHANGELOG) | ✅ Dev deliverable merged. ⏳ Owner apply step on 192.168.1.199 still pending — `sudo bash scripts/ops/apply-vm-hardening.sh` + runbook §AC7 verification |
| **STORY-002** Engine module | #26 (impl) + #23 (TDD red, closed/superseded) + #29 (R-1 housekeeping → ADR-0017+0018 Accepted) | ✅ Merged. Pure-Python, Decimal-precision, mypy --strict clean |
| **STORY-003a** Web shell core | #42 (impl + d007 observability) + #37 (TDD red contract suite) + #56 (ruff cleanup) + #59 (regress pin) | ✅ Merged. SPA shell + FastAPI surface, keyboard-first |
| **STORY-003b** Deferred components + LAN-bind | #49 (impl) + #51 (BACKUP_CRON_EXPR fix) | ✅ Merged. `<atilcalc-history>` / `<atilcalc-mode-toggle>` / `<atilcalc-help-popup>` shipped |
| **STORY-004** Front-end framework ADR | #13 (ADR-0018) + #29 (flip to Accepted) | ✅ ADR-0018 Accepted: vanilla JS + Web Components |
| **STORY-005** Verdict-sentinel doctrine | #36 (design, Option C) | ⚠️ **CANCELLED** by owner 2026-06-17T21:13:31Z (Issue #38 closed) — verdict:* label NOT implemented in Sprint 2 |
| **Doctrine gap** (Issue #10) | #33 (ADR-0019 R-3 contract) + #36 (STORY-005 design, repurposed) | ✅ Doctrine gap closed (4-cat label invariant + status-label-to-board sync ADR-0012 + ADR-0013) |
| **STORY-006** Watcher dedup fix (carry-over from Sprint 0, Issue #6) | #9 (fix, Issue #6) + #24 (Issue #14 follow-up) + #34 (Issues #25 follow-up) | ✅ Content-stable event IDs shipping |

### ADRs authored in Sprint 1

- **ADR-0017** — Tech stack (Python 3.11+, pytest, Typer, Decimal). Accepted (PR #5).
- **ADR-0018** — Front-end framework: vanilla JS + Web Components. Accepted (PR #13).
- **ADR-0019** — R-3 HTTP API contract for engine wrapper. Accepted (PR #33) + **amended** (PR #63) with Decimal trailing-zero rule + Exception taxonomy.
- **ADR-0020** — Label-mutation transactionality (4-cat invariant enforcement). Accepted (PR #62).
- **ADR-0021** — Docs PR convention. Accepted (PR #62).

5 ADRs in 1 sprint = architecture runway Sprint 2/3 will lean on heavily.

### Process & doctrine artifacts

- **TD-009 resolution** (option a — per-agent worktrees). PR #61 merged, `docs/sprints/sprint-01/td-009-resolution.md` shipped.
- **ADR-0012** — 4-cat label invariant (type, status, agent, cc required on every issue/PR). CI gate: `.github/workflows/label-check.yml`.
- **ADR-0013** — Status-label-to-board sync (Projects v2 auto-mirror). Workflow: `.github/workflows/status-label-to-board.yml`.
- **ADR-0015** — Atomic 4-flag handoff (add-add-remove-remove discipline).
- **STORY-044** proactive board scan (PR #54) — orchestrator runs board hygiene every N minutes.
- **STORY-045** STATUS block action driver (PR #64) — orchestrator auto-pings on P0/P1 blocker detection from STATUS output.

### Carry-over to Sprint 2

| Issue | Title | Status | Sprint 2 plan |
|---|---|---|---|
| **#46** | TD-006 root cause fix (stale-cc watchdog spam) | Architect design done via PR #62 | Developer implements in Sprint 2 P1 |
| **#65** | Reclassify fastapi+uvicorn from `[dev]` to runtime deps | Architect PR #66 in peer review | Lands early Sprint 2 P1 |
| **#48** | Template port — Sprint 1 lessons → `dev-studio-template` | Open, gated on Sprint 1 retro | **Unblocks NOW** (this retro is the gate) |

---

## What didn't ship

- **STORY-005 verdict:* label taxonomy** — owner decision 2026-06-17T21:13:31Z (Issue #38 closed): "we are not going to do this update". Will NOT be in Sprint 2 scope. The PR-review `verdict:approved` / `verdict:changes-requested` / `verdict:pending` label idea is parked. Sprint 2 reviewers must use inline-comment verdicts + status:* labels only.
- **PR reviewer auto-assignment** (Sprint 1 stretch STORY-008) — deferred to Sprint 3+. Workaround: orchestrator + humans track manually. TD for next sprint.
- **HTTPS / TLS** on the FastAPI surface — explicitly out of STORY-001 scope (Sprint 2 P1 stretch).
- **Owner apply step on 192.168.1.199** — STORY-001 dev deliverable merged but the `sudo bash scripts/ops/apply-vm-hardening.sh` invocation on the VM is the human's step, not the agent's. Until this runs, the LAN exposure is technically still running on un-hardened defaults.

---

## What hurt (the lessons)

### 1. PR #62 chronic re-fire loop (TD-010) — 68 phantom wakes

**Symptom:** PR #62 had architect 🟢 + tester 🟢 + my orchestrator 🟢 all in comments, but every 60s `agent-watch.sh` re-fired on the same event because the PR was stuck at `status:in-review` (tester forgot to flip status when approving).

**Root cause:** Tester's soul §Handoff Discipline didn't include `--remove-label status:in-review` in the APPROVED path. So the PR was "approved in comment" but the queue said "still in review". The watcher's `processed_event_ids` dedup correctly stopped re-processing the SAME event, but every new poll cycle re-read the label state and saw the same dirty state.

**Fix (orchestrator atomic flip):** `gh pr edit 62 --remove-label status:in-review --remove-label needs-tester-signoff --add-label status:ready` unblocked it.

**Lesson:** "Approved in comment" ≠ "approved in queue". Soul §Handoff Discipline must include BOTH the comment AND the label flip. Filed as TD-010; tester soul needs amendment in Sprint 2 P1 (separate from this retro, owned by tester).

### 2. My repeated atomic-flip doctrine bug

I hit "add status:X without removing status:Y" **at least 3 times** in Sprint 1 (PR #68, PR #76, plus one I caught pre-write). Each time the PR/issue had TWO `status:*` labels simultaneously, which ADR-0012 will eventually forbid via CI gate.

**Fix:** Discipline — every status transition is `remove X, add Y` in ONE `gh issue edit` call. ADR-0015 §Atomic 4-flag handoff documents this; my orchestrator soul needs a §Doctrine Reminder line in the §Handoff Discipline table.

**Lesson:** Soul contracts only help if I follow them. The doctrine is in the docs; I need to actually run it.

### 3. PM watcher gap (Issue: PM's `agent-watch.sh` lacks issue-level events)

PM is supposed to wake on `issue_assigned` to stories they should groom, but the watcher script doesn't emit that event for them. PM worked anyway in Sprint 1 by manually checking the board + getting `notify.sh` pings from me, but this is a process debt.

**Fix for Sprint 2:** Architect to file a TD in `docs/tech-debt.md` + either (a) extend agent-watch.sh to include issue events for PM, or (b) PM soul adds manual board scan to its daily hygiene. Owner decision needed.

### 4. Owner review bandwidth bottleneck (predicted, confirmed)

The plan.md flagged it; Sprint 1 confirmed it. **~25 PRs in ~30 hours** = the human (you) was the throughput ceiling on multiple days. Sprint 2 will need to either:
- (a) Batch owner reviews into 2 windows/day (morning + evening)
- (b) Delegate Sprint 2 P1 PRs to the orchestrator-merge convention (orchestrator proposes merge, owner 1-click approve) — needs your sign-off
- (c) Trim Sprint 2 scope (don't do this; the architect pre-work is the load-bearing path)

### 5. Sprint 0 → Sprint 1 handoff gap

Sprint 0 ended with PR #8 (vision) and Issue #6 (watcher dedup) open. Sprint 1 started with both. There was no "Sprint 0 retro" — we jumped straight into Sprint 1 with incomplete Sprint 0 closure. Sprint 2 MUST end with this retro (now), and Sprint 1 closeout must include Issue #6 closure (done) + Issue #38 (done) + Issue #10 (done) + ST-005 cancel confirmation (done). Going forward, every sprint closes with a retro BEFORE the next kickoff.

---

## Sprint 2 readiness checklist

| Item | Status |
|---|---|
| Plan + backlog on main | ✅ (PR #75 merged) |
| 6 stories groomed + sized | ✅ (25 SP final, 3 verdicts concur + 1 revise STORY-011 to 7 SP) |
| Architect pre-work scoped | ✅ (R-5 ~3SP + R-2 ~2SP + ADR-0019 amendment ~1SP = 6 SP equivalent) |
| Carry-over triaged | ✅ (3 issues, 10 SP buffer absorbs) |
| Kickoff tracking issue | ✅ (#78 open) |
| Architect pre-work **started** | ❌ **NOT YET** — see action item below |
| Owner review cadence | ⚠️ Decision needed (lesson 4 above) |

---

## Action items (post-retro)

| # | Owner | Item | Target |
|---|---|---|---|
| A1 | **orchestrator** | Ping architect: "Start R-5 + R-2 + ADR-0019 amendment drafts" — gating STORY-007/009/011 | **Now** (this session) |
| A2 | **orchestrator** | Close #48's gate (post-Sprint-1 retro) — write the actual retro content here (DONE by this file). Owner to file template-port PR off this doc | Sprint 2 day 1 |
| A3 | **architect** | Update `docs/tech-debt.md`: TD-009 → Resolved (cross-ref `td-009-resolution.md`); TD-010 → Open (tester soul amendment needed) | Sprint 2 P1 |
| A4 | **tester** | Soul §Handoff Discipline amendment: include `--remove-label status:in-review` in the APPROVED path | Sprint 2 P1 |
| A5 | **architect** | File TD for PM watcher gap; propose fix in Sprint 2 (soul manual-scan OR watcher script extension) | Sprint 2 P1 |
| A6 | **owner (atilcan65)** | Decide Sprint 2 owner-review cadence: (a) batch 2x/day, (b) orchestrator-merge propose convention, (c) trim scope | Before Sprint 2 P2 |
| A7 | **orchestrator** | Add §Doctrine Reminder to orchestrator soul §Handoff Discipline: "every status transition is atomic — `remove X, add Y` in ONE gh call" | Sprint 2 P1 |
| A8 | **orchestrator** | Append retro entry to CHANGELOG.md `[Unreleased]` (small chore PR) | Sprint 2 P1 |

---

## Sprint 2 P1 priority order (echoed from `plan.md`)

1. **Architect pre-work** — R-5, R-2, ADR-0019 amendment (gates STORY-007/009/011)
2. **STORY-007** (P0, persistent history backend) — unblocks #008 + #010
3. **STORY-008** (P0, history UI wiring) — depends on #007 backend
4. **STORY-011** (P1, scientific functions) — independent; runs in parallel with #007
5. **STORY-009** (P1, skin system) — depends on R-2 ADR
6. **STORY-010** (P1, skin pref persistence) — depends on #009 + R-5
7. **STORY-012** (P2, docs) — batch at end

---

## Metrics & signals

- **PR throughput:** ~25 merged PRs in ~30 active hours → ~1 PR/72min wall-clock (across all 4 agents in parallel)
- **P0 burn-down:** 6/6 (100%)
- **Stories cancelled:** 1 (STORY-005 verdict:* label, owner choice)
- **Tech debt opened Sprint 1:** 4 (TD-005, TD-006, TD-007, TD-010) — 1 already resolved (TD-009)
- **Architecture decisions authored:** 5 (ADR-0017 to 0021 + 0019 amendment)
- **ADRs going into Sprint 2:** 3 more (R-5, R-2, ADR-0019 amendment)

---

— Orchestrator (Claude), 2026-06-18T16:00:00+03:00
