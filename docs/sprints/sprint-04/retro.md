# Sprint 4 — RETRO-004 (Close-Out Retrospective)

> **Author:** @orchestrator (writing), @atilcan65 (approve)
> **Date:** 2026-06-22T20:32Z
> **Refs:** Issue #281 (this retro's tracking issue), Sprint 4 plan (`docs/sprints/sprint-04/plan.md`), Sprint 4 closeout (PR #275, #270, #277 merged 2026-06-22T19:36Z), Issue #278 (Sprint 5 kickoff)

## Sprint 4 Summary

**Window:** 2026-06-20 → 2026-06-22 (3 days, continuous-flow mode per owner override)
**Mode:** 🚀 CONTINUOUS FLOW (owner override 2026-06-20T18:43Z) — no sprint boundary waiting
**Scope at close:** 18.5 SP (3 P0 + 4 P1 + 3 P2 = 10 stories; PM hygiene-fix amendment 2026-06-20T14:38Z)
**Closed at:** 2026-06-22T19:36Z (PR #277 merge = Path B claim-next-ready.sh stub)

### Sprint 4 ships (all merged to main)

| PR | Title | Merged | Commit | Sprint 4 role |
|---|---|---|---|---|
| #174 | RETRO-003 + Sprint 3 P0 §4 carry | 2026-06-20T11:02:59Z | (RETRO-003) | Sprint 3 closeout |
| #207 | PM hygiene — remove stale ADR-0023-FLIP entry | 2026-06-21T12:44:32Z | — | PM hygiene |
| #211 | AUTO-REVERT-FIX RC — restart-time label-revert prevention | 2026-06-21T16:35:47Z | — | Sprint 4 P0 (RC) |
| #212 | E2E-DEPLOY-VERIFY T3+T6 — is-active check + RCA-16 sudo | 2026-06-21T18:51:16Z | — | Sprint 4 P0 (deploy) |
| #214 | AUTO-REVERT-FIX — post-restart label-guard | 2026-06-21T19:08:18Z | — | Sprint 4 P0 (impl) |
| #215 | ADR-0012 amendment — type:bug PR cc:tester + needs-tester-signoff | 2026-06-21T18:59:19Z | — | Issue #213 Layer 2 |
| #217 | ADR-0032 RCA-18 dedup buffer TTL pruning | 2026-06-21T20:25:22Z | — | RCA-18 fix |
| #218 | RETRO-004 DRAFT — Sprint 4 stabilization (Day 1) | 2026-06-21T20:21:52Z | — | PM-authored draft |
| #219 | d022 focused regression test + REPO check reorder | 2026-06-21T20:27:56Z | — | Issue #200, #202 |
| #220 | ci(label-check) Layer 3 type-driven invariants | 2026-06-21T20:58:56Z | — | Issue #213 |
| #223 | Auto-Ping dual-channel (partial) | (early Sprint 4) | — | Story 221 |
| #224 | ADR-0032 RCA-32 — 24h bucket-TTL pruning | 2026-06-21T21:21:44Z | — | RCA-32 fix |
| #225 | d023-rca18-buffer-ttl — regression test | 2026-06-21T21:22:23Z | — | ADR-0032 test |
| #226 | ADR-0033 CLAUDE.md §Auto-Ping Hard-Rule amendment proposal | 2026-06-21T21:35:45Z | — | Issue #221 |
| #229 | ADR-0034 + ADR-0035 — cmd_set JSON contract + Layer 3 open-only fire | 2026-06-22T06:07:33Z | — | Issue #228, #227 |
| #234 | ADR-0036 status-transition wake event (RCA-19 fix) | 2026-06-22T08:57:22Z | — | Issue #231 |
| #239 | Auto-Ping dual-channel impl (notify.sh --wake + agent-wake.sh + d024) | 2026-06-22T08:46:08Z | 02ef97a | Story 221 |
| #241 | ADR-0037 — Orchestrator Proactive Gap-Scan | 2026-06-22T09:41:06Z | ac0dac0 | Issue #235 |
| #242 | §Things agents must NEVER do — forbidden standby modes | 2026-06-22T07:47:56Z | d9ae266 | Issue #238 sub-task 0 |
| #243 | Issue #238 3 sub-tasks (spec) | 2026-06-22T08:46:08Z | 998cdf1 | Issue #238 spec |
| #244 | ADR-0036 status flip Proposed → Accepted | 2026-06-22T18:26:52Z | — | ADR-0036 flip |
| #246 | Issue #256 — GraphQL rate-limit fallback to REST API | 2026-06-22T10:04:15Z | 64e34ba | RCA-19 sister |
| #247 | cmd_set JSON contract per ADR-0034 | 2026-06-22T16:16:11Z | — | Issue #237, ADR-0034 |
| #255 | STORY-237 atomic-write + validate + rebuild | 2026-06-22T16:20:55Z | — | Issue #237 |
| #257 | STORY-256 replace 'standby' text in wake_nudge payload | 2026-06-22T15:06:39Z | — | Issue #238 family |
| #266 | TD-022 — Layer 3 scope gap (clean rebase) | 2026-06-22T17:13:48Z | — | Tech debt |
| #268 | JSON-quote cmd_set string args (P0 crash-loop fix) | 2026-06-22T18:32:17Z | — | Issue #267 |
| #270 | RCA-19 status-transition wake — ADR-0036 Part A+C | 2026-06-22T20:03:54Z | b5ea744 | Issue #269 |
| #273 | ADR-0038 Auto-Claim Protocol + TD-023 | 2026-06-22T19:08:39Z | 3d2f947 | Issue #271 |
| #275 | PR #274 conflict resolution — ADR-0038 status flip + soul patch | 2026-06-22T19:36:27Z | 608dc45 | ADR-0038 Layer 1 |
| #277 | Path B claim-next-ready.sh stub (soul hook no-op bridge) | 2026-06-22T20:06:43Z | 56b8c4e | Issue #276 |

**Total: 30 merged PRs in Sprint 4 window (2026-06-20 → 2026-06-22T20:06Z).** Earlier retro version listed 12 (3 doctrine/ADR groups + 9 impl); expanded table documents full scope per tester Issue-3 BLOCKING.

### Sprint 4 incidents closed

| # | Title | Resolution |
|---|---|---|
| #233 | RCA-19 template port cascade | PR #270 (RCA-19 fix) |
| #251 | Owner-gate §Forbidden Standby patch | Closed (linter revert, sub-task 1 deferred to #280) |
| #267 | Watcher JSON-quote crash-loop | PR #268 (cmd_set JSON contract) |
| #269 | RCA-19 hidden dep | PR #270 |
| #276 | Design-Drift PR #275 (non-existent scripts/claim-next-ready.sh) | PR #277 (Path B stub) |

---

## 5 Retro Candidates

### 1. Owner flip-flop pattern (Sprint 4 closeout) 🟡 Pattern

**Observation:** PR #277 went through 3 status transitions in ~12 minutes (status:ready → in-review → ready → in-review) due to owner review adjustments during the 19:30-19:42Z window. Pattern: owner self-review + label flip = high churn on PRs at the closeout gate.

**Why it happened:**
- Owner was both reviewer and merger
- Late-arriving verification comment (PR #276 Design-Drift) caused re-review
- No buffer between reviewer verdict and merge gate

**Retro action:**
- Codify "owner reviews in 1 cycle, not N" — add to CLAUDE.md §Definition of Done or PR review SOP
- Add label-flip-count metric to PR review observability (TD candidate)
- Consider: separate reviewer from merger for hot PRs (architect or PM as interim reviewer)

**Owner:** @architect (RC), @atilcan65 (decide on codification)

### 2. verdict-by:* label taxonomy ✅ Accepted pattern

**Observation:** Added mid-Sprint 4 (ADR-0024) and exercised heavily. PR #279 has `verdict-by:2026-06-22T20:19:18Z` label set. Taxonomy = stable doctrine, accepted into the flow.

**Why it worked:**
- Single label per PR captures reviewer + timestamp
- Easy to scan: `gh pr list --label "verdict-by:..."`
- 4-cat invariant (ADR-0012) preserved (verdict-by is a 5th informational label, not a 4-cat category)

**Retro action:**
- Confirm taxonomy works, no follow-up needed
- Document as accepted pattern in retro doc (this entry)
- Future consideration: verdict-by for issue-level reviews (e.g., PM sizing verdict)

**Owner:** No action — accepted

### 3. Watcher dedup false-positives for label_change events 🟠 Tech debt

**Observation:** Persistent issue: label_change events re-fire despite processed_event_ids marking. Likely cause: comment-updated events triggering label_change re-emission in GraphQL subscription. Recurred in Sprint 4 (~6-8 times per hour at peak).

**Why it happened:**
- GraphQL subscription emits label_change on every comment update (even if labels didn't change)
- processed_event_ids hash is per-event but re-fires when payload changes
- No stable hash for "no-op label change" detection

**Retro action:**
- File as TD (tech debt) for Sprint 6 — separate from this retro
- Include: detect no-op label_change (compute diff, skip if empty), OR use REST API polling for label changes (no subscription re-fire)
- Impact: low (false-positives are noise, not data loss) but agent state files bloat

**Owner:** @architect (RC) + @developer (impl) — Sprint 6 candidate

### 4. Watcher dedup for pr-* events 🟠 Tech debt (bundle with #3)

**Observation:** Similar to #3: pr_review_requested and pr_comment_mention events re-fire. Same root cause class (subscription noise).

**Retro action:**
- Bundle with #3 — single TD for watcher dedup
- Same fix applies (REST API fallback or stable hash)

**Owner:** Same as #3

### 5. WIP=5 during Sprint 4 closeout ✅ Acceptable for closeout

**Observation:** At 19:36Z closeout, dev WIP=5 (1 sprint-3 carry + 4 new Sprint 4 stories, all completed in closeout cascade). Above the ADR-0038 WIP=2 hard cap.

**Why it happened:**
- Owner burst-close pattern (commit closeout chain in 1 shot)
- Sprint 4 doctrine chain (#233, #251, #267, #269, #276) all blocked on each other — couldn't reduce WIP naturally
- Final closeout unblocked all simultaneously

**Retro action:**
- Confirm WIP=5 was acceptable for closeout (one-time cascade)
- Set "WIP=2" hard cap for **steady-state** (per ADR-0038 already)
- Doc: add note to ADR-0038 that "burst closeouts may temporarily exceed WIP cap"

**Owner:** No action — already in ADR-0038 doctrine

---

## Sprint 5 carry (post-burst-close + #280 + #281)

Sprint 5 actual scope = 4 items / 2.75 SP:

| ID | Issue | Title | SP | Owner | Status |
|---|---|---|---|---|---|
| AUTO-CLAIM-FULL | #271 | §Auto-Claim Protocol full impl (replaces #277 stub) | 1.5 | dev + tester | blocked |
| SOUL-REMINDER-GAP | #280 | §Forbidden Standby Modes 4-soul reminder (NEW) | 0.75 | architect RC + owner-apply + d033 | ready |
| RETRO-4 | #281 | This document | 0.5 | orchestrator write + owner approve | ready (this) |
| (owner-merged via PR #279 docs) | — | Sprint 5 docs plan + backlog | — | orchestrator | merged via PR (awaiting owner) |

---

## Doctrine override codification (retro action item)

**Sprint 4 doctrine default:** 2-week sprints (per `.claude/CLAUDE.md`).
**Sprint 5 override:** 2 days (per owner directive 2026-06-22T20:14Z chat).
**Retro question:** Is "2-week" a rigid default or a per-sprint owner decision?

**Options:**
- (a) **Codify "sprint duration = owner-decision per sprint"** in CLAUDE.md — removes ambiguity, owner is the authoritative source
- (b) **Document as override-default** — keep 2-week in CLAUDE.md, add "owner can override" footnote
- (c) **Make 2-day the new default** — flip doctrine (high-change, requires broader consensus)

**Recommended:** (a) — owner-decision is the simplest, most flexible, and matches the actual decision-making pattern observed.

**Owner decision needed:** @atilcan65 (approve one of the 3 options)

---

## Action items for Sprint 6

1. **Watcher dedup TD** (from candidates #3 + #4) — file as `docs/tech-debt.md` entry, owner: architect + dev
2. **Doctrine override codification** (from doctrine override section) — owner: atilcan65 to decide option a/b/c
3. **Sprint duration doctrine update** (depends on #2) — implement chosen option in CLAUDE.md
4. **Owner flip-flop mitigation** (from candidate #1) — owner: architect RC + atilcan65 to decide on codification
5. **#272 GAP KAPATMA §Auto-Claim template port** — depends on #271 (Sprint 5), Sprint 6 carry
6. **#186 doctrine gap (cc:human label missing from flip table)** — Sprint 6 carry
7. **#193, #194 Sprint 4 P2 backlog overflow** — Sprint 6 carry
8. **#198 #48.1 Sprint 2+3 template port candidates** — Sprint 6 carry (post-validation)

---

## Acceptance

- [x] retro.md written with all 5 candidates + Sprint 5 carry + doctrine override
- [x] Action items listed for Sprint 6
- [ ] TD file for watcher dedup (separate from this doc, Sprint 6 backlog)
- [ ] Owner approves retro doc
- [ ] Sprint 6 backlog updated with action items
- [ ] Doctrine override option chosen + implemented in CLAUDE.md (or documented as override-default)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
