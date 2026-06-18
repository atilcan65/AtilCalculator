"""Contract tests for the observability harness (ADR-0019 §Observability).

Every HTTP request must emit a structured log entry with at minimum:
- route (path)
- request_id (UUID, matches the error envelope's request_id on errors)
- latency_ms
- status

This is the runtime counterpart of d007 (Issue #35), which is the static check.
If the implementer's middleware stops logging, d007 T1 (file exists + referenced)
will pass, but this suite will fail — that's the desired layered defence.
"""

from __future__ import annotations

import io
import logging

import pytest


@pytest.fixture
def log_capture():
    """Capture logs from the ``atilcalc.api`` logger."""
    buf = io.StringIO()
    handler = logging.StreamHandler(buf)
    handler.setLevel(logging.DEBUG)
    logger = logging.getLogger("atilcalc.api")
    logger.addHandler(handler)
    logger.setLevel(logging.DEBUG)
    yield buf
    logger.removeHandler(handler)


class TestObservability:
    def test_request_emits_log_entry(self, client, log_capture):
        client.get("/api/skin")
        logs = log_capture.getvalue()
        assert "atilcalc.api" in logs or "request" in logs.lower()

    def test_error_logged_with_type(self, client, log_capture):
        client.post("/api/evaluate", json={"expr": "5 / 0"})
        logs = log_capture.getvalue()
        # Per ADR-0019 §Observability, engine errors are logged at WARNING with
        # the exception type, message, and request_id.
        assert "DivisionByZeroError" in logs or "engine_error" in logs.lower()

    def test_request_id_present_in_logs(self, client, log_capture):
        """The request_id in the error envelope must appear in the log line."""
        r = client.post("/api/evaluate", json={"expr": "5 / 0"})
        request_id = r.json()["error"]["request_id"]
        logs = log_capture.getvalue()
        assert request_id in logs
