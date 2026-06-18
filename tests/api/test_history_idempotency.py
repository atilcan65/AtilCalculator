"""Idempotency tests for POST /api/history (STORY-007, AC5).

Refs Issue #69. Per ADR-0019 §Idempotency keys:
- POST requires ``Idempotency-Key`` header (UUID v4)
- Replay of same key + same payload within 60s → cached response, NO duplicate DB row
- Replay of same key + DIFFERENT payload → 409 Conflict (per ADR-0019 spec)

These tests are the regression pin for AC5.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

import pytest


def _ts() -> str:
    return datetime.now(UTC).isoformat()


def _post_with_key(client, expr: str, result: str, ts: str, idempotency_key: str):
    return client.post(
        "/api/history",
        json={"expr": expr, "result": result, "ts": ts},
        headers={"Idempotency-Key": idempotency_key},
    )


class TestIdempotencyReplay:
    """TC-5: AC5 — Idempotency-Key replay returns cached response, no duplicate."""

    @pytest.mark.usefixtures("_temp_db")
    def test_replay_same_key_same_payload_returns_cached(self, client):
        """First POST 201; second POST with same key + same payload → 200 OR 201 cached.

        Per ADR-0019 §Idempotency keys, the second call should NOT create
        a duplicate row. Acceptable response: 200 (cached) or 201 (same
        id returned). Critical assertion: DB has exactly ONE record.
        """
        key = str(uuid.uuid4())
        ts = _ts()

        first = _post_with_key(client, "1 + 1", "2", ts, key)
        assert first.status_code == 201, f"First POST should succeed, got {first.status_code}"

        second = _post_with_key(client, "1 + 1", "2", ts, key)
        # Acceptable: 200 (cached) or 201 with same id (idempotent insert)
        assert second.status_code in (200, 201), (
            f"Replay should return 200 or 201, got {second.status_code}. "
            f"Body: {second.text}"
        )

        # Critical: DB has exactly one record (no duplicate)
        history = client.get("/api/history").json()["history"]
        matches = [h for h in history if h["expr"] == "1 + 1"]
        assert len(matches) == 1, (
            f"AC5 violation: replay created duplicate. "
            f"Expected 1 record, got {len(matches)}: {matches}"
        )

    @pytest.mark.usefixtures("_temp_db")
    def test_replay_same_key_different_payload_returns_409(self, client):
        """AP-12: Idempotency-Key reuse with DIFFERENT payload → 409 Conflict.

        Per ADR-0019 §Idempotency keys, key reuse with different body is a
        client error. The server returns 409 Conflict to signal the misuse.
        """
        key = str(uuid.uuid4())

        first = _post_with_key(client, "1 + 1", "2", _ts(), key)
        assert first.status_code == 201

        # Different payload, same key
        second = _post_with_key(client, "2 + 2", "4", _ts(), key)
        assert second.status_code == 409, (
            f"Different payload with same key must return 409 Conflict, "
            f"got {second.status_code}. Body: {second.text}"
        )


class TestIdempotencyTTL:
    """TC-5: AC5 — Idempotency cache TTL is 60s per ADR-0019.

    After 60s, the same key may be reused (cache expires). This test
    pins the 60s TTL boundary. NOTE: time-dependent; may need
    freezegun or mock-clock injection in the implementation.
    """

    @pytest.mark.skip(reason="Time-dependent test; requires freezegun or mock clock — defer to impl")
    def test_replay_after_60s_ttl_creates_new_record(self, client):
        """After 60s, same key + same payload creates a NEW record (cache expired)."""
        pass


class TestIdempotencyKeyFormat:
    """TC-9: Idempotency-Key must be UUID v4."""

    @pytest.mark.usefixtures("_temp_db")
    def test_non_uuid_idempotency_key_returns_400(self, client):
        resp = _post_with_key(client, "1 + 1", "2", _ts(), "not-a-uuid")
        assert resp.status_code == 400, (
            f"Non-UUID Idempotency-Key must return 400, got {resp.status_code}. "
            f"Body: {resp.text}"
        )

    @pytest.mark.usefixtures("_temp_db")
    def test_uuid_v1_idempotency_key_returns_400(self, client):
        """ADR-0019 specifies UUID v4 (not v1, v3, v5)."""
        # Generate a UUID v1
        v1_uuid = uuid.uuid1()
        resp = _post_with_key(client, "1 + 1", "2", _ts(), str(v1_uuid))
        # Acceptable: 400 (strict v4 check) or 201 (lenient UUID check)
        # Pin the strict behavior per ADR-0019 spec.
        assert resp.status_code == 400, (
            f"UUID v1 Idempotency-Key must return 400 (ADR-0019 requires v4), "
            f"got {resp.status_code}. Body: {resp.text}"
        )
