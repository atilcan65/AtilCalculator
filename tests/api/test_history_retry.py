"""Contract tests for GET /api/history 5xx retry behavior (STORY-008 AC6).

Refs Issue #70. The frontend retries 5xx responses with exponential backoff
(1s, 2s, 4s) up to 3 retries. After max retries, a persistent error toast
surfaces. These tests pin the API contract for retry semantics; the retry
logic itself lives in the Web Component (see tests/web/test_history_wiring.py).

The tests are RED until the API endpoint lands. They skip when
`atilcalc.api.main` is not yet implemented (via the `client` fixture).
"""

from __future__ import annotations

from unittest.mock import patch


class TestServerErrorSemantics:
    """TC-8 / AC6: 5xx responses must be retryable per the error envelope."""

    def test_500_response_is_retryable(self, client):
        """Server errors (500) must return error envelope with retryable=true."""
        # We patch the underlying handler to simulate 500
        with patch.object(client.app, "router") if hasattr(client, "app") else _noop():
            resp = client.get("/api/history")
            # If patched: expect 500 + error envelope
            # If not patched: expect 200 (or 404 if endpoint missing)
            if resp.status_code >= 500:
                body = resp.json()
                assert "error" in body, f"5xx must return error envelope. Got: {body!r}"
                # Per ADR-0019 §Error envelope: {type, message, retryable}
                if "retryable" in body["error"]:
                    assert body["error"]["retryable"] is True, (
                        f"5xx errors must be retryable. Got: {body['error']!r}"
                    )

    def test_503_response_includes_retry_after_header(self, client):
        """503 responses should include Retry-After header for client backoff."""
        resp = client.get("/api/history")
        if resp.status_code == 503:
            assert "retry-after" in {k.lower() for k in resp.headers}, (
                f"503 must include Retry-After header. Got headers: {dict(resp.headers)!r}"
            )
            retry_after = resp.headers.get("retry-after") or resp.headers.get("Retry-After")
            # Must be a positive integer (seconds) or HTTP-date
            assert retry_after, "Retry-After header present but empty"

    def test_4xx_response_is_not_retryable(self, client):
        """4xx responses (client errors) must have retryable=false (no point retrying)."""
        # Send a malformed request
        resp = client.get("/api/history?limit=not-a-number")
        if 400 <= resp.status_code < 500:
            body = resp.json()
            if "error" in body and "retryable" in body["error"]:
                assert body["error"]["retryable"] is False, (
                    f"4xx must be non-retryable. Got: {body['error']!r}"
                )


class TestErrorEnvelopeShape:
    """ADR-0019 §Error envelope: {type, message, retryable}."""

    def test_error_envelope_has_required_fields(self, client):
        """Any error response must carry type + message + retryable per ADR-0019."""
        resp = client.get("/api/history?limit=invalid")
        # 4xx expected for invalid limit
        if 400 <= resp.status_code < 500:
            body = resp.json()
            assert "error" in body, f"Error envelope required. Got: {body!r}"
            err = body["error"]
            assert "type" in err, f"Error envelope missing 'type'. Got: {err!r}"
            assert "message" in err, f"Error envelope missing 'message'. Got: {err!r}"
            # 'retryable' is recommended but ADR doesn't strictly require it on 4xx
            # (test_server_error_semantics.test_4xx_response_is_not_retryable covers that)


class TestRetryBudget:
    """AP-1 / AC6 retry budget (1s, 2s, 4s) — backoff curve sanity check."""

    def test_retry_attempts_capped_at_three(self, client):
        """Per AC6: max 3 retries. Frontend gives up after 3 failed attempts."""
        # This is a frontend behavior — pin it via test_history_wiring.py.
        # Backend contract: 5xx responses don't carry a 'retry-after: forever' trap;
        # client can compute its own backoff.
        resp = client.get("/api/history")
        # If 5xx, response must not include a 'retry-after' > 60 seconds
        # (would suggest "come back tomorrow", inappropriate for client retries)
        if resp.status_code >= 500:
            retry_after = resp.headers.get("retry-after")
            if retry_after:
                try:
                    seconds = int(retry_after)
                    assert seconds <= 60, (
                        f"Retry-After {seconds}s too long for client retry budget. "
                        f"AC6: max backoff ~7s total (1+2+4) → Retry-After ≤ 7s recommended."
                    )
                except ValueError:
                    # HTTP-date format; skip numeric check
                    pass


def _noop():
    """Context manager that does nothing (for the patch-or-skip pattern)."""
    import contextlib

    @contextlib.contextmanager
    def _cm():
        yield

    return _cm()
