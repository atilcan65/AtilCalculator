# ADR-0022 — Persistence layer (SQLite file backend + shared-volume cross-device sync)

**Status:** Accepted (via PR #82, 2026-06-18T20:44:07Z, merged by @atilcan65)
**Date:** 2026-06-18
**Deciders:** @architect (drafting), @product-manager (verdict on M2/M4/M5 alignment), @developer (verdict on implementation contract for STORY-007 + STORY-010), @tester (verdict on test plan alignment with PR #79 contract)
**Supersedes:** —
**Related:** [ADR-0017](ADR-0017-tech-stack.md) §Concrete stack + §Repository layout (engine ↔ UI separation invariant); [ADR-0019](ADR-0019-api-contract.md) §GET /api/history, §POST /api/history, §Idempotency keys, §Decimal serialization; [Issue #76](https://github.com/atilcan65/AtilCalculator/issues/76) Sprint 2 sizing ceremony; [Issue #80](https://github.com/atilcan65/AtilCalculator/issues/80) Architect pre-work ticket; [PR #79](https://github.com/atilcan65/AtilCalculator/pull/79) STORY-007 TDD RED contract suite (the implementation contract).

---

## Context

Sprint 2 STORY-007 (P0) requires persistent cross-device history storage, and STORY-010 (P1) requires skin preference persistence. ADR-0017 §What this ADR does *not* decide deferred the persistence ADR (R-5) to "Sprint 2 latest per PM" — that window is now. ADR-0019 defines the **HTTP API contract** (`GET /api/history`, `POST /api/history` with `Idempotency-Key`) but explicitly leaves the storage layer undefined.

Vision invariants this ADR must satisfy:

| Metric | Source | Constraint |
|---|---|---|
| **M1** (Decimal precision) | vision §M1, ADR-0019 §Decimal serialization | Lossless storage; no float coercion; trailing-zero rule preserved (PR #63 finding codified) |
| **M2** (daily-use stickiness) | vision §M2 | History persistence for ≥35 records/week across sessions |
| **M4** (skin transition) | vision §M4 | Skin preference persists across sessions + across devices on LAN |
| **M5** (history performance) | vision §M5 | `POST /api/history` <50ms p99 (AC1); `GET /api/history?q=...` <100ms p95 with 1000+ records (AC2) |

Cross-cutting constraints:

- **Engine ↔ UI separation invariant** (ADR-0017): engine module (`src/atilcalc/engine/`) is pure-Python stdlib-only. The persistence layer must be a separate module that the engine never imports.
- **Decimal-as-string serialization** (ADR-0019): API serializes `Decimal` as lossless strings. Storage must round-trip the same string. PR #63 codifies trailing-zero rule (e.g., `"105.00"` must not collapse to `"105"`).
- **Idempotency** (ADR-0019 §Idempotency keys): `POST /api/history` requires `Idempotency-Key: <UUID v4>`. Replay (same key, same payload) returns cached response; reuse with different payload is a client error.
- **TDD red contract** (PR #79): test suite is the implementation contract. 9 test cases (TC-1 to TC-9) + 12 adversarial probes (AP-1 to AP-12) + 3 perf budgets. Storage layer must satisfy all of these.

Sizing ceremony output (Issue #76, architect + developer + tester columns): PM recommendation is SQLite file-based (M5 latency budget <50ms p99). Developer concurs. Postgres is overkill for single-LAN deployment. Litestream is a Sprint 3+ polish option for replication.

---

## Decision

**Adopt SQLite file backend** at an operator-configured path (default `~/.local/share/atilcalc/history.db`), with **cross-device sync via shared filesystem volume** on the LAN VM (NFS mount at `/srv/atilcalc/`). Schema is a single SQLite database file containing two tables (`history`, `skin`). Engine ↔ persistence boundary is enforced by a new `src/atilcalc/persistence/` module — engine never imports it.

### Schema (canonical)

```sql
-- history table (AC1, AC2, AC3, AC4, AC5, AC7)
CREATE TABLE IF NOT EXISTS history (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    expr            TEXT    NOT NULL,                   -- raw expression string (engine input)
    result          TEXT    NOT NULL,                   -- Decimal as lossless string (ADR-0019 §Decimal serialization)
    ts              TEXT    NOT NULL,                   -- ISO 8601 string: datetime.now().isoformat()
    idempotency_key TEXT    UNIQUE NOT NULL             -- UUID v4 (ADR-0019 §Idempotency keys)
);
CREATE INDEX IF NOT EXISTS idx_history_ts ON history(ts DESC);            -- AC2 ordering
CREATE INDEX IF NOT EXISTS idx_history_expr_fts ON history(expr);         -- placeholder; FTS5 added below

-- Full-text search virtual table (AC2 substring search perf)
CREATE VIRTUAL TABLE IF NOT EXISTS history_fts USING fts5(
    expr,
    content='history',
    content_rowid='id'
);

-- skin table (M4 cross-device skin preference)
CREATE TABLE IF NOT EXISTS skin (
    key              TEXT PRIMARY KEY,
    value            TEXT NOT NULL,
    updated_at       TEXT NOT NULL                      -- ISO 8601 string
);

-- PRAGMA settings (perf budget + concurrency)
PRAGMA journal_mode = WAL;                              -- concurrent reads + writes
PRAGMA synchronous  = NORMAL;                           -- ~10x throughput vs FULL; acceptable for calculator history
PRAGMA busy_timeout = 5000;                             -- 5s lock wait (AC8 DB lock contention adversarial probe)
PRAGMA foreign_keys = ON;                               -- future-proof for relational extensions
```

### Engine ↔ persistence boundary (ADR-0017 invariant)

```
src/
  atilcalc/
    engine/             # Pure-Python stdlib-only (unchanged)
      parser.py
      evaluator.py
    persistence/        # NEW — depends on stdlib + sqlite3 (stdlib)
      __init__.py
      history.py        # CRUD: insert_history(), get_history(), search_history()
      schema.py         # DDL + PRAGMA bootstrap (called once at startup)
      migrations.py     # Forward-only schema migrations (placeholder for Sprint 3+)
    api/                # FastAPI — depends on engine + persistence (NOT vice versa)
      routes.py         # POST /api/history, GET /api/history
```

**Invariant check**: `grep -r "import atilcalc.persistence" src/atilcalc/engine/` returns ZERO matches (engine must not import persistence). CI gate: a ruff custom rule or a dedicated test asserting this invariant.

### Idempotency contract enforcement

The `idempotency_key TEXT UNIQUE` constraint enforces AC5 (PR #79 TC-5) at the DB layer. Replay semantics:

| Scenario | Behavior |
|---|---|
| First POST with key K + payload P | INSERT row, return 201 with new record ID |
| Replay POST with key K + payload P (same body, within cache window) | UNIQUE constraint hit on re-INSERT; query returns existing record, return 200 with cached record (per ADR-0019 §Idempotency: "replay returns cached response") |
| Replay POST with key K + payload P' (different body) | UNIQUE constraint hit on re-INSERT with DIFFERENT payload; return 409 Conflict (per ADR-0019: "key reuse with different body is a client error", also PR #79 AP-12) |

Cache window: 60 seconds (matches PR #79 TC-5 assumption). Replay outside window is treated as a fresh request — the previous record's idempotency key is reused (since the UNIQUE constraint is on the key, not on a time window), so the new INSERT will hit the constraint. Architect's interpretation: cache window is logical (cached response in memory); the DB UNIQUE is permanent (one record per key).

### Cross-device sync model

Single SQLite file on a shared filesystem volume (NFS mount on 192.168.1.199). Multiple FastAPI processes (or one process + multiple browser clients via HTTP) read/write the same file. Cross-device semantics:

- **No application-level sync layer.** SQLite + NFS handles it.
- **No WAL replication.** Single-writer; reads from multiple clients.
- **Backup strategy** (deferred to Sprint 3+): `cp history.db backup-$(date +%F).db` cron; Litestream is the post-MVP option.

### Operator config (env-var path)

```bash
# Default: ~/.local/share/atilcalc/history.db
export HISTORY_DB_PATH="/srv/atilcalc/history.db"     # operator override; NFS mount point
```

Path is read at FastAPI startup; missing directory auto-created with `mkdir -p` + chmod 0700 (operator-only access).

---

## Rationale

### Why SQLite (vs Postgres / Litestream / Redis)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **SQLite file** (CHOSEN) | Zero external service; ~1MB binary; embedded; LAN-suitable; PR #79 tests already authored against SQLite | Single-writer (mitigated by WAL); shared filesystem dependency | **Best fit** for single-LAN, ~10 req/min, single-user deployment |
| SQLite + Litestream | Adds streaming replication to S3-compatible backup | Adds ops burden (S3 bucket, retention config); replication is overkill for single-LAN | **Deferred to Sprint 3+** (per Issue #80 context + Issue #76 sizing: "Litestream is a Sprint 3+ polish option") |
| Postgres | Production-grade; multi-writer; transactional DDL | External service (systemd unit, backup, monitoring); ops overhead; overkill for ~10 req/min | **Rejected** — capacity mismatch (vision is single-LAN, not multi-region) |
| Redis | Fast; pub/sub for cross-device events | In-memory → durability risk; adds ops service; no SQL for ad-hoc queries | **Rejected** — persistence guarantees don't match M2 (history must survive restart) |

### Why shared filesystem (vs sync layer / multi-host SQLite)

Cross-device requirement from vision §Persistent history "shared across LAN devices" is satisfied by:

- **Shared NFS volume** (CHOSEN): single SQLite file at NFS mount; multiple browser clients reach the same data via the FastAPI HTTP API. No application sync.
- **Application-level sync layer** (REJECTED): would require a separate sync process (Litestream, custom replication, or a distributed KV store). Adds complexity; not justified by 10 req/min load.
- **Per-device SQLite + eventual merge** (REJECTED): would require conflict resolution (CRDT or last-write-wins); history is append-only so conflicts are rare but possible (same idempotency key, different timestamps). NFS approach is simpler.

### Why `journal_mode=WAL` + `synchronous=NORMAL`

Per PR #79 Perf-1 risk: SQLite default (`journal_mode=DELETE` + `synchronous=FULL`) requires fsync on every commit → ~10ms+ latency per write → AC1 <50ms p99 budget is at risk.

| Setting | Latency (per write) | Durability | Verdict |
|---|---|---|---|
| `journal_mode=DELETE` + `synchronous=FULL` (default) | ~10-20ms | Strong (every commit fsync'd) | Too slow for AC1 |
| **`journal_mode=WAL` + `synchronous=NORMAL` (CHOSEN)** | ~1-2ms | Moderate (commits fsync'd at checkpoint, not per-commit) | **Best fit** for calculator history (not financial data) |
| `journal_mode=WAL` + `synchronous=OFF` | ~0.5ms | Weak (no fsync; OS crash → data loss) | **Rejected** — risk vs reward is wrong for M2 stickiness |

WAL also enables concurrent reads during writes (multiple browser clients + FastAPI write → reads don't block). This satisfies PR #79 AC3 cross-device concurrent reads (Perf-3 risk).

### Why Decimal as TEXT (not NUMERIC)

SQLite has no native `Decimal`-with-precision type. SQLite's NUMERIC affinity uses IEEE-754 doubles when the value can be losslessly represented as such — but trailing zeros are silently dropped (e.g., `105.00` becomes `105`). This violates the PR #63 trailing-zero rule (codified in ADR-0019 §Decimal serialization).

| Storage type | `0.3` round-trip | `105.00` round-trip | Verdict |
|---|---|---|---|
| `TEXT` (CHOSEN) | `"0.3"` ✓ | `"105.00"` ✓ | Lossless per ADR-0019 |
| `NUMERIC` (SQLite IEEE-754 affinity) | `"0.3"` ✓ | `"105"` ✗ (trailing zeros dropped) | Violates PR #63 trailing-zero rule |
| `REAL` (double) | `"0.3"` ✓ | `"105"` ✗ | Same as NUMERIC; also has float-precision issues at large magnitudes |

### Why FTS5 virtual table for substring search

PR #79 Perf-2 risk: `LIKE '%substring%'` cannot use a B-tree index → full table scan on every query → 1000-record dataset is fine but vision M5 calls for "1000+ records" with p95 <100ms. FTS5 provides:

- Tokenized index (Porter stemmer by default; unicode61 for internationalization)
- `MATCH` operator for substring search (`WHERE history_fts MATCH '0.1'`)
- Order-of-magnitude faster than `LIKE` at 1000+ rows

Trade-off: FTS5 requires an extra virtual table that mirrors `history` (synced via triggers). ~10% storage overhead; acceptable for 1000-record scale.

### Why idempotency key UNIQUE (not application-level dedup)

The `idempotency_key TEXT UNIQUE NOT NULL` constraint enforces dedup **at the DB layer**, not in application code:

- **Race-safe**: two concurrent POSTs with the same key → second hits UNIQUE constraint → DB raises `IntegrityError` → application catches + returns 200 cached. No race window.
- **No extra cache layer**: in-memory dict cache (alternative) is per-process; doesn't work cross-device. DB-backed cache is shared.

### Why no engine ↔ persistence coupling

Engine is pure-Python stdlib-only (ADR-0017 §Concrete stack). If engine imported persistence, every engine test would pull in sqlite3 + schema setup. The boundary is enforced by:

- Architectural invariant: `engine/` does not depend on any `atilcalc.*` module.
- CI gate: a `tests/engine/test_no_io_imports.py` test that greps `src/atilcalc/engine/` for `import atilcalc.` and fails if found.

---

## Alternatives considered

### A. SQLite + WAL + NFS (chosen)

- **Pros**: matches PR #79 contract; engine ↔ UI invariant preserved; zero ops burden; fits Sprint 2 capacity; PM + dev + arch all concur
- **Cons**: NFS single point of failure; WAL files small disk overhead
- **Verdict**: chosen

### B. SQLite + Litestream replication

- **Pros**: streaming backup; replication to S3-compatible storage
- **Cons**: adds S3 bucket, retention config, restore procedure; not justified for single-LAN MVP
- **Verdict**: rejected (Sprint 3+ polish per Issue #80)

### C. Postgres

- **Pros**: production-grade; transactional DDL; multi-writer
- **Cons**: external service (systemd unit, monitoring, backup); ops overhead; capacity mismatch (~10 req/min doesn't need it)
- **Verdict**: rejected

### D. Per-device SQLite + eventual merge (CRDT-style)

- **Pros**: no shared filesystem dep; works offline
- **Cons**: requires conflict resolution (history is append-only but idempotency-key reuse across devices is a conflict scenario); implementation complexity exceeds Sprint 2 capacity
- **Verdict**: rejected (over-engineered for single-LAN)

### E. Redis with AOF persistence

- **Pros**: fast; pub/sub for cross-device events
- **Cons**: in-memory primary storage; durability risk vs SQLite file; no SQL for ad-hoc queries; adds ops service
- **Verdict**: rejected (durability concerns for M2 stickiness)

---

## Consequences

### Positive

- Engine ↔ UI separation invariant preserved (ADR-0017). Engine module still pure-Python stdlib-only.
- PR #79 TDD red contract suite is the implementation spec. Implementation is mechanical against an already-written test suite.
- Zero new ops burden. SQLite is embedded; no separate service to deploy/monitor/backup.
- Decimal precision lossless (ADR-0019 §Decimal serialization + PR #63 trailing-zero rule codified at storage layer).
- Cross-device sync via NFS satisfies vision M4 (skin persistence across devices) + AC3 (cross-device history).
- WAL + `synchronous=NORMAL` clears AC1 <50ms p99 budget per PR #79 Perf-1 risk.
- FTS5 substring search clears AC2 <100ms p95 budget per PR #79 Perf-2 risk.

### Negative

- **Single point of failure**: shared NFS volume. Mitigated by: VM is single-user LAN (acceptable blast radius); backup is `cp history.db backup-$(date).db` (manual cron, deferred to Sprint 3+ automation).
- **WAL file accumulation**: ~few MB per day at 10 req/min. Mitigated by: SQLite auto-checkpoint at 1000 pages; manual `PRAGMA wal_checkpoint(TRUNCATE)` if needed.
- **NFS dependency**: requires the VM's NFS volume correctly mounted on operator hosts. Mitigated by: README install section + `scripts/check-nfs-mount.sh` health check (deferred to Sprint 3+).
- **No cross-process locking guarantee at app level**: SQLite file-level lock is per-process; multiple FastAPI processes writing concurrently could race on WAL checkpoint. Mitigated by: single FastAPI process under systemd (per ADR-0017 §Runtime infra).

### Out of scope (deferred to follow-up tickets)

| Item | Sprint | Owner |
|---|---|---|
| Backup/restore automation (cron + Litestream) | Sprint 3+ | @orchestrator (Sprint 3+ capacity) |
| Multi-user isolation (auth) | Sprint 3+ | needs separate auth ADR |
| History export/import (CSV, JSON) | Sprint 3+ stretch | @product-manager scope call |
| Analytics ("most-calc'd expressions") | Out of MVP per vision | n/a |
| Skin preference UI (sprint 2 STORY-009) | Sprint 2 P2 | @developer (blocked on R-2 ADR) |
| Cross-process WAL checkpoint coordination | Sprint 3+ | not needed (single FastAPI process) |

### Follow-up tickets to file

- [ ] STORY-007 implementation PR (developer-owned; against PR #79 contract + this ADR's schema)
- [ ] STORY-010 implementation PR (developer-owned; skin table CRUD + PUT /api/skin wiring)
- [ ] CI gate: `tests/engine/test_no_io_imports.py` (architect-authored; owner-merged)
- [ ] Backup strategy ticket (Sprint 3+; cron + Litestream evaluation)
- [ ] NFS mount health check script (Sprint 3+; operator-facing)
- [ ] README + USER-GUIDE updates for operator deployment (parallel to STORY-012 in Sprint 2 P2)

---

## What this ADR commits to *now*

- Storage backend: **SQLite file** at `HISTORY_DB_PATH` (default `~/.local/share/atilcalc/history.db`).
- Schema: `history` + `history_fts` (FTS5 virtual) + `skin` tables; PRAGMA settings as specified.
- Cross-device sync: **shared NFS volume** on LAN VM (operator-configured mount).
- Engine ↔ persistence boundary: new `src/atilcalc/persistence/` module; engine never imports it.
- Decimal storage: **TEXT column type** (lossless, trailing-zero rule preserved).
- Idempotency: **DB-backed UNIQUE constraint** on `idempotency_key TEXT UNIQUE NOT NULL`.
- Substring search: **FTS5 virtual table** mirroring `history`.
- Test contract: PR #79 (already authored; TDD red) is the implementation spec.

---

## Cross-references

- **API contract**: [ADR-0019](ADR-0019-api-contract.md) §GET /api/history, §POST /api/history, §Idempotency keys, §Decimal serialization
- **Engine ↔ UI separation**: [ADR-0017](ADR-0017-tech-stack.md) §Concrete stack + §Repository layout
- **TDD contract**: [PR #79](https://github.com/atilcan65/AtilCalculator/pull/79) (9 TCs, 12 APs, 3 perf budgets)
- **Sizing output**: [Issue #76](https://github.com/atilcan65/AtilCalculator/issues/76) (architect + developer + tester columns)
- **Architect pre-work**: [Issue #80](https://github.com/atilcan65/AtilCalculator/issues/80) (this ADR is the first of 3)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>