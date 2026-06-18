# Sprint 2 — MVP-1 Features (2026-07-01 → 2026-07-15, 14 days)

> **Status:** 🟢 ACTIVE — kickoff complete, sizing ceremony closed (Issue #76, 2026-06-18T14:48Z)
> **Scope source of truth:** [backlog.json](backlog.json) — 25 SP feature stories + 6 SP architect pre-work
> **Capacity:** 5 agents × 14 days ≈ 35-45 SP (Sprint 1 baseline)
> **Sprint goal:** Ship MVP-1 features — history persistence (M2/M5), skin system (M4), scientific functions (M2) — closing the M2/M4/M5 metrics from vision.md.
> **Last actuals update:** 2026-06-18T14:50Z (sizing verdicts compiled)

---

## Sprint Goal

Ship MVP-1 features that close vision.md M2/M4/M5 metrics:

- **M2** (daily-use stickiness): ≥35 evals/week/owner, history persistence for cross-session recall
- **M4** (cross-device + skin): ≥3 skins with cross-device preference persistence
- **M5** (history performance): <50ms p99 latency, <100ms p95 substring search on 1000+ records

Architecture decisions from Sprint 1 (ADR-0017, ADR-0018, ADR-0019, ADR-0020, ADR-0021) provide the contract surface. Sprint 2 closes MVP-1 by filling in the deferred persistence + frontend theming + scientific precision layers.

---

## Sprint 2 actuals (live, day -13)

**Backlog**: 6 stories, 25 SP final (PM 23 + dev +2 on STORY-011 for mpmath precision).
**Architect pre-work**: 6 SP equivalent (R-5 + R-2 + ADR-0019 amendment ADRs), delivered in parallel to feature work.
**Carry-over from Sprint 1** (separate from this backlog, tracked in #46/#65/#48):
- Issue #46 — TD-006 root cause fix (architect design done via PR #62; developer implements)
- Issue #65 — Reclassify fastapi+uvicorn from [dev] to runtime deps (architect's PR #66 in review)
- Issue #48 — Template port (gate: post-Sprint-1 validation)

**Sprint 1 closed status** (referenced for context):
- P0 burn-down: 6/6 ✅ (STORY-001 VM hardening, STORY-002 engine, STORY-003a/003b web shell, doctrine gap, TD-009 worktrees)
- Production: live at http://192.168.1.199:8000 (192.168.1.199)
- Sprint 1 retro: pending (to be written post-Sprint-1-close-out; gate in #48)

---

## Capacity & commitment

- **Sprint length:** 14 days (2026-07-01 → 2026-07-15)
- **Agent capacity:** 5 agents × 14 days ≈ 35-45 SP
- **Committed feature stories:** 6 (25 SP)
- **Architect pre-work:** 6 SP equivalent (parallel to implementation)
- **Buffer:** 10 SP for carry-over + unplanned work + ceremonies

---

## Committed stories (must-have)

### STORY-007 — Persistent cross-device history (SQLite backend) [P0]

**Owner:** @developer (writes) + @tester (test plan first, then signoff) + @architect (R-5 ADR)
**Why P0:** vision M2/M5 — history persistence is the load-bearing feature for daily-use stickiness. ADR-0019 §GET /api/history and §POST /api/history define the API contract; R-5 ADR selects the storage backend.

**Acceptance criteria:**
- [ ] R-5 persistence layer ADR merged (architect, ~3 SP equivalent)
- [ ] `GET /api/history` returns paginated history (cursor-based, ADR-0019 §Pagination shape verified with PM)
- [ ] `POST /api/history` with `Idempotency-Key` header (cached response within 60s window)
- [ ] Decimal serialization lossless: `Decimal("105.00")` round-trip = `"105.00"` (NOT `"105"`, per ADR-0019 trailing-zero rule, PR #63)
- [ ] Cross-device: two TestClient instances pointing at same DB see the same records
- [ ] Durability: write → close DB → reopen → records intact
- [ ] Test isolation: autouse `_temp_db` fixture with `tmp_path` + cleanup
- [ ] Adversarial probes: SQL injection (`'; DROP TABLE history;--`), Unicode (emoji/RTL/NULL byte), concurrent writes, DB lock, corrupted SQLite file
- [ ] Decimal stored as TEXT (not NUMERIC) — preserves trailing zeros per ADR-0019
- [ ] sqlmodel==0.0.22 + alembic==1.13.x pinned per R-5 ADR
- [ ] Latency <50ms p99 with 1000 records (perf test via pytest-benchmark or simple timing)
- [ ] Substring search <100ms p95 with 1000 records

**Out of scope:** Backup/restore strategy (Sprint 3+ polish); Postgres/litestream sync (R-5 ADR decision).

**Definition of done:** PR merged, R-5 ADR accepted, all AC tests pass, no P0/P1 bugs within 24h.

---

### STORY-008 — History UI wiring (render + substring search + click-to-load) [P0]

**Owner:** @developer + @tester
**Why P0:** Closes the UI loop for STORY-007. Without wiring, the backend is invisible.

**Acceptance criteria:**
- [ ] `fetch(/api/history?cursor=...)` + render via `<atilcalc-history>` Web Component (already shipped in Sprint 1)
- [ ] Pagination UI: previous/next + cursor state
- [ ] Substring search input → server-side filter
- [ ] Click-to-load: history item → loads expr into the input
- [ ] Empty state: "no history yet" placeholder
- [ ] Adversarial: empty history, very long history (10k items), cursor expiry, search-no-match
- [ ] Pagination shape matches PM-confirmed contract from STORY-007 boundary

**Out of scope:** Virtual scrolling (Sprint 3+); keyboard navigation across history items (Sprint 3+).

**Definition of done:** PR merged, AC tests pass, no P0/P1 bugs within 24h.

---

### STORY-009 — Skin system — ≥3 built-in skins (Dark, Light, Retro) + mode-toggle wired [P1]

**Owner:** @developer + @tester + @architect (R-2 ADR)
**Why P1:** vision M4 — skin transition <500ms with no flicker. The R-2 frontend ADR is the gating decision (CSS variables vs Shadow DOM tokens vs theme JSON).

**Acceptance criteria:**
- [ ] R-2 frontend ADR merged (architect, ~2 SP equivalent) — CSS variables most likely path
- [ ] ≥3 skins shipped: Dark (default, current), Light, Retro (each as a CSS file or theme object)
- [ ] Mode-toggle wired: `<atilcalc-mode-toggle>` (Sprint 1) swaps the active theme
- [ ] `GET /api/skin` returns current skin (ADR-0019 §GET)
- [ ] `PUT /api/skin` with `Idempotency-Key` (ADR-0019 §PUT)
- [ ] Transition: <500ms with no flicker (per M4 metric)
- [ ] CSS var snapshot test (manual fallback OK if no test infra)
- [ ] Adversarial: invalid skin name (rejected with 400), PUT idempotency replay (cached), cross-device skin sync

**Out of scope:** Custom user-defined skins (Sprint 3+); animated transitions (Sprint 3+).

**Definition of done:** R-2 ADR accepted, PR merged, all AC tests pass.

---

### STORY-010 — Skin preference persistence (cross-session + cross-device) [P1]

**Owner:** @developer + @tester
**Why P1:** Closes the M4 cross-device clause. localStorage fails the criterion; SQLite backend (per PM rec, architect concur) is the path.

**Acceptance criteria:**
- [ ] `PUT /api/skin` writes to SQLite (sharing R-5 layer from STORY-007)
- [ ] Skin preference persists across server restarts
- [ ] Skin preference syncs across LAN clients (cross-device criterion)
- [ ] Concurrent PUT: last-write-wins with version check (no partial rollback)
- [ ] Test fixture reuses STORY-007's temp-DB pattern
- [ ] Adversarial: survives server restart, concurrent PUT from 2 clients, rollback on partial failure

**Out of scope:** Conflict resolution UI (Sprint 3+); skin sync conflict history (Sprint 3+).

**Definition of done:** PR merged, AC tests pass.

---

### STORY-011 — Scientific functions (trig / log / √ / !) [P1] — **+2 SP REVISION**

**Owner:** @developer + @tester + @architect (ADR-0019 amendment)
**Why P1 + 2 SP:** vision §Open Questions Q3 answered by Sprint 1 plan (Sprint 2). Dev revised 5 → 7 SP to preserve Sprint 1 AC7 Decimal-precision contract via `mpmath==1.3.0` (math.sin/cos/tan on float loses precision; mpmath is full-precision).

**Acceptance criteria:**
- [ ] ADR-0019 amendment merged: Decimal-precision model for transcendental functions, factorial overflow cap at 170!
- [ ] Engine additions: `sin`, `cos`, `tan` (with rad/deg toggle), `log` (natural), `ln` (alias or drop), `√` (sqrt), `!` (factorial)
- [ ] Precision regression test: `sin(π) ≈ 0` to 28 digits (NOT `0.0` with floor)
- [ ] Precision preservation: `Decimal` strings round-trip losslessly (existing AC7)
- [ ] UI: `<atilcalc-help-popup>` extended to list sci shortcuts (Sprint 1 STORY-003b shipped the shell)
- [ ] Factorial: cap at 170! per ADR-0019 amendment; `171!` raises `ExpressionEvaluationError(factorial overflow)` → HTTP 400
- [ ] Domain errors: `log(-1)`, `asin(2)`, `sqrt(-1)` → `ExpressionEvaluationError` → HTTP 400
- [ ] Unicode operator `√` vs ASCII support (both accepted)
- [ ] mpmath==1.3.0 pinned per ADR-0019 amendment
- [ ] Adversarial probes: precision floor (sin(π) ≈ 0 not exactly 0), 170!/171! boundary, log(-1), asin(2), sqrt(-1), Unicode handling

**Out of scope:** Custom user-defined functions; hex/binary/bitwise programmer mode (vision §Out-of-scope).

**Definition of done:** ADR-0019 amendment accepted, PR merged, all AC tests pass.

---

### STORY-012 — Owner-facing documentation pass [P2]

**Owner:** @developer + @tester
**Why P2:** Lower friction → more daily use. README + help + keyboard shortcuts reference is the canonical docs surface.

**Acceptance criteria:**
- [ ] README.md: install + run (FastAPI uvicorn entry) + test commands
- [ ] In-app `?`-popup content refresh — exhaustive keyboard shortcut list
- [ ] docs/USER-GUIDE.md: skin mode, history view, scientific functions usage
- [ ] CHANGELOG.md [Unreleased] entry per merged PR (atomic per PR)
- [ ] Link checker pass: no broken internal links
- [ ] README example runs: `0.1+0.2 = 0.3` (the canonical Sprint 1 demo)
- [ ] Keyboard shortcut drift: list matches `<atilcalc-help-popup>` registry exactly

**Out of scope:** MkDocs vs plain markdown (plain markdown is current default); video tutorials.

**Definition of done:** PR merged, link checker passes, README example verified.

---

## Architect pre-work (parallel to implementation, ~6 SP equivalent)

These are NOT counted in the 25 SP feature total but are **gating dependencies** for implementation. Architect delivers in Sprint 2 P1 alongside story work.

| ADR | Scope | Blocks | Effort |
|---|---|---|---|
| **R-5 persistence ADR** | Storage backend choice (SQLite file vs SQLite+Litestream vs Postgres) + sync model + engine ↔ persistence boundary | STORY-007, STORY-010 | ~3 SP |
| **R-2 frontend ADR** | Theming model decision (CSS variables / Shadow DOM tokens / theme JSON) + Web Component contracts | STORY-009 | ~2 SP |
| **ADR-0019 amendment** | Codify Decimal-precision model for transcendental functions + factorial overflow cap (170!) + ADR-0019 §Engine exception taxonomy amendment | STORY-011 | ~1 SP |

**Total architect pre-work**: ~6 SP equivalent. Sprint 2 P1 should reserve architect capacity for these. Architect's other duties (review + chore work) are unaffected.

---

## New runtime dependencies (ADR-pinned)

| Dependency | Version | Stories | ADR pin |
|---|---|---|---|
| `sqlmodel` | 0.0.22 | STORY-007, STORY-010 | R-5 |
| `alembic` | 1.13.x | STORY-007 | R-5 |
| `mpmath` | 1.3.0 | STORY-011 | ADR-0019 amendment |

All three are MIT-licensed, pure-Python or near-stdlib. ADR pins must land before the corresponding implementation PR opens.

---

## Risks & dependencies

| Risk | Severity | Mitigation |
|---|---|---|
| R-5 ADR slips → STORY-007 + STORY-010 blocked | P0 | Architect prioritizes R-5 in Sprint 2 P1; PM/PM agent flagged for tracking |
| R-2 ADR slips → STORY-009 blocked | P1 | Architect prioritizes R-2 in Sprint 2 P1; CSS variables decision is low-friction |
| STORY-011 precision model ambiguous → implementation rework | P1 | ADR-0019 amendment gated before implementation; mpmath pinned in amendment |
| PM watcher gap (Issue: PM's agent-watch.sh doesn't include issue-level wake) | P2 | Bypass via `notify.sh` ping + manual check; Sprint 2 retro should add this as tech debt |
| Sprint 1 retro not written → Sprint 2 not officially "closed" | P2 | Write retro in Sprint 2 P1 alongside other ceremony work |
| Carry-over contention (Issue #46 + #65 + #48) competes for capacity | P2 | 10 SP buffer reserved; triage in Sprint 2 P1 standup |

---

## Sprint 2 P1 priority order

Per dependency analysis, the parallel-friendly first 3 days should be:

1. **Architect pre-work** (R-5 + R-2 + ADR-0019 amendment) — gates STORY-007/009/011
2. **STORY-007** (P0, persistent history) — backend foundation, unblocks STORY-008 + STORY-010
3. **STORY-008** (P0, history UI wiring) — depends on STORY-007 backend
4. **STORY-011** (P1, scientific functions) — independent of #007/009; can run in parallel
5. **STORY-009** (P1, skin system) — depends on R-2 ADR + ADR-0018 Web Components
6. **STORY-010** (P1, skin pref persistence) — depends on STORY-009 + R-5 (shared with STORY-007)
7. **STORY-012** (P2, docs) — can be batched at end

---

## Daily standup format

Per `docs/OPERATIONS.md` §2.2:
- `[Sprint 2] Daily Standup` issue, threaded comments per day
- 09:00 Europe/Istanbul
- Orchestrator posts, agents respond, blocker escalation to owner via Telegram

---

## Definition of Done (sprint-level)

Sprint 2 is **DONE** when ALL of:
1. All 6 committed stories merged to main with owner approval
2. R-5 + R-2 + ADR-0019 amendment ADRs accepted
3. CI green on main post-merge
4. Sprint 2 MVP-1 verification: `0.1+0.2 == 0.3` + persistent history + skin toggle + `sin(π) ≈ 0` from a fresh client
5. `docs/sprints/sprint-02/retrospective.md` written
6. Sprint 3 backlog drafted (grooming-ready)
7. No P0/P1 bugs filed against Sprint 2 stories within 24h

---

## Coordination issues

- **Issue #76** — Sizing ceremony (✅ closed)
- **Issue #77** (TBD) — Sprint 2 kickoff tracking (this plan inline)

— Orchestrator (Claude), 2026-06-18T14:50:00+03:00