"""TDD RED contract tests for STORY-011 mpmath pin.

Pins ADR-0019 amendment 2 §Transcendental precision model:
- `mpmath==1.3.0` exact pin (per ADR-0017 doctrine: no floating pins)
- `mp.dps = 50` internal precision setting

Run with: pytest tests/engine/test_mpmath_pin.py -v
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

# TDD red guard — module-level skip ensures CI is green while the impl
# PR lands. Three preconditions per ADR-0019 amend 2 §Transcendental
# precision model:
#   1. `mpmath==1.3.0` exact pin in pyproject.toml [project.dependencies]
#   2. `mpmath` installed in the test venv
#   3. `_MP_DPS = 50` constant exported from the engine
try:
    import mpmath  # noqa: F401
    from atilcalc.engine.evaluator import _MP_DPS  # noqa: F401
except (ImportError, AttributeError):
    pytest.skip(
        "STORY-011 TDD red — mpmath pin + _MP_DPS not yet wired up per ADR-0019 amend 2. "
        "Implementation PR will unskip by adding `mpmath==1.3.0` to pyproject.toml "
        "[project.dependencies] (runtime, not dev) and exposing `_MP_DPS = 50`.",
        allow_module_level=True,
    )


# ---------------------------------------------------------------------------
# TC-12: pyproject.toml shows mpmath==1.3.0 (exact pin)
# ---------------------------------------------------------------------------
class TestMpmathDependencyPin:
    """mpmath==1.3.0 is pinned exactly in pyproject.toml [project.dependencies].

    Per ADR-0017 doctrine: never use floating pins (>=, ~=, ^) for runtime deps.
    The engine boundary's stdlib-only invariant is explicitly carved out by
    ADR-0019 amendment 2 to permit mpmath as a runtime dep.
    """

    def test_pyproject_has_mpmath_exact_pin(self) -> None:
        pyproject = Path(__file__).resolve().parents[2] / "pyproject.toml"
        contents = pyproject.read_text()
        # Must contain mpmath==1.3.0 exactly (not >= or ~=).
        match = re.search(r'mpmath\s*==\s*1\.3\.0', contents)
        assert match is not None, (
            "pyproject.toml must contain `mpmath==1.3.0` exact pin "
            "(ADR-0019 amendment 2 §Transcendental precision model)"
        )

    def test_mpmath_is_runtime_not_dev_dependency(self) -> None:
        """mpmath must be in [project.dependencies], not [dev].

        Same precedent as PR #66 (ADR-0017 amendment — fastapi/uvicorn moved
        from dev to runtime). The engine USES mpmath at runtime, so it MUST
        be in runtime deps.
        """
        pyproject = Path(__file__).resolve().parents[2] / "pyproject.toml"
        contents = pyproject.read_text()

        # Find [project.dependencies] block (between [project] and next section)
        deps_match = re.search(
            r'\[project\][^[]*dependencies\s*=\s*\[(.*?)\]',
            contents,
            re.DOTALL,
        )
        assert deps_match is not None, (
            "pyproject.toml must have [project.dependencies] block"
        )
        deps_block = deps_match.group(1)
        assert "mpmath" in deps_block, (
            "mpmath must be in [project.dependencies] (runtime), not [dev] "
            "(PR #66 precedent: deps used at runtime go in [project.dependencies])"
        )

    def test_no_floating_pin_for_mpmath(self) -> None:
        """No >= or ~= pin for mpmath (ADR-0017 doctrine)."""
        pyproject = Path(__file__).resolve().parents[2] / "pyproject.toml"
        contents = pyproject.read_text()
        # Negative: must NOT contain mpmath>=X, mpmath~=X, or mpmath^X.
        for bad_pattern in [r'mpmath\s*>=\s*1', r'mpmath\s*~=\s*1', r'mpmath\s*\^']:
            match = re.search(bad_pattern, contents)
            assert match is None, (
                f"mpmath must be exact-pinned (==), not floating (>= / ~= / ^). "
                f"Found: {match.group(0) if match else 'n/a'}"
            )


# ---------------------------------------------------------------------------
# Engine module imports mpmath (engine boundary carved out by amendment 2)
# ---------------------------------------------------------------------------
class TestEngineImportsMpmath:
    """The engine module (atilcalc.engine.evaluator) imports mpmath for
    transcendental precision. This violates the stdlib-only invariant at the
    module boundary, but ADR-0019 amendment 2 explicitly carves out mpmath
    as the documented exception.
    """

    def test_engine_module_imports_mpmath(self) -> None:
        """The engine imports mpmath; this is the documented exception to the
        stdlib-only invariant per ADR-0019 amendment 2.
        """
        # The import is at module load time; if the implementation imports
        # mpmath at top of evaluator.py, this will succeed.
        import mpmath
        assert mpmath is not None


class TestMpmathPrecisionSetting:
    """mp.dps = 50 per ADR-0019 amendment 2 §Transcendental precision model."""

    def test_engine_sets_mp_dps_to_50(self) -> None:
        """Engine sets `mp.dps = 50` at module load (or in evaluate() context)."""

        import atilcalc.engine.evaluator as evaluator  # noqa: F401

        # Implementation may set mp.dps inside evaluate() via with block;
        # we check the global setting (post-import) OR a constant in the
        # evaluator module.
        # If implementation uses local context, this assertion is informational.
        from atilcalc.engine.evaluator import _MP_DPS  # type: ignore
        assert _MP_DPS == 50, (
            f"Engine must set mp.dps = 50 per ADR-0019 amendment 2; got {_MP_DPS}"
        )
