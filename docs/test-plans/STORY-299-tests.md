# Test Plan: STORY-299 — Basic arithmetic via typer CLI (M1 acceptance)

> Source: [Issue #299 (STORY-CLI-001)](https://github.com/atilcan65/AtilCalculator/issues/299).
> Author: @tester (this PR). Implementer: @developer.
> TDD discipline: tests in this plan land in `scripts/tests/d036a-cli-basic-arithmetic.sh` + `tests/cli/test_basic_arithmetic.py` BEFORE
> the CLI implementation (TDD RED). The implementer's job is to make them pass
> (TDD GREEN) without breaking the contract.

## Scope

### In scope
- `atilcalc <expr>` CLI invocation via typer (ADR-0017 §Tech stack)
- Basic arithmetic: `+ - * /` with exact `decimal.Decimal` precision
- stdout/stderr semantics (success vs error path)
- Exit codes (0 on success, non-zero on error)
- Parametrised regression test suite
- mypy --strict on `src/atilcalc/engine/` (per ADR-0017 §Architecture rule)
- ruff check on the CLI module

### Out of scope
- Multi-op precedence (STORY-300)
- REPL mode (STORY-301)
- Scientific functions (sin, cos, log, sqrt) — Sprint 8+
- History persistence — Sprint 2 STORY-007 (HTTP only)
- HTTP surface — ADR-0017 §Deferred
- Skin/theme support — web-only per vision

## Test Cases (mapping to ACs in Issue #299)

### TC-1: AC1 — M1 baseline `0.1 + 0.2 == 0.3` (tester-owned, this PR)
**Landed in `test_cli_basic_arithmetic_m1_baseline` (parametrised, 4 cases).**
- `atilcalc 0.1 + 0.2` → stdout `0.3` exactly (no `0.30000000000000004`)
- `atilcalc 0.1 + 0.2 + 0.3` → stdout `0.6` exactly (chained addition exactness)
- `atilcalc 0.1 + 0.2 + 0.3 + 0.4` → stdout `1.0` exactly
- Type assertion: stdout is string, parsed as `Decimal("0.3")` exactly

### TC-2: AC2 — Integer/decimal arithmetic (tester-owned, this PR)
**Landed in `test_cli_basic_arithmetic_integer_decimal` (4 cases).**
- `atilcalc 1.5 * 3` → stdout `4.5` (no scientific notation for small results)
- `atilcalc 2 + 3` → stdout `5` (integer arithmetic)
- `atilcalc 10 / 3` → stdout `3.333333333333333333333333333` (Decimal default 28-digit precision)
- `atilcalc 100 - 50` → stdout `50`

### TC-3: AC3 — Large numbers (tester-owned, this PR)
**Landed in `test_cli_basic_arithmetic_large_numbers` (3 cases).**
- `atilcalc 999999999 * 999999999` → stdout `999999998000000001` (no overflow)
- `atilcalc 2 ** 64` → stdout `18446744073709551616` (2^64, Decimal precision holds)
- `atilcalc 0.000000001 + 0.000000002` → stdout `0.000000003` (small numbers)

### TC-4: AC5 — Division by zero error path (tester-owned, this PR)
**Landed in `test_cli_division_by_zero_error_path` (3 cases).**
- `atilcalc 1 / 0` → stderr contains `decimal.DivisionByZero: 0` or similar; exit code non-zero (e.g., 1); stdout does NOT contain `inf` or `Infinity`
- `atilcalc 0 / 0` → same error path
- `atilcalc 1 / (2 - 2)` → same error path (zero via expression)

### TC-5: AC6 — Invalid expression error path (tester-owned, this PR)
**Landed in `test_cli_invalid_expression_error_path` (3 cases).**
- `atilcalc 1 + + 2` → stderr shows parse error; exit code non-zero; NO traceback to user
- `atilcalc ""` → stderr shows empty expression error; exit code non-zero
- `atilcalc abc` → stderr shows parse error (token `abc` unknown); exit code non-zero

### TC-6: AC7 — Parametrised regression test suite ≥15 cases (tester-owned, this PR)
**Landed in `test_cli_regression_suite` (parametrised, 15 cases).**
- 4 ops × 3 cases each (integer, decimal, large/small) = 12
- +1 chained addition exactness (TC-1's `0.1 + 0.2 + 0.3` case)
- +1 division-by-zero error path (TC-4)
- +1 parse error path (TC-5)
- Total: 15 cases

### TC-7: AC8 — mypy --strict on engine (developer-owned, gated)
**CI gate: `.github/workflows/ci.yml` mypy step.**
- `mypy --strict src/atilcalc/engine/` → 0 errors
- Per ADR-0017 §Architecture rule: engine is pure-Python, no I/O deps

### TC-8: AC9 — ruff check on CLI module (developer-owned, gated)
**CI gate: `.github/workflows/ci.yml` ruff step.**
- `ruff check src/atilcalc/cli/` → 0 errors
- CLI module is a thin wrapper, not a logic layer

## Adversarial Probes (per tester soul doc)

### Input Validation
- **Empty string**: `atilcalc ""` → error path (TC-5)
- **Very long expression**: `atilcalc $(python3 -c 'print("+".join(["1"]*10000))')` → no DoS, fast response
- **Unicode**: `atilcalc ١ + ١` (Arabic-Indic digits) → either Decimal precision OR clear error
- **NULL byte**: `atilcalc 1 + 2$'\x00'` → no crash, clear error
- **Float input**: `atilcalc 1e308 + 1e308` → Decimal handles large floats without overflow

### Security
- **Shell injection**: `atilcalc 1; rm -rf /` → typer treats as literal expression, no shell eval
- **Path traversal**: `atilcalc ../../../etc/passwd` → typer treats as expression, parse error

### State
- **Concurrent runs**: 100 parallel `atilcalc 1+1` → all return `2`, no shared state corruption
- **Slow network**: N/A (CLI is local)

### Performance
- **Latency**: `atilcalc 0.1 + 0.2` < 50ms (cold start OK; warm < 10ms)
- **Large expression**: 1000-op expression < 1s
- **Memory**: < 50MB RSS for typical expression

## Performance Concerns

- **CLI startup time**: typer import + Decimal context — measure cold vs warm
- **Expression parser**: should be linear in expression length
- **N+1 patterns**: N/A for stateless CLI

## Regression Risk

- This story reuses Sprint 1 STORY-002 engine (PR #26). Regression risk: low (engine is well-tested).
- Typer integration is new — could break on Python version differences
- Decimal context propagation through CLI → engine must be explicit (don't rely on thread-local)

## Test Framework

- **Framework**: `pytest` (parametrised) per ADR-0017 §Test framework
- **CLI driver**: invoke `atilcalc` as subprocess via `subprocess.run()` in tests
- **Hermetic**: pytest fixtures create temp input/output, no shared state
- **Coverage target**: ≥90% line coverage on `src/atilcalc/cli/__init__.py` + `src/atilcalc/__main__.py`

## Test Scripts (TDD RED deliverable)

- `scripts/tests/d036a-cli-basic-arithmetic.sh` — hermetic shell test (15 TUs, ~60 LOC)
- `tests/cli/test_basic_arithmetic.py` — pytest regression suite (parametrised, 15 cases)

## Acceptance Sign-Off

- All 15 TUs PASS (d036a)
- All 15 pytest cases PASS (test_basic_arithmetic.py)
- mypy --strict on engine: 0 errors
- ruff check on CLI: 0 errors
- M1 acceptance: `atilcalc 0.1 + 0.2` → `0.3` exactly

— @tester, 2026-06-23T13:35Z, STORY-299 test plan ready, awaiting Sprint 7 launch for TDD RED script write.
