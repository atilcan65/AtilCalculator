"""Contract tests for GET /healthz (DEPLOY-003, ADR-0027 §Decision.3).

Per ADR-0027 §Decision.3:
- Request: ``GET /healthz`` (no auth, no body)
- Success: ``200 {"status": "ok", "git_sha": "<40-char-hex>", "ts": "<iso-8601>"}``
- Engine-import failure: ``503 {"status": "error", "error": "<msg>", "ts": "<iso-8601>"}``
- Cheap: <50ms p99, no DB I/O, no auth, no body.

The endpoint is consumed by DEPLOY-001's workflow post-deploy smoke test
(curl -fsS http://$DEPLOY_HOST:PORT/healthz) and by the auto-rollback
trigger on smoke-test failure.

Refs Issue #132, ADR-0027 §Decision.3, ADR-0019 §HTTP API contract.
"""

from __future__ import annotations

import re
import time

from fastapi.testclient import TestClient

HEX_SHA_RE = re.compile(r"^[0-9a-f]{40}$")
ISO_8601_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(\+\d{2}:\d{2}|Z)?$"
)


class TestHealthzHappyPath:
    """TC-1: GET /healthz returns 200 with status='ok' + git_sha + ts."""

    def test_healthz_returns_200(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        assert resp.status_code == 200, (
            f"Expected 200, got {resp.status_code}: {resp.text}"
        )

    def test_healthz_content_type_is_json(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        assert resp.headers["content-type"].startswith("application/json"), (
            f"Expected JSON content-type, got {resp.headers['content-type']}"
        )

    def test_healthz_status_is_ok(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        body = resp.json()
        assert body["status"] == "ok", (
            f"Expected status='ok', got {body.get('status')!r}. "
            f"Full body: {body}"
        )

    def test_healthz_git_sha_is_40_char_hex(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        body = resp.json()
        git_sha = body.get("git_sha")
        assert git_sha is not None, (
            f"git_sha should be present in healthy response, got {body}"
        )
        assert isinstance(git_sha, str), (
            f"git_sha must be a string (JSON-safe), got {type(git_sha).__name__}"
        )
        assert HEX_SHA_RE.match(git_sha), (
            f"git_sha must be 40-char hex (matches `git rev-parse HEAD`), "
            f"got {git_sha!r}"
        )

    def test_healthz_ts_is_iso8601(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        body = resp.json()
        ts = body.get("ts")
        assert ts is not None, f"ts should be present, got {body}"
        assert isinstance(ts, str), f"ts must be a string, got {type(ts).__name__}"
        assert ISO_8601_RE.match(ts), (
            f"ts must be ISO-8601 (e.g., 2026-06-19T18:30:00+00:00), got {ts!r}"
        )


class TestHealthzNoAuth:
    """TC-3: /healthz requires no authentication."""

    def test_healthz_no_auth_header_returns_200(self, client: TestClient) -> None:
        resp = client.get("/healthz")  # no Authorization header
        assert resp.status_code == 200, (
            f"Expected 200 without auth, got {resp.status_code}: {resp.text}"
        )

    def test_healthz_no_body_returns_200(self, client: TestClient) -> None:
        # FastAPI TestClient is requests-API-shaped for ``.get()`` (no body).
        # To send a GET with a body we must drop down to ``.request()`` —
        # httpx.Client.get does not accept ``json=``/``content=`` (those are
        # HTTP-body kwargs only on ``.request(method, ...)`` per the httpx
        # API contract). The endpoint contract is "GET ignores body".
        resp = client.request("GET", "/healthz", content=b"{}")
        assert resp.status_code == 200


class TestHealthzJsonCleanliness:
    """TC-4: response has no Decimal artifacts (per ADR-0019-amend-2)."""

    def test_healthz_no_decimal_serialization_artifacts(
        self, client: TestClient
    ) -> None:
        resp = client.get("/healthz")
        body = resp.json()
        raw = resp.text
        # Per ADR-0019-amend-2, response is JSON-only (no Decimal coercion).
        # Decimal can serialize as `1E+1` (scientific) or with trailing zeros.
        # These should not appear in a healthy response.
        assert "E+" not in raw, (
            f"Decimal positive-scientific notation leaked into /healthz response: {raw!r}"
        )
        assert "E-" not in raw, (
            f"Decimal negative-scientific notation leaked into /healthz response: {raw!r}"
        )
        # ts should be ISO-8601 string, not a numeric timestamp.
        ts = body.get("ts")
        if ts is not None:
            assert not isinstance(ts, int | float), (
                f"ts must be ISO-8601 string, got numeric: {ts!r}"
            )


class TestHealthzTimestampMonotonicity:
    """TC-6: ts is monotonically increasing across calls."""

    def test_healthz_ts_increases_across_calls(self, client: TestClient) -> None:
        resp1 = client.get("/healthz")
        ts1 = resp1.json()["ts"]
        # Sleep briefly to ensure ts moves forward.
        time.sleep(1.05)
        resp2 = client.get("/healthz")
        ts2 = resp2.json()["ts"]
        assert ts2 > ts1, (
            f"ts should be monotonically increasing: ts1={ts1!r} ts2={ts2!r}"
        )


class TestHealthzNoSecretLeakage:
    """AP-1 (test plan): /healthz does NOT leak secrets, env vars, or infra details."""

    def test_healthz_does_not_echo_secrets(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        raw = resp.text.lower()

        # These markers would indicate secret leakage.
        forbidden_markers = [
            "openssh private key",
            "-----begin",
            "atilcan65:",  # SSH key username prefix
            "ghp_",  # GitHub PAT prefix
            "password",
            "secret_value",
            "192.168.1.199",  # internal IP (only valid in DEPLOY-001 workflow, not /healthz)
        ]
        for marker in forbidden_markers:
            assert marker not in raw, (
                f"/healthz response contains forbidden marker {marker!r}: {raw!r}"
            )

    def test_healthz_response_keys_are_canonical(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        body = resp.json()
        # Per ADR-0027 §Decision.3, the contract is exactly:
        #   {"status": "ok"|"error", "git_sha": "<sha>", "ts": "<iso>"}
        # Optional fields per impl discretion, but core 3 must be present on 200.
        assert "status" in body, f"Missing 'status' key: {body}"
        # git_sha MAY be null in non-git env (TC-5); we tolerate either.
        assert "ts" in body, f"Missing 'ts' key: {body}"
        # No surprise keys with infra details.
        allowed_keys = {"status", "git_sha", "ts", "error", "version"}
        unexpected = set(body.keys()) - allowed_keys
        assert not unexpected, (
            f"Unexpected keys in /healthz response (possible info leak): "
            f"{unexpected}. Full body: {body}"
        )


# ----------------------------------------------------------------------------
# TDD-RED SKIPS — these would run once the impl lands and TC-1..TC-6 pass.
# ----------------------------------------------------------------------------
# TC-2 (engine import failure → 503): cannot simulate cleanly without
#   breaking the import chain for other tests. Marked TDD-red; impl PR
#   should add a fault-injection helper (e.g., import-time env var) to
#   enable this test path.
#
# TC-5 (git_sha=None when not in git repo): cannot run from inside the
#   test repo (we ARE in a git repo). Marked TDD-red; impl PR should
#   add an opt-in test fixture that mocks subprocess.run to fail.
#
# TC-7 + TC-8 (workflow integration + rollback): blocked on DEPLOY-001
#   workflow merge. Documented in docs/test-plans/DEPLOY-003-tests.md.
#   Will land as separate `tests/ops/test_deploy_workflow.py` once
#   DEPLOY-001 ships.
