# STORY-007: Persistent cross-device history (SQLite backend)

## User Story
As a **P1 — Atil (owner-operator, software/infrastructure professional, 5–20 calcs/day, multi-device on LAN)**,
I want **every completed calculation to be persisted to a durable backend (not browser memory, not localStorage), accessible from any device on my LAN**,
So that **I can find "that calculation from last Tuesday" on whichever device I'm using today — and the history survives tab closes, browser restarts, and device switches (M2 + M5 acceptance)**.

## Why now
Sprint 1 shipped the HTTP surface + 4 Web Components (`<atilcalc-history>` exists as a render shell, Issue #30 STORY-003a). Without persistence, history is in-memory only (per ADR-0019 §Non-goals: "GET /api/history returns in-memory deque for MVP-1; durable backend in Sprint 2"). M2 (≥35 records/week stickiness) and M5 (<100ms with 1000+ records + substring search) both require durable storage. Sprint 2's MVP-1 close-out hinges on this.

## Acceptance Criteria
- **AC1** — GIVEN the calculator evaluates an expression (e.g., `0.1 + 0.2` → `0.3`) WHEN the response returns to the browser THEN a history record `{expr, result, ts}` is persisted to the backend with sub-50ms p99 latency overhead (does not block the eval response).
- **AC2** — GIVEN the backend has 1000+ history records WHEN the browser requests `GET /api/history?q=0.1` THEN the response returns matching records (substring search on `expr` field) in <100ms p95 (M5).
- **AC3** — GIVEN device A has 100 records in history WHEN device B (different LAN client) calls `GET /api/history` THEN device B sees all 100 records (cross-device sync via shared backend).
- **AC4** — GIVEN the FastAPI server restarts WHEN the browser calls `GET /api/history` THEN all records are intact (durability: SQLite file on disk, not in-memory).
- **AC5** — GIVEN the browser sends a duplicate `POST /api/history` (same expr+result+ts within 60s) with same `Idempotency-Key` THEN the server returns the cached response without writing a duplicate record (idempotency per ADR-0019 §Idempotency keys).
- **AC6** — GIVEN the SQLite DB file exists WHEN the dev/test runs `pytest` THEN test fixtures use a temp DB (no leakage between tests, no production data touched).
- **AC7** — GIVEN `Decimal("0.1") + Decimal("0.2") = Decimal("0.3")` evaluates WHEN persisted THEN the stored `result` field is `"0.3"` (string, lossless per ADR-0019 §Decimal serialization + ADR-0019 amendment PR #63 trailing-zero rule).

## Out of scope
- Cross-user history isolation (no multi-user, no auth — single-user LAN, deferred to auth ADR per ADR-0019 §Authentication).
- History export/import (CSV, JSON) — Sprint 3+ stretch.
- History analytics ("most-calc'd expressions", frequency charts) — out of MVP per vision §Out-of-scope.
- Cloud backup / remote sync — explicit out per vision §Out-of-scope (self-host only).
- Backup cadence (daily snapshot) — separate story or part of R-5 ADR (architect's call at sizing).

## Open questions
- [ ] **Architect**: R-5 Persistence layer ADR — when does it get drafted? PM recommends Sprint 2 P1 (before STORY-007 implementation begins) so the SQL schema + index strategy is settled. → architect
- [ ] **Architect**: SQLite vs JSON-flat-file vs nothing (vision §Open Questions Q to architect) — resolved at R-5? → architect
- [ ] **Developer**: SQLite ORM (raw `sqlite3` stdlib vs `sqlmodel` / `sqlalchemy`)? PM no preference; boring tech wins per ADR-0017 follow-ups. → developer
- [ ] **Owner**: Backup cadence — daily snapshot, weekly off-site sync, or on-demand? (vision §Open Questions Q to owner; PM recommends daily snapshot + weekly off-site). → owner @atilcan65

## Mockups / references
- ADR-0019 §GET /api/history + §POST /api/history (Sprint 2 endpoints)
- ADR-0019 §Decimal serialization (string)
- ADR-0019 §Idempotency keys
- vision.md §M2 + §M5 acceptance criteria

## Dependencies
- **Upstream**:
  - ADR-0019 R-3 HTTP API contract (Accepted, PR #33 + PR #63 amendment)
  - R-5 Persistence layer ADR (architect to draft; Sprint 2 P1)
- **Downstream**:
  - STORY-008 (History UI wiring — calls the backend)
  - STORY-010 (Skin preference persistence — likely uses same backend, see design_open_question)

## Metrics of success
- **Leading**: history write p99 latency <50ms (so it doesn't block eval response).
- **Leading**: 1000-record `GET /api/history?q=...` substring search p95 <100ms (M5 target).
- **Lagging**: M2 stickiness signal — owner uses calculator ≥5/day for 7 consecutive days with ≥35 history records written that week.
- **Lagging**: M5 perf validation with real data (1 week of accumulated records post-launch).