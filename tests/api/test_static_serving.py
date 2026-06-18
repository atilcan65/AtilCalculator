"""Contract tests for GET / (STORY-003a, AC1 + AC8 — static SPA shell).

Per ADR-0018, the FastAPI app serves the SPA shell (HTML + CSS + JS) from `GET /`.
The shell must contain the 3 custom-element tags: <atilcalc-display>,
<atilcalc-keypad>, <atilcalc-history>.
"""

from __future__ import annotations


class TestStaticServing:
    def test_get_root_serves_spa_shell(self, client):
        resp = client.get("/")
        assert resp.status_code == 200
        assert resp.headers["content-type"].startswith("text/html")

    def test_spa_shell_contains_three_custom_elements(self, client):
        """AC1: page shows display, keypad, and history panel."""
        body = client.get("/").text
        assert "<atilcalc-display" in body
        assert "<atilcalc-keypad" in body
        assert "<atilcalc-history" in body

    def test_unknown_path_returns_404(self, client):
        resp = client.get("/nonexistent-path")
        assert resp.status_code == 404

    def test_root_accessible_via_localhost(self, client):
        """AC8: 127.0.0.1:PORT serves the UI identically to localhost."""
        # Same handler for both — just verify GET / on TestClient works.
        # The "binds to 127.0.0.1, not 0.0.0.0" check is in LAN-bind (003b).
        resp = client.get("/")
        assert resp.status_code == 200
