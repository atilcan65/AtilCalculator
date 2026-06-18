"""Contract tests for GET/PUT /api/skin (STORY-003a, AC1 + ADR-0019).

Per ADR-0019:
- GET /api/skin → 200 {"skin": "dark", "available": ["dark", "light", "retro"]}
- PUT /api/skin → 200 {"skin": "<name>", "applied_at": "<iso8601>"} (idempotent)
- PUT /api/skin without idempotency_key → 400 (state-mutating endpoints require it)
- PUT /api/skin with unknown skin → 400 UnknownSkinError
"""

from __future__ import annotations


class TestGetSkin:
    def test_get_skin_default_is_dark(self, client):
        resp = client.get("/api/skin")
        assert resp.status_code == 200
        body = resp.json()
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
            json={"skin": "light", "idempotency_key": "test-key-1"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["skin"] == "light"
        assert "applied_at" in body

    def test_put_skin_to_retro(self, client):
        resp = client.put(
            "/api/skin",
            json={"skin": "retro", "idempotency_key": "test-key-2"},
        )
        assert resp.status_code == 200
        assert resp.json()["skin"] == "retro"

    def test_put_skin_requires_idempotency_key(self, client):
        """State-mutating endpoint MUST require idempotency_key per ADR-0019."""
        resp = client.put("/api/skin", json={"skin": "light"})
        assert resp.status_code == 400

    def test_put_skin_unknown_returns_400(self, client):
        resp = client.put(
            "/api/skin",
            json={"skin": "neon-pink", "idempotency_key": "test-key-3"},
        )
        assert resp.status_code == 400
        body = resp.json()
        assert "error" in body
        assert body["error"]["type"] == "UnknownSkinError"

    def test_put_skin_idempotency_replay_returns_cached_response(self, client):
        """Replay with same key returns the FIRST response (no re-apply)."""
        key = "test-key-replay-1"
        r1 = client.put("/api/skin", json={"skin": "light", "idempotency_key": key})
        r2 = client.put("/api/skin", json={"skin": "light", "idempotency_key": key})
        assert r1.status_code == 200
        assert r2.status_code == 200
        assert r1.json()["applied_at"] == r2.json()["applied_at"]

    def test_put_skin_idempotency_replay_with_different_value_uses_cache(self, client):
        """Edge case: client changes mind and reuses key with different value.
        Per ADR-0019, the FIRST response is returned (cached, no re-apply).
        """
        key = "test-key-replay-2"
        r1 = client.put("/api/skin", json={"skin": "light", "idempotency_key": key})
        r2 = client.put("/api/skin", json={"skin": "retro", "idempotency_key": key})
        assert r1.json()["skin"] == "light"
        assert r2.json()["skin"] == "light"  # cached, not "retro"
