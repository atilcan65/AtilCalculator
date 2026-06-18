"""Shared fixtures for the FastAPI contract suite (STORY-003a + STORY-007).

These fixtures wire the FastAPI TestClient to the as-implemented app at
``src/atilcalc/api/main.py``. They are deliberately minimal — the contract
tests in this directory are the executable spec; the implementer's job is to
land the FastAPI app that makes them pass.

The dependency on ``httpx`` and ``fastapi`` is added to ``pyproject.toml`` dev
extras as part of the implementation PR (see Issue #30 / ADR-0019).

STORY-007 extensions (refs Issue #69, ADR-0019 §API contract):
- ``_temp_db`` fixture: per-test SQLite file in ``tmp_path`` (AC6 test isolation)
- ``make_post`` helper: wraps ``client.post`` with idempotency-key header
- ``HISTORY_DB_PATH`` env override: app reads DB path from env (AC6 isolation)
"""

from __future__ import annotations

import contextlib
import uuid

import pytest


def _try_import_app():
    """Import the FastAPI app, returning None if not yet implemented.

    TDD red: before the implementer lands ``src/atilcalc/api/main.py``, this
    returns ``None`` and every test that depends on the ``client`` fixture
    fails with a clear "app not implemented" error. Once the app lands, the
    import succeeds and the contract tests can be collected + executed.
    """
    try:
        from atilcalc.api.main import app  # type: ignore[import-not-found]
    except ImportError:
        return None
    return app


@pytest.fixture(scope="session")
def client():
    """FastAPI TestClient bound to the as-implemented app.

    Skips with a clear message if the app module is not yet on the path.
    """
    app = _try_import_app()
    if app is None:
        pytest.skip(
            "atilcalc.api.main not implemented yet — TDD red phase. "
            "Land the FastAPI app per docs/test-plans/STORY-003a-tests.md to enable this fixture."
        )
    from fastapi.testclient import TestClient  # type: ignore[import-not-found]

    return TestClient(app)


@pytest.fixture(autouse=True)
def _history_reset(client):
    """Clear the in-memory history between tests for determinism.

    No-op if the history reset endpoint is not yet implemented; tests that
    depend on a clean history use this fixture explicitly.

    STORY-007: this fixture is superseded by ``_temp_db`` for tests that
    require SQLite persistence. The in-memory reset is retained for
    STORY-003a backward compat (Issue #30 + #52 regression pin).
    """
    if client is None:
        return
    # Best-effort: the implementer may not have a reset endpoint.
    # If absent, individual tests must arrange their own setup.
    with contextlib.suppress(Exception):
        client.post("/api/_test/reset")  # type: ignore[union-attr]
    return


# ----------------------------------------------------------------------------
# STORY-007 fixtures (refs Issue #69 — persistent cross-device history)
# ----------------------------------------------------------------------------


def _try_import_persistence():
    """Import the persistence layer, returning None if not yet implemented.

    TDD red: before the implementer lands ``src/atilcalc/persistence/`` (or
    equivalent module per R-5 ADR), this returns ``None`` and every test
    that depends on ``_temp_db`` skips with a clear message. Once the
    persistence layer lands, the import succeeds and tests run.
    """
    try:
        from atilcalc.persistence.history import (  # type: ignore[import-not-found]
            init_db,
            insert_record,
        )
    except ImportError:
        return None
    return init_db, insert_record


@pytest.fixture
def _temp_db(tmp_path, monkeypatch):
    """Per-test SQLite file for AC6 (test isolation, no production DB touched).

    Creates a fresh ``history-{test_id}.db`` in pytest's ``tmp_path``, sets
    the ``HISTORY_DB_PATH`` env var so the FastAPI app points at this temp
    file, and cleans up after the test. Each test gets a clean DB → no
    leakage between tests, no production data touched.

    Skips with a clear message if the persistence module is not yet
    implemented (TDD red phase). Tests that need the DB path should read
    it from ``os.environ["HISTORY_DB_PATH"]`` (set by this fixture).

    NOTE: dev fix during STORY-007 impl. The previous version of this
    fixture did ``db_path.unlink(missing_ok=True)`` in the fixture body
    (no ``yield``), which deleted the temp file BEFORE the test body ran.
    Tests that open the file directly with ``sqlite3.connect(db_path)``
    (e.g. ``test_history_decimal_precision``'s schema-type assertion and
    ``test_history_search_perf``'s bulk seed) saw an empty file and
    failed with ``no such table: history``. The proper pytest teardown
    pattern is to ``yield`` to the test body, then clean up after.
    See https://docs.pytest.org/en/stable/how-to/fixtures.html#teardown-cleanup
    """
    persistence = _try_import_persistence()
    if persistence is None:
        pytest.skip(
            "atilcalc.persistence.history not implemented yet — TDD red phase. "
            "Land the SQLite persistence layer per docs/test-plans/STORY-007-tests.md "
            "to enable AC4/AC6 tests."
        )
    init_db, _ = persistence
    db_path = tmp_path / f"history-{uuid.uuid4().hex[:8]}.db"
    monkeypatch.setenv("HISTORY_DB_PATH", str(db_path))
    init_db(str(db_path))
    yield  # let the test body run against the freshly-initialised DB
    # Teardown: tmp_path auto-cleans at session end, but explicit unlink
    # gives us paranoid isolation and surfaces lingering handles earlier.
    with contextlib.suppress(Exception):
        db_path.unlink(missing_ok=True)


def make_post(client, expr: str, result: str, ts: str, idempotency_key: str | None = None):
    """Helper for POST /api/history with idempotency-key header.

    Per ADR-0019 §Idempotency keys, POST requires an ``Idempotency-Key``
    header (UUID v4). If ``idempotency_key`` is None, a fresh UUID is
    generated; pass an explicit key for replay tests (AC5).

    Returns the TestClient response object.
    """
    headers = {"Idempotency-Key": idempotency_key or str(uuid.uuid4())}
    return client.post(
        "/api/history",
        json={"expr": expr, "result": result, "ts": ts},
        headers=headers,
    )
