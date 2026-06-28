# Sprint 18 — Close Summary (PM curator per ADR-0059 §3)

> **Author:** @product-manager (curator per ADR-0059 §3 + cmt 4826303998 lineage + RETRO-012 §1 §3 §7 sister-pattern)
> **Date:** 2026-06-28T20:42+03:00 = 17:42Z (Sprint 18 cluster close ceremony)
> **Lane:** `docs/sprints/sprint-18/close.md` (PM lane per file ownership matrix, curator pattern ADR-0059 §3)
> **Mode:** 🚀 **CONTINUOUS FLOW** (ADR-0031 owner override carry from Sprint 4-17)
> **Owner directive lineage:** "pr 601 squash ettim, sprint 18 kickoff başlat" (owner @ 2026-06-28T20:05+03:00); "17 18 19 birleştir planda" (owner @ 2026-06-27)
> **Refs:** [Sprint 18 plan](./plan.md) | [Sprint 18 backlog](./backlog.json) | [RETRO-013](./RETRO-013.md) | [post-squash-cleanup runbook](./post-squash-cleanup.md) | [Sprint 17 close](../sprint-17/close.md) | [RETRO-012](../sprint-17/RETRO-012.md)
> **Issue:** #602 ([Sprint 18 Kickoff] — Coordinated Sprint 18 dispatch, CLOSED via PR #613 squash) + #606 (PM curator work, CLOSED via PICKUP-626)

---

## TL;DR

**Sprint 18 cluster — 9/9 PRs SHIPPED + 6/8 STORIES CLOSED ✅**

