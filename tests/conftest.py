"""Root-level pytest fixtures — Sprint 22 PIVOT Faz 1.2 env-aware test infrastructure.

Why this file exists
--------------------
Sprint 22 PIVOT (Issue #708) Faz 1.1 migrated workflow files from GH-hosted
ubuntu-latest runners to self-hosted runners at atilproject org. Lint & Test
run on self-hosted VM (192.168.1.197) revealed env-side perf budget violations
(per arch v4 verdict cmt 4842471072):

  - test_transcendental_p99_under_100ms   — got 206ms (budget 100ms)
  - test_arithmetic_p99_under_50ms_still_holds — got 218ms (budget 50ms)
  - test_search_latency_p95_under_100ms   — got 117ms (budget 100ms)
  - test_e2e_*_keyboard — subprocess timeout at 1s (cold start > 1s)

Arch recommended Option B: env-aware perf budget * 2x multiplier for self-hosted
+ e2e subprocess timeout bumped to 10s. This conftest provides the shared
fixtures + module-level constants to make per-test budget assertions env-aware
without each test needing to inline env detection.

Usage
-----
Tests can either use module-level constants directly:

    from tests.conftest import BUDGET_MULTIPLIER, SUBPROCESS_TIMEOUT_S

    def test_x() -> None:
        budget = 100 * BUDGET_MULTIPLIER
        assert elapsed < budget

Or use the pytest fixtures (preferred for parametrized per-test logic):

    def test_x(runner_env, budget_multiplier, subprocess_timeout_s) -> None:
        assert runner_env in ("self-hosted", "github-hosted", "local")
        # ...

Fixtures
--------
- ``detect_runner_env()``: pure function (no fixture) for inline use
- ``runner_env``: session-scoped fixture returning the detected env string
- ``budget_multiplier``: session-scoped fixture returning 2.0 (self-hosted)
  or 1.0 (github-hosted + local)
- ``subprocess_timeout_s``: session-scoped fixture returning 10.0 (self-hosted)
  or 5.0 (github-hosted + local)

Doctrinal refs
--------------
- Issue #708 §Faz 1.2 (Sprint 22 PIVOT dev lane)
- arch v4 verdict cmt 4842471072 (Option B recommendation)
- arch TD-046-extension design cmt 4847385602 (conftest env-var precedence doctrine)
- ADR-0019 amendment 2 (perf budget baseline — env-agnostic, superseded)
- ADR-0019 amendment 3 (env-aware perf budget + ci.yml env block propagation)
- ADR-0019 amendment 4 (CANDIDATE — conftest env-var precedence contract, arch will file post-#732-squash)
- ADR-0044 (RED-first TDD)
- ADR-0049 (d-test framework sister-pattern)
- ADR-0055 §1 Cadence Rule 1 atomic
- ADR-0056 (silent_skip fail-loud sister-pattern — ValueError on garbage env var)
"""

from __future__ import annotations

import os

import pytest


def detect_runner_env() -> str:
    """Return 'self-hosted' | 'github-hosted' | 'local'.

    Detection priority (most-specific-first):
      1. RUNNER_ENV env var explicit override ('self-hosted'/'github-hosted'/'local')
      2. RUNNER_LABELS contains 'self-hosted' (case-insensitive)
      3. GITHUB_ACTIONS=true (default to 'github-hosted')
      4. None of the above = 'local' (dev workstation)

    Returns one of three strings. Never raises — defaults to 'local' on any
    unexpected environment state so test execution is not blocked by detection
    failures (per ADR-0056 §silent_skip doctrine for env-side issues).
    """
    explicit = os.environ.get("RUNNER_ENV", "").strip().lower()
    if explicit in ("self-hosted", "github-hosted", "local"):
        return explicit

    runner_labels = os.environ.get("RUNNER_LABELS", "")
    if "self-hosted" in runner_labels.lower():
        return "self-hosted"

    if os.environ.get("GITHUB_ACTIONS") == "true":
        return "github-hosted"

    return "local"


