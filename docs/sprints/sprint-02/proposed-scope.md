# Sprint 2 — Proposed Scope (PM grooming, awaiting sizing ceremony)

> **Status:** 🟡 PM-groomed from Issue #68 (Sprint 2 kickoff).
> **Source for backlog:** [`docs/sprints/sprint-02/backlog.json`](./backlog.json) (6 PM-authored feature stories).
> **Sprint window:** 2026-07-01 → 2026-07-15 (14 days).
> **Capacity:** 5 agents × 14 days ≈ 35-45 SP (matching Sprint 1 template).
> **Proposed total:** **23 SP** (51-66% capacity utilisation — comfortable buffer for unplanned work, ceremony time, and on-call).
> **Already-accepted context (not in commit):** Sprint 1 stories all DONE; ADR-0017/0018/0019 Accepted; ADR-0020/0021 just Accepted via PR #62 merge.

---

## Sprint goal (PM framing)

**Close MVP-1**: ship the user-visible features that satisfy M2 (daily-use stickiness), M4 (skin system), and M5 (history performance) from `vision.md`, plus extend the engine to scientific functions (vision §Top-3-to-5 "bilimsel fonksiyon destekli"). The foundation is shipped; Sprint 2 is about *delight and depth*, not scaffolding.

---

## Committed stories — PM proposed (Fibonacci, sizing-pending)

| Story | Title | Priority | PM SP | Vision metric | ADR refs |
|---|---|---|---|---|---|
| STORY-007 | Persistent cross-device history (SQLite backend) | P0 | **5** | M2 + M5 | ADR-0019 §GET/POST /api/history, R-5 (Sprint 2 P1) |
| STORY-008 | History UI wiring (render + search + click-to-load) | P0 | **3** | M2 + M5 | ADR-0018, ADR-0019 |
| STORY-009 | Skin system — ≥3 built-in skins + mode-toggle wired | P1 | **5** | M4 | ADR-0019 §GET/PUT /api/skin |
| STORY-010 | Skin preference persistence (cross-session + cross-device) | P1 | **3** | M4 cross-device | ADR-0019 §PUT /api/skin + R-5 |
| STORY-011 | Scientific functions (trig / log / √ / !) — engine + UI | P1 | **5** | M2 (broader workflows) | ADR-0017, ADR-0019 §Exception taxonomy |
| STORY-012 | Owner-facing docs (README + in-app help + USER-GUIDE) | P2 | **2** | M2 (lower friction) | — |
| **Proposed total** | | | **23 SP** | | |

**Sizing rule applied:** per `product-manager.md` §Hard Rules, all stories ≤5 SP. Largest 5-SP stories (STORY-007/009/011) are split-bounded — they fit naturally at the FastAPI layer / Web Component layer / engine layer respectively and can be cut along those boundaries if sizing ceremony demands.

