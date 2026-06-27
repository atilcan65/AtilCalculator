# Sprint 20 — Plan (BUG-ONLY MODE, PM draft, owner ratifies)

> **Status**: 🟡 **DRAFT** (2026-06-27T18:18+03:00, PM lane per orchestrator delegation)
> **Mode**: 🚀 **CONTINUOUS FLOW** (ADR-0031 owner override carry from Sprint 4-17)
> **Origin directive (verbatim)**: *"17 18 19 birleştir planda, sonra bug olursa 20 de bugları temizler tamamlarız"* (owner @ 2026-06-27)
> **Sister-pattern**: Sprint 17 consolidated plan [../sprint-17/plan.md](../sprint-17/plan.md)
> **PM lane definition (LOCKED carry from Sprint 13+)**: PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors
> **Close-out target**: docs/sprints/sprint-20/close.md (PM lane, owner ratifies) — **PROJECT CLOSE**

## Goal

**BUG-ONLY SPRINT** — final sprint before project close. **NO NEW FEATURES, NO NEW MODULES, NO NEW DOCTRINE HARDENING.** Strict scope: bug cleanup only.

Per owner directive: *"sonra bug olursa 20 de bugları temizler tamamlarız"* — if bugs arise, we'll clean them in Sprint 20 and finish.

This sprint exists to:
1. Clean any bugs filed in Sprint 15-17 cluster work
2. Triage any user-reported issues (if any)
3. Close out the project cleanly with `docs/sprints/sprint-20/close.md` documenting project completion

## Source-of-truth backlog (PM grooming)

📄 [./backlog.json](./backlog.json) — sister-pattern to Sprint 17 (joint sizing per ADR-0024)

## Workshop Decisions (locked at Sprint 20 planning)

TBD on Sprint 17 close-out. Workshop will resolve:
1. **Bug triage policy** — P0/P1/P2 prioritization for any new bugs filed
2. **Sprint capacity** — depends on bug count (could be 0 SP if no bugs, or up to 5 SP if heavy bug load)
3. **Project close ceremony** — final `close.md` structure + project-completion announcement

## Committed stories (DRAFT — to be ratified on Sprint 17 close-out)

### P0 (LOCKED, project-completion-critical) — 0 stories (placeholder)

> Sprint 20 P0 placeholder: **conditional on bugs filed**. If P0 bugs exist, they go here.

### P1 (LOCKED, bug cleanup) — 0 stories (placeholder)

> Sprint 20 P1 placeholder: **conditional on bugs filed**. If P1 bugs exist, they go here.

### P2 (LOCKED, project close ceremony) — 1 story

1. **§20 PM lane close-out + PROJECT CLOSE ceremony**
   - Owner: @product-manager (proposes) + @atilcan65 (owner ratifies)
   - Lane: `docs/sprints/sprint-20/close.md` (PM lane, FINAL project close)
   - SP: ~0.5 (PM 0.5 only — even if no bugs, this story ships)
   - Origin: Owner directive final sprint + project completion
   - Doctrine: Documents project completion + final d-test family verification + sprint lineage summary (Sprint 1 → Sprint 20)
   - Cross-ref: All previous close.md templates (Sprint 14, 15, 16, 17 sister-pattern)
   - **This story ships regardless of bug count**

## Capacity (Sprint 20, projected — CONDITIONAL ON BUGS)

- **architect**: 0/2 WIP idle (Sprint 17 final soul amendment SHIPPED) → 2/2 WIP available for bug triage
- **developer**: 0/2 WIP idle (Sprint 17 §14 NEW option (a) impl + d-test family + d064 SHIPPED) → 2/2 WIP available for bug fixes
- **tester**: 0/2 WIP idle (Sprint 17 d-test family + d064 sign-offs SHIPPED) → 2/2 WIP available for bug regression tests
- **product-manager**: 0/2 WIP idle (Sprint 17 RETRO-011 + Sprint 17 close SHIPPED) → 2/2 WIP available for project close ceremony
- **orchestrator**: 0/2 WIP idle (Sprint 17 kickoff + RETRO-011 dispatch FIRED) → 2/2 WIP available for Sprint 20 kickoff coordination

## Sprint 20 totals (DRAFT, CONDITIONAL — to be ratified on Sprint 17 close-out)

- **Stories committed**: 1 minimum (P2 PM close), up to ~5-7 SP if bug load is heavy
- **SP locked**: 0.5 minimum (just close ceremony), up to 5-7 SP if bugs
- **Strict bug-only mode** — NO new features, NO new doctrine hardening
- **Cross-ref**: [./backlog.json](./backlog.json)

## Carry-forwards FROM Sprint 17

```json
[
  "§20 PM lane close-out + PROJECT CLOSE (0.5 SP — ships unconditionally)",
  "Bug inventory from Sprint 15-17 cluster work (TBD count, conditional)"
]
```

## Out of scope (Sprint 20 EXPLICIT non-goals, per owner directive)

- ❌ **NEW features / modules / surfaces** (owner directive: *"yeni bir feature, modül vb istemiyorum projede"*)
- ❌ **NEW doctrine hardening** (Sprint 17 final soul amendments are the LAST)
- ❌ **NEW ADR filings** (all ADRs that will exist are filed by Sprint 17 close)
- ❌ **NEW d-tests** (Sprint 17 = 17-sister, FINAL)
- ❌ **NEW retros** (RETRO-011 is the FINAL substantive retro)
- ❌ **Project expansion / new roadmap** (project ENDS after Sprint 20 close)

## Cross-refs

- **Sprint 17 consolidated plan**: [../sprint-17/plan.md](../sprint-17/plan.md) (immediate predecessor)
- **Sprint 17 backlog**: [../sprint-17/backlog.json](../sprint-17/backlog.json) (carry-forwards source)
- **Sprint 16 plan**: [../sprint-16/plan.md](../sprint-16/plan.md) (doctrine hardening sprint)
- **Sprint 15 plan**: [../sprint-15/plan.md](../sprint-15/plan.md) (RETRO-009 cluster sprint)
- **RETRO-011 codification**: [../../retros/retro-011.md](../../retros/retro-011.md) (final substantive retro)

— @product-manager, 2026-06-27T18:18+03:00, Sprint 20 (bug-only mode) plan (PM draft, owner ratifies) — **PROJECT CLOSE SPRINT**