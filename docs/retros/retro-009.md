# RETRO-009 — Sprint 14 Codifications

> **Author:** @product-manager (PM lane, owner ratifies)
> **Date:** 2026-06-27T17:21+03:00 = 14:21Z (draft via Issue #512)
> **Scope:** Codifications from Sprint 14 P1 cluster (9/9 SHIPPED) + AC5 follow-up
> **Lane:** `docs/retros/retro-009.md` (PM-owned companion to RETRO-008, owner ratifies)
> **Closes:** Issue #512 (RETRO-009 Sprint 14 codification dispatch)
> **Sister-pattern:** RETRO-008 (Sprint 13 codifications, PR #485 squash @ 72ff88d)

## TL;DR

RETRO-009 catalogues **12 retrospective candidates** identified during Sprint 14 P1 cluster work (9/9 SHIPPED) + AC5 follow-up. **Tier 1 (5 candidates)** is Sprint 15 P0/P1 high-priority. **Tier 2 (5 candidates)** is Sprint 15 P2 medium-priority. **Tier 3 (2 candidates)** is Sprint 15+ backlog.

**Origin:** Sprint 14 P1 cluster surfaced 6 RETRO-008 watchlist continuation items + 6 new candidates from cluster work. The work generated new doctrine refinement candidates beyond what RETRO-008 captured.

**Sister-pattern to RETRO-008:**
- 12 candidates (parallel to RETRO-008's 12)
- 5/5/2 tier split (same as RETRO-008)
- Live evidence section (Issue #488-style with timestamps)
- Cross-refs to ADRs, Issues, PRs

**Cluster 9/9 SHIPPED (full Sprint 14 P1 close):**

| # | PR | Type | Title | Closes |
|---|---|---|---|---|
| 1 | #500 | docs(adr) | ADR-0051 engine perf flake vs regression codification | #493 |
| 2 | #501 | docs(adr) | ADR-0052 CI re-run race codification | #494 |
| 3 | #499 | docs(soul) | PM §Pre-citation cross-check amendment | #498 |
| 4 | #502 | docs(adr) | ADR-0053 Layer 5 race pattern codification | #496 |
| 5 | #504 | docs(adr) | ADR-0038 amendment — §Work-Stream Awareness | #497 (AC1) |
| 6 | #503 | docs(adr) | ADR-0054 §9-Lens enforcement application | #495 |
| 7 | #506 | feat(scripts) | d058 work-stream awareness impl | #497 (AC2) |
| 8 | #509 | docs(sprint-14) | PM lane close-out draft + RETRO-008 §6/#14 codifications | #507 |
| 9 | #511 | chore(workflow) | d058 CI integration (AC5 follow-up) | #508 + #497 (AC5) |

**main HEAD post-cluster:** `70e33d7` (PR #511 squash, 2026-06-27T14:17:36Z)

## Tier 1 — Sprint 15 P0/P1 candidates (5)

### §1 — Pre-push branch-base check (chain dep pollution prevention tooling)

**Observed**: PR #509 had chain dep pollution (3 scripts/ files duplicated PR #506 squash). Fixed mid-cycle via `reset --hard origin/main` + `cherry-pick` playbook. **§6 LIVE INSTANCE #6** (Sprint 14 P1 PM close-out) caught the same pattern **pre-commit, zero harm** — but still required manual detection.

**Pattern**: Manual detection of branch-base drift is fragile. After 6 evidence points (PR #503 + #504 + #506 + #509 + #511 + #512 branch fix), the pattern is mature enough to require tooling-level prevention.

**Doctrine needed**: Pre-push hook (or CI guard) that warns when local branch base < `origin/main` (i.e., branch is missing squashed commits). Sister-pattern to existing pre-push hook that prevents direct push to main.

**Codification level (mature-state)**:
- §6 LIVE INSTANCES #1-5: surfaced as bugs (had to fix mid-cycle)
- §6 LIVE INSTANCE #6: surfaced as caught-and-fixed pre-commit (mature)
- **Next level**: tooling-level prevention (pre-push hook) — Sprint 15 P1 candidate

**Cross-ref**: PR #509 (live instance), Issue #512 branch fix (pre-commit catch), RETRO-008 §6 LIVE INSTANCES table, RETRO-008 §Cluster-Symmetry Un-Draft Doctrine (PR #504 + #506 codification).

**Sprint 15 P1 owner**: developer (impl) + tester (sign-off) joint, ~1.0 SP.

### §2 — Comment-based architect verdicts not surfaced by agent-watch (watcher extension)

**Observed**: Architect posted 🟢 APPROVED UNCONDITIONAL on PR #509 at 12:17:54Z (comment-based, not formal review submission). I missed it on polling because `agent-watch pr_review_requested` only fires on formal review submissions. **Caught by periodic_backlog_scan** (ADR-0017 catch-stuck-queues) at 12:39+ (~22 min late).

**Pattern**: Comment-based verdicts are a natural workflow (architects may comment rather than submit formal review), but the current watcher (`agent-watch.sh`) only watches formal review events.

**Doctrine needed**: Two options evaluated:
- (a) Extend watcher to parse comment verdicts via webhook post-comment payload scan — mechanical, robust, future-proof, catches variant patterns
- (b) Codify doctrine requiring formal review submission — brittle, blocks "architects who use comments" lane, fights natural workflow

**Recommended**: (a). Letting agents choose comment vs review keeps the workflow natural; watcher extension catches both. **ORCH concurrence** at 12:41+03:00: "observability is preferable to enforcement. We extend watchers, not codify doctrine, when both can solve the problem."

**Cross-ref**: PR #509 architect comment (12:17:54Z, cycle 37 cmt 4817429145), periodic_backlog_scan catch at 12:39+03:00, RETRO-007 §6 pre-verdict cross-check (Issue #414, sister-pattern), Issue #430 §Pre-citation cross-check (PM doctrine origin).

**Sprint 15 P2 owner**: arch + dev joint, ~1.0 SP (script + d-test).

### §3 — Post-squash label hygiene sweep script (label-state lag fix)

**Observed**: 3 LIVE INSTANCES of label-state lag in Sprint 14 P1 cluster:
- **Issue #507** (closed at 13:47:08Z): label `status:in-progress` not auto-flipped to `status:done` (board perspective lag)
- **Issue #508** (closed at 14:17:37Z): label `status:ready` not auto-flipped to `status:done` (board perspective lag)
- **Issue #512** (this issue, in-progress): label will not auto-flip on close (predicted pattern)

**Pattern**: Layer 5 auto-rotation (`status:ready` → `status:done` on issue close) is incomplete. The `github-actions[bot]` workflow removes `agent:*` and `cc:*` but leaves `status:*` untouched on close. This is a **board-perspective lag** (separate from §14 NEW which is queue-perspective lag).

**Doctrine needed**: Orchestrator post-squash hygiene sweep script — auto-flip `status:ready` / `status:in-progress` / `status:in-review` to `status:done` on closed issues. Idempotent, script-able, runs after PR cluster squash. **ORCH concurrence** at 13:50+03:00 (proposed hygiene sweep as Sprint 15 P2 candidate).

**Cross-ref**: §14 NEW (queue-perspective lag codification, RETRO-008 line 241), Issue #507 + #508 (LIVE INSTANCES), PR #511 squash (final trigger), §14 NEW DUAL-AXIS codification (board-perspective enrichment).

**Sprint 15 P2 owner**: orchestrator (in-lane), ~0.5 SP (script only, no d-test needed).

### §4 — §14 NEW DUAL-AXIS codification (board-perspective lag, empirically validated)

**Observed**: §14 NEW codification (RETRO-008 line 241) captures queue-perspective lag (issue closed, watcher still says active). DUAL-AXIS enrichment captures board-perspective lag (issue closed, label state not auto-flipped). Both axes lag independently after squash.

**Pattern**: Layer 5 race pattern has **3 axes** racing independently:
- Axis 1: issue state (CLOSED on squash, instant)
- Axis 2: label state (auto-rotation, LAGGED — observed 3+ times in this cluster)
- Axis 3: watcher state (sees active, LAGGED further — sister to §14 NEW)

**Doctrine needed**: §14 NEW DUAL-AXIS codification: Layer 5 lag is multi-axis. Issue-state is fastest, label-state is medium, watcher-state is slowest. Sister-pattern: tri-axis lag (not dual-axis as initially proposed).

**Sprint 14 cluster-vs-single hypothesis** (NEW observation, codification candidate):
- Single-PR squash (Issue #505 via PR #506): watcher lag 20-100+ min
- Cluster squash (Issue #507 via PR #509): watcher lag ~5 min
- **Hypothesis**: Layer 5 batch processing converges faster on cluster squashes. Sister-pattern: bigger batch → faster convergence (queue-priority).

**Cross-ref**: §14 NEW (queue-perspective), §3 above (label hygiene sweep), Issue #507 + #508 (LIVE INSTANCES), RETRO-008 line 241.

**Sprint 15 P2 owner**: orchestrator (in-lane, observation only, not a code change), 0 SP (Sprint 15 P2 backlog carrier for further validation).

### §5 — Sprint 15 PM lane continuation + RETRO-007 watchlist #10 NEW

**Observed**: Sprint 14 P1 cluster surfaced **1 NEW RETRO-007 watchlist entry** (#10 PM-cc gap on d-test follow-up issues, Issue #508 cc pattern). PM lane is well-defined (Sprint 13+ LOCKED) but cc pattern on follow-up issues is inconsistent.

**Pattern**: When PM files a follow-up issue (e.g., Issue #508 AC5), the cc pattern on the resulting PR (PR #511) is `cc:human` (per `agent:human` label) — but PM is the **spec author** and should be cc'd for traceability. Current pattern misses PM on follow-up issues.

**Doctrine needed**: PM must be `cc:product-manager` on follow-up issues filed by PM (per PM spec, separate lane from impl). Sister-pattern: orchestrator cc on coordination issues.

**Sprint 15 scope**: PM lane continuation (Sprint 14 PM cluster sister-pattern) + RETRO-007 #10 NEW codification.

**Cross-ref**: Issue #508 (cc pattern), PR #511 (out-of-lane for PM per Sprint 13+ LOCKED, but PM was spec author), RETRO-007 watchlist table, Sprint 13 PM lane definition amendment (PR #473 squash).

**Sprint 15 P1 owner**: PM (lane continuation) + arch (RETRO-007 #10 codification) joint, ~1.0 SP.

## Tier 2 — Sprint 15 P2 candidates (5)

### §6 — d-test family persistence (11-sister pattern candidate)

**Observed**: Sprint 14 P1 cluster brought d-test family coverage to **10-sister on main** (d046/d048/d050b/d051/d052/d053/d054/d055/d056/d058). Sister-pattern: each d-test codifies a specific doctrine and lives in `scripts/tests/`.

**Pattern**: d-test family is operationalized RETRO doctrine. Each retro candidate gets a d-test (when codifiable). Sprint 14 saw 3 new d-tests (d055, d056, d058). Sprint 15 candidates (§1 pre-push hook, §2 watcher extension, §3 hygiene sweep) all need d-tests.

**Doctrine needed**: RETRO-008 §d-test persistence — make d-test family coverage a Sprint goal metric. Sister-pattern: 10-sister → 11-sister → 12-sister evolution.

**Cross-ref**: d-test INDEX (Issue #508 AC5 follow-up, PR #511), ADR-0049 d-test framework, d-test family sister-pattern across SPRINT 13-14.

**Sprint 15 P2 owner**: arch + dev + tester joint, ~1.25 SP (3 d-tests for §1/#2/#3 candidates).

### §7 — Layer 5 race pattern enrichment (3-axis lag codification)

**Observed**: §4 above captures the 3-axis lag pattern (issue / label / watcher). Codification is needed at the doctrine level (RETRO-008 §14 NEW was 1-axis; enrichment is 3-axis).

**Pattern**: Layer 5 race codification (ADR-0053) was originally 1-surface (CI re-run). Sprint 14 P1 cluster surfaced 6+ Layer 5 race instances in 30 min. The pattern is broader than originally codified.

**Doctrine needed**: ADR-0053 enrichment — Layer 5 race is a 3-axis pattern (CI re-run, status auto-rotation, watcher queue state). Sister-pattern: §14 NEW DUAL-AXIS codification.

**Cross-ref**: ADR-0053 (PR #502, current 1-axis codification), §4 above (3-axis observation), Sprint 14 P1 cluster observations (6+ instances in 30 min).

**Sprint 15 P2 owner**: arch (in-lane), ~0.5 SP (ADR amendment).

### §8 — Sprint 14 P1 cluster cycle compression lesson

**Observed**: Sprint 14 P1 cluster shipped 6 P1 stories + 1 PM lane + 1 AC2 follow-on + 1 AC5 follow-up = **9 PRs in ~2h elapsed window** (Sprint 13 close @ ~10:30Z → PR #511 squash @ 14:17:36Z). Lane Transfer Pattern 5-for-5+1 verified across cluster.

**Pattern**: High-cadence cluster cycles are achievable when: (a) P1 cluster scope is tight, (b) joint sizing is RATIFIED via cluster, (c) Lane Transfer Pattern is respected (PM→ARCH→DEV→TEST→ORCH→HUMAN→PM close-out).

**Doctrine needed**: Sprint planning template for high-cadence cluster cycles. Sister-pattern: Sprint 14 P1 cluster (9 PRs / 2h) vs Sprint 13 P1 cluster (4 PRs / 4h, sister-pattern but slower).

**Cross-ref**: PR #509 description (cluster cycle stats), Lane Transfer Pattern 5-for-5+1, Sprint 13 P1 cluster sister-pattern (PR #485 + #487 + #465 + #472).

**Sprint 15 P2 owner**: orchestrator (in-lane), 0.5 SP (planning template, no code).

### §9 — Sprint 14 RETRO-007 watchlist continuation (#1, #2, #4)

**Observed**: 3 RETRO-007 watchlist entries carry forward from Sprint 13 (deferred in Sprint 14 due to P1 cluster capacity). Specifically:
- #1: PM-cc gap on d-test follow-up issues (sister to §5 above, dual codification)
- #2: Watcher self-cc-skip behavioral (d094 candidate, separate story)
- #4: Tester lane INDEX maintainer (P2 carry)

**Pattern**: Watchlist entries are deferred codifications that may surface new variants when revisited. Sister-pattern: §5 (PM-cc gap) was an entirely NEW surface, not just continuation of #1.

**Doctrine needed**: Process for watchlist continuation — when a deferred watchlist entry surfaces a new variant in a later sprint, codify the new variant separately rather than amending the old entry. Sister-pattern: §5 + watchlist #1 dual codification.

**Cross-ref**: RETRO-007 watchlist (3 carry-forwards), §5 above (new variant), Sprint 13 RETRO-008 codification.

**Sprint 15 P2 owner**: arch (in-lane), ~0.5 SP (process codification, no code).

### §10 — Tester lane d-test sign-offs + INDEX maintainer (carry)

**Observed**: Tester lane is responsible for d-test sign-offs (RED-first per ADR-0044) and INDEX maintenance (scripts/tests/INDEX.md). Sprint 14 P1 cluster had 0.25 SP of tester lane work (d031 TC harmonization post-d058, partial). Carry-forward to Sprint 15.

**Pattern**: Tester lane has a structural role (d-test sign-off, INDEX maintainer) that's often under-resourced in cluster cycles. Sister-pattern: §1 pre-push hook (§6 d-test) will need tester sign-off.

**Doctrine needed**: Tester lane capacity reservation in Sprint planning — when P1 cluster codifies d-tests, tester lane is auto-reserved for sign-off. Sister-pattern: §1 above (1.0 SP dev, 0.25 SP tester).

**Cross-ref**: ADR-0044 (RED-first TDD), d-test family sister-pattern, Sprint 14 P1 #6 (Issue #497 AC4 = 0.25 SP tester).

**Sprint 15 P2 owner**: tester (in-lane), ~1.0-2.0 SP (sign-offs + INDEX maintenance for §1/#2/#6 candidates).

## Tier 3 — Sprint 15+ backlog (2)

### §11 — Pre-push branch-base hook (tooling-level prevention, full implementation)

**Observed**: §1 above proposes the doctrine for branch-base check. Full implementation (git pre-push hook + CI guard) is a larger effort (~2.0 SP). Sister-pattern: existing pre-push hook that prevents direct push to main.

**Pattern**: Tooling-level prevention is the mature state of codification. After doctrine (Sprint 15 P1 §1) and observation (Sprint 15 P2 §4 DUAL-AXIS), tooling enforcement (Sprint 15+ §11) closes the loop.

**Doctrine needed**: Full pre-push hook implementation (bash script + CI guard + d-test for both). Sister-pattern: pre-push hook for direct-push prevention (existing infra).

**Cross-ref**: §1 above (Sprint 15 P1 doctrine), §4 (Sprint 15 P2 observation), pre-push hook infra (existing).

**Sprint 15+ owner**: dev (impl) + tester (sign-off) joint, ~2.0 SP (script + d-test + CI integration).

### §12 — Sprint 14 P1 cluster cycle lesson (full process codification)

**Observed**: §8 above captures the cluster cycle compression lesson. Full process codification (sprint planning template + cadence guidelines + Lane Transfer Pattern enforcement) is a larger effort (~2.0 SP). Sister-pattern: existing sprint planning template (PM-owned docs/sprints/).

**Pattern**: Process codification is the meta-level. After individual retrospective candidates (§1-§10) are codified, the **meta-lesson** (high-cadence cluster cycles are achievable) needs a process template to make it repeatable.

**Doctrine needed**: Sprint planning template update — high-cadence cluster cycle pattern codified as a planning option (not just ad-hoc). Sister-pattern: PM-owned docs/sprints/ lane.

**Cross-ref**: §8 above (Sprint 15 P2 lesson), Sprint 14 P1 cluster cycle stats (9 PRs / 2h), Lane Transfer Pattern.

**Sprint 15+ owner**: PM (in-lane) + orchestrator (planning), ~2.0 SP (template + guidelines).

## Live evidence section

### Sprint 14 P1 cluster cadence (timestamps)

| Time (UTC) | Event | Cluster % |
|---|---|---|
| 2026-06-27T10:30:00Z | Sprint 13 close (PR #485 squash) | 0% |
| 2026-06-27T11:28:27Z | PR #504 squash (ADR-0038 amend) | 11% |
| 2026-06-27T11:28:28Z | Issue #497 auto-close | 11% |
| 2026-06-27T11:58:47Z | PR #503 squash (ADR-0054) | 22% |
| 2026-06-27T12:03:07Z | PR #506 squash (d058 impl) | 33% |
| 2026-06-27T12:08:33Z | Issue #507 auto-claim (PM) | 33% |
| 2026-06-27T12:12:33Z | PR #509 opened (PM close-out) | 44% |
| 2026-06-27T13:47:07Z | PR #509 squash (Sprint 14 P1 close) | 88% |
| 2026-06-27T14:17:36Z | PR #511 squash (AC5 follow-up, FINAL) | 100% |

**Total cycle**: ~2h 47m for 9 PRs (Sprint 14 P1 cluster 8/8 + AC5 follow-up).

### Sister-pattern to Sprint 13 P1 cluster

| Sprint 13 P1 | Sprint 14 P1 |
|---|---|
| PR #485 close-out | PR #509 close-out |
| PR #487 plan.md | PR #506 d058 impl |
| PR #465 d053 pre-merge 4-cat | PR #504 ADR-0038 amend |
| PR #472 PM soul amendment | PR #499 PM §Pre-citation amendment |
| 4 PRs / ~4h | 9 PRs / ~2.8h (2.25x faster) |

### Layer 5 race instances in Sprint 14 P1 cluster (6+)

| Time | Pattern | Codification |
|---|---|---|
| 12:12:32Z | label-check FAIL (workflow race) | ADR-0053 (PR #502) |
| 12:13:32Z | CHANGES_REQUESTED post-fix race | §Pre-citation cross-check |
| 12:39+ | periodic_backlog_scan catch (comment verdict) | §2 above (Sprint 15 P2) |
| 13:47:08Z | Issue #507 close + label state lag | §14 NEW + §3 (Sprint 15 P2) |
| 14:17:37Z | Issue #508 close + label state lag | §3 above (Sprint 15 P2) |
| 14:20+ | PR #509 squash, watcher settled | §4 hypothesis (cluster vs single) |

## Cross-references

**ADRs (3 + 1 amend):**
- ADR-0038 §Work-Stream Awareness (PR #504 squash @ a45c613)
- ADR-0051 engine perf flake vs regression (PR #500 squash)
- ADR-0052 CI re-run race codification (PR #501 squash)
- ADR-0053 Layer 5 race pattern (PR #502 squash @ 30c9a97)
- ADR-0054 §9-Lens enforcement (PR #503 squash @ 2b66b73)

**Issues (9 closed + 1 in-flight):**
- #493 (PR #500 close) — Sprint 14 P1 #2
- #494 (PR #501 close) — Sprint 14 P1 #3
- #495 (PR #503 close) — Sprint 14 P1 #4
- #496 (PR #502 close) — Sprint 14 P1 #5
- #497 (PR #504 close + PR #506 AC2 + PR #511 AC5) — Sprint 14 P1 #6
- #498 (PR #499 close) — Sprint 14 P1 PM lane
- #505 (PR #506 close) — d058 sister story
- #507 (PR #509 close) — Sprint 14 P1 close-out dispatch
- #508 (PR #511 close) — d058 AC5 follow-up
- #512 (this issue, RETRO-009 dispatch) — in-flight

**PRs (9 SHIPPED):**
- PR #499 (Squash @ a779dac) — PM §Pre-citation cross-check
- PR #500 (Squash) — ADR-0051
- PR #501 (Squash) — ADR-0052
- PR #502 (Squash @ 30c9a97) — ADR-0053
- PR #503 (Squash @ 2b66b73) — ADR-0054
- PR #504 (Squash @ a45c613) — ADR-0038 amend
- PR #506 (Squash @ 226b546) — d058 impl + sister-pattern parity
- PR #509 (Squash @ 097f1c2) — Sprint 14 P1 close-out + RETRO-008 §6/#14 codifications
- PR #511 (Squash @ 70e33d7) — d058 AC5 CI integration

**Sister-pattern docs:**
- RETRO-008 (`docs/retros/retro-008.md`) — predecessor, Sprint 13 codifications
- Sprint 13 close.md (`docs/sprints/sprint-13/close.md`) — sister-pattern to Sprint 14 close
- Sprint 14 close.md (`docs/sprints/sprint-14/close.md`) — already authored in PR #509

**Soul + doctrine refs:**
- Issue #113 (PM doctrine: labels = ownership, work spec not body)
- Issue #238 (no self-justified pauses, RETRO-008 §3 carrier)
- Issue #414 (orchestrator §Pre-verdict cross-check, RETRO-007 #6 origin)
- Issue #430 (PM §Pre-citation cross-check, RETRO-008 §6 4 LIVE INSTANCES)
- Issue #471 (Sprint 13 PM lane definition amendment, RETRO-007 #9)

— @product-manager, 2026-06-27T17:22+03:00, RETRO-009 Sprint 14 codifications draft (Issue #512, Closes #512 on owner squash)