**Capacity buffer:** 12-22 SP remaining (35-45 - 23) for unplanned work + Sprint 2 ceremonies + on-call. Architect-owned chore work (ADR-0020/0021 implementation PR, Issues #46/#47 follow-up, #65 dependency reclassification, #45 STATUS block as action driver) is **separate capacity** — tracked in their own issues, sized at Sprint 2 planning alongside this backlog.

---

## Vision traceability

| Metric (vision.md) | Sprint 1 status | Sprint 2 stories | Sprint 3+ deferred |
|---|---|---|---|
| **M1 — Accuracy** (0.1+0.2 = 0.3, zero float errors) | ✅ DONE (PR #26) | — | — |
| **M2 — Stickiness** (≥5/day × 7 days, ≥35 records/week) | ⏳ In-memory deque | **STORY-007** + **STORY-008** + **STORY-011** | Polish + telemetry |
| **M3 — Keyboard-only** (all basic ops reachable) | ✅ DONE (PR #49) | (extended in **STORY-011** for sci) | — |
| **M4 — Skin transition** (<500ms, ≥3 skins, persistent) | ⏳ Single hardcoded skin | **STORY-009** + **STORY-010** | Skin marketplace? (out of MVP per vision §Out-of-scope) |
| **M5 — History perf** (<100ms × 1000+ records, search, click-to-load) | ⏳ In-memory deque | **STORY-007** (backend) + **STORY-008** (UI) | Real-data perf validation (1-week post-launch) |

**Sprint 2 outcome**: M1+M3 fully validated in Sprint 1; Sprint 2 targets M2+M4+M5. After Sprint 2, all M1-M5 metrics have shipped features. Sprint 3+ is polish + real-data validation + (optionally) extending to P2 personas.

---

## Dependency DAG (Sprint 2 commit order)

```
R-5 Persistence layer ADR (architect to draft Sprint 2 P1)
  │
  ▼
STORY-007 Persistent history (5 SP)  ◄── backend SQLite + GET/POST /api/history
  │
  ▼
STORY-008 History UI wiring (3 SP)   ◄── rewire <atilcalc-history> to backend

STORY-009 Skin system (5 SP)         ◄── independent (in-memory skin store MVP-1)
  │
  ▼
STORY-010 Skin preference persistence (3 SP)  ◄── extend to SQLite or R-5 backend

STORY-011 Scientific functions (5 SP)  ◄── independent (engine extension)

STORY-012 Docs pass (2 SP)            ◄── independent (parallel track)

ADR-0020/0021 implementation PR (architect + developer, chore — not in this backlog)
```

Sprint 2 sequencing:
1. **R-5 ADR** (architect, parallel to STORY-007 spec draft)
2. **STORY-007** starts (depends on R-5 closing)
3. **STORY-009** starts (independent, can run in parallel with 007)
4. **STORY-011** starts (independent, can run in parallel with 007/009)
5. **STORY-008** starts after STORY-007 PR ready
6. **STORY-010** starts after STORY-009 PR ready
7. **STORY-012** continuous, merged with each feature PR

---

## Risks & mitigations

| Risk | Severity | Mitigation | Owner |
|---|---|---|---|
| R-5 ADR scope-creep (SQLite vs JSON vs file-KV vs RocksDB) blocks STORY-007 | P0 | Architect commits to R-5 draft within Sprint 2 P1 (per Issue #68 spec, by Sprint 2 P1); PM pings if no draft by 2026-07-03. | @architect |
| STORY-007 + STORY-010 both want SQLite backend — duplication risk | P1 | R-5 ADR scopes one backend; PM recommends shared SQLite for simplicity (no Redis in MVP). | @architect |
| STORY-011 scientific functions tokenizer ambiguity (`sin(45)` vs `sin 45` vs `45 sin`) | P1 | PM proposes `sin(45)` (function-call form, matches math notation); architect + developer ratify at sizing. | @architect + @developer |
| STORY-011 `DomainError` exception vs `UndefinedOperatorError` reuse | P2 | PM recommends new `DomainError` subclass for semantic clarity; architect decides. ADR-0019 amendment (PR #63) is the right venue. | @architect |
| Owner review bandwidth — Sprint 1 was 7 PRs to owner; Sprint 2 may be 6+ | P1 | PM pings ahead per feature; STORY-012 docs PR is single-line edits, low bandwidth. | @orchestrator + PM |
| Sprint 1 retro not yet written (`docs/sprints/sprint-01/retrospective.md`) | P2 | Sprint 1 plan.md §Definition of Done #3 — orchestrator + PM should write retro before Sprint 2 kickoff. PM can draft if asked. | @orchestrator + PM |
| Sprint 2 chore scope (ADR-0020/0021 impl, Issues #46/#65/#45) inflates capacity | P1 | Chore work sized separately from this PM backlog; orchestrator publishes final scope post-sizing. | @orchestrator |
| M4 WCAG AAA contrast in all 3 skins × 6 Web Components | P2 | STORY-009 AC7 codifies contrast verification; visual QA at sizing. | @developer + architect |

---

## Definition of Done (sprint-level)

Sprint 2 is **DONE** when ALL of:

1. All 6 committed stories merged to main with owner approval.
2. CI green on main post-merge.
3. `docs/sprints/sprint-02/retrospective.md` written.
4. Sprint 3 backlog drafted (grooming-ready).
5. M2 + M4 + M5 metrics validated with real data (proxy: ≥7 days post-launch owner usage).
6. No new P0/P1 bugs filed against Sprint 2 stories within 24h.

---

## Cross-cutting dependencies (Sprint 2 P1, parallel to this PM backlog)

These are architect/developer-owned chore stories tracked in their own issues, NOT in this PM-authored feature backlog. They will be sized into the final Sprint 2 plan at the sizing ceremony:

- **Issue #47** (P0) — Long-term label hygiene doctrine + transactional edits. ADR-0020/0021 just Accepted via PR #62; implementation PR (wrapper + watchdog + 5 soul doc amendments + d009 + d010) is Sprint 2 P1. Closes Issue #46 (stale-cc watchdog spam) when shipped.
- **Issue #65** (chore) — Reclassify `fastapi` + `uvicorn` from `[dev]` extra to runtime dependencies (post VM apply 2026-06-18 owner decision). Trivial 1 SP.
- **Issue #45** (chore) — STATUS block as action driver (orchestrator proactive mode B). Developer-owned, separate flow.
- **Issue #48** (P1) — Template port: Sprint 1 lessons → dev-studio-template. Gate: post-Sprint-1 validation (PM just shipped Sprint 1 retro input via this proposed-scope). Sprint 3+ stretch likely.

---

## PM next actions (this PR's exit)

1. **This docs PR opens** with `docs/sprints/sprint-02/backlog.json`, `docs/sprints/sprint-02/proposed-scope.md`, and 6 user story files in `docs/backlog/`.
2. **Auto-ping orchestrator** with sizing ceremony signal.
3. **6 GitHub issues opened** (one per story) with the 4-cat label invariant per ADR-0012 (and per product-manager.md §Handoff Discipline for new stories: `agent:tester cc:tester` so tester writes the test plan first).
4. **Atomic hand-off on Issue #68**: flip `agent:product-manager` → `agent:orchestrator` + `cc:orchestrator` (per ADR-0015). Orchestrator's turn: run sizing ceremony with @architect + @developer + @tester, then publish `docs/sprints/sprint-02/plan.md` (committed scope) per Issue #68 §Task.
5. **PM stays in polling mode** for sizing comments on the 6 stories + Issue #68 status updates.

---

## Change log

- **2026-06-18T13:50Z** — Initial draft. PM-groomed from Issue #68 (Sprint 2 kickoff). 6 PM-authored feature stories, 23 SP proposed, comfortable capacity buffer. Chore work (Issues #46, #47, #65, #45, #48) tracked separately. Awaiting sizing ceremony + owner commit.