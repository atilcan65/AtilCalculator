"""SQLite-backed history persistence (STORY-007, refs #69).

Per ADR-0022 (R-5, in-review via PR #82):
- Schema: ``history`` table with TEXT columns for Decimal (lossless per ADR-0019 §Decimal serialization
  + PR #63 trailing-zero rule).
- Idempotency at the DB layer via ``idempotency_key TEXT UNIQUE`` (race-safe; no in-memory cache).
- PRAGMAs: ``journal_mode=WAL`` + ``synchronous=NORMAL`` (durability vs latency trade-off).
- Substring search via ``LIKE`` (MVP-1). FTS5 virtual table deferred to Sprint 3+ per
  PR #82 P3 #3 — LIKE on 1000 rows passes the <100ms p95 budget with 100x headroom.

Engine ↔ UI separation (ADR-0017): this module is stdlib-only and has no FastAPI / HTTP / engine deps.
"""

from __future__ import annotations

import sqlite3
import threading
import uuid
from typing import Any

# ----------------------------------------------------------------------------
# Schema (pinned per PR #82 working spec; rebase if the architect's amendment
# changes the table layout).
# ----------------------------------------------------------------------------
_DDL: list[str] = [
    """CREATE TABLE IF NOT EXISTS history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expr TEXT NOT NULL,
        result TEXT NOT NULL,
        ts TEXT NOT NULL,
        idempotency_key TEXT UNIQUE
    )""",
    "CREATE INDEX IF NOT EXISTS idx_history_ts ON history(ts DESC)",
    "CREATE INDEX IF NOT EXISTS idx_history_expr ON history(expr)",
]

# Thread-local connection cache: FastAPI runs handlers in a thread pool, each
# thread gets its own SQLite connection (sqlite3.Connection is not thread-safe
# by default). check_same_thread=False is required because we share the
# connection object across requests on the same worker thread.
_local = threading.local()