# Module-level constants evaluated at conftest import time. These are the
# canonical env-aware values used by perf tests + e2e tests:
#
#   BUDGET_MULTIPLIER: 2.0 on self-hosted (per arch Option B + ADR-0019 amendment 3
#                      CANDIDATE), 1.0 on github-hosted + local (strict budgets preserved)
#
#   SUBPROCESS_TIMEOUT_S: 10.0 on self-hosted (cold start > 1s, 8s GH budget
#                         insufficient), 5.0 on github-hosted + local (faster cold start)
#
# Explicit 'github-hosted' branch (TC4 regression guard): if env ==
# 'github-hosted', multiplier = 1.0 and timeout = 5.0 — strict budgets preserved
# (matches ADR-0019 amendment 2 baseline).
#
# TD-046-extension (cycle ~#1770+): env-var precedence resolution chain. Three-tier
# canonical precedence (per arch design cmt 4847385602 + ADR-0019 amend 4 doctrine):
#   1. Operator env var (os.environ["BUDGET_MULTIPLIER"] / ["SUBPROCESS_TIMEOUT_S"])
#   2. Runner detection (detect_runner_env() → 'self-hosted'|'github-hosted'|'local')
#   3. Hardcoded map fallback (_BUDGET_MULTIPLIER_MAP / _SUBPROCESS_TIMEOUT_MAP_S)
# Fail-loud: unparseable env var raises ValueError (ADR-0056 silent_skip sister-pattern).

_BUDGET_MULTIPLIER_MAP = {
    "self-hosted": 2.0,
    "github-hosted": 1.0,
    "local": 1.0,
}

_SUBPROCESS_TIMEOUT_MAP_S = {
    "self-hosted": 10.0,
    "github-hosted": 5.0,
    "local": 5.0,
}


def _resolve_budget_multiplier() -> float:
    """TD-046-extension canonical precedence: env var > runner-detected > hardcoded map.

    Operator env var (os.environ['BUDGET_MULTIPLIER']) takes precedence per
    ADR-0019 amendment 3 §Runner-aware multipliers (env var = single source of truth
    for operator overrides). detect_runner_env() is canonical for unconfigured
    environments. Hardcoded map is the final fallback (canonical Sprint 22 PIVOT
    self-hosted baseline lives here — map RETAINED per arch Q3 answer).

    Raises ValueError on unparseable env var (fail-loud per ADR-0056 silent_skip
    sister-pattern — bad operator input must not silently downgrade to runner default).
    """
    env_val = os.environ.get("BUDGET_MULTIPLIER")
    if env_val is not None:
        return float(env_val)  # raises ValueError on garbage
    return _BUDGET_MULTIPLIER_MAP[detect_runner_env()]


def _resolve_subprocess_timeout_s() -> float:
    """TD-046-extension canonical precedence: env var > runner-detected > hardcoded map.

    Sister-contract to _resolve_budget_multiplier() — same precedence doctrine applies
    because both are operator-tunable perf budget knobs (per ADR-0019 amend 3 doctrine:
    env var = single source of truth for all perf-budget operator overrides).
    """
    env_val = os.environ.get("SUBPROCESS_TIMEOUT_S")
    if env_val is not None:
        return float(env_val)
    return _SUBPROCESS_TIMEOUT_MAP_S[detect_runner_env()]


BUDGET_MULTIPLIER: float = _resolve_budget_multiplier()
SUBPROCESS_TIMEOUT_S: float = _resolve_subprocess_timeout_s()


@pytest.fixture(scope="session")
def runner_env() -> str:
    """Detected runner environment string: 'self-hosted' | 'github-hosted' | 'local'.

    Session-scoped: env detection runs once per test session. All tests in the
    same session see the same value. Tests that need per-test env should call
    ``detect_runner_env()`` directly (no fixture parametrize).
    """
    return detect_runner_env()


@pytest.fixture(scope="session")
def budget_multiplier(runner_env: str) -> float:
    """Env-aware perf budget multiplier.

    Returns 2.0 when runner_env == 'self-hosted' (per arch Option B + ADR-0019
    amendment 3 CANDIDATE), 1.0 otherwise (github-hosted + local). Tests can
    apply: ``budget = BASE * budget_multiplier``.
    """
    return _BUDGET_MULTIPLIER_MAP[runner_env]


@pytest.fixture(scope="session")
def subprocess_timeout_s(runner_env: str) -> float:
    """Env-aware subprocess timeout (seconds).

    Returns 10.0 when runner_env == 'self-hosted' (cold start > 1s on VM
    192.168.1.197), 5.0 otherwise (GH runners faster cold start). Tests use
    this for _wait_for_healthz + proc.communicate + proc.wait timeouts.
    """
    return _SUBPROCESS_TIMEOUT_MAP_S[runner_env]
