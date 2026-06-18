"""Contract tests for POST /api/history + GET /api/history (STORY-007).

Refs Issue #69. Per ADR-0019 §API contract:
- POST /api/history → 201 {"id": int, "expr": ..., "result": ..., "ts": ...}
- GET /api/history → 200 {"history": [{"id": ..., "expr": ..., "result": ..., "ts": ...}, ...]}
- Reverse-chronological order (newest first)
- SQLite-backed (durable across restart; refs AC4)
- Idempotency-Key header required on POST (refs ADR-0019 §Idempotency)
- result is a string (lossless per AC7 + ADR-0019 §Decimal serialization)
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

import pytest

# Local imports guarded by try/except in test functions to enable TDD RED skip
try:
    from fastapi.testclient import TestClient  # type: ignore[import-not-found]
except ImportError:
    TestClient = None  # type: ignore[assignment]


def _ts() -> str:
    """Current UTC timestamp in ISO 8601."""
    return datetime.now(UTC).isoformat()


def _make_post(client, expr: str, result: str, ts: str, idempotency_key: str | None = None):
    """Helper for POST /api/history with idempotency-key header.

    Per ADR-0019 §Idempotency keys, POST requires an ``Idempotency-Key``
    header (UUID v4). If ``idempotency_key`` is None, a fresh UUID is
    generated; pass an explicit key for replay tests (AC5).
    """
    headers = {"Idempotency-Key": idempotency_key or str(uuid.uuid4())}
    return client.post(
        "/api/history",
        json={"expr": expr, "result": result, "ts": ts},
        headers=headers,
    )


def _try_import_persistence():
    """Import the persistence layer; returns None if not implemented."""
    try:
        from atilcalc.persistence.history import (  # type: ignore[import-not-found]
            init_db,
        )
    except ImportError:
        return None
    return init_db


class TestPostHistory:
    """TC-1: POST /api/history persists a record."""

    @pytest.mark.usefixtures("_temp_db")
    def test_post_history_returns_201(self, client):
        resp = _make_post(client, "1 + 1", "2", _ts())
        assert resp.status_code == 201, (
            f"POST /api/history should return 201 on success, got {resp.status_code}. "
            f"Body: {resp.text}"
        )

    @pytest.mark.usefixtures("_temp_db")
    def test_post_history_response_shape(self, client):
        """Response body has id, expr, result, ts per ADR-0019 §POST /api/history."""
        resp = _make_post(client, "1 + 1", "2", _ts())
        assert resp.status_code == 201
        body = resp.json()
        assert "id" in body, "POST response must include record id"
        assert isinstance(body["id"], int), "id must be int"
        assert body["expr"] == "1 + 1"
        assert body["result"] == "2"
        assert body["ts"]  # non-empty

    @pytest.mark.usefixtures("_temp_db")
    def test_post_history_persists_record(self, client):
        """AC1: POST persists to backend (visible in subsequent GET)."""
        ts = _ts()
        post_resp = _make_post(client, "0.1 + 0.2", "0.3", ts)
        assert post_resp.status_code == 201

        get_resp = client.get("/api/history")
        assert get_resp.status_code == 200
        history = get_resp.json()["history"]
        # At least one record matches our POST
        matches = [h for h in history if h["expr"] == "0.1 + 0.2"]
        assert len(matches) == 1, f"Expected 1 match for expr='0.1 + 0.2', got {len(matches)}"
        assert matches[0]["result"] == "0.3", (
            "AC7: result must be stored as string '0.3' (lossless per ADR-0019 §Decimal serialization)"
        )

    @pytest.mark.usefixtures("_temp_db")
    def test_post_history_requires_idempotency_key(self, client):
        """TC-8: POST without Idempotency-Key header returns 400.

        Per ADR-0019 §Idempotency keys, state-mutating endpoints require
        the header. Missing header → 400 with MissingIdempotencyKeyError.
        """
        resp = client.post(
            "/api/history",
            json={"expr": "1 + 1", "result": "2", "ts": _ts()},
        )
        assert resp.status_code == 400, (
            f"POST without Idempotency-Key must return 400, got {resp.status_code}. "
            f"Body: {resp.text}"
        )
        body = resp.json()
        assert "error" in body
        assert body["error"]["type"] == "MissingIdempotencyKeyError"

    @pytest.mark.usefixtures("_temp_db")
    def test_post_history_rejects_malformed_idempotency_key(self, client):
        """TC-9: Idempotency-Key must be UUID v4 per ADR-0019 §Idempotency."""
        resp = client.post(
            "/api/history",
            json={"expr": "1 + 1", "result": "2", "ts": _ts()},
            headers={"Idempotency-Key": "not-a-uuid"},
        )
        assert resp.status_code == 400, (
            f"Malformed Idempotency-Key must return 400, got {resp.status_code}. "
            f"Body: {resp.text}"
        )


class TestGetHistory:
    """TC-1, TC-2: GET /api/history returns persisted records."""

    @pytest.mark.usefixtures("_temp_db")
    def test_get_history_empty_returns_200(self, client):
        resp = client.get("/api/history")
        assert resp.status_code == 200
        body = resp.json()
        assert "history" in body
        assert isinstance(body["history"], list)
        # Empty DB → empty history (or previously-inserted records from prior tests in same session;
        # _temp_db isolates each test, so this should be empty)
        assert body["history"] == [], (
            f"_temp_db fixture should provide a fresh DB per test; "
            f"got {len(body['history'])} pre-existing records"
        )

    @pytest.mark.usefixtures("_temp_db")
    def test_get_history_after_post(self, client):
        """A successful POST is reflected in subsequent GET."""
        ts = _ts()
        _make_post(client, "1 + 1", "2", ts)
        resp = client.get("/api/history")
        assert resp.status_code == 200
        history = resp.json()["history"]
        assert len(history) >= 1
        assert history[0]["expr"] == "1 + 1"
        assert history[0]["result"] == "2"

    @pytest.mark.usefixtures("_temp_db")
    def test_get_history_reverse_chronological(self, client):
        """Newer records come first."""
        _make_post(client, "1 + 1", "2", _ts())
        _make_post(client, "2 + 2", "4", _ts())
        _make_post(client, "3 + 3", "6", _ts())
        history = client.get("/api/history").json()["history"]
        assert len(history) >= 3
        ts_list = [h["ts"] for h in history[:3]]
        assert ts_list == sorted(ts_list, reverse=True), (
            "history must be newest-first (reverse-chronological per ADR-0019 §GET /api/history)"
        )


class TestCrossDeviceSync:
    """TC-3: AC3 — cross-device sync via shared backend.

    Two TestClient instances pointing at the same SQLite file (via
    HISTORY_DB_PATH env override) simulate two devices. Records written
    by Client A must be visible to Client B.
    """

    def test_two_clients_share_backend(self, tmp_path, monkeypatch):
        """Two TestClient instances sharing the same SQLite DB see the same records.

        This is a deliberate double-fixture dance: we don't use the ``client``
        fixture (which is session-scoped) because we need a SECOND client
        pointing at the same DB. Instead we construct both clients manually
        inside the test, sharing the temp DB path.
        """
        persistence = _try_import_persistence()
        if persistence is None:
            pytest.skip("atilcalc.persistence.history not implemented yet — TDD red phase")

        try:
            from atilcalc.api.main import app  # type: ignore[import-not-found]
        except ImportError:
            pytest.skip("atilcalc.api.main not implemented yet — TDD red phase")

        db_path = tmp_path / "shared.db"
        monkeypatch.setenv("HISTORY_DB_PATH", str(db_path))

        init_db = persistence
        init_db(str(db_path))

        # Two clients, same DB
        client_a = TestClient(app)
        client_b = TestClient(app)

        # Client A writes
        resp_a = _make_post(client_a, "1 + 1", "2", _ts())
        assert resp_a.status_code == 201

        # Client B reads — must see Client A's record
        resp_b = client_b.get("/api/history")
        assert resp_b.status_code == 200
        history_b = resp_b.json()["history"]
        assert any(h["expr"] == "1 + 1" for h in history_b), (
            f"AC3 violation: Client B cannot see Client A's record. "
            f"Client B history: {history_b}"
        )
