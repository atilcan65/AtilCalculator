# RETRO-014 — Sprint 18 Final Process Gaps + Sprint 20 Trigger (DRAFT, PM lane)

> **Author:** @product-manager (lane: docs/sprints/ per file ownership matrix, curator pattern per ADR-0059 §3)
> **Date:** 2026-06-28T21:13+03:00 = 18:13Z (Sprint 18 Final Ceremony)
> **Scope:** Sprint 18 final wave (PR #623 + #624) + Sprint 20 trigger condition + PROJECT CLOSE recommendation
> **Lane:** `docs/sprints/sprint-18/RETRO-014.md` (PM curator lane per file ownership matrix, sister-pattern to RETRO-013)
> **Sister-pattern:** RETRO-013 (Sprint 18 P0+P1 ProcessGap retro, `docs/sprints/sprint-18/RETRO-013.md`, PM lane) + RETRO-012 (Sprint 17 P1, `docs/sprints/sprint-17/RETRO-012.md`, orchestrator lane)
> **PM curator commitment:** cmt 4826303998 lineage (Issue #584, Option B → ADR-0059 §3)
> **Owner ratification:** Pending (deferred per ADR-0031 owner gating; PM drafts, orchestrator ratifies, owner ratifies scope)
> **Forward-resolution:** This is the FINAL substantive ProcessGap retro for Sprint 18. Captures dev lane stall incident + owner-author-and-merge doctrine + Sprint 20 trigger condition. Archival in `docs/sprints/sprint-18/close.md` (PM lane, this PR's companion file).

## TL;DR

Sprint 18 SHIPPED 8/8 ✅🎉🎉🎉 (PR #612 + #613 + #614 + #615 + #616 + #617 + #619 + #620 + #621 + #623 + #624 all merged). **Final process gaps surfaced**:

| # | Gap | Cycle / Origin | Severity | Status |
|---|---|---|---|---|
| 1 | Dev lane claim-without-deliver pattern (Issue #611 claimed 21:00:11Z, owner authored+merged 21:07:47Z — 7m36s idle) | Sprint 18 final wave | P2 | SURFACED — doctrine gap candidate for Sprint 20+ |
| 2 | Owner-author-and-merge doctrine gap (workflows change = human-only territory per file ownership, but code delivery can be owner-authored) | Sprint 18 final wave (PR #624) | P2 | SURFACED — doctrine codification candidate |
| 3 | Orchestrator 'monitor mode' over-confidence (orchestrator said dev lane in-flight, missed stall — claim→PR ratio check after 10min idle) | Sprint 18 final wave | P3 | SURFACED — orchestrator self-improvement |
| 4 | Sprint 20 trigger condition (no carry-overs + no bugs filed → direct PROJECT CLOSE) | Sprint 18 close | P1 | RECOMMENDATION — PM recommends (b) direct PROJECT CLOSE |
| 5 | d-test family 19-sister completion (d065/d066/d067/d068 NEW in Sprint 18) | Sprint 18 close | P3 | DOCUMENTED — d-test count 19 |
| 6 | Sprint 19 SKIPPED per owner directive 2026-06-27 | Sprint 18 close | P3 | CONFIRMED — Sprint 19 absent from numbering |

**Tier 1 (2 candidates)**: Dev lane stall + owner-author-and-merge doctrine (cross-cutting)
**Tier 2 (1 candidate)**: Orchestrator monitor mode over-confidence
**Tier 3 (3 candidates)**: Sprint 20 trigger + d-test family + Sprint 19 confirmation

## Sprint 18 FINAL cluster ledger (11/11 PRs SHIPPED + 8/8 STORIES CLOSED ✅🎉)

| # | Story | PR | Squash SHA | Closer | Closes |
|---|-------|---|---|---|---|
| 1 | STORY-S18-001 §AC mapping verification doctrine (ADR-0060 NEW) | #615 | d4572b6 | owner | #604 |
| 2 | STORY-S18-002 Cluster-lag-detector workflow YAML wiring | #616 | fbe3839 | owner | #605 |
| 3 | STORY-S18-003 Cluster-lag.log retrospective population (PM curator) | #619 | 39f6772 | owner | #618 |
| 4 | STORY-S18-004 d065 dual-channel-enforcement d-test | #614 | 8fcb955 | owner | #607 (Refs, manual close) |
| 5 | STORY-S18-005 §verdict-by:<ts> discipline codification (orchestrator.md) | #612 | af1880e | owner | #608 |
| 6 | STORY-S18-006 d066 WIP cap filter regression guard | #620 | 1bd70ba5 | owner | #609 (Refs, manual close) |
| 7 | STORY-S18-007 d067 proactive-scan wip_overflow (re-classified as bug) | #623 | 6e85bce | owner | #610 (Refs, manual close) |
| 8 | STORY-S18-008 d064 CI workflow integration (owner-authored) | #624 | 485c967 | **owner (authored + merged)** ⚠️ | #611 |
| 9 | (PM curator docs carrier) Sprint 18 backlog.json + plan.md | #613 | 339d474 | owner | (PM curator tracker) |
| 10 | (Runbook carrier) post-squash cleanup runbook | #617 | 2d15cd7 | owner | (Refs only) |
| 11 | (Sprint 18 P1 docs/tech-debt) TD-033+TD-034+TD-035 recovery | #621 | b2d593d9 | owner | (no Closes) |

**Cluster timeline (FULL)**:
- Sprint 17 close + RETRO-012 SHIPPED: 2026-06-28T16:55Z (PR #601 squash d8739d6)
- Issue #602 opened (Sprint 18 Kickoff dispatch): 2026-06-28T17:08Z
- First story PR merged (PR #614 — d065): 2026-06-28T19:20:11Z
- Last story PR merged (PR #624 — d064 CI workflow integration): 2026-06-28T21:07:47Z
- Sprint 18 8/8 SHIPPED: 2026-06-28T21:07:47Z
- Issue #611 closed (PR #624 owner-authored + merged): 2026-06-28T21:10:32Z
- **Sprint 18 cluster elapsed: ~4h** (Issue #602 open → Issue #611 closed)

## Tier 1 — Cross-cutting doctrine gaps

### §1 — Dev lane claim-without-deliver pattern (seed #1, P2)

**Observed**: Dev lane auto-claimed Issue #611 (S18-008 d064 CI workflow integration) at 2026-06-28T21:00:11Z. After 7m36s of idle (no PR draft opened, no commit activity), owner took over and authored + merged PR #624 directly at 2026-06-28T21:07:47Z. Issue #611 closed via PR #624 Closes anchor at 21:10:32Z.

**Pattern**: When dev lane auto-claims an issue (via `scripts/claim-next-ready.sh` per ADR-0038 Layer 2 spec), the agent is expected to either (a) open a PR draft within reasonable time, or (b) explicitly release the claim if blocked. Currently:
- No explicit "claim → PR draft" SLA timer
- No automatic release mechanism for idle claims
- Owner-step-in is the failure mode (owner-authored + merged)

**Codification candidate**: Add §Claim-without-deliver SLA to `.claude/agents/developer.md` (or `.claude/agents/orchestrator.md` since orchestrator dispatches):
- **10-min SLA:** after auto-claim, dev lane must open PR draft or post status update
- **20-min idle:** orchestrator pings dev lane for status
- **30-min idle:** orchestrator escalates to owner or triggers re-claim by another agent
- **45-min idle:** owner can author + merge directly (current pattern, but explicit)

**Resolution**: Captured in RETRO-014 §1. Filed as P2 doctrine gap for Sprint 20+ (or post-Sprint 20 in PROJECT CLOSE retro).

### §2 — Owner-author-and-merge doctrine gap (seed #2, P2)

**Observed**: PR #624 (S18-008 d064 CI workflow integration) was authored + merged by owner. The PR changed `.github/workflows/` (owner-only territory per file ownership matrix) AND the implementation code (`scripts/tests/d064-cluster-lag.sh`). File ownership matrix says `.github/workflows/` requires owner approval for changes — but the implementation code in `scripts/tests/` is dev lane territory.

**Pattern**: When owner authors a PR that touches BOTH owner-only territory (workflow YAML) AND dev lane territory (implementation code), the lane boundaries blur:
- Owner-only: `.github/workflows/` (file ownership matrix)
- Dev lane: `scripts/tests/` (file ownership matrix)
- PR #624 touched both → owner authored/merged (justified by workflow YAML owner-only requirement)
- But the implementation code should have been dev lane (claim-by-dev pattern)

**Codification candidate**: Add §Owner-author-and-merge doctrine to `.claude/agents/orchestrator.md`:
- **Owner-only territory** changes (`.github/workflows/`, `.claude/`, secrets) → owner-authored is required
- **Dev lane territory** changes (`scripts/`, `src/`, `tests/`) → owner-authored is fallback only when dev lane has claim-without-deliver incident
- **Mixed-territory** PRs (owner-only + dev lane) → owner-authored allowed IF dev lane claim-without-deliver gap OR owner-requested urgency
- **Audit trail:** every owner-authored PR with dev lane territory changes must cite the justification in PR body (e.g., "Issue #611 claim-without-deliver pattern, owner fallback per RETRO-014 §2")

**Resolution**: Captured in RETRO-014 §2. Filed as P2 doctrine codification candidate for Sprint 20+ (or post-Sprint 20).

## Tier 2 — Orchestrator self-improvement

### §3 — Orchestrator 'monitor mode' over-confidence (seed #3, P3)

**Observed**: Orchestrator (in monitor mode for Sprint 18 final wave) said "Dev WIP 1/2 (S18-008 d064 CI workflow integration)" at 21:01Z — implying dev lane was actively working on Issue #611. In reality, dev lane had auto-claimed at 21:00:11Z but did not produce a PR draft in the next 7 minutes. Owner took over at 21:07:47Z.

**Pattern**: Orchestrator's "monitor mode" relies on `agent:* + status:in-progress` label state to infer lane activity. But:
- `status:in-progress` is set on auto-claim
- PR draft opening is a separate action
- Orchestrator doesn't track "claim → PR draft" lag separately from "PR draft → merge" lag
- Therefore orchestrator over-reports lane activity (says "dev lane working" when dev lane has stalled)

**Codification candidate**: Add §Claim → PR ratio monitoring to `.claude/agents/orchestrator.md`:
- After auto-claim, orchestrator tracks `claim_time` (from auto-claim log)
- After 10min idle (no PR draft), orchestrator pings dev lane
- After 20min idle, orchestrator escalates to owner
- After 30min idle, orchestrator marks lane as "stalled" in monitor mode reports

**Resolution**: Captured in RETRO-014 §3. Filed as P3 orchestrator self-improvement for Sprint 20+.

## Tier 3 — Sprint 20 trigger + d-test family + Sprint 19 confirmation

### §4 — Sprint 20 trigger condition (P1 — RECOMMENDATION)

**Observed**: Sprint 18 SHIPPED 8/8 (all carry-overs + original stories done). Sprint 19 SKIPPED per owner directive. Sprint 20 doctrine (per Sprint 18 close.md §Sprint 20 kickoff pre-stage):
- Sprint 20 = bug-only mode
- ONLY bug fixes (type:bug) eligible
- **Trigger condition:** if no bugs filed in Sprint 18+, Sprint 20 closes empty (project close ceremony)
- **Current state:** no bugs filed → Sprint 20 closes empty

**PM recommendation on (a) vs (b)** (per orchestrator question):
- **(a) Sprint 20 kickoff** — Sprint 20 has no carry-overs, no eligible work in bug-only mode → empty sprint ceremony
- **(b) direct PROJECT CLOSE** — Sprint 20 closes empty per trigger condition, PROJECT CLOSE ceremony triggers immediately

**PM RECOMMENDS: (b) direct PROJECT CLOSE.** Rationale:
1. Sprint 20 has no Sprint 18 carry-overs (all shipped in Sprint 18 final wave)
2. Sprint 20 has no bugs filed yet (bug-only mode doctrine)
3. Opening Sprint 20 just to close it is ceremony overhead with no work
4. Direct PROJECT CLOSE respects the trigger condition logic
5. Owner retains the final call (may ratify Sprint 20 kickoff for cleaner ceremony)

**Resolution**: PM recommendation captured in RETRO-014 §4 + close.md. Owner ratifies path.

### §5 — d-test family 19-sister completion (P3, DOCUMENTED)

**Observed**: Sprint 18 d-test additions:
- **d065:** dual-channel-enforcement (PR #614) — NEW
- **d066:** WIP cap filter regression guard (PR #620) — NEW
- **d067:** proactive-scan wip_overflow per-role semantics (PR #623, re-classified as bug) — NEW
- **d068:** cluster-lag-detector regression guard (PR #616, sister-pattern to d064) — NEW

**Total d-test count:** 19 (was 17-sister post-Sprint 17 → 19-sister post-Sprint 18 = +4)

**Codification candidate**: d-test family 20-sister (d069 + d070, post-d067/d068) is Sprint 18 P2 deferred (DEFERRED-2). Not eligible for Sprint 20 bug-only mode (doctrine improvement, not bug). Owner triage in PROJECT CLOSE.

**Resolution**: Captured in RETRO-014 §5. Sprint 18 d-test additions documented. d-test count: 19.

### §6 — Sprint 19 SKIPPED per owner directive (P3, CONFIRMED)

**Observed**: Per owner directive 2026-06-27 ("17 18 19 birleştir"), Sprint 19 is SKIPPED in numbering. Sprint 17 absorbed Sprint 18 + Sprint 19 originally (per Sprint 17 close.md §Sprint 18 kickoff pre-stage), but Sprint 18 was re-instated for the post-cluster consolidation phase.

**Sprint lineage (FINAL)**:
- Sprint 0 → Sprint 17 (SHIPPED, includes original Sprint 18+19 absorbed scope)
- Sprint 18 (SHIPPED, post-cluster consolidation, this sprint)
- Sprint 19 (SKIPPED per owner directive)
- Sprint 20 (bug-only mode, likely empty → PROJECT CLOSE)

**Resolution**: Captured in RETRO-014 §6. Sprint lineage confirmed.

## PM Recommendation Summary (orchestrator question: what's next?)

**PM RECOMMENDS: (b) direct PROJECT CLOSE**

Rationale:
1. Sprint 18 SHIPPED 8/8 ✅
2. Sprint 19 SKIPPED per owner directive
3. Sprint 20 has no carry-overs (S18-007 + S18-008 shipped in Sprint 18 final wave)
4. Sprint 20 has no bugs filed (bug-only mode trigger condition)
5. Opening Sprint 20 just to close it is ceremony overhead with no work

Owner retains final call. If owner prefers Sprint 20 kickoff for cleaner ceremony, PM will draft Sprint 20 close.md + RETRO-015 (substantive final retro) when triggered. Otherwise, PROJECT CLOSE ceremony triggers directly.

## Cross-refs

- **ADR-0012** — Required Label Set (4-cat invariant)
- **ADR-0024** — verdict-by:<ts> convention (codified in orchestrator.md per PR #612)
- **ADR-0031** — Owner override (sprint scope + squash gate, owner-author-and-merge pattern)
- **ADR-0033** — Auto-Ping Hard-Rule (dual-channel)
- **ADR-0038** — Per-role WIP cap 2/2 (auto-claim mechanism, claim-without-deliver gap)
- **ADR-0044** — RED-first TDD (d-test framework)
- **ADR-0059** — Cluster-squash batch-lag detection (Sprint 18 §1 amendment candidate)
- **ADR-0060** — §AC mapping verification doctrine (NEW Sprint 18, PR #615)
- **Issue #113** — labels > body doctrine
- **Issue #238** — rate limit = API throttling NOT work pause
- **Issue #430 + #470** — PM-side verify-before triangulation
- **Issue #508** — LIVE INSTANCE cluster-squash detection origin
- **Issue #602** — Sprint 18 Kickoff dispatch (CLOSED via PR #613)
- **Issue #606** — PM curator work (CLOSED via PICKUP-626)
- **Issue #607** — STORY-S18-004 doctrinal home (CLOSED manual)
- **Issue #608** — STORY-S18-005 doctrinal home (CLOSED via PR #612)
- **Issue #609** — STORY-S18-006 doctrinal home (CLOSED manual)
- **Issue #610** — STORY-S18-007 doctrinal home (CLOSED via PR #623)
- **Issue #611** — STORY-S18-008 doctrinal home (CLOSED via PR #624, owner-authored)
- **Issue #618** — Sprint 17 close.md §Cluster-lag factual error (CLOSED via PR #619)
- **PR #597** — cluster-lag-detector.sh impl (Sprint 17 SHIPPED)
- **PR #598** — RETRO-012 + post-squash-cleanup runbook (Sprint 17 SHIPPED)
- **PR #601** — Sprint 17 close.md (Sprint 17 SHIPPED, PM curator)
- **PR #612** — orchestrator.md §Verdict-by Discipline (squashed af1880e, Sprint 18)
- **PR #613** — Sprint 18 backlog.json + plan.md (squashed 339d474, PM curator)
- **PR #614** — d065 dual-channel-enforcement d-test (squashed 8fcb955, Sprint 18)
- **PR #615** — ADR-0060 §AC mapping verification (squashed d4572b6, Sprint 18)
- **PR #616** — cluster-lag-detector YAML wiring + d068 (squashed fbe3839, Sprint 18)
- **PR #617** — post-squash cleanup runbook (squashed 2d15cd7, Sprint 18)
- **PR #619** — Sprint 17 close.md §Cluster-lag factual error fix (squashed 39f6772)
- **PR #620** — d066 WIP cap filter d-test (squashed 1bd70ba5, Sprint 18)
- **PR #621** — Sprint 18 P1 docs/tech-debt (squashed b2d593d9)
- **PR #622** — Sprint 18 close.md + RETRO-013 (squashed 4574f95b, PM curator, this PR's companion)
- **PR #623** — d067 proactive-scan wip_overflow (squash, Sprint 18 final wave)
- **PR #624** — d064 CI workflow integration (squashed 485c967, owner-authored, Sprint 18 final wave)
- **Cycle 530** — Stale-state correction (Issue #113 doctrine, labels > body)
- **Cycle 549** — Trust-but-verify (PR #591 flake re-diagnosis)
- **Cycle 567** — Squash-pending tolerance
- **Cycle 647** — Arch AC mapping drift (RETRO-012 §1 codification origin → ADR-0060)
- **PICKUP-625 + PICKUP-626** — PM curator work for cluster-lag detector (Issue #606)
- **PICKUP-627** — PM lane hygiene cleanup (cc:product-manager removed from #609-#611)
- **PICKUP-628** — Orchestrator squash miss flag (PR #617 unsquashed, ironic)
- **PICKUP-631** — PR #617 squash ACK (closes the ironic pattern)
- **PICKUP-634** — Sprint 18 cluster close-out PR #622 OPENED (PM curator)
- **PICKUP-639** — Sprint 18 SHIP COMPLETE (PR #622 squash verified)
- **PICKUP-645** — Sprint 18 SHIPPED 8/8 (PR #624 squash + Issue #611 closed)
- **RETRO-009** — Sprint 14 codifications (`docs/retros/retro-009.md`)
- **RETRO-010** — Sprint 15 codifications (`docs/retros/retro-010.md`)
- **RETRO-011** — Sprint 16 codifications (`docs/retros/retro-011.md`, "final substantive retro")
- **RETRO-012** — Sprint 17 P1 ProcessGap retro (`docs/sprints/sprint-17/RETRO-012.md`)
- **RETRO-013** — Sprint 18 P0+P1 ProcessGap retro (`docs/sprints/sprint-18/RETRO-013.md`, PM curator)
- **cmt 4826303998** — PM curator commitment + ProcessGap RETRO-012 candidate lineage
- **cmt 4826478137** — PM sponsor review on RETRO-012 DRAFT
- **cmt 4826486795** — PM formal review on PR #598 (ADR-0024 observation, RETRO-012 §4a origin)

## Forward-resolution

- **Owner ratification**: Pending. Owner reviews RETRO-014 scope + close.md amendment, decides whether to ratify as Sprint 18 final input.
- **PM curator activation**: COMPLETE. PM drafted close.md amendment + RETRO-014 per ADR-0059 §3. cluster-lag.log populated via Issue #606.
- **Sprint 18 close.md amendment** (`docs/sprints/sprint-18/close.md`, PM lane, this PR's companion file) — was 6/8 → now 8/8, captures PR #623 + #624, doctrine additions updated, carry-over section cleared, PM recommendation on Sprint 20 trigger captured.
- **Sprint 20 trigger**: Per RETRO-014 §4, PM recommends (b) direct PROJECT CLOSE. Owner ratifies final path.
- **PROJECT CLOSE ceremony**: Pre-staged in Sprint 18 close.md §PROJECT CLOSE pre-stage + RETRO-014 §6 (sprint lineage). Awaiting owner ratification.

— @product-manager, 2026-06-28T21:13+03:00 = 18:13Z, RETRO-014 draft (Sprint 18 FINAL ProcessGap retro + Sprint 20 trigger recommendation, PM curator lane, orch ratification pending → owner squash)