"""Contract tests for GET /api/history (STORY-003a, AC1 + ADR-0019).

Per ADR-0019:
- GET /api/history → 200 {"history": [{"expr": ..., "result": ..., "ts": ...}, ...]}
- Reverse-chronological order (newest first)
- In-memory deque; cleared on server restart
- Default 50 entries, max 1000
"""

from __future__ import annotations

import pytest


class TestGetHistory:
    def test_get_history_empty_returns_200(self, client):
        resp = client.get("/api/history")
        assert resp.status_code == 200
        body = resp.json()
        assert "history" in body
        assert isinstance(body["history"], list)

    def test_get_history_after_evaluation(self, client):
        """A successful evaluation is appended to history."""
        client.post("/api/evaluate", json={"expr": "1 + 1"})
        client.post("/api/evaluate", json={"expr": "2 + 2"})
        resp = client.get("/api/history")
        assert resp.status_code == 200
        history = resp.json()["history"]
        assert len(history) >= 2
        # Most recent first
        assert history[0]["expr"] == "2 + 2"
        assert history[0]["result"] == "4"

    def test_get_history_reverse_chronological(self, client):
        """Newer entries come first."""
        client.post("/api/evaluate", json={"expr": "1 + 1"})
        client.post("/api/evaluate", json={"expr": "2 + 2"})
        client.post("/api/evaluate", json={"expr": "3 + 3"})
        history = client.get("/api/history").json()["history"]
        if len(history) >= 2:
            ts_list = [h["ts"] for h in history[:3]]
            assert ts_list == sorted(ts_list, reverse=True), "history must be newest-first"
