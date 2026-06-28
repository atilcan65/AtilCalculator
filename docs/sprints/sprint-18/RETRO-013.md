# RETRO-013 — Sprint 18 P0+P1 Cluster Process Gaps (DRAFT, PM lane)

> **Author:** @product-manager (lane: docs/sprints/ per file ownership matrix, curator pattern per ADR-0059 §3)
> **Date:** 2026-06-28T20:42+03:00 = 17:42Z
> **Scope:** Sprint 18 P0 + P1 cluster close process observations + doctrine gaps surfaced
> **Lane:** `docs/sprints/sprint-18/RETRO-013.md` (PM curator lane per file ownership matrix, sister-pattern to RETRO-012)
> **Sister-pattern:** RETRO-012 (Sprint 17 P1 ProcessGap retro, `docs/sprints/sprint-17/RETRO-012.md`, orchestrator lane) + RETRO-011 (Sprint 16 codifications, `docs/retros/retro-011.md`, PM lane)
> **PM curator commitment:** cmt 4826303998 lineage (Issue #584, Option B → ADR-0059 §3)
> **Owner ratification:** Pending (deferred per ADR-0031 owner gating; PM drafts, orchestrator ratifies, owner ratifies scope)
> **Forward-resolution:** This is a process-gap retro for Sprint 18 cluster, NOT a codification retro. Captures Sprint 18 process observations for archival in `docs/sprints/sprint-18/close.md` (PM lane per file ownership matrix, this same PR).

## TL;DR

Sprint 18 cluster (8 stories: 3 P0 + 5 P1) closed via 9-PR parallel-ship pattern. **Process gaps surfaced**:

| # | Gap | Cycle / Origin | Severity | Status |
|---|---|---|---|---|
| 1 | PM lane discipline drift (cc:product-manager on scripts/ stories in Sprint 18 P1) | PICKUP-627 (lane hygiene cleanup) | P3 | RESOLVED (label hygiene applied, lane definition LOCKED enforced) |
| 2 | Squash miss lesson (PR #617 unsquashed in P0 wave gap, ironic pattern) | PICKUP-628 (orchestrator flag) | P2 | SURFACED — fix-strengthening proposal in §4 |
| 3 | GraphQL rate limit exhaustion (REST API fallback exhausted during Sprint 18 cluster close window) | PICKUP-625 (cluster-lag detector invocation) | P3 | WORKAROUND — REST API + owner web UI path |
| 4 | Squash miss + ironic runbook pattern (PR #617 = post-squash cleanup runbook itself unsquashed) | (NEW, lesson surfaced in §4 below) | P2 | FIX-STRENGTHENING PROPOSAL |
| 5 | Sub-cluster detection gap (600s window too narrow for retrospective reconstruction) | RETRO-013 §Cluster-lag analysis | P3 | AMENDMENT CANDIDATE — ADR-0059 §1 widen window to 1800s |
| 6 | Per-role WIP cap script miscounts (Sprint 17 issue still present in Sprint 18 cluster) | RETRO-012 §6 + Sprint 18 d066 fix | P3 | RESOLVED via d066 d-test (PR #620) |
| 7 | Proactive-scan wip_overflow false positive (AT-CAP vs OVERFLOW) | RETRO-012 §5 | P3 | NOT YET RESOLVED — S18-007 carry to Sprint 20 |
| 8 | PM curator step cadence (cluster-lag.log population + §Cluster-lag markdown section) | RETRO-012 §7 | P2 | RESOLVED — Issue #606 PM curator work + this RETRO + close.md |

**Tier 1 (1 candidate)**: Sprint 18 P0 cluster ProcessGap codification (close.md carrier + ADR-0059 §1 amendment)
**Tier 2 (3 candidates)**: Squad-level process doctrine updates (squash miss fix-strengthening, PM lane discipline enforcement, d-test family completion)
**Tier 3 (4 candidates)**: Script-tuning backlog, owner triage

## Sprint 18 P0+P1 cluster ledger (9/9 PRs SHIPPED + 6/8 STORIES CLOSED ✅)

| # | Story | PR | Squash SHA | Closer | Closes |
|---|-------|---|---|---|---|
| 1 | STORY-S18-001 §AC mapping verification doctrine (ADR-0060 NEW) | #615 | d4572b6 | owner | #604 (Closes anchor) |
| 2 | STORY-S18-002 Cluster-lag-detector workflow YAML wiring | #616 | fbe3839 | owner | #605 (Closes anchor) |
| 3 | STORY-S18-003 Cluster-lag.log retrospective population (PM curator) | #619 | 39f6772 | owner | #618 (Closes anchor, PM-as-fix-author) |
| 4 | STORY-S18-004 d065 dual-channel-enforcement d-test | #614 | 8fcb955 | owner | #607 (Refs, manual close) |
| 5 | STORY-S18-005 §verdict-by:<ts> discipline codification (orchestrator.md amendment) | #612 | af1880e | owner | #608 (Closes anchor) |
| 6 | STORY-S18-006 d066 WIP cap filter regression guard | #620 | 1bd70ba5 | owner | #609 (Refs, manual close @ 20:38:25Z) |
| 7 | (PM curator docs carrier) Sprint 18 backlog.json + plan.md | #613 | 339d474 | owner | (PM curator tracker, no Closes) |
| 8 | (Runbook carrier) post-squash cleanup runbook | #617 | 2d15cd7 | owner | (Refs only, no Closes, ironic §4 below) |
| 9 | (Sprint 18 P1 docs/tech-debt) TD-033+TD-034+TD-035 recovery | #621 | b2d593d9 | owner | (no Closes, tech-debt carrier) |

**Cluster timeline**:
- Sprint 17 close + RETRO-012 SHIPPED: 2026-06-28T16:55Z (PR #601 squash d8739d6)
- Issue #602 opened (Sprint 18 Kickoff dispatch): 2026-06-28T17:08Z
- First story PR merged (PR #614 — d065): 2026-06-28T19:20:11Z
- Last story PR merged (PR #621 — docs/tech-debt): 2026-06-28T20:36:58Z
- P0 cluster fully shipped (PR #612, #613, #614, #615, #616): 2026-06-28T19:51:11Z
- P0 cluster fully closed (PR #617 squash): 2026-06-28T20:23:31Z
- P1 cluster fully shipped (PR #619, #620, #621): 2026-06-28T20:36:58Z
- Issue #609 manual close: 2026-06-28T20:38:25Z
- **Cluster elapsed: ~3h 31m** (Issue #602 open → P1 cluster fully shipped)

## Tier 1 — Cluster ProcessGap codification (close.md carrier)

### §1 — ADR-0059 §1 amendment candidate: widen sub-cluster window

**Observed**: Sprint 18 P0 cluster (5 PRs: #612, #613, #614, #615, #616) spanned 30+ minutes due to owner-orchestrated squash waves (PRs squashed in 2-3 min intervals but with 5-15 min deliberation gaps between waves). The 600s sub-cluster detector window (per d064 TC2 fixture codification) classified each wave as silent_skip (sub-cluster size 2 < threshold 3) — but the P0 cluster as a whole is a meaningful unit.

**Pattern**: When owner squash events are grouped by deliberate ceremony (e.g., "squash the P0 cluster"), individual squash events may span 15-30 min but represent a single cluster. The detector misses this because:
- 600s window is too narrow for retrospective reconstruction
- Owner-bundle grouping is not yet captured in the detector metadata
- Sub-clusters of size 2 are silent_skip per ADR-0048 lens d (mandatory log emission on no-cluster) — but they're "real" sub-clusters in the owner-bundle sense

**Codification candidate**: Amend ADR-0059 §1 to widen sub-cluster window from 600s to 1800s (30 min) for retrospective detection. Alternative: add owner-bundle grouping via squash comment metadata.

**Resolution**: PM curator captured this observation in Sprint 18 close.md §Cluster-lag. Filed as RETRO-013 Tier 1 candidate for ADR-0059 §1 amendment. Owner triage in Sprint 19+ (skipped per directive) or Sprint 20 bug-only mode.

### §2 — Squash miss + ironic runbook pattern (LESSON #4)

**Observed**: PR #617 (the post-squash cleanup runbook describing how to clean up after squash events) was itself unsquashed for ~32 minutes after the P0 cluster squash wave (PR #617 squashed @ 20:23:31Z vs P0 cluster squashed @ 19:51:11Z). The runbook describes how to handle exactly the situation it was stuck in — meta-ironic but symptomatic.

**Pattern**: When squash events span owner-orchestrated bundles with deliberation gaps:
1. Owner squashes P0 cluster bundle → cluster-squash detector should fire
2. Detector misses because sub-cluster size 2 < threshold 3 (RETRO-013 §1 amendment candidate above)
3. Runbook describing cleanup procedure is itself in the unsquashed remainder
4. PM/orchestrator can't reference the runbook because it's not on main yet
5. Cures itself when owner eventually squashes the runbook (PR #617 squash @ 20:23:31Z)

**Codification candidate**: Add §Squash-bundle completeness pre-check to `.claude/agents/orchestrator.md`:
- Before orchestrator signals "cluster squash ready", verify ALL PRs in the bundle are squash-ready (no PRs in the bundle with open Refs anchors pointing to stories that need manual close)
- If any PR in the bundle is unsquashed, either (a) defer the cluster squash signal until all are ready, or (b) explicitly call out the unsquashed PR(s) in the runbook pre-state
- This is a forward doctrine that prevents the ironic pattern

**Resolution**: Captured in RETRO-013 §4 below + Sprint 18 close.md §Lesson learned. Filed as P2 candidate for Sprint 19+ (skipped per directive) or Sprint 20 bug-only mode.

## Tier 2 — Squad-level process doctrine updates

### §3 — PM lane discipline drift (cycle from PICKUP-627)

**Observed**: Sprint 18 P1 stories (#609, #610, #611 — scripts/ territory per file ownership matrix) were authored with `cc:product-manager` label. Per PM lane definition LOCKED (Sprint 13+), PM is NOT cc'd on scripts/ refactors — the cc:product-manager was a stale lane discipline violation.

**Pattern**: When Sprint 18 backlog.json was authored (PR #613 squash), the cc labels were set per file ownership matrix for the *primary* lane owner (architect, developer, tester) but PM was cc'd as a "sponsor" pattern. The sponsor pattern is appropriate for arch lane work (PM cross-lane sponsor per ADR-0059 §3 lineage) but NOT appropriate for scripts/ dev lane work.

**Codification candidate**: Add §PM lane cc discipline enforcement to `.claude/agents/orchestrator.md`:
- When PM is the primary lane owner (PM lane territory = docs/product/, docs/backlog/, docs/sprints/ content), `cc:product-manager` is appropriate
- When PM is a cross-lane sponsor (arch lane soul amendments per Issue #430 + #470 lineage), `cc:product-manager` is appropriate
- When PM is NOT lane-relevant (scripts/ refactors, src/ impl, tests/ impl), `cc:product-manager` is FORBIDDEN per Sprint 13+ LOCKED lane definition
- File ownership matrix is the source of truth for PM lane eligibility

**Resolution**: PM applied lane hygiene cleanup in PICKUP-627 (removed cc:product-manager from #609, #610, #611). All 3 audit-commented with cross-ref to file ownership matrix + PM lane LOCKED. Filed as Tier 2 candidate for orchestrator.md amendment.

### §4 — Squash miss + ironic runbook pattern (LESSON #4 continued)

See Tier 1 §2 above. Codification: add §Squash-bundle completeness pre-check to `.claude/agents/orchestrator.md`.

### §5 — Sub-cluster detection gap (cross-ref Tier 1 §1)

See Tier 1 §1 above. Codification: amend ADR-0059 §1 to widen sub-cluster window.

### §6 — d-test family completion (d067 + d068 carry-over)

**Observed**: Sprint 18 added d065 (dual-channel-enforcement, PR #614) + d066 (WIP cap filter, PR #620) to the d-test family (17-sister → 18-sister). PR #616 introduced d068 as part of the cluster-lag YAML wiring scope — d068 is the cluster-lag detector regression guard (sister-pattern to d064 + d065 + d066).

**Pattern**: d-test family grows by 2 per sprint (sister-pattern). Sprint 19+ carry-over candidates:
- d067 (proactive-scan wip_overflow false positive, sister to d066) — RETRO-012 §5 + Sprint 18 P1 #610 carry
- d068 already SHIPPED in PR #616 (cluster-lag detector regression guard)

**Codification candidate**: d-test family 19-sister completion requires d067 + d069 (new for Sprint 19+ carry). P2 deferred from Sprint 18 P2 (DEFERRED-2 candidate). Owner triage in Sprint 20 bug-only mode if any of these are re-classified as bugs.

**Resolution**: d068 SHIPPED in PR #616. d067 carry-over to Sprint 20 (Issue #610 dev lane). d069 depends on Sprint 19+ scope.

## Tier 3 — Script-tuning backlog (owner triage)

### §7 — Proactive-scan wip_overflow false positive (carry-over, not yet resolved)

**Observed** (from RETRO-012 §5): `scripts/proactive-board-scan.sh` flags `wip_overflow` when lane count > N (presumably 2 per ADR-0038 cap). When 2 lanes (dev, PM) are at exactly 2/2 cap, scan fires wip_overflow count:3 — this is the cap, not overflow.

**Resolution**: Update scan logic to flag OVERFLOW (count > cap), not AT-CAP (count == cap). Owner territory — `.github/workflows/` per file ownership matrix requires owner approval.

**Sprint 18 carry**: STORY-S18-007 (Issue #610) covers this fix + d067 d-test. Carry to Sprint 20 bug-only mode (dev lane).

### §8 — d064 CI workflow integration (carry-over, not yet resolved)

**Observed** (from Sprint 18 plan): d064 cluster-lag d-test is not yet CI-integrated. Sister-pattern to d015/d031/d058/d059 CI integration per ADR-0044 (RED-first TDD).

**Resolution**: Integrate `scripts/tests/d064-cluster-lag.sh` into `.github/workflows/d-tests.yml`. Owner territory for workflow YAML approval.

**Sprint 18 carry**: STORY-S18-008 (Issue #611) covers this. Carry to Sprint 20 bug-only mode (dev lane).

### §9 — Per-role WIP cap script miscounts (RESOLVED via d066)

**Observed** (from RETRO-012 §6): `scripts/wip-cap-check.sh` counts ALL `agent:*` issues regardless of `status:*` label. PM at WIP 2/2 cap because of #582 + #583, but both are owner-gated.

**Resolution** (Sprint 18 d066): Updated script to filter `status:in-progress` AND `agent:<role>`. Added `status:blocked` exemption for owner-gated items. d066 d-test (PR #620) verifies correctness.

### §10 — Cross-user GraphQL rate limit workaround (P2 deferred from Sprint 18)

**Observed** (from RETRO-012 §4): gh pr ready + gh pr edit (label mutations) require GraphQL `markPullRequestReadyForReview` mutation. When same user ID (269754789) hits 5000/5000 hourly limit (shared across all agents + owner), gh CLI returns "GraphQL: API rate limit already exceeded". PATCH /pulls/{N} {draft:false} is a no-op for the draft flag.

**Resolution (workaround)**: REST API fallback (works when GraphQL blocked). Owner web UI click for gh pr ready + squash (only path that bypasses rate limit entirely). Sprint 18+ rate limit events: PICKUP-625 (cluster-lag detector invocation triggered REST fallback).

**Codification candidate**: P2 deferred from Sprint 18 (DEFERRED-1). Owner triage in Sprint 19+ (skipped) or Sprint 20 bug-only mode.

### §11 — PM curator step cadence (RESOLVED)

**Observed** (from RETRO-012 §7): PM is curator for cluster-squash retro markdown per ADR-0059 §3 + cmt 4826303998. PM reads `cluster-lag.log` JSON output, generates §Cluster-lag markdown section per cluster-squash event, injects into retro or close.md.

**Resolution (Sprint 18)**: Issue #606 PM curator work fired (PICKUP-625 → PICKUP-626). cluster-lag.log populated retroactively for Sprint 17 P1 + Sprint 14 P1 base + Sprint 18 (pre-wiring) + partial Sprint 18 (post-wiring emissions). This RETRO + close.md carry the curator output. Cadence enforcement remains informal (Sprint 18 P2 DEFERRED-3).

## Cross-refs

- **ADR-0012** — Required Label Set on Issue/PR Creation (4-cat invariant)
- **ADR-0015** — Atomic 4-flag handoff
- **ADR-0024** — verdict-by:<ts> convention (codified in orchestrator.md per PR #612)
- **ADR-0031** — Owner override (sprint scope + squash gate)
- **ADR-0033** — Auto-Ping Hard-Rule (dual-channel, enforced via PR #597 squash notify.sh fix)
- **ADR-0038** — Per-role WIP cap 2/2 (Sprint 18 d066 fix)
- **ADR-0044** — RED-first TDD (d-test framework)
- **ADR-0045** — 9-Lens (arch pre-publish gate)
- **ADR-0048** — Type-driven verdict gate matrix (lens d silent_skip)
- **ADR-0049** — d-test framework
- **ADR-0055** — d-test ID uniqueness + sub-pattern remediation
- **ADR-0056** — F3 silent_skip doctrine (Option X applied via PR #597)
- **ADR-0059** — Cluster-squash batch-lag detection (Sprint 18 §1 amendment candidate)
- **ADR-0060** — §AC mapping verification doctrine (NEW Sprint 18, PR #615)
- **Issue #113** — labels > body doctrine
- **Issue #238** — rate limit = API throttling NOT work pause
- **Issue #430** — PM-side §Pre-citation cross-check (sister-pattern to ADR-0060)
- **Issue #470** — PM-side §Timing window (sister-pattern to ADR-0060)
- **Issue #508** — LIVE INSTANCE cluster-squash detection origin
- **Issue #582 + #583** — Sprint 17 P1 owner-gated WIP miscount incident (RESOLVED via d066)
- **Issue #602** — Sprint 18 Kickoff dispatch (CLOSED via PR #613)
- **Issue #604** — STORY-S18-001 doctrinal home (CLOSED via PR #615)
- **Issue #605** — STORY-S18-002 doctrinal home (CLOSED via PR #616)
- **Issue #606** — PM curator work (CLOSED via PICKUP-626)
- **Issue #607** — STORY-S18-004 doctrinal home (CLOSED manual)
- **Issue #608** — STORY-S18-005 doctrinal home (CLOSED via PR #612)
- **Issue #609** — STORY-S18-006 doctrinal home (CLOSED manual @ 20:38:25Z)
- **Issue #610** — STORY-S18-007 doctrinal home (OPEN, carry to Sprint 20)
- **Issue #611** — STORY-S18-008 doctrinal home (OPEN, carry to Sprint 20)
- **Issue #618** — Sprint 17 close.md §Cluster-lag factual error (CLOSED via PR #619)
- **PR #597** — cluster-lag-detector.sh impl (SHIPPED Sprint 17, on main)
- **PR #598** — RETRO-012 + post-squash-cleanup runbook (SHIPPED Sprint 17)
- **PR #601** — Sprint 17 close.md (SHIPPED, PM curator per ADR-0059 §3)
- **PR #612** — orchestrator.md §Verdict-by Discipline (squashed af1880e, this sprint)
- **PR #613** — Sprint 18 backlog.json + plan.md (squashed 339d474, PM curator)
- **PR #614** — d065 dual-channel-enforcement d-test (squashed 8fcb955, this sprint)
- **PR #615** — ADR-0060 §AC mapping verification (squashed d4572b6, this sprint)
- **PR #616** — cluster-lag-detector YAML wiring + d068 (squashed fbe3839, this sprint)
- **PR #617** — post-squash cleanup runbook (squashed 2d15cd7, ironic §4)
- **PR #619** — Sprint 17 close.md §Cluster-lag factual error fix (squashed 39f6772)
- **PR #620** — d066 WIP cap filter d-test (squashed 1bd70ba5, this sprint)
- **PR #621** — Sprint 18 P1 docs/tech-debt (squashed b2d593d9)
- **Cycle 530** — Stale-state correction (Issue #113 doctrine, labels > body)
- **Cycle 549** — Trust-but-verify (PR #591 flake re-diagnosis)
- **Cycle 567** — Squash-pending tolerance
- **Cycle 647** — Arch AC mapping drift (RETRO-012 §1 codification origin → ADR-0060)
- **PICKUP-625 + PICKUP-626** — PM curator work for cluster-lag detector (Issue #606)
- **PICKUP-627** — PM lane hygiene cleanup (cc:product-manager removed from #609-#611)
- **PICKUP-628** — Orchestrator squash miss flag (PR #617 unsquashed)
- **PICKUP-631** — PR #617 squash ACK (closes the ironic §4 pattern)
- **RETRO-009** — Sprint 14 codifications (`docs/retros/retro-009.md`)
- **RETRO-010** — Sprint 15 codifications (`docs/retros/retro-010.md`)
- **RETRO-011** — Sprint 16 codifications (`docs/retros/retro-011.md`, "final substantive retro")
- **RETRO-012** — Sprint 17 P1 ProcessGap retro (`docs/sprints/sprint-17/RETRO-012.md`)
- **cmt 4826303998** — PM curator commitment + ProcessGap RETRO-012 candidate lineage
- **cmt 4826478137** — PM sponsor review on RETRO-012 DRAFT
- **cmt 4826486795** — PM formal review on PR #598 (ADR-0024 observation, RETRO-012 §4a origin)
- **cmt 4826960727** — Arch FINAL 🟢 on PR #612 (orchestrator soul amendment)
- **cmt 4827041214 + cmt 4827112996** — PM peer reviews on PR #617 (runbook)
- **cmt 4827054515** — PM peer verdict on PR #612 (verdict-by doctrine)

## Forward-resolution

- **Owner ratification**: Pending. Owner reviews RETRO-013 scope + close.md draft, decides whether to ratify as Sprint 18 close input.
- **PM curator activation**: COMPLETE. PM drafted close.md + RETRO-013 per ADR-0059 §3. cluster-lag.log populated via Issue #606.
- **Sprint 18 close.md** (`docs/sprints/sprint-18/close.md`, PM lane, this PR's companion file) is the canonical landing pad for RETRO-013 + PM curator output + cluster-lag observations.
- **Sprint 19+ scope**: SKIPPED per owner directive 2026-06-27. Carry-over candidates (S18-007 + S18-008 + P2 DEFERRED-1/2/3) route to Sprint 20 bug-only mode (or close empty if no bugs filed).

— @product-manager, 2026-06-28T20:42+03:00 = 17:42Z, RETRO-013 draft (Sprint 18 P0+P1 cluster ProcessGap retro, PM curator lane, orch ratification pending → owner squash)