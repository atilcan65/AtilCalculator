# Test Plan: STORY-007 — Persistent cross-device history (SQLite backend)

## Scope
- **In scope**: AC1 (POST persist <50ms p99), AC2 (GET substring search <100ms p95 with 1000+ records), AC3 (cross-device sync via shared backend), AC4 (durability via SQLite file), AC5 (idempotency via `Idempotency-Key` header), AC6 (test isolation via temp DB), AC7 (Decimal precision lossless storage); adversarial probes (SQL injection, Unicode, concurrent writes, DB lock, corrupted file).
- **Out of scope**: history export/import (Sprint 3+ stretch), multi-user isolation (deferred per ADR-0019 §Authentication), backup cadence (separate story per R-5 ADR scope), analytics ("most-calc'd expressions" — out of MVP per vision §Out-of-scope).

## Test Cases

### TC-1: Happy Path — POST persists to backend
- **Setup**: empty SQLite DB; FastAPI app started; fresh TestClient.
- **Steps**:
  1. `POST /api/evaluate` with `{"expr": "0.1 + 0.2"}` → expect 200, `result: "0.3"`.
  2. `POST /api/history` with `{"expr": "0.1 + 0.2", "result": "0.3", "ts": "<iso>"}` → expect 201.
  3. `GET /api/history` → expect at least 1 record matching `expr=0.1 + 0.2`.
- **Expected**: Record persists; `result` field is `"0.3"` (string, lossless per AC7).

### TC-2: Happy Path — GET substring search
- **Setup**: DB pre-seeded with 1000 records via direct `sqlite3` insert.
- **Steps**:
  1. `GET /api/history?q=0.1` → expect 200, body `{"history": [...]}` filtered.
  2. Assert each record's `expr` contains substring `0.1`.
  3. Assert latency <100ms p95 across 20 calls (AC2 perf budget).
- **Expected**: All matched records returned, p95 <100ms.

### TC-3: Happy Path — Cross-device sync
- **Setup**: Same SQLite file path configured for two TestClient instances.
- **Steps**:
  1. Client A: `POST /api/history` with record R1.
  2. Client B (same DB file, separate process simulator): `GET /api/history` → expect R1 in body.
- **Expected**: AC3 — both clients see the same data; no client-local cache divergence.

### TC-4: Edge Case — Durability across restart
- **Setup**: SQLite file on disk (not `:memory:`).
- **Steps**:
  1. `POST /api/history` with record R1.
  2. Close DB connection / shutdown FastAPI app.
  3. Re-open FastAPI app.
  4. `GET /api/history` → expect R1 intact.
- **Expected**: AC4 — record survives restart; SQLite file is source of truth.

### TC-5: Edge Case — Idempotency-Key replay
- **Setup**: TestClient with idempotency-key middleware enabled.
- **Steps**:
  1. `POST /api/history` with header `Idempotency-Key: abc-123` and payload P1 → expect 201.
  2. `POST /api/history` with same `Idempotency-Key: abc-123` and payload P1 (within 60s) → expect 200 (cached) OR 201 with same record ID.
  3. Assert only ONE record in DB (no duplicate).
- **Expected**: AC5 — replay returns cached response; no duplicate row.

### TC-6: Edge Case — Test isolation
- **Setup**: Autouse `_temp_db` fixture using `tmp_path / "history-{test_id}.db"`.
- **Steps**:
  1. Test A: insert record R_A.
  2. Test B (separate test): assert R_A NOT in DB.
  3. After Test A: assert DB file removed (fixture cleanup).
- **Expected**: AC6 — no leakage between tests; production DB untouched.

