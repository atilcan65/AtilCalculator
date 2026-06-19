"""SQLite-backed skin preference persistence (STORY-010, refs #72).

Per ADR-0022 (R-5, MERGED via PR #82) — extends the persistence layer
with two new tables on the SAME SQLite file used by ``history.py``:

- ``skin`` — single-row key/value (always ``key='current'``); the active
  skin name. Updated on every successful PUT /api/skin.
- ``skin_audit`` — append-only log of every transition with the
  ``idempotency_key`` that drove it. The ``idempotency_key TEXT UNIQUE``
  constraint enforces AC5 (replay detection) at the DB layer. Same key
  + same body → no new audit row; same key + different body → 409
  Conflict (per ADR-0019 §Idempotency keys).

Cross-device sync (AC2) is provided automatically by the shared SQLite
file on the LAN — no application-level sync layer (per ADR-0022
§Cross-device sync model).

Engine ↔ UI separation (ADR-0017): this module is stdlib-only and has
no FastAPI / HTTP / engine deps. The same invariant that guards
``history.py`` applies here (``tests/engine/test_no_io_imports.py``).

Public surface
--------------

- :func:`init_db` — idempotent schema setup (skin + skin_audit).
- :func:`get_current_skin` — read the active skin name (or None).
- :func:`set_current_skin` — atomic UPDATE skin + INSERT skin_audit.
  Returns ``{"skin": ..., "applied_at": ...}`` on success.
- :func:`get_audit_by_idempotency_key` — replay detection: returns
  the audit row for a given key, or None.
- :func:`reset_for_tests` — DELETE all rows (test-only).
"""

from __future__ import annotations

import sqlite3
import threading
from datetime import UTC, datetime
from typing import Any

# ----------------------------------------------------------------------------
# Schema (pinned per ADR-0022 §Schema, extended for STORY-010).
# ----------------------------------------------------------------------------
_DDL: list[str] = [
    """CREATE TABLE IF NOT EXISTS skin (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
    )""",
    """CREATE TABLE IF NOT EXISTS skin_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_skin TEXT,
        to_skin TEXT NOT NULL,
        idempotency_key TEXT UNIQUE NOT NULL,
        ts TEXT NOT NULL
    )""",
]

# Thread-local connection cache (same pattern as history.py — FastAPI
# runs handlers in a thread pool, each thread gets its own SQLite
# connection; sqlite3.Connection is not thread-safe by default).
_local = threading.local()

# Process-level cache of paths that have been schema-initialized.
# Used for lazy init: the first request to a given DB path triggers
# _init_schema (idempotent CREATE IF NOT EXISTS), so the schema is
# guaranteed to exist regardless of import order or test setup.
# Module-level in main.py calls init_db at import time too, but that
# uses whatever HISTORY_DB_PATH was at import — tests that change the
# env var after import need lazy init on first request to take effect.
_initialized_paths: set[str] = set()

# Per ADR-0022 §Schema — single-row table; the active skin is always
# stored at key='current'. The schema allows extension (e.g., a
# per-device override key in a future Sprint), but AC1-AC5 only ever
# read/write the 'current' key.
CURRENT_SKIN_KEY = "current"


