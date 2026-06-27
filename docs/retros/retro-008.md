# RETRO-008 — Sprint 13 Codifications

> **Author:** @product-manager (PM lane, owner ratifies)
> **Date:** 2026-06-27T09:55+03:00 = 06:55Z (draft via Issue #480)
> **Scope:** 12 candidates from Sprint 13 cluster work + RETRO-007 watchlist carry-forwards
> **Lane:** `docs/retros/retro-008.md` (PM-owned companion to RETRO-005/006/007 series, owner ratifies)
> **Closes:** Issue #480 (RETRO-008 Sprint 13 codification dispatch)

## TL;DR

RETRO-008 catalogues **12 retrospective candidates** identified during Sprint 13 cluster work. Tier 1 (5 candidates) is high-priority and Sprint 14 P1 candidates. Tier 2 (5 candidates) is medium-priority and Sprint 14 P2 candidates. Tier 3 (2 candidates) is low-priority and Sprint 15+ backlog.

Origin: Sprint 13 surfaced 6 RETRO-007 watchlist entries via 8 PRs (Issue #463-471 + Issue #480). The work generated new doctrine refinement candidates beyond what RETRO-007 captured.

## Tier 1 — Sprint 14 P1 candidates (5)

### §1 — CI re-run race condition (Issue #463 → d053 observed)

**Observed**: PR #472 status:ready auto-promote raced PM status:in-review flip on Sprint 13 PR #472.

**Pattern**: GitHub Actions re-runs can complete between label flip and verdict post, causing transient state confusion.

**Doctrine needed**: Re-query CI status within 30s of verdict post (sister-pattern to §Timing window), not just label state.

**Cross-ref**: Issue #463, d053 §Pre-merge 4-cat verification, RETRO-007 watchlist #3 codification.

### §2 — Engine perf flake vs regression codification (Issue #329 hypothesis confirmed)

**Observed**: Sprint 13 PR #472 Lint & Test FAIL at p99=143ms was transient flake, not deterministic regression. Same engine code on main @ 0ddbe80 had CI SUCCESS in re-run.

**Pattern**: p99 budget threshold tight (50ms / 100ms) for CI variance. Single-flake instance per Issue #329 hypothesis (environmental sensitivity).

**Doctrine needed**: Distinguish flake vs regression codification — single CI FAIL ≠ deterministic regression. Requires 2+ consecutive failures before labeling regression.

**Cross-ref**: Issue #329 (origin), Issue #463 (d053 carrier), RETRO-007 watchlist #6 codification.

**Live evidence**: PR #472 CI FAIL run → re-query showed success. PR #465 CI FAIL run (p99=209ms) → re-query showed success. Both single-flake, not regressions.

**Sprint 14 REFINEMENT — 3-source convergent evidence chain (PM integrator)**:

- **Source 1 (Tester source)**: PR HEAD re-run is UNRELIABLE discriminator for engine perf regressions. A docs-only PR (e.g., PR #487 plan.md) re-tests the SAME engine code as main — if main HEAD is broken, PR HEAD will also fail (but it's not the PR's fault). Observed live on PR #487: 2 consecutive Lint & Test FAILs on docs-only PR (first p99=53.75ms, re-run p99=135.25ms, 2.5x WORSE) — but PR #487 has zero engine code, so the FAIL must be inherited from main.

- **Source 2 (Orchestrator source)**: Doctrine gap — dispatcher view. When Lint & Test FAILs on a docs-only PR, FIRST verify main HEAD state before labeling it as a PR-introduced regression. If main HEAD fails too → real regression on main (NOT flake, NOT PR-caused). The reliable discriminator is: does main HEAD itself fail CI?

- **Source 3 (Dev source)**: Canonical scratch PR test on main HEAD exonerates the PR-introduced-regression hypothesis. Dev opened scratch PR #489 on main HEAD, Lint & Test SUCCESS @ 2026-06-27T07:23:07Z. Combined with PR #487 3rd CI PASS @ 2026-06-27T07:19:35Z → confirms flake (NOT regression). [Note: PR #489 is canonical scratch PR for CI verification; PR #314 = STORY-300 ** power operator from Sprint 11 (merged @ 3d2406b8 on 2026-06-23T20:20:11Z) — distinct from PR #489.]

**Doctrine refinement (3-source converged)**:
1. **PR HEAD re-run = UNRELIABLE** for docs-only PRs (re-tests main's engine code, not PR's own).
2. **Main HEAD re-run = canonical "is-main-actually-broken" check**. The reliable discriminator.
3. **Condition 3 (re-run passes within 4 min) is the falsification gate**. Issue #488: 2 consecutive FAILs initially looked like regression, but 3rd CI run PASSES → condition 3 = TRUE → FLAKE.
4. **Distinction**: 2 consecutive FAILs with NO 3rd-pass within 4 min = regression (canonical evidence). 2 consecutive FAILs followed by PASS within 4 min = flake.

**Live evidence (Issue #488, 2026-06-27)**:
- PR #487 docs-only (plan.md only, no engine code)
- 1st FAIL: p99=53.75ms (7.5% over 50ms)
- 2nd FAIL: p99=135.25ms (170% over, 2.5x WORSE) — both `test_arithmetic_p99_under_50ms_still_holds` AND `test_transcendental_p99_under_100ms_still_holds` failing
- 3rd run PASS @ 2026-06-27T07:19:35Z → condition 3 = TRUE → FLAKE (not regression)
- Dev scratch PR on main HEAD PASS → main HEAD not broken
- **Verdict**: Issue #488 RESOLVED as environmental flake per RETRO-008 §2 condition 3 (NOT deterministic regression).

**Cross-ref**: Issue #488 (tester P1 filing → resolved as flake), RETRO-008 §6 (dev ground-truth drift sister-pattern), [ORCH→PM] convergent dispatch.

### §3 — wip_overflow false positive (RETRO-008 candidate)

**Observed**: agent-watch.sh wip_overflow heuristic can trigger false positive on legitimate 2-issue concurrent work (e.g., PR-A closes 2 issues simultaneously).

**Pattern**: WIP = 2 active streams ≠ 2 separate issues. PR cluster (PR-A closes #N + #M) is one work stream, not two.

**Doctrine needed**: WIP count should be by work-stream, not by issue count. Auto-claim script (ADR-0038) needs work-stream awareness.

**Cross-ref**: ADR-0038 §Auto-Claim Protocol, Issue #238 (no self-justified pauses).

### §4 — Layer 5 race pattern (sister-pattern to §1)

**Observed**: GitHub Actions Layer 5 auto-promote can race with manual label flips. Sister-pattern to §1 CI re-run race.

**Pattern**: Workflow run completion → status:ready auto-add → user label flip in same window → stale state.

**Doctrine needed**: Layer 5 race awareness in label flip timing. Re-query within 30s of any auto-promote.

**Cross-ref**: ADR-0013 (board sync), ADR-0015 (atomic 4-flag hand-off), Issue #450 (sister-pattern PR).

### §5 — Peer-poke CI timing gap (ADR-0033 dual-channel observed)

**Observed**: scripts/peer-poke.sh dual-channel invocation requires both Telegram + tmux pane wake. tmux context requires -w -r <role> flags. Single-channel (notify.sh -l <role>) silently fails peer wake.

**Pattern**: Agent in tmux context can write Telegram message but peer tmux pane never wakes. Peer-poke.sh bakes correct invocation shape.

**Doctrine needed**: All peer-poke invocations use peer-poke.sh (not notify.sh) from tmux context. ADR-0033 codification complete in PR #471.

**Cross-ref**: ADR-0033, Issue #471 (PM lane amendment carrier), scripts/peer-poke.sh, scripts/ping.sh.

## Tier 2 — Sprint 14 P2 candidates (5)

### §6 — Agent factual ground-truth drift

**Observed**: Sprint 13 PM cluster: PM cached label state from chat memory, missed Issue #481 status flip until re-query. Sister-pattern to RETRO-005 #18/#20.

**Pattern**: Chat-memory caching of GitHub label state is the failure mode. Re-query within 30s of any action is required.

**Doctrine needed**: §Pre-verdict cross-check (Issue #430) + §Timing window (Issue #470) cover this for PRs. Extend to issues: re-query issue labels within 30s of any action.

**Cross-ref**: Issue #430, Issue #470, RETRO-005 #18/#20.

**Sprint 14 LIVE INSTANCE (Issue #488, 2026-06-27)**:
- Dev sent URGENT wake to PM: "Issue #488 currently status:backlog + agent:developer. Please flip status:backlog → status:ready."
- Dev's wake was based on **chat-memory cached state** from earlier observation.
- Ground truth at wake time: Issue #488 was **already status:in-progress** (dev had auto-claimed via ADR-0038 in parallel with sending the wake).
- PM's response to flip was **redundant** — Issue #488 was no longer status:backlog.
- Orchestrator caught this as RETRO-008 §6 concrete instance.
- **Lesson**: BEFORE acting on stale label state from a peer's wake, re-query ground truth within 30s (sister-pattern to §Timing window for verdicts). Dev's wake should have included a `gh issue view` snapshot.

**Sprint 14 LIVE INSTANCE #2 (PR #490 §2 source 3, 2026-06-27)**:
- PM agent drafted RETRO-008 §2 amendment referencing "Dev locally created scratch PR #314 on main HEAD, ran CI, PASS" — **conflated PR numbers from chat memory**.
- Ground truth: PR #314 = STORY-300 ** power operator (merged @ 3d2406b8, 2026-06-23T20:20:11Z). PR #489 = canonical scratch PR for Issue #488 CI verification (closed @ 2026-06-27T07:27:14Z, no merge — scratch/audit-trail only).
- Orchestrator caught this via re-query before squash: "[ORCH→PM] PR #490 READY for squash — ONE factual correction needed in §2. PR #314 ≠ PR #489. Fix and force-push."
- PM self-corrected via Edit + force-push before merge — doctrine applied to self (sister-pattern to Issue #488 instance above).
- **Lesson**: PM agents are equally susceptible to §6 drift as dev/peer agents. §Timing window + §Pre-verdict cross-check must apply to PM's OWN doctrinal references, not just peer verdicts. Add to PM soul §Pre-verdict cross-check: "verify PR numbers via `gh pr view N --json title,labels` within 30s of any doctrinal citation."

### §7 — stale_cc deadlock (peer review handoff)

**Observed**: Peer reviews can stall if cc:* label is not flipped after peer responds. Watcher loop re-wakes original agent (because cc:* stayed on them).

**Pattern**: Original agent finishes action → expects peer to flip cc:* → peer forgets → original agent re-wakes on same event.

**Doctrine needed**: Each peer must flip cc:* after responding. Issue tracking via `processed_event_ids` mitigates but doesn't eliminate.

**Cross-ref**: ADR-0015 (atomic 4-flag hand-off), Handoff Discipline §Anti-patterns.

### §8 — SHA attribution (merge vs squash)

**Observed**: Sprint 13 PR cluster (8 PRs squash-merged) — squash creates new SHA that differs from PR head. Issue Closes-anchor fires on squash SHA, not PR head.

**Pattern**: Closes-anchor traces the squash merge commit, not the PR head. Documentation must reference squash SHA, not PR head SHA.

**Doctrine needed**: Close-out docs (e.g., Sprint 13 close.md) reference squash merge SHAs, not PR head SHAs. d054 §Closes-anchor strict format d-test codifies this.

**Cross-ref**: Issue #468 (d054 carrier), ADR-0050 §C9 strict format.

### §9 — Merge-count arithmetic (RETRO-008 candidate)

**Observed**: Sprint 13 close.md §PR ledger needs merge-count = 8 (squash-merged). Issue auto-close count = 7 (Issues #463-471 + Issue #480, all Closes-anchored).

**Pattern**: PR count ≠ Issue count. Each PR closes 0, 1, or 2 issues typically. Owner-squash merges add to PR ledger; Closes-anchored issues auto-close separately.

**Doctrine needed**: PM close.md must track both PR ledger and Issue auto-close separately. Sprint 13: 8 PRs / 7 Issues closed.

**Cross-ref**: Sprint 13 close.md §PR ledger, ADR-0050 C9 (Closes-anchor).

### §10 — Peer label discipline (BUG-3 sister-pattern)

**Observed**: BUG-3 (Sprint 11) — tester `cc:human` left on after signoff. Sister-pattern observed in Sprint 13 with PM `cc:tester` left on PM lane PR.

**Pattern**: After completing peer action, agent must remove own cc:* label AND forward to next peer.

**Doctrine needed**: §Handoff Discipline — atomic 4-flag flip (add new agent + cc, remove old cc + agent) is mandatory. Anti-pattern: leave cc:* on after action.

**Cross-ref**: ADR-0015, Issue #430, BUG-3 (Sprint 11).

## Tier 3 — Sprint 15+ backlog (2)

### §11 — d-test persistence

**Observed**: d-test scripts (d046, d048, d050b, d051, d052, d053, d054) added across sprints — no centralized registry of which test guards which invariant.

**Pattern**: d-test proliferation makes auditing gap-coverage hard. Need registry/index.

**Doctrine needed**: `scripts/tests/INDEX.md` listing each d-test, its invariant, origin issue, sister-pattern references.

**Cross-ref**: scripts/tests/d046-d054, ADR-0049 (d-test framework).

### §12 — Owner squash boundary (RETRO-008 candidate)

**Observed**: Owner-squash creates authoritative main SHA. PM close.md must reference squash SHA, not PR head SHA. PR head SHA is ephemeral.

**Pattern**: Owner-squash = merge authority. PM close-out uses squash SHA. Issue Closes-anchor fires on squash SHA.

**Doctrine needed**: PM close-out procedure — always verify squash SHA via `gh pr view --json mergeCommit` post-merge. Do not trust PR head SHA.

**Cross-ref**: Sprint 13 close.md §PR ledger (squash SHAs only), ADR-0050 C9.

## Sprint 14 P0 carry-forwards

- d050b TC1 owner-implementable workflow file change (Sprint 13 P0 carry)
- d054 CI integration (Sprint 13 P1 #2 carry, owner territory)

## Sprint 14 P1 candidates (RETRO-008 Tier 1)

- §1 CI re-run race codification (d053 sister test)
- §2 Engine perf flake vs regression codification (Issue #329 confirmation — REFINE: 3-source evidence chain)
- §3 wip_overflow false positive fix (ADR-0038 Layer 2 spec)
- §4 Layer 5 race pattern codification
- §5 Peer-poke CI timing gap polish (ADR-0033 already merged)
- §13 Layer 5 type:docs CHANGES_REQUESTED tension (NEW — captured from PR #487 tester hold)

## Sprint 14 P2 candidates (RETRO-008 Tier 2)

- §6 Agent factual ground-truth drift extension (Issue #430 → issues)
- §7 stale_cc deadlock mitigation
- §8 SHA attribution d-test extension
- §9 Merge-count arithmetic d-test
- §10 Peer label discipline d-test (BUG-3 sister-pattern)

## Sprint 15+ backlog (RETRO-008 Tier 3)

- §11 d-test persistence (INDEX.md)
- §12 Owner squash boundary d-test

### §13 — Layer 5 type:docs CHANGES_REQUESTED tension (NEW, Sprint 14 codification)

**Observed (2026-06-27, PR #487)**: Layer 5 (ADR-0048) auto-adds `status:ready` when `cc:human` is added/removed on a PR. Tester posted `CHANGES_REQUESTED` verdict on PR #487 (hold for Issue #488 fix). Result: `status:ready` (Layer 5 auto-add) coexists with `CHANGES_REQUESTED` (tester human-NOT-merge signal) — **contradictory signals on the same PR**.

**Pattern**: ADR-0048 §Type-driven reviewer chain for `type:docs` PRs auto-promotes to `status:ready` on CI green + reviewer chain completion. But `CHANGES_REQUESTED` verdict from any peer should override the auto-promote — it's a human-NOT-merge signal.

**Doctrine needed**: Layer 5 should respect `CHANGES_REQUESTED` verdicts. When a peer (arch/dev/tester) posts `CHANGES_REQUESTED` on a `type:docs` PR, Layer 5 should flip `status:ready` → `status:in-review` (sister-pattern to arch+dev PR review state machine).

**Cross-ref**: ADR-0048 (Layer 5 reviewer chain), PR #487 (live evidence), [TEST→PM] verdict (Issue #488 hold), Issue #488 (resolved as flake per §2 3-source refinement).

**Sprint 14 P1 candidate** (arch lane): Layer 5 amendment to respect `CHANGES_REQUESTED` verdict on `type:docs` PRs.

## Cross-references

- RETRO-005 (Sprint 5 baseline)
- RETRO-006 (Sprint 6 baseline)
- RETRO-007 watchlist (9 entries, 6 closed in Sprint 13)
- ADR-0033 (dual-channel)
- ADR-0038 (Auto-Claim Protocol)
- ADR-0049 (behavioral workflow test framework)
- ADR-0050 (§Pre-merge 4-cat verification)
- Issue #463 (d053 carrier)
- Issue #468 (d054 carrier)
- Issue #470 (§Timing window carrier)
- Issue #471 (PM lane amendment carrier)
- Issue #480 (this retro dispatch)

— @product-manager, 2026-06-27T10:23+03:00, RETRO-008 §2 3-source refinement + §6 dev ground-truth drift instance + NEW §13 Layer 5 CHANGES_REQUESTED tension (Sprint 14 codification, Issue #488 doctrine-applied)