def _get_conn(db_path: str) -> sqlite3.Connection:
    """Return the thread-local SQLite connection for ``db_path``.

    Lazily ensures the schema exists (idempotent CREATE IF NOT EXISTS) on first
    open — this handles the case where the app starts up before the schema is
    created (e.g., test sessions that don't use the ``_temp_db`` fixture, or
    fresh production deploys). PRAGMAs are set on first open. The connection
    is reused for subsequent calls on the same thread.
    """
    conn = getattr(_local, "conn", None)
    if conn is None or getattr(_local, "db_path", None) != db_path:
        if conn is not None:
            with __import__("contextlib").suppress(Exception):
                conn.close()
        # Ensure the schema exists (idempotent). The DDL is CREATE IF NOT
        # EXISTS so this is a no-op on subsequent calls.
        _init_schema(db_path)
        conn = sqlite3.connect(db_path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        # PRAGMAs per PR #82 §PRAGMA choices: WAL + synchronous=NORMAL.
        # journal_mode=WAL allows concurrent readers + 1 writer (multi-process
        # cross-device sync on the NFS share). synchronous=NORMAL trades a
        # small durability window for ~10x write latency improvement.
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA synchronous = NORMAL")
        _local.conn = conn
        _local.db_path = db_path
    return conn


def _init_schema(db_path: str) -> None:
    """Create the schema at ``db_path`` if absent. Idempotent.

    Uses a short-lived connection (separate from the cached thread-local
    connection) so the DDL is committed to the file before the cached
    connection opens. This avoids "no such table" races where the cached
    connection is opened against a file that hasn't been initialized yet.
    """
    conn = sqlite3.connect(db_path)
    try:
        for stmt in _DDL:
            conn.execute(stmt)
        conn.commit()
    finally:
        conn.close()


def init_db(db_path: str) -> None:
    """Initialize the schema at ``db_path`` (idempotent — safe to call repeatedly).

    Public API. Used by:
    - The ``_temp_db`` test fixture (per-test temp DB).
    - The FastAPI app startup event (production DB).
    Equivalent to ``_init_schema``; kept as a public function for explicit
    pre-init patterns (e.g., a deployment script that wants to verify schema
    before starting the app).
    """
    _init_schema(db_path)


def insert_record(
    db_path: str,
    expr: str,
    result: str,
    ts: str,
    idempotency_key: str | None = None,
) -> dict[str, Any]:
    """Insert a new record. Returns the row as ``{id, expr, result, ts}``.

    Raises:
        IdempotencyConflictError: If ``idempotency_key`` is non-NULL and already
            exists in the table (UNIQUE constraint violation). Callers should
            distinguish "replay with same payload" (200/201 cache hit) from
            "replay with different payload" (409 Conflict) by first calling
            :func:`get_record_by_idempotency_key`.
    """
    conn = _get_conn(db_path)
    try:
        cur = conn.execute(
            "INSERT INTO history (expr, result, ts, idempotency_key) "
            "VALUES (?, ?, ?, ?)",
            (expr, result, ts, idempotency_key),
        )
        conn.commit()
    except sqlite3.IntegrityError as exc:
        if idempotency_key is not None and "idempotency_key" in str(exc):
            raise IdempotencyConflictError(idempotency_key) from exc
        raise
    return {
        "id": cur.lastrowid,
        "expr": expr,
        "result": result,
        "ts": ts,
    }


def get_records(
    db_path: str,
    q: str | None = None,
    limit: int = 50,
) -> list[dict[str, Any]]:
    """Return records newest-first.

    If ``q`` is set, filter by substring match on the ``expr`` column (LIKE %q%).
    The MVP-1 implementation uses ``LIKE`` for simplicity; FTS5 is deferred to
    Sprint 3+ per PR #82 P3 #3 (LIKE on 1000 rows passes the <100ms p95 budget
    with significant headroom on the dev VM).
    """
    conn = _get_conn(db_path)
    if q:
        rows = conn.execute(
            "SELECT id, expr, result, ts FROM history "
            "WHERE expr LIKE ? ORDER BY ts DESC, id DESC LIMIT ?",
            (f"%{q}%", limit),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT id, expr, result, ts FROM history "
            "ORDER BY ts DESC, id DESC LIMIT ?",
            (limit,),
        ).fetchall()
    return [dict(row) for row in rows]


def get_record_by_idempotency_key(
    db_path: str,
    key: str,
) -> dict[str, Any] | None:
    """Return the record with the given idempotency_key, or None if absent.

    Used by the POST /api/history handler to detect replay (per ADR-0019 §Idempotency).
    """
    conn = _get_conn(db_path)
    row = conn.execute(
        "SELECT id, expr, result, ts, idempotency_key FROM history "
        "WHERE idempotency_key = ?",
        (key,),
    ).fetchone()
    return dict(row) if row else None


def reset_for_tests(db_path: str) -> None:
    """Delete all rows. Test-only — used by the ``/api/_test/reset`` endpoint.

    NOT exposed to the production API surface. Schema is preserved (only rows
    are cleared). Idempotency cache (in-memory in the API layer) is unaffected.

    Lazy-init's the schema first (no-op if already present) so this is safe to
    call against a fresh DB that hasn't been pre-initialized.
    """
    conn = _get_conn(db_path)  # triggers lazy schema init
    conn.execute("DELETE FROM history")
    conn.commit()


def is_uuid_v4(s: str) -> bool:
    """Return True if ``s`` is a valid UUID v4 string per ADR-0019 §Idempotency."""
    try:
        return uuid.UUID(s).version == 4
    except (ValueError, AttributeError, TypeError):
        return False


class IdempotencyConflictError(Exception):
    """Raised when a write is attempted with an ``idempotency_key`` that is
    already present in the ``history`` table (UNIQUE constraint violation).

    Callers (the API handler) should distinguish:
    - Same key + same payload → replay cache hit, return the stored row.
    - Same key + DIFFERENT payload → 409 Conflict (the key was reused with a
      different body, which is a client error per ADR-0019 §Idempotency).
    """

    def __init__(self, key: str) -> None:
        super().__init__(f"idempotency_key {key!r} already used")
        self.key = key
