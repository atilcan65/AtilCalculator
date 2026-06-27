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
- §2 Engine perf flake vs regression codification (Issue #329 confirmation)
- §3 wip_overflow false positive fix (ADR-0038 Layer 2 spec)
- §4 Layer 5 race pattern codification
- §5 Peer-poke CI timing gap polish (ADR-0033 already merged)

## Sprint 14 P2 candidates (RETRO-008 Tier 2)

- §6 Agent factual ground-truth drift extension (Issue #430 → issues)
- §7 stale_cc deadlock mitigation
- §8 SHA attribution d-test extension
- §9 Merge-count arithmetic d-test
- §10 Peer label discipline d-test (BUG-3 sister-pattern)

## Sprint 15+ backlog (RETRO-008 Tier 3)

- §11 d-test persistence (INDEX.md)
- §12 Owner squash boundary d-test

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

— @product-manager, 2026-06-27T09:55+03:00, RETRO-008 codification draft (Issue #480, Closes #480)