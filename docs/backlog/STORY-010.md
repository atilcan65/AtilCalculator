# STORY-010: Skin preference persistence (cross-session + cross-device)

## User Story
As a **P1 — Atil (owner-operator, uses both desktop and laptop on the same LAN)**,
I want **my skin preference (Dark/Light/Retro) to persist across browser sessions AND across devices on the LAN — when I switch to `retro` on my desktop, my laptop shows `retro` next time I open the tab**,
So that **my reading-style preference follows me, not the device (M4 cross-device clause)**.

## Why now
STORY-009 ships the skin system + UI toggle + PUT /api/skin endpoint, but the preference is in-memory (per ADR-0019 §Authentication MVP-1 has no persistence layer). M4 explicitly requires "Skin preference persists across sessions and across devices on the LAN". Without this story, switching skins is ephemeral.

## Acceptance Criteria
- **AC1** — GIVEN the owner sets skin to `retro` on device A via `PUT /api/skin` WHEN device A is closed and reopened THEN the calculator still shows `retro` (cross-session persistence via backend storage, not localStorage).
- **AC2** — GIVEN device A has skin `retro` WHEN device B (different LAN client, never seen before) opens the calculator for the first time THEN it shows `retro` (cross-device sync via shared backend).
- **AC3** — GIVEN the FastAPI server restarts WHEN any device calls `GET /api/skin` THEN the previously-set skin is intact (durability: stored in SQLite or file-backed key-value, not in-memory).
- **AC4** — GIVEN multiple devices send `PUT /api/skin` concurrently with different skin names WHEN the requests complete THEN the last-write-wins semantic applies AND the audit log records all 3 transitions with timestamps + idempotency keys (no silent overwrites; reconciliation debuggable).
- **AC5** — GIVEN device A sends `PUT /api/skin` with `idempotency_key: "k1"` THEN retries (network glitch) with the same key WHEN the server has already applied THEN the cached response is returned (no double-apply, no duplicate audit log entry).

## Out of scope
- Per-device skin overrides (single global skin in MVP — explicit cross-device clause in M4 forbids per-device).
- Per-component skin (skins are global).
- Skin preference migration between owners / users (single-user MVP).

## Open questions
- [ ] **Architect**: Storage backend choice — SQLite (shared with STORY-007 history persistence) vs separate key-value file (Redis-equivalent, but no Redis in MVP)? PM recommends **shared SQLite** for simplicity — one backend, one backup story. → architect at sizing
- [ ] **Architect**: Should the skin preference be part of the R-5 Persistence layer ADR, or a separate ADR (e.g., R-6 "user preferences persistence")? PM recommends bundling into R-5 to avoid ADR sprawl. → architect
- [ ] **Owner**: If you ever have multiple users on the LAN (P2 — Home guest, out of MVP), should skin preference become per-user, or stay global? Vision §Out-of-scope excludes multi-user — this is a hypothetical for Sprint 3+. → owner @atilcan65

## Mockups / references
- ADR-0019 §PUT /api/skin + §Idempotency keys
- ADR-0019 §Authentication (deferred to Sprint 2+; cross-device assumes shared backend identity)
- vision.md §M4 cross-device clause
- STORY-009 (skin system dependency)

## Dependencies
- **Upstream**:
  - STORY-009 (skin system + PUT /api/skin endpoint)
  - R-5 Persistence layer ADR (architect — bundling recommended)
- **Downstream**: Sprint 3+ polish — M4 cross-device validation in real multi-device usage.

## Metrics of success
- **Leading**: skin preference write durability verified (server restart → preference intact).
- **Leading**: cross-device sync latency p95 <500ms (device B sees device A's change).
- **Lagging**: M4 cross-device acceptance — owner uses 2+ devices and the preference follows.
- **Lagging**: Idempotency-Key retry test passes (no double-apply, no audit log duplication).