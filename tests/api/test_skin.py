"""Contract tests for GET/PUT /api/skin (STORY-003a, AC1 + ADR-0019 + STORY-010).

Per ADR-0019 + ADR-0022 (skin persistence, refs #72):
- GET /api/skin → 200 {"skin": <name>, "available": ["dark", "light", "retro"]}
  (skin is DB-backed per STORY-010; default is "dark" on cold start)
- PUT /api/skin → 200 {"skin": "<name>", "applied_at": "<iso8601>"} (idempotent)
- PUT /api/skin without Idempotency-Key HEADER → 400 MissingIdempotencyKeyError
- PUT /api/skin with non-UUID-v4 Idempotency-Key HEADER → 400 InvalidIdempotencyKeyError
- PUT /api/skin with unknown skin → 400 UnknownSkinError
- PUT /api/skin with same key + same body → 200 cached (replay, no new audit row)
- PUT /api/skin with same key + DIFFERENT body → 409 IdempotencyConflictError
  (per ADR-0019 §Idempotency: "key reuse with different body is a client error")

The Idempotency-Key contract was tightened in STORY-010 from "body field, any
string" (the original PR #37 contract) to "header, UUID v4" (per ADR-0019 +
STORY-010 test contract PR #106). The body field is no longer the source;
the HEADER is. The "replay with different body returns cached" assertion in
the old contract was incorrect per ADR-0019 and is now a 409 Conflict.
"""

from __future__ import annotations

import uuid


def _uuid_v4() -> str:
    """Return a fresh UUID v4 string for the Idempotency-Key header."""
    return str(uuid.uuid4())


class TestGetSkin:
    def test_get_skin_default_is_dark(self, client):
        resp = client.get("/api/skin")
        assert resp.status_code == 200
        body = resp.json()
        # Default skin on cold start (no row in skin table yet) is "dark"
        # — the API layer applies the default, the DB only stores what was
        # explicitly set.
        assert body["skin"] == "dark"
        assert "available" in body
        assert "dark" in body["available"]
        assert "light" in body["available"]
        assert "retro" in body["available"]

    def test_get_skin_idempotent(self, client):
        """GET is naturally idempotent — multiple calls return the same skin."""
        r1 = client.get("/api/skin")
        r2 = client.get("/api/skin")
        assert r1.json()["skin"] == r2.json()["skin"]


class TestPutSkin:
    def test_put_skin_to_light(self, client):
        resp = client.put(
            "/api/skin",
            json={"skin": "light"},
            headers={"Idempotency-Key": _uuid_v4()},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["skin"] == "light"
        assert "applied_at" in body

    def test_put_skin_to_retro(self, client):
        resp = client.put(
            "/api/skin",
            json={"skin": "retro"},
            headers={"Idempotency-Key": _uuid_v4()},
        )
        assert resp.status_code == 200
        assert resp.json()["skin"] == "retro"

    def test_put_skin_requires_idempotency_key_header(self, client):
        """State-mutating endpoint MUST require Idempotency-Key header per ADR-0019.

        No header → 400 MissingIdempotencyKeyError (NOT 422 — the contract
        prefers 400, raised by the handler not Pydantic per ADR-0019
        §Idempotency keys).
        """
        resp = client.put("/api/skin", json={"skin": "light"})
        assert resp.status_code == 400
        body = resp.json()
        assert body["error"]["type"] == "MissingIdempotencyKeyError"

    def test_put_skin_invalid_idempotency_key_format(self, client):
        """Non-UUID-v4 Idempotency-Key header → 400 InvalidIdempotencyKeyError."""
        resp = client.put(
            "/api/skin",
            json={"skin": "light"},
            headers={"Idempotency-Key": "not-a-uuid"},
        )
        assert resp.status_code == 400
        body = resp.json()
        assert body["error"]["type"] == "InvalidIdempotencyKeyError"

    def test_put_skin_unknown_returns_400(self, client):
        resp = client.put(
            "/api/skin",
            json={"skin": "neon-pink"},
            headers={"Idempotency-Key": _uuid_v4()},
        )
        assert resp.status_code == 400
        body = resp.json()
        assert "error" in body
        assert body["error"]["type"] == "UnknownSkinError"

    def test_put_skin_idempotency_replay_returns_cached_response(self, client):
        """Replay with same key + same body → 200 cached (no new audit row).

        The skin_audit table has exactly 1 row for this key (the first PUT);
        the second PUT reads the existing audit row and returns its ts.
        """
        key = _uuid_v4()
        r1 = client.put(
            "/api/skin", json={"skin": "light"}, headers={"Idempotency-Key": key}
        )
        r2 = client.put(
            "/api/skin", json={"skin": "light"}, headers={"Idempotency-Key": key}
        )
        assert r1.status_code == 200
        assert r2.status_code == 200
        assert r1.json()["applied_at"] == r2.json()["applied_at"]

    def test_put_skin_idempotency_replay_with_different_body_returns_409(self, client):
        """Same key + DIFFERENT body → 409 IdempotencyConflictError.

        Per ADR-0019 §Idempotency keys: "key reuse with different body is a
        client error". This replaces the older (PR #37) cached-on-conflict
        behavior, which was an early interpretation that has since been
        superseded by the ADR-0019 spec and the STORY-010 test contract.
        """
        key = _uuid_v4()
        r1 = client.put(
            "/api/skin", json={"skin": "light"}, headers={"Idempotency-Key": key}
        )
        r2 = client.put(
            "/api/skin", json={"skin": "retro"}, headers={"Idempotency-Key": key}
        )
        assert r1.status_code == 200
        assert r1.json()["skin"] == "light"
        assert r2.status_code == 409
        assert r2.json()["error"]["type"] == "IdempotencyConflictError"
