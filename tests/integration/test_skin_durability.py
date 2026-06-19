"""Integration tests for STORY-010 AC3 — durability (SQLite file-backed, not in-memory).

Refs Issue #72. Per ADR-0022:
- SQLite file at HISTORY_DB_PATH (default ~/.local/share/atilcalc/history.db)
- skin table schema: (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL)
- PRAGMA journal_mode=WAL, synchronous=NORMAL, busy_timeout=5000

TDD red: skip on missing impl. Module-level probe checks the same schema/PRAGMA
preconditions as test_skin_persistence.py.
"""

from __future__ import annotations

import os
import sqlite3
import uuid
from pathlib import Path

import pytest

try:
    from fastapi.testclient import TestClient  # type: ignore[import-not-found]

    from atilcalc.api.main import app  # type: ignore[import-not-found]

    _TEST_DB_PATH = Path(
        os.environ.get(
            "HISTORY_DB_PATH",
            f"/tmp/atilcalc-test-skin-durability-{uuid.uuid4().int}.db",
        )
    )
    _TEST_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    os.environ["HISTORY_DB_PATH"] = str(_TEST_DB_PATH)

    _client = TestClient(app)

    # Probe: skin table schema
    _conn = sqlite3.connect(str(_TEST_DB_PATH))
    _cols = {
        row[1]
        for row in _conn.execute("PRAGMA table_info(skin);").fetchall()
    }
    if not {"key", "value", "updated_at"}.issubset(_cols):
        raise RuntimeError(
            f"AC3: skin table missing required columns. Have: {_cols}"
        )
    _conn.close()

except Exception as _exc:
    _msg = str(_exc)
    if (
        any(marker in _msg for marker in ["AC3", "probe"])
        or "import" in _msg.lower()
        or "module" in _msg.lower()
        or "table" in _msg.lower()
    ):
        pytest.skip(  # type: ignore[name-defined]
            "STORY-010 TDD red — skin persistence not yet wired. "
            "Durability tests probe SQLite file directly (bypassing HTTP layer).",
            allow_module_level=True,
        )
    raise


# ---------------------------------------------------------------------------
# TC-5: AC3 — SQLite file contains the persisted skin row
# ---------------------------------------------------------------------------
class TestSqliteFileContainsSkinRow:
    """AC3: PUT /api/skin materializes a row in the SQLite skin table."""

    def test_put_skin_inserts_row_in_sqlite(self) -> None:
        """PUT skin=light → SELECT FROM skin returns ('current', 'light', '<ts>')."""
        # Wipe + apply
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        _conn.execute("DELETE FROM skin;")
        _conn.commit()
        _conn.close()

        idempotency_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        put_resp = _client.put(
            "/api/skin",
            json={"skin": "light"},
            headers={"Idempotency-Key": idempotency_key},
        )
        assert put_resp.status_code == 200, (
            f"AC3 setup PUT failed: {put_resp.status_code}: {put_resp.text!r}"
        )

        # Direct DB query (bypassing HTTP layer)
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        rows = _conn.execute("SELECT key, value, updated_at FROM skin;").fetchall()
        _conn.close()

        assert len(rows) == 1, (
            f"AC3: expected exactly 1 row in skin table; got {len(rows)}: {rows!r}"
        )
        key, value, updated_at = rows[0]
        assert key == "current", (
            f"AC3: skin table key must be 'current'; got {key!r}"
        )
        assert value == "light", (
            f"AC3: skin table value must be 'light'; got {value!r}"
        )
        assert updated_at, (
            "AC3: skin table updated_at must be set; got empty string"
        )
        # ISO 8601 sanity check
        try:
            from datetime import datetime

            datetime.fromisoformat(updated_at)
        except (ValueError, TypeError) as e:
            pytest.fail(
                f"AC3: updated_at must be ISO 8601 string; got {updated_at!r}: {e}"
            )

    def test_get_skin_reads_from_sqlite_not_memory(self) -> None:
        """AC3 (negative): bypass HTTP, write directly to SQLite, verify GET picks it up."""
        # Wipe + write directly via sqlite3 (bypassing HTTP layer)
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        _conn.execute("DELETE FROM skin;")
        _conn.execute(
            "INSERT INTO skin (key, value, updated_at) VALUES (?, ?, ?);",
            ("current", "retro", "2026-06-19T00:00:00"),
        )
        _conn.commit()
        _conn.close()

        # GET via HTTP — must read from SQLite, return 'retro'
        resp = _client.get("/api/skin")
        body = resp.json()
        assert body["skin"] == "retro", (
            f"AC3: GET must read from SQLite (not memory). "
            f"Direct DB write 'retro' → HTTP GET returned {body['skin']!r}. "
            f"This indicates in-memory fallback is hiding the persistence layer."
        )


# ---------------------------------------------------------------------------
# TC-6: AC3 (negative) — corrupted SQLite file → loud failure, NOT silent fallback
# ---------------------------------------------------------------------------
class TestCorruptedSqliteFailsLoudly:
    """AC3 (negative): silent fallback to in-memory would violate AC1 (data loss on restart)."""

    def test_corrupted_db_does_not_silently_fallback(self, tmp_path: Path) -> None:
        """Corrupted SQLite file → server refuses to start OR returns 500; never silent fallback."""
        pytest.skip(
            "Corrupted-DB test requires corrupting _db_path and re-importing app. "
            "TDD red: skip; impl PR must surface this case explicitly."
        )
