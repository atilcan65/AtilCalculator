"""Durability tests for STORY-007 (AC4).

Refs Issue #69. Per AC4:
- GIVEN the FastAPI server restarts
- WHEN the browser calls GET /api/history
- THEN all records are intact (durability: SQLite file on disk, not in-memory)

These tests simulate a server restart by closing + reopening the
SQLite connection (and the FastAPI TestClient) and asserting records
survive.
"""

from __future__ import annotations

import sqlite3
import uuid
from datetime import UTC, datetime

import pytest


def _ts() -> str:
    return datetime.now(UTC).isoformat()


def _post(client, expr: str, result: str, ts: str):
    return client.post(
        "/api/history",
        json={"expr": expr, "result": result, "ts": ts},
        headers={"Idempotency-Key": str(uuid.uuid4())},
    )


class TestDurabilityAcrossRestart:
    """TC-4: AC4 — records survive FastAPI server restart.

    Simulates restart by creating a new TestClient pointing at the
    SAME SQLite file. Records written before the restart must be
    visible after the restart.
    """

    def test_records_survive_testclient_restart(self, tmp_path, monkeypatch):
        """Write records, then create a NEW TestClient on same DB → records persist."""
        try:
            from atilcalc.api.main import app  # type: ignore[import-not-found]
            from atilcalc.persistence.history import init_db  # type: ignore[import-not-found]
        except ImportError:
            pytest.skip(
                "atilcalc.persistence.history or atilcalc.api.main not implemented yet — "
                "TDD red phase. Land the persistence layer per docs/test-plans/STORY-007-tests.md."
            )

        from fastapi.testclient import TestClient

        db_path = tmp_path / "durability.db"
        monkeypatch.setenv("HISTORY_DB_PATH", str(db_path))

        init_db(str(db_path))

        # Phase 1: write records
        client_1 = TestClient(app)
        _post(client_1, "1 + 1", "2", _ts())
        _post(client_1, "2 + 2", "4", _ts())

        # Phase 2: simulate restart by creating a NEW TestClient (same DB)
        client_2 = TestClient(app)
        history = client_2.get("/api/history").json()["history"]

        assert len(history) >= 2, (
            f"AC4 violation: records did not survive restart. "
            f"Expected ≥2 records, got {len(history)}: {history}"
        )

        exprs = [h["expr"] for h in history]
        assert "1 + 1" in exprs, "Record '1 + 1' lost across restart"
        assert "2 + 2" in exprs, "Record '2 + 2' lost across restart"

    @pytest.mark.usefixtures("_temp_db")
    def test_records_survive_direct_db_close_reopen(self):
        """Lower-level: close the SQLite connection, reopen, records persist.

        This pins the durability at the SQLite layer (independent of
        the FastAPI app lifecycle). If SQLite is configured with
        ``journal_mode=DELETE`` (default) and ``synchronous=FULL``,
        every write is durably committed before the call returns.
        """
        import os
        db_path = os.environ["HISTORY_DB_PATH"]
        ts = _ts()

        # Write via direct sqlite3 (simulating the persistence layer)
        conn = sqlite3.connect(db_path)
        try:
            conn.execute(
                "INSERT INTO history (expr, result, ts) VALUES (?, ?, ?)",
                ("1 + 1", "2", ts),
            )
            conn.commit()
        finally:
            conn.close()

        # Reopen and verify
        conn = sqlite3.connect(db_path)
        try:
            cur = conn.execute("SELECT expr, result, ts FROM history")
            rows = cur.fetchall()
            assert len(rows) == 1, (
                f"AC4 violation: record lost across SQLite close/reopen. "
                f"Expected 1 row, got {len(rows)}: {rows}"
            )
            assert rows[0] == ("1 + 1", "2", ts), (
                f"Row contents drifted across close/reopen: expected ('1 + 1', '2', {ts!r}), "
                f"got {rows[0]!r}"
            )
        finally:
            conn.close()


class TestDurabilityConfig:
    """AC4: SQLite configuration must be durable (not :memory:, not DELETE journal)."""

    @pytest.mark.usefixtures("_temp_db")
    def test_db_path_is_file_not_memory(self):
        """The DB must be a file path, not ':memory:'."""
        import os
        db_path = os.environ["HISTORY_DB_PATH"]
        assert db_path != ":memory:", (
            "AC4 violation: DB is in-memory. History will not survive restart. "
            "Use a file path per ADR-0019 §Durability."
        )
        assert not db_path.startswith("file::memory:"), (
            f"AC4 violation: DB uses SQLite memory mode: {db_path!r}. "
            f"Use a file path per ADR-0019 §Durability."
        )
