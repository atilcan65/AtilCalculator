"""Decimal precision regression pin for STORY-007 (AC7).

Refs Issue #69. Per ADR-0019 §Decimal serialization + Trailing-zero rule (PR #63 amendment):
- result field MUST be a string (no float coercion)
- trailing zeros MUST be preserved: `Decimal("105.00")` → "105.00" (NOT "105")
- Lossless round-trip: store → fetch returns exact string

These tests are the regression pin for AC7 (Decimal precision lossless).
"""

from __future__ import annotations

import os
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


class TestDecimalPrecision:
    """AC7: result is a string, lossless on storage + retrieval."""

    @pytest.mark.usefixtures("_temp_db")
    def test_result_is_string_not_number_in_response(self, client):
        """POST response: result is string, not float-coerced number."""
        resp = _post(client, "0.1 + 0.2", "0.3", _ts())
        assert resp.status_code == 201
        body = resp.json()
        assert isinstance(body["result"], str), (
            f"AC7: result must be string (lossless per ADR-0019 §Decimal serialization), "
            f"got {type(body['result']).__name__}"
        )
        assert body["result"] == "0.3"

    @pytest.mark.usefixtures("_temp_db")
    def test_trailing_zeros_preserved(self, client):
        """ADR-0019 amendment (PR #63): Decimal("105.00") must round-trip as "105.00".

        This is the exact trailing-zero rule pinned in PR #63 P3 #2.
        Regression risk: SQLite NUMERIC type or float coercion strips
        trailing zeros → "105.00" becomes "105" → breaks the precision
        guarantee.
        """
        resp = _post(client, "100 + 5%", "105.00", _ts())
        assert resp.status_code == 201
        body = resp.json()
        assert body["result"] == "105.00", (
            f"Trailing zeros must be preserved: expected '105.00', got {body['result']!r}. "
            f"This is the ADR-0019 trailing-zero rule pinned in PR #63 P3 #2."
        )

    @pytest.mark.usefixtures("_temp_db")
    def test_long_decimal_round_trips_exactly(self, client):
        """A 30-digit computation must not lose precision in storage."""
        long_result = "3.333333333333333333333333333333"
        resp = _post(client, "1 / 3", long_result, _ts())
        assert resp.status_code == 201
        body = resp.json()
        assert body["result"] == long_result, (
            f"Long Decimal precision must round-trip exactly: "
            f"expected {long_result!r}, got {body['result']!r}"
        )

    @pytest.mark.usefixtures("_temp_db")
    def test_storage_layer_uses_text_not_numeric(self):
        """Direct SQL inspection: result column type must be TEXT, not NUMERIC.

        Per ADR-0019 §Decimal serialization, the storage column must be
        TEXT (lossless). NUMERIC would coerce to float and strip trailing
        zeros — a regression we'd catch via the test above, but this is
        the structural pin at the schema level.
        """
        # DB path is set by the _temp_db fixture via HISTORY_DB_PATH env var
        db_path = os.environ["HISTORY_DB_PATH"]
        conn = sqlite3.connect(db_path)
        try:
            cur = conn.execute(
                "SELECT type, sql FROM sqlite_master WHERE type='table' AND name='history'"
            )
            row = cur.fetchone()
            if row is None:
                # List all tables for the error message
                all_tables = conn.execute(
                    "SELECT name FROM sqlite_master WHERE type='table'"
                ).fetchall()
                pytest.fail(
                    f"Expected 'history' table in {db_path}, got tables: {all_tables}"
                )
            _table_type, schema_sql = row
            assert "result" in schema_sql, "history table must have 'result' column"
            # The 'result' column type must be TEXT (not NUMERIC or REAL)
            assert "result TEXT" in schema_sql.upper(), (
                f"AC7 violation: 'result' column must be TEXT (lossless), "
                f"got schema: {schema_sql!r}. "
                f"NUMERIC/REAL would coerce Decimal to float and strip trailing zeros."
            )
        finally:
            conn.close()
