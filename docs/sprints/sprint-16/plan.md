# Sprint 16 — Plan (PM draft, owner ratifies)

> **Status**: 🟡 **DRAFT** (2026-06-27T18:10+03:00, PM lane per orchestrator delegation)
> **Mode**: 🚀 **CONTINUOUS FLOW** (ADR-0031 owner override carry from Sprint 4-15)
> **Trigger**: Sprint 15 close-out (Issue #515 → PR #515 squash @ ebf6bc8 already merged; Sprint 15 9/9 SHIPPED + close.md drafted)
> **Sizing matrix**: TBD on Sprint 15 close-out + Issue #514 sister-pattern
> **PM lane definition (LOCKED carry from Sprint 13+)**: PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors
> **Close-out target**: docs/sprints/sprint-16/close.md (PM lane, owner ratifies)
> **Origin directive (verbatim)**: *"yeni bir feature, modül vb istemiyorum projede, artık somut bir plan ile sprintleri tamamlamamız gerek. buna göre bu sprintten sonraki sprintleri planlayalım ve plana sadık kalalım, önemli bir bug vb bulursak sonuna ekleyerek devam etmeliyiz"* (owner @ 2026-06-25). Sprint 16 is the first sprint of the **post-freeze concrete plan**.

## Goal

Consume **Sprint 15 deferred items** (4 items carried from Sprint 15 backlog.json `deferred_to_sprint_16`) + close RETRO-010 (Sprint 15 codifications) + finish d-test family expansion to 13-sister → 14-sister.

**No new features.** Scope is doctrine hardening, ADR consolidation, d-test family completion. Strict carry-forward discipline.

## Source-of-truth backlog (PM grooming)

📄 [./backlog.json](./backlog.json) — sister-pattern to Sprint 15 (joint sizing per ADR-0024)
📄 Carry-forwards: Sprint 15 `deferred_to_sprint_16` + RETRO-009 §14 + RETRO-010 (Sprint 15 codifications)

## Workshop Decisions (locked at Sprint 16 planning)

TBD on Sprint 15 close-out. Workshop will resolve:
1. **d059b timing** — companion to d061, OR defer to Sprint 17 (consolidated)?
2. **§14 NEW option (a) arch spec timing** — Sprint 16 P1 or Sprint 17 P1 (consolidated)?
3. **§2 watcher ext sequencing** — Sprint 16 P1 (after Sprint 15 §9-Lens step 4 is on main) OR Sprint 17 P2?
4. **d-test family target** — 14-sister (Sprint 16) OR 15-sister (Sprint 16+17 consolidated)?

## Committed stories (DRAFT — to be ratified on Sprint 15 close-out)

### P1 (LOCKED, agent executable) — 4 stories

1. **§2 comment-based arch verdicts watcher ext** (RETRO-009 §2)
   - Owner: @architect (spec) + @developer (impl) + @tester (sign-off)
   - Lane: `scripts/agent-watch.sh` extension (or sister-pattern file)
   - SP: ~1.0 (dev 0.75 + tester 0.25)
   - Origin: PR #509 arch 🟢 comment-based verdict missed by watcher 22min (caught by periodic_backlog_scan)
   - Doctrine: Watcher extension to detect comment-based verdicts (state=COMMENTED), not just formal review submissions
   - Dependency: ADR-0054 §9-Lens enforcement (Sprint 15 P1 #6 SHIPPED via PR #526) + RETRO-009 §2 codification
   - Cross-ref: RETRO-009 §2, Issue #414, ADR-0054, PR #509

2. **§6b CI backfill d015+d031** (RETRO-008/009 §6b)
   - Owner: @developer (CI integration) + @tester (sign-off)
   - Lane: `.github/workflows/lint-and-test.yml` paths trigger + d015+d031 d-test integration (sister-pattern to d058 in PR #511)
   - SP: ~1.0 (dev 0.75 + tester 0.25)
   - Origin: Sprint 14 deferred 2 d-tests to manage load — backfill in Sprint 16
   - Doctrine: d015 (no-standby) + d031 (claim-next-ready) d-tests reach main-branch CI parity with d058
   - Dependency: d031 TC5/6/7 expansion (Sprint 15 P1 #5 via PR #540 SHIPPED) + ADR-0038 §Work-Stream Awareness
   - Cross-ref: RETRO-008 §11, RETRO-009 §6, Issue #238, Issue #119, PR #511 sister-pattern

3. **§14 NEW option (a) arch spec** (RETRO-009 §14)
   - Owner: @architect (spec only, impl deferred to Sprint 17 consolidated)
   - Lane: `docs/decisions/ADR-0055-cluster-squash-lag.md` (new ADR) + `docs/retros/retro-009.md` §14 amendment
   - SP: ~0.25 (arch 0.25 only — spec/observation)
   - Origin: Cluster-squash batch-lag pattern (Layer 5 converges faster on cluster squashes than single PRs)
   - Doctrine: Codify the cluster-vs-single squash lag hypothesis as ADR
   - Dependency: RETRO-009 §5 (Sprint 15 P1 #4 SHIPPED via PR #529) + Issue #508 LIVE INSTANCE
   - Cross-ref: RETRO-007 watchlist entry #10 NEW (Sprint 15 P1 codification), RETRO-009 §14

4. **d059b post-squash label hygiene companion** (Sprint 15 workshop decision deferred)
   - Owner: @developer (d-test impl) + @tester (sign-off)
   - Lane: `scripts/tests/d059b-post-squash-label-hygiene.sh` (sister-pattern to d059)
   - SP: ~1.0 (dev 0.75 + tester 0.25)
   - Origin: Sprint 15 workshop decision: variant (b) companion to d061 (post-squash label hygiene §3)
   - Doctrine: Sister-pattern d-test for d061 — covers edge case where `status:*` stale persists post-squash
   - Dependency: d061 d-test (Sprint 15 P1 #3 SHIPPED via PR #536) + ADR-0048 Layer 5 race codification
   - Cross-ref: RETRO-009 §3 + §6, Issue #507, Issue #508, Issue #512, PR #502 squash, ADR-0048

### P2 (LOCKED, observation only) — 2 stories

5. **d055/d056 d-test creation** (Sprint 14 P1 cluster spec drift remediation, RETRO-007 §11)
   - Owner: @developer (d-test file creation) + @tester (sign-off)
   - Lane: `scripts/tests/d055-*.sh` + `scripts/tests/d056-*.sh` (new files, sister-pattern to d054/d058)
   - SP: ~1.0 (dev 0.75 + tester 0.25)
   - Origin: Issue #535 (Sprint 14 P1 cluster d-test spec drift) — Sprint 14 docs claimed "Sprint 14 P1 cluster added 4 d-tests (d054, d055, d056, d058)" but only d054 + d058 landed on main
   - Doctrine: d-test family 14-sister → 15-sister completion + RETRO-007 §11 codification (spec drift on claimed deliverables)
   - Dependency: d054 sister-pattern template + d058 work-stream awareness sister-pattern
   - Cross-ref: Issue #535, RETRO-007 §11, Issue #524 (STORY-023 AC4 INDEX drift sister-pattern), PR #506 (d058 impl)
   - **Status note**: Issue #535 reassigned from `agent:product-manager` to `agent:developer` in Sprint 16 plan absorption (2026-06-27, PM lane disposition)

6. **RETRO-010 ceremony** (Sprint 15 codifications dispatcher)
   - Owner: @product-manager (proposes) + @atilcan65 (owner ratifies)
   - Lane: `docs/retros/retro-010.md` (PM-owned territory, sister-pattern to RETRO-009)
   - SP: ~0.5 (PM 0.5 only)
   - Origin: Sprint 15 P0+P1+P2 SHIPPED generates new codification candidates (RETRO-010)
   - Doctrine: Codify Sprint 15 cluster-compression observation (small + targeted vs Sprint 14 P1 cluster 9/9) + d-test family 14-sister target post-Sprint 16 + any LIVE INSTANCES captured in Sprint 15 cluster
   - Cross-ref: RETRO-009 sister-pattern, Issue #514 kickoff sister-pattern, PR #515 squash

## Capacity (Sprint 16, projected)

- **architect**: 1/2 WIP (carry from Sprint 15 §9-Lens step 4 if PR #542 squash pending) + §14 NEW option (a) spec
- **developer**: 2/2 WIP idle (Sprint 15 P1 §1 + §3 + d059 SHIPPED) + d059b + §2 watcher ext impl + §6b CI backfill
- **tester**: 1/2 WIP idle (Sprint 15 P1 #5 d031 TC5/6/7 SHIPPED + d059 + d061 sign-offs SHIPPED) + d059b + §2 watcher ext + §6b CI backfill
- **product-manager**: 1/2 WIP (carry from Sprint 15 §5 RETRO-007 #10 NEW + PM lane continuation SHIPPED via PR #529) + RETRO-010 ceremony
- **orchestrator**: 1/2 WIP (Sprint 15 kickoff + RETRO-009 dispatch FIRED) + Sprint 16 kickoff coordination

## Sprint 16 totals (DRAFT, to be ratified)

- **Stories committed**: 5 (P1 4 + P2 1)
- **SP locked**: ~3.75 (within 4-5 PM top-down capacity)
- **No new features** — doctrine hardening + ADR consolidation + d-test family 14-sister
- **Cross-ref**: [./backlog.json](./backlog.json)

## Carry-forwards FROM Sprint 15 (sister-pattern doc)

```json
[
  "§2 comment-based arch verdicts watcher ext (1.0 SP) — needs PR #503 verdict template standardization first",
  "§6b CI backfill d015+d031 (1.0 SP) — defer 2 d-tests to manage load",
  "§14 NEW option (a) — arch spec filed-for-grooming, Sprint 16 sizing",
  "d059b post-squash label hygiene companion (Sprint 16 P2 candidate, variant (b) per workshop decision)"
]
```

All 4 items absorbed into Sprint 16 plan above.

## Out of scope (Sprint 16 explicit non-goals, per owner directive)

- ❌ New features / modules / surfaces (owner directive: *"yeni bir feature, modül vb istemiyorum projede"*)
- ❌ New HTTP API / persistence / front-end framework (deferred to indefinite, per tech stack section in CLAUDE.md)
- ❌ Sprint 17+ items (consolidated plan tracks them, but Sprint 16 is the working sprint)
- ❌ Bug cleanup (Sprint 20 bug-only mode, per owner directive)

## Cross-refs

- **Sprint 15 plan**: [../sprint-15/plan.md](../sprint-15/plan.md) (PM draft, owner ratifies — sister-pattern)
- **Sprint 15 backlog**: [../sprint-15/backlog.json](../sprint-15/backlog.json) (carry-forwards source)
- **Sprint 17 consolidated plan**: [../sprint-17/plan.md](../sprint-17/plan.md) (combined 17+18+19 scope per owner directive)
- **Sprint 20 bug-only plan**: [../sprint-20/plan.md](../sprint-20/plan.md) (final bug cleanup sprint per owner directive)
- **RETRO-009 codification**: [../../retros/retro-009.md](../../retros/retro-009.md) (12 candidates, Tier 1/2/3)

— @product-manager, 2026-06-27T18:10+03:00, Sprint 16 plan (PM draft, owner ratifies)