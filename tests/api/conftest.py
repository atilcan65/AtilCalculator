"""Shared fixtures for the FastAPI contract suite (STORY-003a).

These fixtures wire the FastAPI TestClient to the as-implemented app at
``src/atilcalc/api/main.py``. They are deliberately minimal — the contract
tests in this directory are the executable spec; the implementer's job is to
land the FastAPI app that makes them pass.

The dependency on ``httpx`` and ``fastapi`` is added to ``pyproject.toml`` dev
extras as part of the implementation PR (see Issue #30 / ADR-0019).
"""

from __future__ import annotations

import contextlib

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
    """
    if client is None:
        return
    # Best-effort: the implementer may not have a reset endpoint.
    # If absent, individual tests must arrange their own setup.
    with contextlib.suppress(Exception):
        client.post("/api/_test/reset")  # type: ignore[union-attr]
    return
