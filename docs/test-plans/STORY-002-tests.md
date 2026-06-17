# Test Plan: STORY-002 — Engine module (4 ops, decimal precision)

> Source: [Issue #16 (STORY-002)](https://github.com/atilcan65/AtilCalculator/issues/16).
> Author: @tester (this PR). Implementer: @developer.
> TDD discipline: tests in this plan land in `tests/engine/test_evaluator.py` BEFORE
> the engine implementation (TDD RED). The implementer's job is to make them pass
> (TDD GREEN) without breaking the contract.

## Scope

### In scope
- `evaluate(expression: str) -> Decimal` for the MVP-1 operator set: `+ - * / % ( )`
- Decimal precision (no float coercion)
- Structured exception hierarchy: `EngineError`, `ExpressionSyntaxError`, `DivisionByZeroError`, `UndefinedOperatorError`
- mypy / ruff / pytest gates
- Public API docstring discipline
- ≥90% line coverage on `src/atilcalc/engine/`

### Out of scope
- Scientific functions (trig, log, √, !) — Sprint 2
- Operator precedence customisation — MVP uses Python default
- Unary operators (e.g. `-5`) — Sprint 2 if needed
- HTTP layer (`POST /api/evaluate`) — STORY-003

## Test Cases (mapping to ACs in Issue #16)

### TC-1: AC1 — Decimal precision (no float coercion)
**Developer-owned.** Landed in `test_evaluator_decimal_precision` (parametrised, 4 cases).
- `0.1 + 0.2` → `Decimal("0.3")` (canonical float-error case)
- `0.1 + 0.2 + 0.3` → `Decimal("0.6")`
- `1.5 + 2.5` → `Decimal("4.0")`
- `10 - 9.9` → `Decimal("0.1")`
- Type assertion: result is `Decimal`, not `float`

### TC-2: AC2 — Parenthesised expressions (tester-owned, this PR)
**Landed in `test_evaluate_parenthesised_expression` (5 parametrised cases).**
- `2 * (3 + 4)` → `Decimal("14")` (canonical)
- `(2 + 3) * 4` → `Decimal("20")` (paren-multiplication)
- `((1 + 2) * (3 + 4))` → `Decimal("21")` (nested parens)
- `5 + (3)` → `Decimal("8")` (single-value paren, no-op)
- `100 + (5 + 5)%` → `Decimal("110")` (paren + percent, compound)

### TC-3: AC3 — Percent operator (tester-owned, this PR)
**Landed in `test_evaluate_percent_operator` (5 parametrised cases).**
- `100 + 5%` → `Decimal("105")` (canonical, financial-calculator semantics)
- `200 - 10%` → `Decimal("180")` (subtract variant)
- `50 * 20%` → `Decimal("10")` (multiply variant)
- `100%` → `Decimal("1")` (percent-only, no preceding value)
- `100 + 5% + 1` → `Decimal("106")` (percent mid-expression)

### TC-4: AC4 — Precision stability (developer-owned)
**Landed in `test_evaluate_precision_stable_across_repeated_calls`.**
- `0.1 + 0.2` called 1000 times → all results bit-identical to the first

### TC-5: AC5 — Division by zero → structured error (tester-owned, this PR)
**Landed in `test_evaluate_division_by_zero_raises_structured_error` (4 cases).**
- `5 / 0` → `DivisionByZeroError` (not built-in `ZeroDivisionError`)
- `7 % 0` → `DivisionByZeroError`
- `0 / 0` → `DivisionByZeroError`
- `100 / (5 - 5)` → `DivisionByZeroError` (zero-via-parens)
- All instances must be subclasses of `EngineError` (catch-all for HTTP layer)

### TC-6: Adversarial probes — malformed input (tester-owned, this PR)
**Landed in `test_evaluate_malformed_expression_raises_syntax_error` (7 cases).**
- `""` (empty), `"   "` (whitespace), `"()"` (empty parens)
- `"("`, `")"` (unbalanced parens)
- `"abc"` (non-numeric), `"1.2.3"` (malformed decimal)
- All must raise a structured `EngineError` (not crash with built-in exception)

### TC-7: AC6 — mypy --strict on `src/atilcalc/engine/`
**Not a pytest test.** This is a CI gate, run via Makefile or `make ci`. The contract
suite will include it as a subprocess check in CI workflow (separate from this PR).
Documented here for traceability.

### TC-8: AC7 — ruff check on `src/atilcalc/engine/`
Same as TC-7: CI gate, not pytest. Documented for traceability.

### TC-9: AC8 — pytest ≥30 cases + ≥90% line coverage
**Coverage count is meta.** With 4 (AC1) + 1 (AC4) + 5 (AC2) + 5 (AC3) + 4 (AC5) + 7 (adversarial) = 26 cases, the AC8 ≥30 target requires ~4 more cases (e.g. unary minus, exponent, scientific-notation decimals, very large/small numbers). These land in Sprint 2 if Sprint 1 hits the 30 mark without them.
Coverage ≥90% is enforced by `pytest --cov=src/atilcalc/engine --cov-fail-under=90` in CI.

### TC-10: AC9 — Docstring audit
**Not a pytest test.** Public API functions (`evaluate`, exception classes) must have
docstrings with description, args, returns, raises. The `evaluator.py` scaffold already
includes these for `evaluate` and the exception classes. CI gate could enforce this
via `interrogate` or a custom script — not in STORY-002 scope.

## Adversarial Probes (input validation)

| Probe | Input | Expected |
|---|---|---|
| Empty string | `""` | `ExpressionSyntaxError` |
| Whitespace only | `"   "` | `ExpressionSyntaxError` |
| Empty parens | `"()"` | `ExpressionSyntaxError` |
| Unbalanced parens | `"("` / `")"` | `ExpressionSyntaxError` |
| Non-numeric token | `"abc"` | `ExpressionSyntaxError` |
| Malformed decimal | `"1.2.3"` | `ExpressionSyntaxError` |
| Two operators in a row | `"1 ++ 2"` | `ExpressionSyntaxError` |
| Number followed by number (no op) | `"1 2"` | `ExpressionSyntaxError` |
| Tab character | `"1\t+\t2"` | `Decimal("3")` (whitespace ignored) |
| Unicode minus | `"1 − 2"` | `ExpressionSyntaxError` (or `UndefinedOperatorError`) |
| Very large number | `"9" * 100` | exact `Decimal` (no overflow) |
| Very small number | `"0." + "0" * 100 + "1"` | exact `Decimal` |
| 1MB expression | random tokens | `ExpressionSyntaxError` (no DoS) |

## Performance Concerns

- **Tokenizer + parser** should be O(n) on expression length. Benchmark with
  10k-char expression (mostly digits): must complete in < 100ms.
- **No regex backtracking traps** in the tokenizer — adversarial 1MB string with
  pathological patterns should fail fast.
- **No global state** — `evaluate()` is a pure function; repeated calls must not
  accumulate parser state.

## Regression Risk

- The TDD-RED contract is the regression pin. Once the engine ships, any change
  that breaks an AC test fails CI.
- Cross-cutting risk: `decimal.Decimal` context (precision, rounding mode) is
  global in Python. If a peer module mutates `getcontext()`, this engine could
  drift. **Mitigation**: use `decimal.localcontext()` around `evaluate()` to
  scope the context, with a pinned `prec=28` (Decimal default).
- The exception hierarchy is part of the HTTP contract (ADR-0018 watch-item #1).
  Adding new exception types is fine; renaming/relocating is a breaking change.

## Test Counts (after this PR)

- AC1: 4 parametrised
- AC2: 5 parametrised (tester, this PR)
- AC3: 5 parametrised (tester, this PR)
- AC4: 1 (1000-iteration loop)
- AC5: 4 parametrised (tester, this PR)
- Adversarial: 7 parametrised (tester, this PR)
- **Total: 26 parametrised cases + 1 property test**

To hit AC8's ≥30 target, the dev should add ~4 more cases (e.g. unary minus,
scientific notation, very large/small numbers). Out of scope for this contract PR.

## PR Conventions

- Branch: `test/story-002-contract-tests` (this branch)
- Targets: `main` (after dev merges `STORY-002-engine-module`)
- 4-cat labels: `type:feature` + `status:in-review` + `agent:tester` + `cc:developer`
- Auto-ping: `[TEST→DEV] STORY-002 contract suite TDD-RED, implementation needed`