### TC-7: Edge Case — Decimal precision lossless
- **Setup**: DB configured with `Decimal` column as TEXT (not NUMERIC) per ADR-0019 §Decimal serialization + trailing-zero rule.
- **Steps**:
  1. `POST /api/history` with `result: "0.3"` (no trailing zeros).
  2. `POST /api/history` with `result: "105.00"` (trailing zeros — pin against PR #63 P3 finding).
  3. Direct SQL: `SELECT result FROM history WHERE id=?` → expect exact strings `"0.3"` and `"105.00"`.
- **Expected**: AC7 — trailing zeros preserved; no float coercion in storage layer.

### TC-8: Negative — Missing Idempotency-Key on POST
- **Setup**: POST endpoint requires `Idempotency-Key` header per ADR-0019 §Idempotency.
- **Steps**:
  1. `POST /api/history` WITHOUT `Idempotency-Key` → expect 400 with `error.type: "MissingIdempotencyKeyError"`.
- **Expected**: Per ADR-0019 §Idempotency keys: state-mutating endpoints require the header.

### TC-9: Negative — Invalid Idempotency-Key format
- **Setup**: Idempotency-Key must be UUID v4 per ADR-0019.
- **Steps**:
  1. `POST /api/history` with `Idempotency-Key: not-a-uuid` → expect 400.
- **Expected**: Reject malformed keys; no DB write.

## Adversarial Probes

### AP-1: SQL injection in `expr` field
- **Payload**: `expr = "'; DROP TABLE history;--"`
- **Expected**: Parameterized query (sqlite3 `?` placeholder); no table drop; record stored as literal string.

### AP-2: SQL injection in `result` field
- **Payload**: `result = "1' OR '1'='1"`
- **Expected**: Parameterized query; literal string stored; no query rewrite.

### AP-3: Unicode / emoji in `expr`
- **Payload**: `expr = "🚀 + 🌙"` (engine should reject with 400 `ExpressionSyntaxError`, but storage should handle Unicode)
- **Expected**: 400 at evaluate layer; if hypothetically stored, fetch returns same string.

### AP-4: NULL byte in `expr`
- **Payload**: `expr = "1 + 1\x00; DROP TABLE history"`
- **Expected**: Engine rejects; if stored, NULL byte preserved (TEXT type).

### AP-5: RTL / combining chars in `expr`
- **Payload**: `expr = "‮1 + 1‬"` (Right-to-Left Override + Pop Directional)
- **Expected**: Engine rejects (invalid syntax); storage preserves bytes if written.

### AP-6: Very long expr (1MB+)
- **Payload**: `expr = "1" + (" + 1" * 250000)` (~1.25 MB)
- **Expected**: Request rejected at FastAPI body-size limit OR engine rejects; no OOM crash.

### AP-7: Concurrent writes (race condition)
- **Setup**: 2 threads each POSTing 100 records with same Idempotency-Key.
- **Expected**: Atomic write (per-idempotency); no duplicate rows; final count = 100, not 200.

### AP-8: DB lock contention
- **Setup**: Long-running read transaction + concurrent write.
- **Expected**: Write waits (SQLite default busy_timeout); no deadlock; eventual consistency.

### AP-9: Corrupted SQLite file
- **Setup**: Write garbage bytes to `history.db`, then start app.
- **Expected**: App fails fast with clear error message (sqlite3.DatabaseError); no silent data loss.

### AP-10: Read-only filesystem
- **Setup**: Mount DB dir as read-only, attempt POST.
- **Expected**: 500 with clear error; no partial write; no data loss.

### AP-11: Disk full
- **Setup**: Fill disk; attempt POST.
- **Expected**: 500 with clear error; no app crash; app remains responsive for reads.

### AP-12: Idempotency-Key reuse with DIFFERENT payload
- **Setup**: First POST with key K + payload P1; second POST with key K + payload P2.
- **Expected**: 409 Conflict (per ADR-0019 §Idempotency: "key reuse with different body is a client error") OR 200 with P1 (cached response ignoring P2). Document the chosen behavior; pin via test.

## Performance Concerns

### Perf-1: AC1 latency budget
- **Test**: 100 sequential `POST /api/history` calls with pre-warmed DB.
- **Pass criteria**: p99 latency <50ms (per AC1).
- **Risk**: If implementer uses synchronous fsync (`PRAGMA synchronous=FULL`), latency may exceed budget. Recommend `PRAGMA synchronous=NORMAL` + WAL mode for Sprint 2 perf.

### Perf-2: AC2 substring search
- **Test**: Seed 1000 records (mix of expr patterns); run 20 `GET /api/history?q=0.1` calls.
- **Pass criteria**: p95 <100ms (per AC2).
- **Risk**: `LIKE '%substring%'` cannot use index. Implementer must add `expr` column index OR use FTS5 virtual table. Document the choice.

### Perf-3: Cross-device concurrent reads
- **Test**: 10 concurrent GET /api/history (simulating 10 devices).
- **Pass criteria**: No 5xx; p95 <100ms; no read lock starvation.

## Regression Risk

- **`tests/api/test_history.py`** (existing, STORY-003a in-memory tests): STORY-007 implementation must NOT regress the in-memory tests. After AC6 fixture takes over, the in-memory deque may be removed (per ADR-0019 §Non-goals: "durable backend in Sprint 2"). Update test_history.py to skip the in-memory tests OR remove if the deque is gone. **Action**: implementer must update or remove the in-memory tests when landing STORY-007.
- **`tests/api/test_evaluate.py`**: AC7 Decimal precision already pinned here. The HISTORY `result` field must serialize the SAME way (string, no float). Cross-test alignment required.
- **`tests/api/test_conftest_ruff_clean.py`**: `_history_reset` fixture pattern (Issue #52). If implementer changes the autouse fixture structure (e.g., moves to a `_temp_db` fixture), update the structural pin tests too.
- **`docs/test-plans/STORY-003a-tests.md`**: References to "in-memory deque" must be updated if STORY-007 replaces the deque with SQLite.

## Open Test Questions (flag to architect before test plan lock)

1. **R-5 ADR scope**: this test plan is authored against ADR-0019 API contract + general SQLite best practices. If R-5 ADR lands with a different schema (e.g., PostgreSQL instead of SQLite), the SQL-level tests (AP-1, AP-9, Perf-2) must be re-authored. **Action**: re-run test plan after R-5 ADR lands; flag as `blocked_on: R-5`.
2. **Storage format for Decimal**: ADR-0019 says "string". Is the SQLite column TEXT (lossless) or NUMERIC (precision loss risk)? Test assumes TEXT. Confirm before implementation.
3. **Idempotency cache location**: in-memory dict (per-server) or DB-backed (cross-device)? AC5 implies DB-backed for cross-device, but doesn't say. Confirm.
4. **`ts` field semantics**: ISO 8601 string (engine emits `datetime.now().isoformat()`) or Unix timestamp? Test assumes ISO 8601. Confirm.

## Test Files to Land

| File | Purpose | ACs covered |
|---|---|---|
| `tests/api/test_history_endpoint.py` | POST/GET contract | AC1, AC3, AC4, AC6, AC7 |
| `tests/api/test_history_idempotency.py` | Idempotency-Key contract | AC5, TC-8, TC-9, AP-12 |
| `tests/api/test_history_decimal_precision.py` | Decimal storage regression pin | AC7, TC-7 |
| `tests/api/test_history_durability.py` | Restart persistence | AC4 |
| `tests/api/test_history_search_perf.py` | Substring search perf | AC2, Perf-2 |
| `tests/api/test_history_concurrency.py` | Concurrent write adversarial | AP-7, AP-8 |
| `tests/api/test_history_adversarial.py` | SQL injection + Unicode | AP-1 to AP-6, AP-9 to AP-11 |
| `tests/api/conftest.py` (extend) | `_temp_db` fixture + idempotency helper | AC6 |

## Pre-Lock Blockers

This test plan is authored in TDD RED phase against ADR-0019 API contract. Before implementation begins:

- [ ] **R-5 persistence layer ADR accepted** — architect commitment (Sprint 2 P1).
- [ ] **Storage format for Decimal confirmed** — TEXT vs NUMERIC (test plan assumes TEXT).
- [ ] **Idempotency cache location confirmed** — in-memory vs DB-backed.

These are flagged to @architect in the PR body + auto-ping; if R-5 lands with materially different decisions, the SQL-level tests in this plan are rewritten.

## Out-of-Scope Tests (NOT in this plan)

- History export/import (Sprint 3+ stretch).
- Multi-user isolation (deferred to auth ADR).
- Backup/restore strategy (separate story per R-5 scope).
- Analytics ("most-calc'd expressions") — out of MVP per vision.