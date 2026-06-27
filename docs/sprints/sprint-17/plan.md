# Sprint 17 — Plan (CONSOLIDATED 17+18+19 scope, PM draft, owner ratifies)

> **Status**: 🟡 **DRAFT** (2026-06-27T18:15+03:00, PM lane per orchestrator delegation)
> **Mode**: 🚀 **CONTINUOUS FLOW** (ADR-0031 owner override carry from Sprint 4-16)
> **Origin directive (verbatim)**: *"17 18 19 birleştir planda, sonra bug olursa 20 de bugları temizler tamamlarız"* (owner @ 2026-06-27)
> **Sister-pattern**: Sprint 16 plan [../sprint-16/plan.md](../sprint-16/plan.md) + Sprint 14 plan [../sprint-14/plan.md](../sprint-14/plan.md)
> **PM lane definition (LOCKED carry from Sprint 13+)**: PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors
> **Close-out target**: docs/sprints/sprint-17/close.md (PM lane, owner ratifies)

## Goal

**CONSOLIDATED SPRINT** — combines Sprint 17 + Sprint 18 + Sprint 19 from the original 3-sprint proposal into ONE sprint per owner directive 2026-06-27. Scope: **remaining backlog from Sprint 16 deferrals + doctrine hardening tail-end + d-test family 15-sister → 16-sister completion + RETRO-011 ceremony + final soul file amendments**.

**No new features.** This is the doctrine/ADR/d-test finishing sprint before Sprint 20 bug cleanup.

## Source-of-truth backlog (PM grooming)

📄 [./backlog.json](./backlog.json) — sister-pattern to Sprint 15/16 (joint sizing per ADR-0024)

## Workshop Decisions (locked at Sprint 17 planning)

TBD on Sprint 16 close-out. Workshop will resolve:
1. **§14 NEW option (a) impl timing** — Sprint 16 spec, Sprint 17 impl (LOCKED in plan, but confirm)
2. **d-test family target** — 15-sister (Sprint 16+17) OR 16-sister (Sprint 16+17) OR 17-sister (Sprint 16+17+20)?
3. **Soul file finalization scope** — last amendments before project close (which soul files, which sections)?
4. **RETRO-011 ceremony scope** — Sprint 16 codifications dispatcher (final retro?)

## Committed stories (DRAFT — to be ratified on Sprint 16 close-out)

### P1 (LOCKED, agent executable) — 4 stories