def _get_conn(db_path: str) -> sqlite3.Connection:
    """Return the thread-local SQLite connection for ``db_path``.

    Lazy schema init on first open (CREATE IF NOT EXISTS is idempotent,
    so this is safe to call repeatedly). PRAGMAs set per ADR-0022
    §PRAGMA settings (journal_mode=WAL, busy_timeout=5000).

    Lazy init also covers test scenarios where ``HISTORY_DB_PATH`` is
    changed after the app's import-time ``init_db`` call (the import
    uses the env var at module load; tests that set a new path before
    the first request need lazy init here to materialize the schema).
    """
    conn = getattr(_local, "conn", None)
    if conn is None or getattr(_local, "db_path", None) != db_path:
        if conn is not None:
            with __import__("contextlib").suppress(Exception):
                conn.close()
        if db_path not in _initialized_paths:
            _init_schema(db_path)
            _initialized_paths.add(db_path)
        conn = sqlite3.connect(db_path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        # PRAGMAs per ADR-0022 §PRAGMA settings.
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA synchronous = NORMAL")
        conn.execute("PRAGMA busy_timeout = 5000")
        _local.conn = conn
        _local.db_path = db_path
    return conn


def _init_schema(db_path: str) -> None:
    """Create the schema at ``db_path`` if absent. Idempotent.

    Uses a short-lived connection (separate from the cached thread-local
    connection) so the DDL is committed to the file before the cached
    connection opens. Same race-avoidance pattern as ``history.py``.

    The PRAGMAs (WAL mode, busy_timeout=5000) are applied HERE, on the
    init connection, so that subsequent connections to the same DB
    file inherit them — per ADR-0022 §PRAGMA settings. PRAGMAs set
    on a connection are persistent for the file (WAL especially).
    """
    conn = sqlite3.connect(db_path)
    try:
        # PRAGMA settings per ADR-0022 §PRAGMA settings. These must be
        # applied on the schema-init connection so that the file's
        # journal mode is WAL (not DELETE) before any other process /
        # connection reads the file. busy_timeout is a connection-level
        # setting and is re-applied in _get_conn() per-thread.
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA busy_timeout = 5000")
        for stmt in _DDL:
            conn.execute(stmt)
        conn.commit()
    finally:
        conn.close()


def init_db(db_path: str) -> None:
    """Initialize the skin + skin_audit schema at ``db_path`` (idempotent).

    Public API. Used by:
    - The ``_temp_db`` test fixture (per-test temp DB).
    - The FastAPI app startup event (production DB).

    Equivalent to ``_init_schema``; kept as a public function for
    explicit pre-init patterns. Records the path in ``_initialized_paths``
    so the lazy init in ``_get_conn`` can skip re-init for paths that
    were pre-initialized here.
    """
    _init_schema(db_path)
    _initialized_paths.add(db_path)


def _iso8601_now() -> str:
    """Return current UTC time as an ISO-8601 string (second precision)."""
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def get_current_skin(db_path: str) -> str | None:
    """Return the active skin name, or None if no skin has been set yet.

    The default skin ("dark") is returned by the API layer when this
    returns None — the API layer is the source of truth for defaults;
    the persistence layer only stores what was explicitly set.
    """
    conn = _get_conn(db_path)
    row = conn.execute(
        "SELECT value FROM skin WHERE key = ?",
        (CURRENT_SKIN_KEY,),
    ).fetchone()
    if row is None:
        return None
    return row["value"]


def set_current_skin(
    db_path: str,
    to_skin: str,
    idempotency_key: str,
) -> dict[str, str]:
    """Atomically UPDATE skin + INSERT skin_audit. Returns the new state.

    Both writes happen in the same transaction. If the audit INSERT
    fails (e.g., duplicate idempotency_key from a concurrent caller),
    the transaction rolls back and the caller's existing audit row is
    unchanged. This is the AC5 race-safe replay path.

    Returns:
        ``{"skin": <to_skin>, "applied_at": <iso8601 ts>}``.

    Raises:
        sqlite3.IntegrityError: if ``idempotency_key`` already exists
            in ``skin_audit`` (UNIQUE constraint violation). Callers
            should pre-check with :func:`get_audit_by_idempotency_key`
            to distinguish "replay" (200 cached) from "conflict" (409).
    """
    conn = _get_conn(db_path)
    ts = _iso8601_now()
    # Read the prior value for the audit log's from_skin column. Done
    # outside the transaction's mutation phase (SELECT doesn't take a
    # write lock); both the UPDATE and the INSERT happen atomically
    # below in a single transaction.
    prior_row = conn.execute(
        "SELECT value FROM skin WHERE key = ?",
        (CURRENT_SKIN_KEY,),
    ).fetchone()
    from_skin: str | None = prior_row["value"] if prior_row else None
    try:
        conn.execute("BEGIN")
        conn.execute(
            "INSERT OR REPLACE INTO skin (key, value, updated_at) "
            "VALUES (?, ?, ?)",
            (CURRENT_SKIN_KEY, to_skin, ts),
        )
        conn.execute(
            "INSERT INTO skin_audit (from_skin, to_skin, idempotency_key, ts) "
            "VALUES (?, ?, ?, ?)",
            (from_skin, to_skin, idempotency_key, ts),
        )
        conn.execute("COMMIT")
    except Exception:
        conn.execute("ROLLBACK")
        raise
    return {"skin": to_skin, "applied_at": ts}


def get_audit_by_idempotency_key(
    db_path: str,
    idempotency_key: str,
) -> dict[str, Any] | None:
    """Return the audit row for ``idempotency_key``, or None.

    Used by the API layer for AC5 replay detection:
    - ``None`` → fresh request, apply
    - same key + same ``to_skin`` → 200 cached (replay)
    - same key + different ``to_skin`` → 409 Conflict
    """
    conn = _get_conn(db_path)
    row = conn.execute(
        "SELECT from_skin, to_skin, idempotency_key, ts "
        "FROM skin_audit WHERE idempotency_key = ?",
        (idempotency_key,),
    ).fetchone()
    if row is None:
        return None
    return {
        "from_skin": row["from_skin"],
        "to_skin": row["to_skin"],
        "idempotency_key": row["idempotency_key"],
        "ts": row["ts"],
    }


def reset_for_tests(db_path: str) -> None:
    """DELETE all rows from skin + skin_audit. Test-only."""
    conn = _get_conn(db_path)
    conn.execute("DELETE FROM skin")
    conn.execute("DELETE FROM skin_audit")
    conn.commit()
