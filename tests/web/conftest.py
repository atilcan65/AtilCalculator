"""Shared fixtures for the Web Components contract suite (STORY-003a).

The web layer is vanilla JS + Web Components (ADR-0018). Testing requires a
real DOM; we use Playwright headless. The implementer's job is to land the
Web Components and the Playwright config; the contract tests in this directory
will be collected + executed when the implementation lands.

For Sprint 1 MVP, the dev may opt to use ``jsdom`` (npm) for simpler FSM
testing and defer full E2E to STORY-003b.
"""

from __future__ import annotations

import pytest


@pytest.fixture(scope="session")
def browser_page():
    """Playwright headless browser page bound to the local server.

    Skips with a clear message if Playwright is not yet installed or if the
    server is not running. TDD red: the dev adds ``playwright`` to dev extras
    + starts the FastAPI server (``make run``) to enable this fixture.
    """
    pytest.skip(
        "Playwright + FastAPI server not yet implemented — TDD red phase. "
        "Land the Web Components + start the server to enable web tests."
    )
