"""AtilCalculator test package — enables `from tests.conftest import X` style imports.

Why this file exists
--------------------
PR #709 (Sprint 22 PIVOT Faz 1.1, Issue #708) added tests/conftest.py at the
root of the tests/ tree to host shared env-aware perf-budget constants
(BUDGET_MULTIPLIER, SUBPROCESS_TIMEOUT_S). The test files import these via
`from tests.conftest import X` — which requires `tests` to be importable as a
Python package.

Without `tests/__init__.py`, pytest's namespace-package handling does not
guarantee that `tests` is on sys.path (it depends on cwd + pythonpath config),
so CI runners without an editable install of the project see
`ModuleNotFoundError: No module named 'tests'`. This was the live CI failure
on PR #709 (commit cdf869b, run 28440336903, 3 failed + 3 errored).

Sister-pattern fix: add an empty `tests/__init__.py` so `tests` becomes a
real package and the import path resolves deterministically across all
pytest invocations. Per ADR-0017 §Repository layout, src/ already mirrors
tests/ and src/ has __init__.py files for the same reason — this brings
tests/ into the same convention.

Refs:
  - PR #709 commit cdf869b (lint fix that missed the conftest import bug)
  - Issue #708 (Sprint 22 PIVOT Faz 1.1)
  - ADR-0017 §Repository layout
"""