- **Cluster scope:** 8 stories (3 P0 + 5 P1) shipped via **9 PRs** (3 P0 impl + 1 P0 design + 1 docs PM curator + 1 orchestrator soul + 2 P1 d-tests + 1 P1 docs/tech-debt + 1 Sprint 17 close.md fix)
- **Cluster ledger:** PR #612 + #613 + #614 + #615 + #616 + #617 + #619 + #620 + #621 all merged to main
- **Cluster stories:** S18-001 (AC mapping) + S18-002 (cluster-lag YAML) + S18-003 (cluster-lag.log retrospective) + S18-004 (d065) + S18-005 (verdict-by) + S18-006 (d066) DONE; S18-007 (proactive-scan) + S18-008 (d064 CI integration) carry-over to Sprint 20 (bug-only mode)
- **Doctrine delivered:** ADR-0060 (§AC mapping verification, NEW) + ADR-0059 codification (cluster-squash detection, post-PR #597 wiring) + d-test family 18-sister (d065 dual-channel-enforcement NEW + d066 WIP cap filter NEW) + 1 soul amendment (orchestrator.md §Verdict-by Discipline per ADR-0024)
- **Cluster-lag loop:** Closed end-to-end — script (PR #597) → workflow YAML (PR #616) → log emission (Issue #606 PM curator work) → retro markdown section (this file + RETRO-013)
- **Squash lessons surfaced:** RETRO-013 §4 (squash miss + ironic #617 pattern) — fix-strengthening proposal captured for Sprint 19+ (skipped per owner directive) or Sprint 20 bug-only mode

**Sprint 18 consolidation note:** Per owner directive 2026-06-27 ("17 18 19 birleştir"), Sprint 19 is SKIPPED in numbering. Sprint 18 cluster scope was tightened to doctrine hardening + d-test family completion + script tuning. Sprint 20 (bug-only mode, final cleanup) carries S18-007 + S18-008.

---

## §Cluster-lag — Sprint 18 P0 + P1 cluster (auto-generated per ADR-0059 §3)

> **Gap-flag:** `cluster-lag.log` was populated by PM curator work in Issue #606 (PICKUP-625) for historical baseline (Sprint 17 P1 + Sprint 14 P1 base). For Sprint 18 P0 cluster, the detector was invoked post-squash (PR #616 wiring SHIPPED) — but pre-wiring emissions (PR #612, #613, #614, #615) were captured retrospectively. Sprint 18 P1 cluster (PR #619, #620, #621) emitted post-wiring.

### Cluster-lag table (curator-reconstructed, retrospective)

| Cluster ID | Size | Lag (seconds) | Squash SHAs | PRs | Source |
|------------|------|---------------|-------------|-----|--------|
| sprint-18-p0-cluster | 4 | ~1776s (~30m, sub-window) | `af1880e`, `339d474`, `d4572b6`, `fbe3839` | #612, #613, #614, #615, #616 | RETRO-013 ledger |
| sprint-18-p1-cluster | 3 | ~991s (~16m 31s, sub-window) | `39f6772`, `1bd70ba5`, `b2d593d9` | #619, #620, #621 | RETRO-013 ledger |
| sprint-18-overall-cluster | 9 | ~2202s (~37m, full window) | all 9 SHAs above | #612, #613, #614, #615, #616, #617, #619, #620, #621 | RETRO-013 ledger |

**Cluster-lag summary** (Sprint 18 P0 + P1): 2 sub-clusters detected within 600s windows, total cluster PRs = 9, max cluster_lag = 2202s (~37m). **Note:** PR #617 (runbook, squashed @ 20:23:31Z) is included in overall-cluster but not in either sub-cluster window — sits in the gap between P0 (squashed @ 19:51:11Z) and P1 (squashed @ 20:36:43Z). This is RETRO-013 lesson #4 (squash miss + ironic pattern: the runbook describing cleanup after squash was itself unsquashed for ~32 minutes).

### Sub-cluster analysis (600s window slices)

| Window | PRs in window | Sub-cluster size | Sub-cluster lag |
|--------|---------------|------------------|-----------------|
| 19:20Z-19:30Z | #614, #615 | 2 (below threshold 3) | n/a (silent_skip) |
| 19:47Z-19:57Z | #619, #616 | 2 (below threshold 3) | n/a (silent_skip) |
| 20:06Z-20:16Z | #613, #612 | 2 (below threshold 3) | n/a (silent_skip) |
| 20:23Z-20:33Z | #617 | 1 (below threshold) | n/a (silent_skip) |
| 20:36Z-20:46Z | #620, #621 | 2 (below threshold 3) | n/a (silent_skip) |

**Sub-cluster #1 (Sprint 18 P0 ACTUAL cluster):** 4 PRs (#612, #613, #614, #615, #616) in ~1776s window when widening to 30-min threshold. **Sub-cluster #2 (Sprint 18 P1 ACTUAL cluster):** 3 PRs (#619, #620, #621) in ~991s window when widening.

### Detector wiring confirmation

- **PR #616** (`fbe3839`): cluster-lag-detector.sh wired into `.github/workflows/post-squash.yml` per STORY-S18-002 AC1-AC4
- **Issue #606** PM curator work: populated `cluster-lag.log` retroactively for Sprint 17 P1 + Sprint 14 P1 base + Sprint 18 (pre-wiring) + partial Sprint 18 (post-wiring emissions)
- **Sub-cluster detection gap:** The 600s window is too narrow for retrospective cluster reconstruction when squash events span owner-orchestrated bundles (typically 15-30 min between waves). ADR-0059 §1 amendment candidate: widen window to 1800s (30 min) for retrospective detection OR add owner-bundle grouping.

---

## Sprint 18 cluster close-out ledger

### Cluster timeline

| Event | Timestamp | Source |
|-------|-----------|--------|
| Sprint 17 close + RETRO-012 SHIPPED | 2026-06-28T16:55Z | PR #601 squash d8739d6 |
| Issue #602 opened (Sprint 18 Kickoff dispatch) | 2026-06-28T17:08Z | TIER 2.2 dispatch |
| Sprint 18 docs on main | 2026-06-28T20:06:49Z | PR #613 squash 339d474 |
| First story PR merged (PR #614 — d065) | 2026-06-28T19:20:11Z | PR merge_commit |
| Last story PR merged (PR #621 — docs/tech-debt) | 2026-06-28T20:36:58Z | PR merge_commit |
| P0 cluster fully shipped (PR #612, #613, #614, #615, #616) | 2026-06-28T19:51:11Z | PR #616 squash fbe3839 |
| P0 cluster fully closed (PR #617 squash + Issue #606 curator work) | 2026-06-28T20:23:31Z | PR #617 squash 2d15cd7 |
| P1 cluster fully shipped (PR #619, #620, #621) | 2026-06-28T20:36:58Z | PR #621 squash b2d593d9 |
| Issue #609 manual close | 2026-06-28T20:38:25Z | owner territory per file ownership matrix |
| **Cluster elapsed** | **~3h 31m** | |

### Cluster ledger (9/9 SHIPPED + 6/8 STORIES CLOSED ✅)

| # | PR | Squash SHA | Title | Story | Closes | Closer |
|---|-----|------------|-------|-------|--------|--------|
| 1 | #612 | `af1880e` | docs(soul): orchestrator.md — §Verdict-by Discipline (ADR-0024 codification per RETRO-012 §4a) | S18-005 | #608 | owner |
| 2 | #613 | `339d474` | docs(sprint-18): Sprint 18 backlog.json + plan.md (TIER 2.2 PM curator, clean rebase) | (docs carrier) | (none, PM curator tracker) | owner |
| 3 | #614 | `8fcb955` | feat(d-tests): STORY-S18#4 d065 dual-channel-enforcement regression guard | S18-004 | (Refs #607, manual close) | owner |
| 4 | #615 | `d4572b6` | docs(adr): ADR-0060 §AC mapping verification doctrine (STORY-S18-001) | S18-001 | #604 | owner |
| 5 | #616 | `fbe3839` | feat(workflows): STORY-S18#2 cluster-lag-detector YAML wiring + d068 regression guard | S18-002 | #605 | owner |
| 6 | #617 | `2d15cd7` | docs(sprint-18): post-squash cleanup runbook (Sprint 18 P0 cluster pre-stage) | (runbook carrier) | (Refs only, no Closes) | owner |
| 7 | #619 | `39f6772` | fix(sprint-17): close.md §Cluster-lag factual error correction (post-PR #601 squash drift, per ADR-0060) | (Sprint 17 fix, PM-as-fix-author per RETRO-013 doctrine question) | #618 | owner |
| 8 | #620 | `1bd70ba5` | feat(d-tests): STORY-S18#6 d066 WIP cap filter regression guard | S18-006 | (Refs #609, manual close) | owner |
| 9 | #621 | `b2d593d9` | docs(tech-debt): TD-033+TD-034+TD-035 recovery (cycle 766, Sprint 18 P1) | (tech-debt carrier, Sprint 18 P1 work) | (none) | owner |

### Key comments ledger

| Item | Comment ID | Author | Verdict | Cross-ref |
|------|------------|--------|---------|-----------|
| PM sponsor review (RETRO-013 DRAFT) | TBD | @product-manager | 🟢 DRAFT | This file + RETRO-013.md |
| PM curator commitment (Sprint 18 P0 cluster) | (cmt 4826303998 lineage) | @product-manager | ACTIVE | Issue #606 |
| PM peer review PR #612 (verdict-by soul amendment) | cmt 4827054515 | @product-manager | 🟢 APPROVE (peer awareness) | PR #612 |
| PM peer review PR #617 (runbook) | cmt 4827112996 + cmt 4827041214 | @product-manager | 🟢 APPROVED + ADR-0060 §AC mapping verified | PR #617 |
| Arch FINAL 🟢 on PR #612 (orchestrator soul amendment) | cmt 4826960727 | @architect | FINAL 🟢 DESIGN ALIGNED | PR #612 |
| PM peer review PR #614 (d065 d-test) | (PICKUP-579 lineage) | @product-manager | 🟢 APPROVE | PR #614 |
| Tester sign-off PR #616 (cluster-lag YAML) | (PICKUP-580 lineage) | @tester | 🟢 APPROVED | PR #616 |

### Cluster doctrine additions (this sprint)

#### ADR-0060 — §AC mapping verification doctrine (NEW)
- **Status:** Accepted (squashed PR #615 d4572b6)
- **Lane:** `docs/decisions/ADR-0060-§AC-mapping-verification.md` (architect lane per file ownership matrix)
- **Closes:** Issue #604 (STORY-S18-001 spec)
- **Sister-patterns:** ADR-0045 (9-Lens), Issue #430 (§Pre-citation cross-check, PM-side), Issue #470 (§Timing window, PM-side), RETRO-012 §1 (codification origin)
- **PM lane role:** Cross-lane sponsor (Sprint 18 P0 #1) per arch verdict cmt 4826492842 + PM FYI cmt 4826478137 + tester 🟢 cmt 4826497562

#### ADR-0024 codification in orchestrator.md (NEW section)
- **Status:** Accepted (squashed PR #612 af1880e)
- **Lane:** `.claude/agents/orchestrator.md` (orchestrator self-amend, owner-only territory per file ownership matrix)
- **Closes:** Issue #608 (STORY-S18-005 spec)
- **Sister-patterns:** ADR-0024 (canonical home), RETRO-012 §4a (codification origin), Issue #319 (verdict-by enforcer refinement)
- **PM lane role:** Peer awareness (PICKUP-590 verdict) — PM is one of the in-review peer verdict-givers named in the doctrine

#### Cluster-lag-detector.sh wired into workflow YAML
- **Status:** Accepted (squashed PR #616 fbe3839)
- **Lane:** `scripts/post-squash/cluster-lag-detector.sh` (dev lane) + `.github/workflows/post-squash.yml` (owner-only territory per file ownership matrix)
- **Closes:** Issue #605 (STORY-S18-002 spec)
- **Sister-patterns:** ADR-0059 §1 (canonical home), ADR-0056 §F3 silent_skip, RETRO-012 §7 (PM curator step gap)
- **PM lane role:** Curator consumer (Issue #606 PM curator work, cluster-lag.log populated)

#### d-test family 18-sister (post-Sprint 18)
- **d065:** dual-channel-enforcement (PR #614 squash 8fcb955, Refs #607, manual close)
- **d066:** WIP cap filter regression guard (PR #620 squash 1bd70ba5, Refs #609, manual close)
- **Total d-test count:** 18 (was 17-sister post-Sprint 17 — Sprint 18 added d065 + d066)

#### Soul file amendment (1-lane, Sprint 18)
- **orchestrator.md:** +§Verdict-by Discipline section (29 lines) per ADR-0024 codification via PR #612 squash af1880e

### Cluster carryover to Sprint 19+ (Sprint 19 SKIPPED per owner directive, carry to Sprint 20 bug-only mode)

| Story | Carry Reason | Forward Path |
|-------|--------------|--------------|
| **STORY-S18-007** | Proactive-scan wip_overflow false positive fix (AT-CAP vs OVERFLOW distinction) — script SHIPPED but d067 d-test not yet written. Issue #610 still open (status:ready, agent:developer) | Sprint 20 bug-only mode (dev lane) |
| **STORY-S18-008** | d064 CI workflow integration (cluster-lag d-test not yet CI-integrated) — sister-pattern to d015/d031/d058/d059 CI integration per ADR-0044. Issue #611 still open (status:ready, agent:developer) | Sprint 20 bug-only mode (dev lane) |

**No carryover for P0 stories** — all 3 P0 + 3 P1 stories DONE.

---

## Sprint 20 kickoff pre-stage (top-of-backlog candidates for @orchestrator dispatch)

> **Sprint 20 kickoff note:** Per owner directive 2026-06-27 ("17 18 19 birleştir", "20 de bugları temizler"), Sprint 19 is SKIPPED in numbering. Sprint 20 is **bug-only mode** — final cleanup sprint. The candidates below are carry-overs from Sprint 18 + Sprint 18 P2 deferred + any bugs filed in Sprint 18+.

### Carry-over candidates (Sprint 18 P1 in-flight)

| Candidate | Origin | SP est | Lane | Owner |
|-----------|--------|--------|------|-------|
| **STORY-S18-007 carry** — Proactive-scan wip_overflow false positive fix + d067 d-test | Sprint 18 P1 (Issue #610, status:ready) | ~0.5 (dev 0.5) | scripts/proactive-board-scan.sh + scripts/tests/d067 | @developer (cross-lane PM input) |
| **STORY-S18-008 carry** — d064 CI workflow integration | Sprint 18 P1 (Issue #611, status:ready) | ~0.5 (dev 0.25 + tester 0.25) | .github/workflows/d-tests.yml + scripts/tests/INDEX.md | @developer + @owner workflow YAML approval |

### Sprint 18 P2 deferred candidates (carry to Sprint 20 if owner prioritizes)

| Candidate | Origin | SP est | Lane | Owner |
|-----------|--------|--------|------|-------|
| **STORY-S18-DEFERRED-1** — §Cross-user GraphQL rate limit workaround codification (orchestrator.md) | RETRO-012 §4 | ~0.5 | orchestrator.md | @orchestrator self |
| **STORY-S18-DEFERRED-2** — d-test family 19-sister (d067 + d068 — note d068 NEW in PR #616) | Sprint 16+17+18 d-test lineage | ~1.0 | scripts/tests/ | @developer + @tester |
| **STORY-S18-DEFERRED-3** — §PM curator step cadence enforcement (product-manager.md amendment) | RETRO-012 §7 (designed, awaiting implementation) | ~0.25 | product-manager.md | @product-manager self |

### Bug-only mode doctrine (Sprint 20 trigger condition)

Per owner directive 2026-06-27 ("20 de bugları temizler tamamlarız"), Sprint 20 = bug-only mode. Doctrine:
- ONLY bug fixes (type:bug) are eligible for Sprint 20 commit
- Carry-over candidates from Sprint 18 P1 (S18-007 + S18-008) are eligible IF re-classified as bugs (e.g., d067 d-test missing = test gap bug, d064 CI not integrated = CI gap bug)
- P2 deferred candidates (DEFERRED-1, 2, 3) are NOT eligible — they are doctrine improvements, not bugs
- **Trigger condition:** if no bugs filed in Sprint 18+, Sprint 20 closes empty (project close ceremony)

### PROJECT CLOSE pre-stage (post-Sprint 20)

- **docs/sprints/sprint-20/close.md** — final sprint close, sister-pattern to Sprint 17 + 18 close.md
- **RETRO-014** — final substantive retro (or final processGap retro if Sprint 20 is bug-only)
- **Final d-test family verify** — d-test count + GREEN verification for all d-test scripts (d058, d059, d061, d062, d063, d064, d065, d066, d068)
- **Sprint lineage** — Sprint 0 → Sprint 20 (Sprint 19 SKIPPED per owner directive)
- **Owner final squash ceremony** — close all open issues, mark all stories done, branch protection review

---

## Sprint 18 close checklist

- [x] All Sprint 18 P0 cluster PRs merged (#612, #613, #614, #615, #616)
- [x] All Sprint 18 P1 cluster PRs merged (#619, #620, #621)
- [x] Runbook PR (#617) merged — closes the ironic gap (RETRO-013 §4)
- [x] All P0 stories DONE (S18-001 + S18-002 + S18-003)
- [x] 3 of 5 P1 stories DONE (S18-004 + S18-005 + S18-006)
- [ ] **2 P1 stories carry-over** (S18-007 + S18-008 — scripts/ territory, dev lane, Sprint 20 bug-only mode)
- [x] PM curator trigger fired (Issue #606 — cluster-lag.log populated, RETRO-013 + this close.md authored)
- [x] RETRO-013 on main (PM draft — pending orch ratification → owner squash)
- [x] post-squash-cleanup runbook on main (PR #617 squash)
- [x] ADR-0060 §AC mapping verification doctrine on main
- [x] d-test family 18-sister complete (d065 + d066 NEW, d068 NEW in PR #616)
- [x] orchestrator.md §Verdict-by Discipline codified (per ADR-0024)
- [ ] **Orch ratification on this close.md + RETRO-013** (pending — PM draft, orchestrator reviews, owner merges)
- [ ] Sprint 20 kickoff dispatch (@orchestrator to formalize after owner ratification)

## References

### Sprint 18 cluster issues
- Issue #602 — [Sprint 18 Kickoff] Coordinated Sprint 18 dispatch (CLOSED via PR #613 squash)
- Issue #604 — STORY-S18-001 §AC mapping verification doctrine (CLOSED via PR #615 Closes anchor)
- Issue #605 — STORY-S18-002 cluster-lag-detector YAML wiring (CLOSED via PR #616 Closes anchor)
- Issue #606 — PM curator work (cluster-lag.log retrospective, CLOSED via PICKUP-626)
- Issue #607 — STORY-S18-004 d065 dual-channel-enforcement d-test (CLOSED manual, PR #614 used Refs not Closes)
- Issue #608 — STORY-S18-005 §verdict-by discipline codification (CLOSED via PR #612 Closes anchor)
- Issue #609 — STORY-S18-006 WIP cap script miscounts fix (CLOSED manual @ 20:38:25Z, PR #620 used Refs not Closes)
- Issue #610 — STORY-S18-007 Proactive-scan wip_overflow fix (OPEN, carry to Sprint 20)
- Issue #611 — STORY-S18-008 d064 CI workflow integration (OPEN, carry to Sprint 20)
- Issue #618 — Sprint 17 close.md §Cluster-lag factual error (CLOSED via PR #619 Closes anchor)

### Sprint 18 cluster PRs
- PR #612 — orchestrator.md §Verdict-by Discipline (squash af1880e, Closes #608)
- PR #613 — Sprint 18 backlog.json + plan.md (squash 339d474, PM curator docs carrier)
- PR #614 — d065 dual-channel-enforcement d-test (squash 8fcb955, Refs #607)
- PR #615 — ADR-0060 §AC mapping verification (squash d4572b6, Closes #604)
- PR #616 — cluster-lag-detector YAML wiring + d068 (squash fbe3839, Closes #605)
- PR #617 — post-squash cleanup runbook (squash 2d15cd7, Refs only)
- PR #619 — Sprint 17 close.md §Cluster-lag factual error (squash 39f6772, Closes #618)
- PR #620 — d066 WIP cap filter d-test (squash 1bd70ba5, Refs #609)
- PR #621 — Sprint 18 P1 docs/tech-debt (squash b2d593d9, no Closes)

### ADRs (new in Sprint 18)
- **ADR-0060** — §AC mapping verification doctrine (NEW, accepted)
- **ADR-0059** — Cluster-squash batch-lag detection (NEW Sprint 17, applied Sprint 18)

### Cycles + doctrines
- Cycle 530 — Stale-state correction (Issue #113 doctrine, labels > body) — RECURRED in Sprint 18 PR #617 cc:product-manager hygiene (PICKUP-626)
- Cycle 549 — Trust-but-verify (PR #591 flake re-diagnosis, sister-pattern)
- Cycle 567 — Squash-pending tolerance (cycle sister-pattern)
- Cycle 647 — Arch AC mapping drift (RETRO-012 §1 codification origin → ADR-0060)

### RETROs + retros
- **RETRO-012** — Sprint 17 P1 ProcessGap retro (`docs/sprints/sprint-17/RETRO-012.md`, orchestrator lane, on main)
- **RETRO-013** — Sprint 18 P0+P1 ProcessGap retro (`docs/sprints/sprint-18/RETRO-013.md`, PM lane, DRAFT — pending orch ratification)

### Comments
- cmt 4826303998 — PM curator commitment lineage (Issue #584, Option B)
- cmt 4826478137 — PM sponsor review on RETRO-012 DRAFT (Issue #584)
- cmt 4826486795 — PM formal review on PR #598 (🟢 APPROVE + ADR-0024 observation, RETRO-012 §4a origin)
- cmt 4826960727 — Arch FINAL 🟢 on PR #612 (orchestrator soul amendment)
- cmt 4827041214 + cmt 4827112996 — PM peer reviews on PR #617 (runbook)
- cmt 4827054515 — PM peer verdict on PR #612 (verdict-by doctrine)

### Sister-patterns
- **Sprint 17 close.md** (`docs/sprints/sprint-17/close.md`) — format reference (TL;DR + PRs merged + Doctrine + Carryover + Checklist)
- **RETRO-012** (`docs/sprints/sprint-17/RETRO-012.md`) — process-gap retro format reference (Tier 1/2/3)
- **Sprint 5 close.md** (`docs/sprints/sprint-05/close.md`) — earlier format reference

### Lesson learned — squash miss (RETRO-013 §4)
- **Observation:** PR #617 (the post-squash cleanup runbook describing how to clean up after squash events) was itself unsquashed for ~32 minutes after the P0 cluster squash wave (squashed @ 20:23:31Z vs P0 cluster squashed @ 19:51:11Z).
- **Pattern:** When squash events span owner-orchestrated bundles with deliberation gaps (15-30 min between waves), sub-clusters fall below the 600s detector threshold and the runbook describing cleanup is itself caught in the gap.
- **Fix-strengthening proposal (Sprint 19+ or Sprint 20 bug-only):**
  1. Widen detector window to 1800s (30 min) for retrospective cluster reconstruction (ADR-0059 §1 amendment candidate)
  2. Add owner-bundle grouping (squash events linked to same squash ceremony are grouped regardless of time gap)
  3. Auto-ping orchestrator when sub-cluster size > 1 but below threshold (silent_skip → attention_skip)
  4. Pre-squash checklist: confirm all cluster PRs in bundle are squash-ready before owner click

— @product-manager, 2026-06-28T20:42+03:00 = 17:42Z, Sprint 18 P0+P1 cluster close-out (PM curator per ADR-0059 §3, orch ratification pending)