# Test Plan: STORY-010 — Skin preference persistence (cross-session + cross-device)

## Scope

- **In scope**: AC1 (cross-session persistence via backend storage, NOT in-memory), AC2 (cross-device sync via shared backend), AC3 (durability — server restart preserves preference), AC4 (concurrent PUTs + audit log: last-write-wins, no silent overwrites, reconciliation debuggable), AC5 (idempotency-key retry — cached response, no double-apply, no audit log duplication).
- **Out of scope**: Per-device skin overrides (vision §M4 forbids), per-component skin, skin preference migration between owners / users (single-user MVP), skin marketplace (vision §Out-of-scope), animated cross-fade transitions (out of M4).

## Source contracts (ADR pinning)

- **ADR-0022** (Accepted, PR #82) — Persistence layer. `skin` table schema: `(key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL)`. Engine ↔ persistence boundary: engine never imports persistence; CI gate in `tests/engine/test_no_io_imports.py`.
- **ADR-0019** (Accepted, PR #33 + amendments PR #63 + PR #84) — HTTP API. `GET /api/skin` + `PUT /api/skin` + `Idempotency-Key` header required for state-mutating PUT.
- **STORY-009** (in-flight, Issue #71) — Skin system + 3 built-in skins + `<atilcalc-mode-toggle>` wired + PUT /api/skin endpoint. STORY-010 layers persistence ON TOP of the STORY-009 endpoint; STORY-009 ships in-memory; STORY-010 swaps in SQLite-backed persistence.

## Acceptance criteria recap

| AC | Description | Test surface |
|---|---|---|
| AC1 | Cross-session persistence: PUT /api/skin → server restart → GET /api/skin returns same skin | `tests/api/test_skin_persistence.py` |
| AC2 | Cross-device sync: device A PUTs skin=retro; device B (different LAN client) GETs skin → returns retro | `tests/integration/test_skin_cross_device.py` |
| AC3 | Durability: server restart preserves preference (SQLite file-backed, not in-memory) | `tests/integration/test_skin_durability.py` |
| AC4 | Concurrent PUTs + audit log: last-write-wins, all 3 transitions logged with ts + idempotency_key | `tests/api/test_skin_concurrent.py` |
| AC5 | Idempotency-Key retry: same key + same body → cached response, no re-apply, no duplicate audit log | `tests/api/test_skin_idempotency.py` (extends STORY-009 test_skin_endpoint.py) |

## Test Cases

### TC-1: AC1 — PUT /api/skin persists across server restart (in-process restart)
- **Setup**: backend running; default skin = `dark`. `_db_path` env var set to a fresh temp file (e.g., `/tmp/atilcalc-test-<uuid>.db`).
- **Steps**:
  1. `PUT /api/skin` with `{"skin": "retro"}` + `Idempotency-Key: K1` → 200.
  2. `GET /api/skin` → `{"skin": "retro", ...}`.
  3. **Server restart**: tear down the FastAPI TestClient (and the underlying persistence layer) + re-instantiate from the same `_db_path`. (For `TestClient`, this means re-importing the app module OR using a real subprocess restart of the server. TDD red: module-level skip on missing impl; green path: subprocess-based restart in CI.)
  4. `GET /api/skin` → `{"skin": "retro", ...}` (NOT `dark`).
- **Expected**: skin preference survives process restart. SQLite file on disk is the source of truth.
- **Pins**: AC1, AC3.

### TC-2: AC1 (variant) — PUT /api/skin persists across server restart (subprocess restart)
- **Setup**: spawn FastAPI server as a subprocess via `subprocess.Popen` (or `uvicorn` CLI). `_db_path` env var points to temp file. Server bound to `127.0.0.1:<free-port>`.
- **Steps**:
  1. `PUT /api/skin` via HTTP → 200; verify skin.
  2. **Subprocess restart**: `Popen.terminate()` + wait + new `Popen` with same `_db_path`.
  3. `GET /api/skin` → `{"skin": <preserved>, ...}`.
- **Expected**: full process restart (not just module reload) preserves preference.
- **Pins**: AC1, AC3. **Stronger guarantee than TC-1** — catches in-process state hiding behind module-level globals.

### TC-3: AC2 — Cross-device sync via shared backend
- **Setup**: 2 separate `TestClient` instances bound to the same `_db_path` (simulating 2 LAN clients on the same NFS-mounted SQLite file). Both clients go through the same FastAPI app instance but simulate independent sessions (different Idempotency-Key namespaces).
- **Steps**:
  1. Client A: `PUT /api/skin` with `{"skin": "retro"}` + `Idempotency-Key: A-K1` → 200.
  2. Client B: `GET /api/skin` → `{"skin": "retro", "available": ["dark", "light", "retro"]}`.
- **Expected**: Client B sees Client A's write immediately (or within the cache invalidation window, <500ms per Perf-1). Single source of truth.
- **Pins**: AC2.

### TC-4: AC2 (variant) — Cross-device sync via separate processes (true NFS simulation)
- **Setup**: spawn 2 separate FastAPI server subprocesses on different ports, both pointing to the same `_db_path` (NFS-equivalent: shared filesystem). Simulates 2 LAN devices hitting the same backend.
- **Steps**:
  1. Server-A (port 8001): `PUT /api/skin` with `{"skin": "light"}` + `Idempotency-Key: A-K1` → 200.
  2. Server-B (port 8002): `GET /api/skin` → `{"skin": "light", ...}`.
- **Expected**: Server-B reads Server-A's write from the shared SQLite file. Latency p95 <500ms per Perf-1.
- **Pins**: AC2, Perf-1.

### TC-5: AC3 — Durability: SQLite file exists and contains skin row
- **Setup**: `PUT /api/skin` with `{"skin": "light"}` + `Idempotency-Key: K1` → 200.
- **Steps**:
  1. Open `_db_path` directly via `sqlite3.connect(_db_path)` (bypassing the FastAPI app).
  2. Query: `SELECT key, value, updated_at FROM skin;` → must return `("current", "light", "<ISO 8601 ts>")`.
  3. PRAGMA `journal_mode` → `wal`.
  4. PRAGMA `synchronous` → `1` (NORMAL).
- **Expected**: skin preference is materialized in the SQLite file; WAL mode enabled for concurrent reads.
- **Pins**: AC3, ADR-0022 §Schema + §PRAGMA settings.

### TC-6: AC3 (negative) — Corrupted SQLite file → 500 with explicit error, NOT silent fallback
- **Setup**: corrupt `_db_path` by writing garbage bytes (`echo "garbage" > _db_path`).
- **Steps**:
  1. FastAPI app startup with corrupted DB → expected: server logs error and **refuses to start** OR returns 500 with `{"error": {"type": "DatabaseCorrupt", ...}}`.
- **Expected**: NO silent fallback to in-memory (silent fallback would violate AC1 — restart would lose data because fallback resets to "dark").
- **Pins**: AC3 (negative — durability must be loud, not silent).

### TC-7: AC4 — Concurrent PUTs: last-write-wins + audit log records all transitions
- **Setup**: 5 concurrent `PUT /api/skin` requests with distinct `Idempotency-Key` values + distinct skin values (`dark`, `light`, `retro`, `dark`, `light`).
- **Steps**:
  1. Use `concurrent.futures.ThreadPoolExecutor(max_workers=5)` to fire all 5 PUTs in parallel.
  2. All 5 must return 200 (none fail).
  3. After completion, `GET /api/skin` → returns the value of the **last** write (per last-write-wins semantics; the test is non-deterministic but must converge to one of the 5 values).
  4. Query audit log table (or `skin_audit` log if ADR-0022 extends the schema; if not, log assertions via captured `logging` output): must have **5 entries**, each with `(from_skin, to_skin, idempotency_key, ts)`.
- **Expected**: no silent overwrites (all 5 transitions logged); no deadlock (5 concurrent PUTs complete within the busy_timeout window per ADR-0022 §PRAGMA `busy_timeout=5000`).
- **Pins**: AC4.

### TC-8: AC5 — Idempotency-Key retry: same key + same body → cached, no re-apply
- **Setup**: `PUT /api/skin` with `{"skin": "retro"}` + `Idempotency-Key: K1` → 200 (first apply).
- **Steps**:
  1. Retry `PUT /api/skin` with `{"skin": "retro"}` + `Idempotency-Key: K1` → 200 (cached, NOT a re-apply).
  2. Verify audit log has **1 entry** (NOT 2) for K1.
  3. Verify `updated_at` in `skin` table is unchanged from the first PUT (the second PUT did not bump the timestamp).
- **Expected**: idempotency per ADR-0019 §Idempotency keys + ADR-0022 §Idempotency contract enforcement. Replay returns cached response.
- **Pins**: AC5.

### TC-9: AC5 (negative) — Idempotency-Key reuse with different body → 409 Conflict
- **Setup**: `PUT /api/skin` with `{"skin": "retro"}` + `Idempotency-Key: K1` → 200.
- **Steps**:
  1. Retry `PUT /api/skin` with `{"skin": "light"}` + `Idempotency-Key: K1` (same key, DIFFERENT body).
  2. Expected: HTTP 409 Conflict per ADR-0019 §Idempotency keys ("key reuse with different body is a client error") + ADR-0022 §Idempotency contract enforcement table.
- **Expected**: explicit conflict signal. No silent overwrite. Per ADR-0022: `UNIQUE constraint hit on re-INSERT with DIFFERENT payload → return 409 Conflict`.
- **Pins**: AC5 (negative — catches silent overwrite bugs).

## Adversarial Probes

### AP-1: Concurrent PUT with same idempotency key (race condition on UNIQUE constraint)
- 2 clients PUT simultaneously with `Idempotency-Key: K1` + identical body.
- Expected: both return 200 (cached response); only 1 INSERT in audit log; no duplicate transition.
- **Stress test for AC5 + ADR-0022 §Idempotency contract enforcement**.

### AP-2: PUT /api/skin with empty idempotency key
- `PUT /api/skin` with `{"skin": "light"}` but `Idempotency-Key: ""` (empty string).
- Expected: 400 Bad Request per ADR-0019 (idempotency required for state-mutating endpoints; empty key is malformed).

### AP-3: Server restart during in-flight PUT
- Fire `PUT /api/skin` + simultaneously `Popen.terminate()` the server.
- Expected: PUT either completes (200) OR fails with connection error (no partial state). On next GET, the database is either pre-write or post-write; never corrupted.

### AP-4: Read `_db_path` while write is in-flight (WAL visibility)
- 1 client fires PUT; another client immediately fires GET. Verify WAL mode ensures the GET does not block on the PUT's commit (per ADR-0022 §Why `journal_mode=WAL`).
- Expected: GET returns either pre-write or post-write value; no `OperationalError: database is locked`.

### AP-5: `_db_path` directory missing at startup
- Set `_db_path` to `/tmp/nonexistent-dir-XYZ/history.db` where `nonexistent-dir-XYZ` does not exist.
- Expected: server startup auto-creates the directory (`mkdir -p` per ADR-0022 §Operator config) + chmod 0700. Skin PUT/GET works.

### AP-6: `_db_path` is read-only filesystem
- Set `_db_path` to a path on a read-only mount (e.g., `/usr/share/readonly.db`).
- Expected: server startup FAILS with explicit error (NOT silent fallback). Per TC-6, durability must be loud.

### AP-7: Idempotency-Key collision across skin + history endpoints
- `POST /api/history` with `Idempotency-Key: K1` → success.
- `PUT /api/skin` with `Idempotency-Key: K1` (same key).
- Expected: 409 Conflict OR 400 — keys are scoped per-endpoint, not global. Verify scope semantics in impl (ADR-0019 + ADR-0022 ambiguous on cross-endpoint scoping; this probe forces the impl to decide).

### AP-8: Audit log table missing
- After impl lands, if the audit log is in-memory only (not in `skin_audit` table), test fails. Audit log MUST be in SQLite (durability invariant — same as the preference itself).

### AP-9: Concurrent PUTs with `busy_timeout` exhaustion
- 50 concurrent PUTs (5× the TC-7 stress). With `busy_timeout=5000`, expect all 50 to complete (some may retry internally).
- Expected: no `OperationalError: database is locked` surfaces to the HTTP layer. If the timeout is exceeded, server returns 503 with explicit error.

### AP-10: Negative / unknown skin value persisted
- Bypass the HTTP layer (e.g., write directly to `skin` table): `INSERT INTO skin VALUES ('current', 'neon', '<ts>')`.
- Subsequent `GET /api/skin` → returns `{"skin": "neon", "available": ["dark", "light", "retro"]}` (impossible state).
- Expected: server validates on read OR ignores unknown values OR returns error. Impl choice; test should NOT crash.

## Performance Concerns

### Perf-1: PUT /api/skin cross-device latency
- p95 <500ms for cross-device PUT (Server-A writes → Server-B sees via shared SQLite).
- **Budget source**: vision §M4 + AC2 cross-device clause.
- **Test method**: spawn 2 subprocess servers on different ports; measure PUT-to-GET latency across them over 100 iterations.

### Perf-2: PUT /api/skin write latency (single-process)
- p99 <50ms per write (ADR-0022 §M5 latency budget applies to history, but skin writes should be similar or faster — skin table is a single-row UPDATE).
- **Test method**: 1000 sequential PUTs; assert p99 <50ms.

### Perf-3: GET /api/skin response time (single-process)
- p95 <50ms (in-memory after cache warmup; first GET may hit SQLite ~1-2ms).
- **Test method**: 1000 sequential GETs; assert p95 <50ms.

### Perf-4: Audit log query latency
- 10,000 audit log entries → query for last 100 transitions: p95 <100ms.
- **Test method**: insert 10,000 fake audit entries; query `SELECT * FROM skin_audit ORDER BY ts DESC LIMIT 100`.

### Perf-5: Server startup time with persistence layer
- Cold start: FastAPI app + SQLite schema bootstrap + audit log table creation: <2s.
- **Test method**: measure `time.monotonic()` from app import to first request served.

## Regression Risk

- **STORY-009 (PR #105 contract)**: STORY-009 ships in-memory `skin` state. STORY-010 swaps in SQLite-backed persistence. The contract tests in PR #105 (AC1 GET, AC4 PUT + idempotency, AC5 UnknownSkinError envelope) MUST still pass after the persistence swap. **Action**: re-run PR #105 test suite after STORY-010 impl.
- **STORY-007 history persistence (PR #79 contract, merged)**: ADR-0022 §Schema defines `history` + `skin` tables in the same SQLite file. A bug in the persistence layer (e.g., PRAGMA `busy_timeout` too low) could starve both endpoints. **Action**: run full STORY-007 test suite alongside STORY-010 tests in CI.
- **ADR-0022 §Engine ↔ persistence boundary**: persistence must NEVER be imported by `src/atilcalc/engine/`. **Action**: `tests/engine/test_no_io_imports.py` already exists (per ADR-0022 §Engine ↔ persistence boundary) — verify it still passes.
- **Idempotency-Key semantics**: AC5 depends on ADR-0019 + ADR-0022 agreeing on scope (per-endpoint vs global). PR #105 test `test_put_skin_with_duplicate_idempotency_key_is_cached` already tests the per-endpoint case. **Action**: AP-7 explicitly tests cross-endpoint collision.
- **Audit log retention**: AC4 audit log grows unbounded. **Action**: add a Sprint 3+ ADR for retention policy; out of scope for STORY-010 MVP but document the debt.

## Test Files to Land

| File | Purpose | ACs |
|---|---|---|
| `tests/api/test_skin_persistence.py` | TC-1, TC-2 — server restart preserves preference | AC1, AC3 |
| `tests/integration/test_skin_cross_device.py` | TC-3, TC-4 — multi-client sync (TestClient + subprocess) | AC2, Perf-1 |
| `tests/integration/test_skin_durability.py` | TC-5, TC-6 — SQLite file contents + corruption handling | AC3, AP-6 |
| `tests/api/test_skin_concurrent.py` | TC-7, AP-1, AP-9 — concurrent PUTs + audit log | AC4 |
| `tests/api/test_skin_idempotency.py` | TC-8, TC-9, AP-2, AP-7 — idempotency retry + cross-endpoint collision | AC5 |

All tests are TDD RED with module-level skip guards (per PR #105 pattern). They probe:
- `atilcalc.api.main` importable
- `_db_path` env var honored
- `skin` table exists in SQLite
- PUT /api/skin persists across restart (via subprocess spawn)
- Idempotency-Key cached

When implementation lands (skin persistence in `src/atilcalc/persistence/skin.py` + integration with `src/atilcalc/api/main.py`), all tests will run.

## Pre-Lock Blockers

1. **ADR-0022 audit log schema decision**: AC4 requires an audit log table. ADR-0022 §Schema lists `skin` (key/value/updated_at) but does NOT mention `skin_audit`. The impl must either extend ADR-0022 with a `skin_audit` table (separate ADR) OR use an in-process logger (rejected by AP-8). **Action**: ping @architect for `skin_audit` schema decision before locking the test plan. If extending ADR-0022, the extension ADR must be merged BEFORE STORY-010 impl PR.
2. **`_db_path` env var name**: ADR-0022 §Operator config defines `HISTORY_DB_PATH`. STORY-010 should reuse the same env var (single SQLite file, two tables) OR define `SKIN_DB_PATH` (separate file). **Action**: confirm with @architect — recommend reuse of `HISTORY_DB_PATH` for simplicity.
3. **Subprocess test infrastructure**: TC-2 + TC-4 require spawning the FastAPI server as a subprocess. CI must support this. **Action**: verify the existing `Makefile` + CI workflow can spawn subprocess servers; if not, add a pytest fixture (`subprocess_server`) + a CI allowlist for `Popen`.
4. **Idempotency-Key scope (AP-7)**: ADR-0019 + ADR-0022 are ambiguous on whether keys are scoped per-endpoint or global. **Action**: confirm with @architect before impl; TC-9 + AP-7 will catch silent decision.

## Out-of-Scope Tests (NOT in this plan)

- Per-device skin overrides (vision §M4 forbids).
- Per-component skin.
- Skin preference migration between owners / users (single-user MVP).
- Cross-region replication (vision is single-LAN, not multi-region).
- Audit log retention policy (Sprint 3+ debt).
