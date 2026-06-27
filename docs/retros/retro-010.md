# RETRO-010 — Sprint 15 Codifications

> **Author:** @product-manager (PM lane, owner ratifies)
> **Date:** 2026-06-27T22:59+03:00 = 19:59Z (draft via Issue #533 close-out + orchestrator PICKUP-38)
> **Scope:** Codifications from Sprint 15 sequential chain + Sprint 15 P1 doctrine hardening candidates for Sprint 16 P1 workshop
> **Lane:** `docs/retros/retro-010.md` (PM-owned companion to RETRO-009, owner ratifies)
> **Sister-pattern:** RETRO-009 (Sprint 14 codifications, on main via PR #513 squash @ ebf6bc8)
> **Stub→real transition**: PR #543 (forward-ratification at owner squash gate) shipped stub for forward reference resolution; this draft replaces stub with real Sprint 15 codifications

## TL;DR

RETRO-010 catalogues **12 retrospective candidates** identified during Sprint 15 sequential chain (PR #536 → #541 → #544 → #545 → #547) + Issue #533 close-out. **Tier 1 (7 candidates)** is Sprint 16 P1 doctrine hardening workshop scope. **Tier 2 (3 candidates)** is Sprint 16 P2 medium-priority. **Tier 3 (2 candidates)** is Sprint 17+ backlog.

**Origin**: Sprint 15 cluster surfaced 6 RETRO-009 watchlist continuation items (d-test family 11-sister → 13-sister, post-squash label hygiene, pre-push branch-base check) + 6 NEW candidates from Sprint 15 doctrine hardening observation (RETRO-010 #17/#18/#19/#26/#27/#32/#33/#34 NEW family).

**Sister-pattern to RETRO-009**:
- 12 candidates (parallel to RETRO-009's 12)
- 7/3/2 tier split (heavier Tier 1 than RETRO-009's 5/5/2, reflecting Sprint 16 P1 doctrine hardening workshop scope per owner directive)
- Live evidence section (Issue #533-style with timestamps)
- Cross-refs to ADRs, Issues, PRs

**Cluster 11/15 SHIPPED + 1 in-review (PR #547) + 3 owner-squash-gate:**

| # | PR | Type | Title | Closes |
|---|---|---|---|---|
| 1 | #528 | feat(scripts) | STORY-016 pre-push branch-base check + d060 d-test | #517 |
| 2 | #530 | feat(scripts) | STORY-017 post-squash label hygiene sweep + d061 d-test | #518 |
| 3 | #536 | feat(scripts) | STORY-022 d059 d-test family persistence (11-sister carrier) | #523 |
| 4 | #541 | refactor(scripts) | d046×3 file rename — d046 → d046a/d046b/d046c | #539 (AC1+AC3) |
| 5 | #544 | refactor(scripts) | d059 TC5 STRICT INVARIANT — drop acknowledged_collisions map | #539 (AC2) |
| 6 | #545 | chore(scripts) | retire d031 stub (Issue #537 AC1+AC2, arch 🟢 Option B verdict) | #537 (AC1+AC2) |
| 7 | #547 | docs(retro) | RETRO-009 §6 drift home FIXED — d031×2 (PR #545) + d046×3 (PR #541) | #537 (AC4) |

**main HEAD post-cluster:** `e8ff51a` (PR #545 squash, 2026-06-27T19:45:45Z)

## Tier 1 — Sprint 16 P1 doctrine hardening workshop candidates (7)

### §17 — Orch issue-count vs work-stream-count drift (RETRO-010 #17 NEW)

**Observed**: Orchestrator reported "1/2" dev WIP based on issue count, but per ADR-0038 §Work-Stream Awareness (PR #504 squash @ a45c613), work-stream = 1 slot regardless of issue count. Dev confirmed: 2 in_progress issues in 2 separate work-streams = 2/2 (NOT 1/2). Tester correction validated by dev (Issue #533 close-out).

**Pattern**: Layer 2 pre-amendment behavior (legacy WIP cap, issue-count) vs Layer 5 post-amendment behavior (ADR-0038 §Work-Stream Awareness, work-stream-count). Layer 5 supersedes Layer 2 for WIP accounting — but orchestrator watcher may still report Layer 2 numbers.

**Doctrine needed**: ADR-0038 enforcement application — orchestrator `WIP` reporting must use work-stream-count, not issue-count. Sister-pattern to RETRO-007 #6 (cross-peer consensus miss).

**Cross-ref**: PR #504 squash @ a45c613 (ADR-0038 §Work-Stream Awareness amendment), PR #506 (d058 impl doctrinal anchor), PR #528 squash (d060 impl first live test), Issue #533 close-out comments, RETRO-009 §6 (sister-pattern lineage).

**Sprint 16 P1 owner**: orchestrator (in-lane, watcher update) + arch (ADR amendment), ~0.25 SP.

### §18 — Stub vs functional-impl sub-pattern (RETRO-010 #18 NEW)

**Observed**: Sprint 15 §6 drift home surfaced TWO distinct d-test ID-collision patterns with DIFFERENT resolutions:
- **d031×2** = 1 impl + 1 stub → **delete** the stub (arch Option B verdict, simplest)
- **d046×3** = 3 functional impls → **rename** to d046a/b/c (Cadence Rule 1 atomic, preserves work)

PR #547 §6 explicitly framed this distinction as "ready for Sprint 16 retro (RETRO-010)" — sub-pattern codification candidate mature for Sprint 16 retro per arch verdict (cmt 4820973931).

**Pattern**: ADR-0049 §ID uniqueness invariant has a single rule (1 ID ↔ exactly 1 file) but multiple remediation paths depending on sub-pattern:
- Sub-pattern A: 1 impl + 1 stub (legacy shadowed) → delete stub
- Sub-pattern B: N functional impls (genuine work) → rename
- Sub-pattern C: N+M mixed → evaluate per-case (arch lane decision)

**Doctrine needed**: ADR-0049 amendment — add §Sub-pattern remediation matrix (sub-pattern A → delete; sub-pattern B → rename; sub-pattern C → arch lane decision). Sister-pattern to RETRO-009 §6 lineage.

**Cross-ref**: PR #547 (RETRO-009 §6 cross-ref, sub-pattern codification paragraph), PR #545 (d031 stub retire, sub-pattern A), PR #541 (d046×3 rename, sub-pattern B), ADR-0049 (current 1-rule codification), arch verdict cmt 4820973931 (promotion-lane confirmation).

**Sprint 16 P1 owner**: arch (in-lane, ADR amendment), ~0.25 SP.

### §19 — Timing window refinements (RETRO-010 #19 NEW)

**Observed**: §Pre-verdict cross-check timing window doctrine (Issue #430, RETRO-007 #6) currently says "within 30s of verdict post". Sprint 15 cluster surfaced edge cases where 30s is too tight (arch re-query after PM amend takes 60-90s) or too loose (immediate post-verdict gap misses peer cmt propagation).

**Pattern**: Single fixed window is fragile. Refinement options:
- (a) Variable window per peer (arch: 60s, tester: 30s, PM: 45s) — Lane-specific timing
- (b) Adaptive window based on CI check state — wait for COMPLETED before re-query
- (c) Event-driven re-query (webhook on peer comment + label_change) — replaces polling

**Doctrine needed**: ADR-0045 §9-Lens step 4 amendment (CI re-query + COMPLETED-wait gate, sister-pattern to Issue #430 §Pre-citation cross-check) + Issue #430 §Pre-verdict cross-check timing window refinement. Owner of refinement: arch lane (9-Lens home).

**Cross-ref**: Issue #430 (PM §Pre-citation cross-check), RETRO-007 #6 (timing window origin), PR #513 §Dispatch Discipline catch (arch 🟢 verdict posted while Lint & Test IN_PROGRESS, FAILED ~10s later), PR #547 cycle 192 arch verdict (CI re-query within 30s window verified).

**Sprint 16 P1 owner**: arch (in-lane, 9-Lens amendment) + PM (Issue #430 refinement), ~0.5 SP.

### §26 — Tester observation candidate (RETRO-010 #26 NEW, detail pending)

**Observed**: Tester surfaced candidate during Issue #533 close-out (per orchestrator PICKUP-38 dispatch). Full detail pending tester-side issue creation.

**Doctrine needed**: TBD per tester lane observation. Sister-pattern to other RETRO-010 candidates (observation-driven codification).

**Cross-ref**: Issue #533 close-out comments (tester observation carrier), orchestrator PICKUP-38 dispatch.

**Sprint 16 P1 owner**: tester (in-lane, observation), arch (codification), ~0.25 SP (detail pending).

### §27 — Tester observation candidate (RETRO-010 #27 NEW, detail pending)

**Observed**: Tester surfaced candidate during Issue #533 close-out (per orchestrator PICKUP-38 dispatch). Full detail pending tester-side issue creation.

**Doctrine needed**: TBD per tester lane observation.

**Cross-ref**: Issue #533 close-out comments, orchestrator PICKUP-38 dispatch.

**Sprint 16 P1 owner**: tester (in-lane, observation), arch (codification), ~0.25 SP (detail pending).

### §32 — Label-check Layer 5 DELETE 404 flake (RETRO-010 #32 NEW, 6 LIVE INSTANCES)

**Observed**: Sprint 15 cluster surfaced 6 LIVE INSTANCES of `label-check` workflow firing with HTTP 404 on `DELETE /repos/:owner/:repo>/issues/:issue_number>/labels/:name` (label not found). Bot retries, eventually succeeds — but logs 404 noise and confuses auto-watcher.

**Pattern**: Layer 5 race between label-remove (bot cascade-strip) and label-check (validation workflow) — DELETE fires before label exists, returns 404. Self-correcting but noisy.

**Doctrine needed**: ADR-0012 §Label Check workflow amendment — handle 404 as idempotent success (label already absent = goal achieved, not failure). Sister-pattern to ADR-0053 §Layer 5 race pattern.

**Cross-ref**: 6 LIVE INSTANCES across Sprint 15 cluster (PR #528 + #530 + #536 + #541 + #544 + #545 cycles), ADR-0012 (current 4-cat invariant validation), ADR-0053 (Layer 5 race sister-pattern).

**Sprint 16 P1 owner**: arch (in-lane, ADR amendment) + dev (workflow YAML fix gated on owner per ADR-0031), ~0.5 SP.

### §33 — Closes-anchor over-aggression (RETRO-010 #33 NEW, 3 variants)

**Observed**: Sprint 15 cluster surfaced 3 distinct Closes-anchor false-positive variants:
- Variant A (original): Issue auto-closes on PR with "Closes #N" in body even when ACs not all done (Issue #537 premature close via PR #541 cross-ref-only mention)
- Variant B (dev pre-staging): PR opened with "Closes #N" before ACs done, force-closes Issue prematurely
- Variant C (PM prose-anchor): "sister-pattern to #N" mentioned in PR body triggers false-positive Closes

**Pattern**: Closes-anchor is too aggressive. Body-text scanning is too permissive. Need stricter matching (exact "Closes #N" line + AC verification gate).

**Doctrine needed**: ADR amendment — Closes-anchor strict-format gate (exact line match + AC verification before issue close). Sister-pattern to ADR-0050 §C9 (pre-merge 4-cat verification).

**Cross-ref**: Issue #537 (Variant A LIVE INSTANCE, premature close @ 19:09:37Z via PR #541 squash), Issue #539 (Variant B LIVE INSTANCE, dev pre-staging), PR #547 (Variant C prose-anchor trap), RETRO-010 #34 NEW (sister-pattern cascade family).

**Sprint 16 P1 owner**: arch (in-lane, ADR amendment) + dev (workflow YAML fix gated on owner per ADR-0031), ~0.75 SP.

### §34 — Auto-cascade self-reversal pattern (RETRO-010 #34 NEW, 5-bug family)

**Observed**: Sprint 15 cluster surfaced 5 distinct Layer 5 auto-cascade bug patterns (EXTENSION v3, per Issue #546):
- Bug #1: cascade on verdict (PR #545 arch verdict path) — CASCADE #1 self-reversed
- Bug #2: cascade on verdict (PR #545 arch verdict path, sister-pattern) — CASCADE #2 self-reversed
- Bug #3: cascade on verdict (PR #545 arch verdict path, sister-pattern) — self-reversed
- Bug #4: cascade on comment (PR #545 tester cmt path) — self-reversed
- **Bug #5 (NEW): cascade on PR-open with peer cc:* labels + subsequent cc:* removal (PR #547 PM-open path, PM observation cmt 4820945747)** — `pull_request_target` event, action=`unlabeled`, label=`cc:tester` triggered status:ready auto-add

**Pattern**: Layer 5 auto-cascade (`status:*` auto-rotation on `pull_request_target` events) is overly aggressive. Multiple trigger paths fire status:ready auto-add WITHOUT dual-🟢 verdict verification. Self-corrects (label-check FAIL + SUCCESS recovery) but creates transient state divergence.

**Doctrine needed**: ADR amendment — Layer 5 cascade gate (require dual-🟢 verdict before status:ready auto-add, suppress cascade on PR-open with peer cc:* labels only). Owner merge required for workflow YAML fix per ADR-0031.

**Cross-ref**: Issue #546 (RETRO-010 #34 NEW, P1, arch-owned, EXTENSION v3 cmt 4820978334), PR #545 (Bug #1-3 LIVE INSTANCES), PR #547 (Bug #5 LIVE INSTANCE, PM observation), ADR-0053 (Layer 5 race pattern sister-pattern), RETRO-010 #33 NEW (Closes-anchor over-aggression sister-pattern).

**Sprint 16 P1 owner**: arch (in-lane, ADR amendment + Issue #546) + dev (workflow YAML fix gated on owner per ADR-0031), ~1.0 SP.

## Tier 2 — Sprint 16 P2 candidates (3)

### §6b — CI backfill d015+d031 (RETRO-009 §6b continuation)

**Observed**: Sprint 15 cluster resolved d031×2 + d046×3 (RETRO-009 §6 drift home). Sprint 14 cluster resolved d058 work-stream awareness (RETRO-009 §6a). Remaining: d015 (pre-existing) + d031 (now sole d031 file, post-#545 squash) need CI backfill per ADR-0049 §d-test framework.

**Pattern**: d-test family expansion requires CI backfill when files are added/removed. Sister-pattern to d058 CI integration (PR #511).

**Doctrine needed**: CI backfill script — auto-detect new d-test files on main, run d-test on PR cluster squash. Owner merge required for workflow YAML fix per ADR-0031.

**Cross-ref**: d015 (legacy), d031 (post-#545, sole file), PR #511 (d058 CI integration sister-pattern), ADR-0049.

**Sprint 16 P2 owner**: dev (in-lane, workflow YAML fix gated on owner per ADR-0031) + tester (sign-off), ~1.0 SP.

### §14 — §14 NEW option (a) — arch spec filed-for-grooming (RETRO-009 §14 continuation)

**Observed**: Sprint 14 §14 NEW (RETRO-008 line 241) codifies queue-perspective lag. Sprint 15 §4 enriched to 3-axis lag (RETRO-009 §4). Sprint 16 option (a) — arch spec filed-for-grooming for tooling-level prevention (Sprint 15 deferred candidate).

**Pattern**: Codification → observation → tooling enforcement is a 3-stage ladder. Sprint 14-15 captured stages 1-2. Stage 3 (tooling) is Sprint 16+ backlog.

**Doctrine needed**: §14 NEW option (a) — arch spec for tooling-level prevention of all 3 axes. Sister-pattern to RETRO-009 §11 (pre-push branch-base hook tooling).

**Cross-ref**: RETRO-008 line 241, RETRO-009 §4 (3-axis enrichment), RETRO-009 §11 (tooling-level sister-pattern).

**Sprint 16 P2 owner**: arch (in-lane, spec) + dev (impl, Sprint 17+) + tester (sign-off), ~0.5 SP spec only.

### §35 — d059b post-squash label hygiene companion (Sprint 15 P2 candidate deferred)

**Observed**: Sprint 15 d059 d-test variant (b) post-squash label hygiene companion was deferred from Sprint 15 P2 to Sprint 16+ per Sprint 15 workshop decision (variant (a) chain dep pollution companion selected instead).

**Pattern**: d-test family expansion follows a 2-variant pattern (variant A + variant B). Sprint 15 chose A. Sprint 16 may pick up B if pattern matures.

**Doctrine needed**: d059b impl — variant B post-squash label hygiene d-test (sister-pattern to d061 already impl'd in PR #530).

**Cross-ref**: PR #530 (d061 impl, variant B already shipped for post-squash hygiene via STORY-017), Issue #523 (Sprint 15 d059 variant selection), RETRO-009 §6 (d-test family).

**Sprint 16+ owner**: dev (impl) + tester (sign-off), ~1.25 SP.

## Tier 3 — Sprint 17+ backlog (2)

### §36 — Sprint 15 cluster-compression observation (RETRO-009 §8 enrichment)

**Observed**: Sprint 15 cluster shipped 7 PRs in ~3h elapsed window (PR #528 @ 18:14Z → PR #547 @ 19:55Z). Lane Transfer Pattern 5-for-5+1+1 verified (dev → tester → arch → orch → human → PM close-out → tester).

**Pattern**: High-cadence cluster cycles are repeatable. Sister-pattern to Sprint 14 P1 cluster (9 PRs / 2.8h) — Sprint 15 cluster was faster on some axes (single tester round vs Sprint 14's two-tester cluster).

**Doctrine needed**: Sprint planning template enrichment — cluster cycle stats tracking (PR count / elapsed / WIP cap / round-trips). Sister-pattern to RETRO-009 §8 (cluster compression lesson).

**Cross-ref**: PR #528 squash @ 18:14Z → PR #547 cycle 192 @ 19:55Z, RETRO-009 §8, Lane Transfer Pattern 5-for-5+1+1.

**Sprint 17+ owner**: orchestrator (in-lane, planning template) + PM (cadence observation), ~0.5 SP.

### §37 — RETRO-007 watchlist continuation (#10 NEW codification)

**Observed**: Sprint 15 PM cluster delivered STORY-018 (PR #529 at owner squash gate) — RETRO-007 watchlist entry #10 NEW codification (PM-cc gap on d-test follow-up issues, Issue #508 cc pattern).

**Pattern**: Watchlist continuation surfaces new variants. #10 NEW is PM-cc gap on follow-up issues. Sister-pattern to RETRO-007 #6 (timing window, 4 LIVE INSTANCES validated across PR #460/#462/#465/#472).

**Doctrine needed**: Watchlist entry #10 NEW codification finalized via PR #529 squash (PM lane, owner merge). Sister-pattern to RETRO-007 #6 (Issue #430 doctrine codification).

**Cross-ref**: PR #529 (Sprint 15 P1 #4, Closes #519), Issue #508 (cc pattern origin), RETRO-007 watchlist, Sprint 13 PR #473 (PM lane def amendment precedent).

**Sprint 17+ owner**: PM (in-lane, owner merge via PR #529), ~0.25 SP (codification only, no new work).

## Live evidence section

### Sprint 15 sequential chain cadence (timestamps)

| Time (UTC) | Event | Cluster % |
|---|---|---|
| 2026-06-27T18:14:00Z | PR #528 squash (STORY-016 pre-push branch-base check + d060) | 14% |
| 2026-06-27T18:30:00Z | PR #530 squash (STORY-017 post-squash label hygiene + d061) | 28% |
| 2026-06-27T19:09:36Z | PR #541 squash (d046×3 file rename — Issue #539 AC1+AC3) | 42% |
| 2026-06-27T19:27:54Z | PR #544 squash (d059 TC5 STRICT INVARIANT — Issue #539 AC2) | 57% |
| 2026-06-27T19:45:45Z | PR #545 squash (chore: retire d031 stub — Issue #537 AC1+AC2) | 71% |
| 2026-06-27T19:55:14Z | PR #547 PM-amend (RETRO-009 §6 drift home FIXED, AC4 docs) | 85% |
| 2026-06-27T19:56:17Z | Issue #537 closed (terminal hand-off, AC1+AC2+AC3+AC4 ✅) | 100% |

**Total cycle**: ~1h 42m for 6 PRs (Sprint 15 sequential chain).

### Sprint 15 sequential Option A lane discipline (validated 5/5)

| PR | Lane | Files | Squash SHA | Cluster % |
|---|---|---|---|---|
| #528 | dev | scripts/tests/d060* | 435b0ae | 14% |
| #530 | dev | scripts/tests/d061* + scripts/sweep-post-squash.sh | 7040a9a | 28% |
| #536 | dev | scripts/tests/d059-dtest-family-persistence.sh | 77acc1d | 42% |
| #541 | dev | scripts/tests/d046 → d046a/b/c rename | 6369633 | 57% |
| #544 | dev | scripts/tests/d059 (TC5 rebaseline) | 4b3b42c | 71% |
| #545 | dev | scripts/tests/d031 stub retire | e8ff51a | 85% |
| #547 | PM | docs/retros/retro-009.md §6 | (pending squash) | 100% |

All 7 PRs verified Option A discipline (sequential within parallel lane, no concurrent edits to same files). Sprint 15 cluster-symmetry doctrine held.

### Layer 5 race instances in Sprint 15 cluster (5+)

| Time | Pattern | Codification |
|---|---|---|
| 19:09:37Z | PR #541 squash, Issue #537 auto-close (Closes-anchor false-positive) | RETRO-010 #33 NEW Variant A |
| 19:45:45Z | PR #545 squash, Issue #537 cascade-strip | RETRO-010 #34 NEW Bug #1-3 |
| 19:53:21Z | PR #547 PM-open, status:in-review labeled | (PM author intent) |
| 19:53:29Z | PR #547 cascade-strip status:in-review (cc:tester removal) | RETRO-010 #34 NEW Bug #5 |
| 19:53:31Z | PR #547 auto-add status:ready (Layer 5 trigger, no dual-🟢) | RETRO-010 #34 NEW Bug #5 |

## Cross-references

**ADRs (referenced, 0 new in Sprint 15):**
- ADR-0038 §Work-Stream Awareness (PR #504 squash @ a45c613, Sprint 14 origin)
- ADR-0044 RED-first TDD (tester sign-off lane)
- ADR-0045 9-Lens Review Checklist (architectural verdicts)
- ADR-0049 §ID uniqueness invariant (d-test framework)
- ADR-0050 §C9 pre-merge 4-cat verification
- ADR-0053 Layer 5 race pattern (Sprint 14 origin)
- ADR-0054 §9-Lens enforcement application (Sprint 14 origin)

**Issues (Sprint 15 cluster, 3 closed + 5 in-scope):**
- #517 (PR #528 close) — STORY-016 pre-push branch-base check (Sprint 15 P1 #2)
- #518 (PR #530 close) — STORY-017 post-squash label hygiene (Sprint 15 P1 #3)
- #519 (PR #529 close pending) — STORY-018 §5 RETRO-007 #10 NEW (Sprint 15 P1 #4)
- #521 (PR #525 close pending) — arch-soul §9-Lens step 4 (Sprint 15 P1 #5)
- #522 (PR #526 close pending) — §4 §14 NEW observation carrier (Sprint 15 P2 #6)
- #523 (PR #536 close) — d059 d-test family persistence (Sprint 15 P2 #7)
- #524 (PR #532 close pending) — §10 tester lane INDEX maintainer (Sprint 15 P2 #9)
- #533 (closed) — batch d-test INDEX drift findings (Sprint 15 cluster)
- #535 (in-flight, agent:product-manager) — d055/d056 spec drift PM Option A (Sprint 16+ defer)
- #537 (closed) — d031×2 historical drift remediation
- #539 (closed) — d046×3 file rename (Issue #533 AC4 split-out)
- #546 (in-flight, agent:architect) — RETRO-010 #34 NEW EXTENSION v3 (Sprint 16 P1 doctrine hardening)

**PRs (Sprint 15 sequential chain):**
- PR #528 (Squash @ 435b0ae) — STORY-016 pre-push branch-base check + d060
- PR #530 (Squash @ 7040a9a) — STORY-017 post-squash label hygiene sweep + d061
- PR #536 (Squash @ 77acc1d) — STORY-022 d059 d-test family persistence
- PR #541 (Squash @ 6369633) — d046×3 file rename
- PR #544 (Squash @ 4b3b42c) — d059 TC5 STRICT INVARIANT
- PR #545 (Squash @ e8ff51a) — chore: retire d031 stub
- PR #547 (pending squash) — PM AC4 docs cross-ref

**Sister-pattern docs:**
- RETRO-009 (`docs/retros/retro-009.md`) — predecessor, Sprint 14 codifications
- RETRO-008 (`docs/retros/retro-008.md`) — Sprint 13 codifications (archived)
- Sprint 15 plan (`docs/sprints/sprint-15/plan.md`) — PM draft, joint sizing per ADR-0024
- Sprint 15 backlog (`docs/sprints/sprint-15/backlog.json`) — sister-pattern to Sprint 14
- Sprint 16 plan (`docs/sprints/sprint-16/plan.md`) — doctrine hardening, PM draft (PR #543 forward-ratification)
- Sprint 17 plan (`docs/sprints/sprint-17/plan.md`) — consolidated 17+18+19, PM draft (PR #543)
- Sprint 20 plan (`docs/sprints/sprint-20/plan.md`) — bug-only mode, PM draft (PR #543)

**Soul + doctrine refs:**
- Issue #113 (PM doctrine: labels = ownership, work spec not body)
- Issue #238 (no self-justified pauses, RETRO-008 §3 carrier)
- Issue #414 (orchestrator §Pre-verdict cross-check, RETRO-007 #6 origin)
- Issue #430 (PM §Pre-citation cross-check, RETRO-008 §6 4 LIVE INSTANCES)
- Issue #471 (Sprint 13 PM lane definition amendment, RETRO-007 #9)
- ADR-0012 4-cat invariant (type + status + agent + cc mandatory)
- ADR-0015 atomic 4-flag hand-off
- ADR-0031 continuous-flow mode (no fixed sprint boundaries)
- ADR-0033 dual-channel ping (notify.sh -w -r)
- ADR-0038 §Work-Stream Awareness + §Auto-Claim Protocol
- ADR-0044 RED-first TDD

— @product-manager, 2026-06-27T22:59+03:00, RETRO-010 Sprint 15 codifications draft (replaces PR #543 stub, sibling-publication candidate for Sprint 16 kickoff)