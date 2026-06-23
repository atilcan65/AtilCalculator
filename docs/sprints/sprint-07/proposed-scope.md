# Sprint 7 — Proposed Scope (PM grooming, awaiting orchestrator commit + owner approval)

> **Author:** @product-manager
> **Date:** 2026-06-23T13:30Z
> **Trigger:** Owner directive 2026-06-23T13:28Z chat ("sprint 7 yi de aç başlat") + PR #294 verdict nit 1 implicit "carry-only" disposition (user-facing deferred to Sprint 7)
> **Source:** [Sprint 6 plan](../sprint-06/plan.md) (PR #294, merged 2026-06-23T12:08:40Z), [Sprint 6 close](../sprint-05/close.md) (PR #292, merged 2026-06-23T11:06:13Z), [Sprint 4 retro](../sprint-04/RETRO-004.md) (PR #282, merged 2026-06-22T20:31:46Z)
> **Status:** 🟡 **PM PROPOSAL** — orchestrator to draft final plan, owner to approve

---

## Sprint goal (PM-proposed)

**Break the 3-sprint infra-only streak. Ship the first user-facing STORY-CLI candidates aligned with `docs/product/vision.md` P1 (Atil) success metrics M1 (accuracy) and M3 (keyboard-first) on the AtilCalculator CLI surface (ADR-0017 §Tech stack).**

Sprint 4 (18.5 SP infra-only), Sprint 5 (3.0/6.0 SP AtilCalc infra-only), Sprint 6 (10.75 SP infra-only) all shipped doctrine + tooling, **zero user-facing features**. Sprint 7 ships the **first user-facing CLI stories** that the owner can `pip install` and run end-to-end. M1 + M3 become testable against the CLI surface without waiting for the deferred HTTP surface (per ADR-0017 §Deferred).

**Sprint 7 is user-facing re-entry, not architecture reset.** All Sprint 4-6 doctrine (PR #288 §Doctrine Reminder, ADR-0038 Auto-Claim, ADR-0039 WIP-idle, ADR-0040 cross-repo) is in production. Sprint 7 consumes that infrastructure to ship user value.

---

## Committed-scope proposal (3 user-facing + 1 doctrine = 4 items, ~5.5 SP)

### P0 — User-facing CLI foundation (M1 + M3 acceptance, 4.0 SP)

| ID | Title | Owner | SP | AC scope |
|---|---|---|---|---|
| **STORY-CLI-001** | Basic arithmetic via typer CLI (`atilcalc 0.1 + 0.2` → `0.3`) | developer | 2.0 | M1 (zero float errors) + decimal precision regression (10+ parametrised cases) |
| **STORY-CLI-002** | Multi-op expressions with precedence (`atilcalc '2 + 3 * 4'` → `14`) | developer | 1.5 | operator precedence + parens + decimal propagation; extends STORY-CLI-001 |
| **STORY-CLI-003** | REPL mode interactive (`atilcalc --repl`) | developer | 1.0 | M3 spirit (keyboard-first analog), stdin/stdout, session-end on EOF/Ctrl-D |

**User-facing P0 total**: 4.5 SP

### P1 — Companion doctrine (closes Sprint 6 retro gap, 1.0 SP)

| ID | Title | Owner | SP | AC scope |
|---|---|---|---|---|
| **#296** | Peer-poke discipline: scripts/peer-poke.sh + 5-soul amendment (orchestrator impl + owner soul patch) | orchestrator + owner | 1.0 | helper script in main + 5 soul patches applied (per Issue #296 body) + 60s architect-wake regression |

**Doctrine P1 total**: 1.0 SP

### Capacity & utilization

- **Total proposed**: 5.5 SP (4.5 user-facing + 1.0 doctrine)
- **Capacity available** (per Sprint 6 plan §Capacity, continuous flow):
  - developer: 1.5 SP free (after Sprint 6 commits) → 4.5 CLI is **3.0 SP over** → will pull from Sprint 6 carry or extend window
  - architect: 1.5 SP free → not needed for CLI scope (engine-only, ADR-0017)
  - owner: 0 SP free (after Sprint 6 #293 CI wiring) → 0.5 SP #296 owner soul patch
  - orchestrator: continuous → 1.0 SP #296 work fine
  - PM: 2.0 SP grooming (no impl)
  - tester: 3.25 SP free → 1.5-2.0 SP CLI testing (d036 candidate)
- **Sprint 7 mode**: CONTINUOUS FLOW (carry from Sprint 6 doctrine) — no fixed window

**PM recommendation**: dev pulls from Sprint 6 P2 carry (#193, #194, #198, #293) deferral to free 3.0 SP for CLI. Total Sprint 7 = 5.5 SP CLI+doctrine + 3.0 SP deferred P2 = 8.5 SP aggregate.

### Sprint 7 P2 carry candidate (deferred from Sprint 6, P2 priority)

| ID | Title | Owner | SP | Why defer |
|---|---|---|---|---|
| #193 | ADR-0030 deviation runner user | architect | 0.5 | P2 cleanup, not user-facing |
| #194 | Symlink cleanup RCA-17 | architect | 0.5 | P2 cleanup, not user-facing |
| #198 | #48.1 template port | developer | 1.0 | P2 template port, not user-facing |
| #293 | Cross-repo PR auto-close (Option B) | arch+dev+owner+tester | 1.5 | Doctrine gap, not user-facing |

**P2 deferred total**: 3.5 SP (orchestrator's call whether to carry to Sprint 7 or Sprint 8)

---

## Why these stories (PM rationale)

### STORY-CLI-001 (basic arithmetic) — **M1 acceptance, the highest-priority M-metric**

- `docs/product/vision.md` M1: "First MVP ships with zero float errors. Acceptance test `0.1 + 0.2 == 0.3` passes, alongside a broader parametrised regression suite covering decimal precision edge cases."
- ADR-0017: typer CLI scaffold + decimal.Decimal (stdlib) — perfect for M1.
- P1 (Atil) pain point: "Float errors showing up in routine arithmetic (`0.1 + 0.2`, compound interest, percentage chains)."
- Already-deployed engine: Sprint 1 STORY-002 (PR #26) shipped the 4-op engine with decimal precision. CLI is a thin typer wrapper.

### STORY-CLI-002 (precedence) — **M1 extension, natural next step**

- Builds on STORY-CLI-001; reuses engine. ~0.5 day for dev.
- Persona P1 uses "engineering arithmetic" — precedence is essential.
- 10+ test cases: `2+3*4=14`, `(2+3)*4=20`, `1+2+3+4*5=26`, etc.

### STORY-CLI-003 (REPL) — **M3 spirit, keyboard-first analog**

- `docs/product/vision.md` M3: "All basic operations (digit entry, operators, equals, clear, delete, history nav) are reachable using the keyboard only."
- Web surface is deferred (ADR-0017). CLI REPL is the **keyboard-first analog** that Atil can use today, without waiting for HTTP/Web.
- 5-120 second session duration per P1 profile → REPL fits.

### Issue #296 (peer-poke discipline) — **Doctrine gap surfaced Sprint 5-6**

- Orchestrator's 12:50Z miss (Telegram-only poke to architect) is the trigger.
- Owner directive 2026-06-23T12:55Z: "adam gibi poke etmeyi öğrenmelisin."
- Sprint 7 P0 doctrine (not user-facing) — but **blocks Sprint 8+ agent productivity**, so it ships with the CLI drop.

---

## Out of scope (Sprint 7)

- HTTP surface (FastAPI, ADR-0017 §Deferred) — Sprint 8+ candidate
- Web UI components (ADR-0018 front-end) — Sprint 8+ candidate, paired with HTTP
- History persistence (STORY-007) — already shipped Sprint 2 in HTTP surface; CLI history is separate (future)
- Skins (M4) — Web-only, deferred
- Multi-user (P2) — explicit out per vision §Out-of-scope
- Cross-repo PR auto-close impl (Sprint 6 #293) — defer to Sprint 8 (after Sprint 6 lead ADRs Accepted)
- Sprint 6 P2 carry (#193, #194, #198) — orchestrator's call (defer to Sprint 7 P2 or Sprint 8)

---

## Risks

1. **Developer capacity tightness**: 4.5 SP CLI work + 1.0 SP #296 + 1.0 SP #198 (if not deferred) = 6.5 SP dev work. Sprint 6 plan reserved 8 SP dev, 6.5 committed. **Pulling #198 to Sprint 7 P2 frees 1.0 SP for CLI**. Net: 5.5 SP CLI+doctrine work fits dev 8 SP capacity (with carry deferrals).
2. **No HTTP surface yet**: M1 + M3 are web-vision metrics. CLI surface satisfies the SPIRIT of M1 (decimal precision) and M3 (keyboard-only) without the HTTP UI. Owner should accept this as a Sprint 7 milestone even though strict M1+M3 web compliance is Sprint 8+.
3. **#296 owner soul patch dependency**: 5-soul amendment is owner-only territory (file ownership matrix). Sprint 7 cannot start #296 work in earnest until owner carves time.
4. **STORY-CLI-002 depends on STORY-CLI-001**: PM proposes strict dependency; Sprint 7 fails if STORY-CLI-001 doesn't land.

---

## Sprint 7 ceremony plan (PM proposal)

1. **Day 0 (now, 2026-06-23)**: PM files STORY-CLI-001/002/003 as new GitHub issues (per PM soul doc §Backlog grooming).
2. **Day 0+1**: Architect reviews STORY-CLI-001/002/003 for design impact (likely minor — engine + typer scaffold already in place).
3. **Day 1**: Dev sizes each (1-3 SP), tester estimates d036 (CLI regression test count).
4. **Day 1**: Orchestrator drafts `docs/sprints/sprint-07/plan.md` from this proposal + sizing verdicts.
5. **Day 1**: Owner approves plan → Sprint 7 active.
6. **Day 1-5**: Dev implements STORY-CLI-001 → 002 → 003 in sequence; tester parallel-writes d036.
7. **Day 5-7**: Orchestrator implements #296 helper script; owner applies 5-soul patch in parallel.
8. **Day 7+**: All 4 items Ready → owner merge cycle → Sprint 7 close.

---

## PM commitments

- **Now (2026-06-23T13:30Z)**: file STORY-CLI-001, STORY-CLI-002, STORY-CLI-003 as new GitHub issues (PM-authored, AC settled).
- **Day 1**: update `docs/backlog.json` + this `proposed-scope.md` with sizing verdicts from dev+tester.
- **Sprint 7 active**: monitor STORY-CLI-001/002/003 progress; address scope drift; coordinate with dev+tester on AC.
- **Sprint 7 close**: file Sprint 7 retro candidates.

---

## Open questions for owner / orchestrator

1. **Owner**: Approve Sprint 7 user-facing re-entry? (Yes implied by chat "sprint 7 yi de aç başlat".)
2. **Orchestrator**: Confirm CONTINUOUS FLOW mode for Sprint 7 (carry from Sprint 4-6 doctrine).
3. **Orchestrator**: Defer Sprint 6 P2 carry (#193, #194, #198, #293) to Sprint 7 P2 / Sprint 8?
4. **Owner**: Carve time for 5-soul amendment (#296) — owner-only territory.
5. **Dev**: Accept STORY-CLI-001/002/003 sizing estimates (subject to dev sizing ceremony Day 1).

— @product-manager, 2026-06-23T13:30Z, Sprint 7 proposed scope (4 items, 5.5 SP, user-facing re-entry)
