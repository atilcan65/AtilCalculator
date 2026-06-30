"""Substring search performance tests for STORY-007 (AC2).

Refs Issue #69. Per AC2:
- GIVEN the backend has 1000+ history records
- WHEN the browser requests GET /api/history?q=0.1
- THEN the response returns matching records (substring search on expr field)
- AND the response is <100ms p95 (M5)

These tests seed 1000+ records via direct SQLite insert and assert
the substring search completes within the latency budget.
"""

from __future__ import annotations

import os
import sqlite3
import statistics
import time

import pytest

SEED_COUNT = 1000  # AC2 minimum
SEED_EXPRS = [
    "0.1 + 0.1", "0.1 + 0.2", "0.1 + 0.3",
    "1 + 1", "2 + 2", "3 + 3", "10 * 10", "100 / 4",
    "1.5 * 2", "2.5 * 4", "0.01 + 0.02", "0.001 * 1000",
    "sin(0)", "cos(0)", "log(1)", "sqrt(4)",
    "(1 + 2) * 3", "((1 + 2) * 3) + 4", "1 / 3", "2 / 7",
]


def _seed_records(db_path: str, count: int = SEED_COUNT) -> int:
    """Insert ``count`` records directly into SQLite for the perf test.

    Returns the number of records inserted.
    """
    conn = sqlite3.connect(db_path)
    try:
        # Use a single executemany for fast bulk insert
        rows = [
            (
                SEED_EXPRS[i % len(SEED_EXPRS)],
                str(i),  # result as string (lossless per AC7)
                f"2026-06-{(i % 28) + 1:02d}T12:00:00+00:00",
            )
            for i in range(count)
        ]
        conn.executemany(
            "INSERT INTO history (expr, result, ts) VALUES (?, ?, ?)",
            rows,
        )
        conn.commit()
        return count
    finally:
        conn.close()


class TestSubstringSearch:
    """TC-2: AC2 — GET /api/history?q=... substring search with perf budget."""

    @pytest.mark.usefixtures("_temp_db")
    def test_search_with_1000_records_returns_matches(self):
        """Seed 1000 records, run substring search, assert matches returned."""
        db_path = os.environ["HISTORY_DB_PATH"]
        _seed_records(db_path, SEED_COUNT)

        # First, sanity: app must be running to test the HTTP endpoint
        try:
            from atilcalc.api.main import app  # type: ignore[import-not-found]
        except ImportError:
            pytest.skip("atilcalc.api.main not implemented yet — TDD red phase")
        from fastapi.testclient import TestClient

        client = TestClient(app)
        resp = client.get("/api/history", params={"q": "0.1"})
        assert resp.status_code == 200, f"GET /api/history?q=0.1 returned {resp.status_code}"
        history = resp.json()["history"]
        # Each seeded expr contains "0.1" — assert at least some matches
        matches = [h for h in history if "0.1" in h["expr"]]
        assert len(matches) > 0, (
            f"Substring search returned no matches for q='0.1'. "
            f"Got {len(history)} total records, 0 matches. "
            f"First 5 records: {history[:5]}"
        )

    @pytest.mark.usefixtures("_temp_db")
    def test_search_latency_p95_under_100ms(self):
        """AC2 perf budget: p95 of 20 substring-search calls < 100ms (env-aware).

        Seeds 1000 records, runs 20 GET /api/history?q=0.1 calls, asserts
        the p95 latency is under the 100ms M5 budget.

        Sprint 22 PIVOT Faz 1.2 env-aware: 2x BUDGET_MULTIPLIER on self-hosted
        runner per arch Option B verdict cmt 4842471072 + ADR-0019 amendment 3
        CANDIDATE. GH-hosted branch preserves strict 100ms budget (TC4 regression
        guard).
        """
        from tests.conftest import BUDGET_MULTIPLIER
        base_budget_ms = 100.0
        effective_budget_ms = base_budget_ms * BUDGET_MULTIPLIER

        db_path = os.environ["HISTORY_DB_PATH"]
        _seed_records(db_path, SEED_COUNT)

        try:
            from atilcalc.api.main import app  # type: ignore[import-not-found]
        except ImportError:
            pytest.skip("atilcalc.api.main not implemented yet — TDD red phase")
        from fastapi.testclient import TestClient

        client = TestClient(app)

        # Warm-up: one call to prime caches
        client.get("/api/history", params={"q": "0.1"})

        # Measure 20 calls
        latencies_ms: list[float] = []
        for _ in range(20):
            start = time.perf_counter()
            resp = client.get("/api/history", params={"q": "0.1"})
            elapsed_ms = (time.perf_counter() - start) * 1000
            assert resp.status_code == 200, (
                f"GET /api/history?q=0.1 returned {resp.status_code}: {resp.text}"
            )
            latencies_ms.append(elapsed_ms)

        # Compute p95 (the 95th percentile; for 20 samples, the 19th sample when sorted)
        latencies_sorted = sorted(latencies_ms)
        p95_index = int(0.95 * len(latencies_sorted)) - 1
        p95_ms = latencies_sorted[p95_index]
        median_ms = statistics.median(latencies_ms)

        assert p95_ms < effective_budget_ms, (
            f"AC2 perf budget violation: p95={p95_ms:.2f}ms exceeds "
            f"{effective_budget_ms:.0f}ms budget "
            f"(base={base_budget_ms}ms * BUDGET_MULTIPLIER={BUDGET_MULTIPLIER} "
            f"per Sprint 22 PIVOT Faz 1.2 env-aware). "
            f"Sample latencies (ms): {latencies_ms}. "
            f"Median: {median_ms:.2f}ms. "
            f"Suggested fixes: add index on `expr` column (LIKE '%substring%' cannot use index without FTS5), "
            f"use FTS5 virtual table for substring search, or precompute a trigram index."
        )

    @pytest.mark.usefixtures("_temp_db")
    def test_search_returns_empty_for_no_match(self):
        """q='xyznevermatches' → 200 with empty history list."""
        db_path = os.environ["HISTORY_DB_PATH"]
        _seed_records(db_path, SEED_COUNT)

        try:
            from atilcalc.api.main import app  # type: ignore[import-not-found]
        except ImportError:
            pytest.skip("atilcalc.api.main not implemented yet — TDD red phase")
        from fastapi.testclient import TestClient

        client = TestClient(app)
        resp = client.get("/api/history", params={"q": "xyznevermatches"})
        assert resp.status_code == 200
        history = resp.json()["history"]
        assert history == [], f"Expected empty result for non-matching q, got {len(history)} records"