1. **§14 NEW option (a) impl** (RETRO-009 §14 cluster-squash batch-lag codification)
   - Owner: @architect (impl) + @developer (script impl) + @tester (sign-off)
   - Lane: `scripts/post-squash/cluster-lag-detector.sh` (new file, sister-pattern to §3 post-squash label hygiene)
   - SP: ~1.5 (arch 0.5 + dev 0.75 + tester 0.25)
   - Origin: Sprint 16 P1 §14 NEW option (a) arch spec only → Sprint 17 impl per workshop decision
   - Doctrine: Tooling-level detection of cluster-vs-single squash lag — observer script logs cluster-squash timestamps, generates RETRO-011 cluster-lag section
   - Dependency: Sprint 16 ADR-0055 cluster-squash-lag.md spec (Sprint 16 P1 #3 SHIPPED) + RETRO-009 §5 (Sprint 15 P1 codification)
   - Cross-ref: RETRO-009 §14, RETRO-007 watchlist #10 NEW, Issue #508 LIVE INSTANCE, ADR-0055, PR #529

2. **d-test family 16-sister completion** (remaining d-test ID slots)
   - Owner: @developer (d-test file creation) + @tester (sign-off)
   - Lane: `scripts/tests/d062-*.sh` + `scripts/tests/d063-*.sh` (new files, sister-pattern)
   - SP: ~1.5 (dev 1.0 + tester 0.5)
   - Origin: Sprint 16 d-test family target 14-sister, Sprint 17 target 16-sister (2 new d-tests)
   - Doctrine: d-test family completeness — covers remaining RETRO-009 candidates with codification potential
   - Dependency: Sprint 16 d-test family 14-sister SHIPPED + RETRO-010 ceremony feedback
   - Cross-ref: RETRO-009 §6 family persistence, RETRO-010 candidates, ADR-0049 §d-test framework

3. **Final soul file amendments** (PM + arch + dev + tester soul finalization)
   - Owner: @product-manager + @architect + @developer + @tester (lane ownership) + @atilcan65 (owner merges all)
   - Lane: `.claude/agents/*.md` (human-only territory, agents propose via PR)
   - SP: ~2.0 (PM 0.5 + arch 0.5 + dev 0.5 + tester 0.5 — joint effort)
   - Origin: Sprint 16 RETRO-010 codification candidates + Sprint 17 final doctrine hardening pass
   - Doctrine: Codify all RETRO-010 + RETRO-011 candidates into soul files before project close
   - Dependency: RETRO-010 SHIPPED + Sprint 16 close-out + RETRO-011 SHIPPED (after Sprint 17 work)
   - Cross-ref: All soul file amendment PRs (Sprint 13-17 lineage: PR #473, #499, #515, #529, #542, +Sprint 16/17 amendments)

4. **§14 NEW option (a) d-test** (cluster-squash batch-lag detection sister-pattern)
   - Owner: @developer (d-test impl) + @tester (sign-off)
   - Lane: `scripts/tests/d064-cluster-lag.sh` (new file, sister-pattern to d059b/d061)
   - SP: ~1.0 (dev 0.75 + tester 0.25)
   - Origin: Sprint 17 §14 NEW option (a) impl requires sister-pattern d-test (RETRO-009 §6 sister-pattern discipline)
   - Doctrine: d-test family 17-sister carrier (16 + d064)
   - Dependency: §14 NEW option (a) impl (Sprint 17 P1 #1) + d061 sister-pattern
   - Cross-ref: RETRO-009 §6, ADR-0049, RETRO-009 §14, ADR-0055

### P2 (LOCKED, ceremony) — 2 stories

5. **RETRO-011 ceremony** (Sprint 16 codifications dispatcher, final substantive retro)
   - Owner: @product-manager (proposes) + @atilcan65 (owner ratifies)
   - Lane: `docs/retros/retro-011.md` (PM-owned territory, sister-pattern to RETRO-010)
   - SP: ~0.5 (PM 0.5 only)
   - Origin: Sprint 16 close-out codification candidates
   - Doctrine: Codify Sprint 16 doctrine hardening + d-test family 14/15/16-sister path + any LIVE INSTANCES captured in Sprint 16 cluster + RETRO-009 §6 family persistence closure
   - Cross-ref: RETRO-010 sister-pattern, Issue #514 kickoff sister-pattern lineage

6. **§17 PM lane close-out + Sprint 18/19 carry-forward closure** (consolidated sprint final ceremony)
   - Owner: @product-manager (proposes) + @atilcan65 (owner ratifies)
   - Lane: `docs/sprints/sprint-17/close.md` (PM lane, sister-pattern to Sprint 16 close)
   - SP: ~0.5 (PM 0.5 only)
   - Origin: Consolidated sprint close-out absorbs Sprint 18 + Sprint 19 close ceremony (per owner directive)
   - Doctrine: Final consolidated sprint close — marks Sprint 18 + Sprint 19 as "consolidated into Sprint 17" in close.md history
   - Cross-ref: Sprint 16 close sister-pattern, Sprint 14 close template, Sprint 15 close template

## Capacity (Sprint 17, projected)

- **architect**: 2/2 WIP (Sprint 16 §14 NEW option (a) spec + 1 soul amendment → Sprint 17 impl + final soul amendment)
- **developer**: 2/2 WIP (Sprint 16 §2 watcher ext + d059b + §6b CI backfill → Sprint 17 §14 impl + d-test family + d064)
- **tester**: 2/2 WIP (Sprint 16 d059b + §2 + §6b sign-offs → Sprint 17 d-test family + d064 + final soul amendment)
- **product-manager**: 2/2 WIP (Sprint 16 RETRO-010 + PM lane continuation → Sprint 17 RETRO-011 + Sprint 17 close)
- **orchestrator**: 2/2 WIP (Sprint 16 kickoff + RETRO-010 dispatch → Sprint 17 kickoff + RETRO-011 dispatch)

## Sprint 17 totals (DRAFT, to be ratified)

- **Stories committed**: 6 (P1 4 + P2 2)
- **SP locked**: ~7.0 (within 8.5-10.0 PM top-down capacity, larger sprint due to consolidation)
- **No new features** — final doctrine/ADR/d-test finishing sprint
- **Cross-ref**: [./backlog.json](./backlog.json)

## Carry-forwards FROM Sprint 16 (sister-pattern doc)

```json
[
  "§14 NEW option (a) impl (1.5 SP) — Sprint 16 spec, Sprint 17 impl per workshop",
  "d-test family 16-sister completion (1.5 SP) — 2 new d-tests",
  "Final soul file amendments (2.0 SP) — all 4 lanes",
  "d064 cluster-lag d-test (1.0 SP) — sister-pattern to d059b/d061",
  "RETRO-011 ceremony (0.5 SP) — Sprint 16 codifications dispatcher",
  "Sprint 17 close (0.5 SP) — absorbs Sprint 18+19 close"
]
```

All 6 items absorbed into Sprint 17 plan above.

## Out of scope (Sprint 17 explicit non-goals, per owner directive)

- ❌ New features / modules / surfaces (owner directive: *"yeni bir feature, modül vb istemiyorum projede"*)
- ❌ New HTTP API / persistence / front-end framework (deferred to indefinite)
- ❌ Sprint 20 bug cleanup (separate sprint, bug-only mode)
- ❌ Project close ceremony (that happens after Sprint 20 closes)

## Cross-refs

- **Sprint 16 plan**: [../sprint-16/plan.md](../sprint-16/plan.md) (immediate predecessor)
- **Sprint 16 backlog**: [../sprint-16/backlog.json](../sprint-16/backlog.json) (carry-forwards source)
- **Sprint 20 bug-only plan**: [../sprint-20/plan.md](../sprint-20/plan.md) (final bug cleanup sprint per owner directive)
- **RETRO-010 codification**: [../../retros/retro-010.md](../../retros/retro-010.md) (Sprint 15 codifications, sister-pattern to RETRO-011)
- **RETRO-009 codification**: [../../retros/retro-009.md](../../retros/retro-009.md) (Sprint 14 codifications)

— @product-manager, 2026-06-27T18:15+03:00, Sprint 17 (consolidated 17+18+19 scope) plan (PM draft, owner ratifies)