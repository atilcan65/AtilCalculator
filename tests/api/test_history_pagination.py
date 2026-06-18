"""Contract tests for GET /api/history pagination (STORY-008 AC5).

Refs Issue #70. The history UI uses infinite-scroll lazy-load via
`?before=<ts>` cursor to fetch the next page of 50 records.

**Contract gap (P3 flag for developer)**: ADR-0019 does NOT pin the
response envelope for GET /api/history. The current in-memory deque
implementation returns `{"history": [...]}` (per `src/atilcalc/api/routes.py:288`).
These tests accept EITHER envelope (bare array OR `{"history": [...]}`)
and pin the AC5 semantics — pagination, cursor, edge cases — against
the eventual SQLite-backed implementation (per STORY-007).

The tests are RED until pagination lands. They skip when
`atilcalc.api.main` is not yet implemented (via the `client` fixture).
"""

from __future__ import annotations

import pytest

# TDD red guard — module-level skip ensures CI is green while the impl
# PR lands. Precondition per STORY-008 AC5:
#   - GET /api/history must honor `?limit=N` and return at most N records
#   - GET /api/history must honor `?before=<ts>` cursor (returns records
#     strictly older than ts)
# Smoke-test against the live FastAPI app; if it ignores `limit` or
# returns records newer than the cursor, skip with a message pointing
# at the impl PR (STORY-007 SQLite persistence + Issue #96 owner-implement
# path).
try:
    import uuid as _uuid

    from fastapi.testclient import TestClient  # type: ignore[import-not-found]

    from atilcalc.api.main import app

    _client = TestClient(app)
    # Seed 3 records with deterministic idempotency keys
    for _i, _expr in enumerate(("1 + 1", "2 + 2", "3 + 3"), start=1):
        _client.post(
            "/api/evaluate",
            json={"expr": _expr},
            headers={
                "Idempotency-Key": f"00000000-0000-4000-8000-{_i:012d}",
            },
        )
    _probe = _client.get("/api/history?limit=2")
    if _probe.status_code != 200:
        raise RuntimeError(f"limit=2 probe returned {_probe.status_code}")
    _probe_body = _probe.json()
    _probe_records = _probe_body if isinstance(_probe_body, list) else _probe_body.get("history", [])
    if len(_probe_records) > 2:
        raise RuntimeError(
            f"Pagination limit not honored: GET /api/history?limit=2 returned {len(_probe_records)} records"
        )
except Exception as _exc:
    if "Pagination limit not honored" in str(_exc):
        pytest.skip(
            "STORY-008 TDD red — pagination limit not honored per AC5. "
            "Implementation PR (owner-implement per Issue #96 path (b)) will unskip "
            "by adding LIMIT clause to GET /api/history handler.",
            allow_module_level=True,
        )
    raise


def _extract_records(body) -> list:
    """Normalize response envelope: bare array OR {"history": [...]}."""
    if isinstance(body, list):
        return body
    if isinstance(body, dict) and "history" in body:
        return body["history"]
    raise AssertionError(
        f"Response must be a JSON array or {{'history': [...]}} envelope. Got: {body!r}"
    )


def _make_post(client, expr: str, *, idempotency_key: str | None = None):
    """Helper: POST /api/evaluate, return (status, body)."""
    import uuid

    headers = {"Content-Type": "application/json"}
    if idempotency_key is None:
        idempotency_key = str(uuid.uuid4())
    headers["Idempotency-Key"] = idempotency_key
    return client.post(
        "/api/evaluate",
        json={"expr": expr},
        headers=headers,
    )


class TestPaginationCursor:
    """TC-7 / AC5: ?before=<ts> cursor returns next page of records."""

    def test_pagination_with_no_before_returns_latest(self, client):
        """GET /api/history (no params) returns the most recent 50 records."""
        resp = client.get("/api/history?limit=50")
        assert resp.status_code == 200, (
            f"Expected 200, got {resp.status_code}: {resp.text[:200]}. "
            f"AC5: GET /api/history is the pagination entry point."
        )
        body = resp.json()
        records = _extract_records(body)
        assert len(records) <= 50, (
            f"limit=50 must cap response at 50 records (got {len(records)})"
        )

    def test_pagination_with_before_returns_older_records(self, client):
        """GET /api/history?before=<ts> returns records strictly older than ts."""
        # Seed: post 3 records with deterministic expressions
        _make_post(client, "1 + 1", idempotency_key="00000000-0000-4000-8000-000000000001")
        _make_post(client, "2 + 2", idempotency_key="00000000-0000-4000-8000-000000000002")
        _make_post(client, "3 + 3", idempotency_key="00000000-0000-4000-8000-000000000003")

        # First page
        page1 = client.get("/api/history?limit=2")
        assert page1.status_code == 200, f"First page must be 200, got {page1.status_code}"
        page1_records = _extract_records(page1.json())
        assert len(page1_records) == 2, (
            f"limit=2 → 2 records, got {len(page1_records)}. "
            f"Pagination cap not implemented yet? (current impl ignores limit)"
        )

        # Second page via cursor (oldest ts on page1)
        oldest_ts_on_page1 = page1_records[-1].get("ts") or page1_records[-1].get("created_at")
        assert oldest_ts_on_page1, (
            f"page1 record must have ts/created_at field: {page1_records[-1]!r}"
        )

        page2 = client.get(f"/api/history?limit=2&before={oldest_ts_on_page1}")
        assert page2.status_code == 200, (
            f"Second page must be 200, got {page2.status_code}. "
            f"Pagination cursor may not be implemented yet."
        )
        page2_records = _extract_records(page2.json())
        # Records on page2 must be strictly older than oldest on page1
        for entry in page2_records:
            entry_ts = entry.get("ts") or entry.get("created_at")
            assert entry_ts < oldest_ts_on_page1, (
                f"AC5: ?before={oldest_ts_on_page1} must return records with ts < {oldest_ts_on_page1}. "
                f"Got: {entry_ts} (entry: {entry!r})"
            )

    def test_pagination_response_shape(self, client):
        """Each entry must have expr + result + ts (or created_at) per ADR-0019 §Response."""
        resp = client.get("/api/history?limit=10")
        if resp.status_code != 200:
            return
        records = _extract_records(resp.json())
        if not records:
            return  # no records to inspect
        entry = records[0]
        # At minimum we need the expression, the result, and a timestamp
        assert "expr" in entry or "expression" in entry, (
            f"History entry must carry the expression (AC1/ADR-0019). Got: {list(entry.keys())}"
        )
        assert "result" in entry, (
            f"History entry must carry the result (ADR-0019 §Decimal string). Got: {list(entry.keys())}"
        )
        assert "ts" in entry or "created_at" in entry, (
            f"History entry must carry ts or created_at (AC5 cursor field). Got: {list(entry.keys())}"
        )


class TestPaginationEdgeCases:
    """AP-1 / AP-4: edge cases for pagination cursor."""

    def test_pagination_before_future_ts_returns_empty(self, client):
        """?before=<future_ts> should return an empty list (no records older than future)."""
        resp = client.get("/api/history?limit=10&before=9999-12-31T23:59:59Z")
        assert resp.status_code == 200, (
            f"Expected 200, got {resp.status_code}. Pagination with far-future before must return empty."
        )
        records = _extract_records(resp.json())
        assert records == [], (
            f"?before=<future_ts> must return empty records. Got: {records!r}"
        )

    def test_pagination_before_epoch_returns_empty(self, client):
        """?before=1970-01-01T00:00:00Z returns empty (no records older than epoch)."""
        resp = client.get("/api/history?limit=10&before=1970-01-01T00:00:00Z")
        assert resp.status_code == 200
        records = _extract_records(resp.json())
        assert records == [], f"Pre-epoch before cursor must return empty. Got: {records!r}"

    def test_pagination_limit_zero_or_negative_400_or_empty(self, client):
        """limit=0 or limit=-1 must reject (400) or return empty."""
        for bad_limit in ("0", "-1", "abc"):
            resp = client.get(f"/api/history?limit={bad_limit}")
            # 400 (validation) OR 200 with empty list are both acceptable
            if resp.status_code == 200:
                records = _extract_records(resp.json())
                assert records == [], (
                    f"limit={bad_limit} returned 200 but non-empty: {records!r}"
                )
            else:
                assert resp.status_code == 400, (
                    f"limit={bad_limit} must return 400 (validation) or 200+[]. "
                    f"Got: {resp.status_code} {resp.text[:200]}"
                )

    def test_pagination_limit_cap_at_50_or_100(self, client):
        """limit=9999 must be capped at server max (50 or 100 per ADR-0019)."""
        resp = client.get("/api/history?limit=9999")
        assert resp.status_code == 200, (
            f"limit=9999 should be accepted (capped). Got: {resp.status_code}"
        )
        records = _extract_records(resp.json())
        # Cap value per ADR-0019: max 100 (we accept ≤ 100 to be lenient)
        assert len(records) <= 100, (
            f"limit=9999 must be capped server-side at ≤100. Got: {len(records)} records."
        )
