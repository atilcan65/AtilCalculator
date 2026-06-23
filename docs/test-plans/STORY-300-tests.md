# Test Plan: STORY-300 — Multi-op expressions with operator precedence

> Source: [Issue #300 (STORY-CLI-002)](https://github.com/atilcan65/AtilCalculator/issues/300).
> Author: @tester (this PR). Implementer: @developer.
> TDD discipline: tests in this plan land in `scripts/tests/d036b-cli-precedence.sh` + `tests/cli/test_precedence.py` BEFORE
> the precedence parser implementation (TDD RED). The implementer's job is to make them pass
> (TDD GREEN) without breaking the contract.

## Scope

### In scope
- Multi-op expressions with correct precedence (`*`, `/` before `+`, `-`)
- Parenthesized grouping (parens override precedence)
- Power operator (`**`) — Sprint 7 per PM recommendation (open question for owner)
- Unary minus (`-5 + 3` → `-2`)
- Left-to-right evaluation for same-precedence operators
- Parametrised regression test suite

### Out of scope
- Variables / assignment (`x = 5; x + 1`) — out of MVP per vision
- Function calls (`sqrt(9)`) — Sprint 8+
- Custom operators — out of MVP
- REPL mode (STORY-301)

## Test Cases (mapping to ACs in Issue #300)

### TC-1: AC1-AC5 — Precedence rules (tester-owned, this PR)
**Landed in `test_cli_precedence_basic` (parametrised, 6 cases).**
- `atilcalc '2 + 3 * 4'` → `14` (multiplication before addition)
- `atilcalc '(2 + 3) * 4'` → `20` (parens override precedence)
- `atilcalc '2 + 3 + 4 * 5'` → `25` (left-to-right for same-precedence, mul before add)
- `atilcalc '10 - 2 * 3'` → `4` (subtraction precedence correct)
- `atilcalc '100 / 5 / 2'` → `10` (left-to-right division)
- `atilcalc '2 ** 3'` → `8` (power operator, integer exponent, decimal base)

### TC-2: AC6 — Power operator edge cases (tester-owned, this PR)
**Landed in `test_cli_power_operator` (parametrised, 4 cases).**
- `atilcalc '2 ** 10'` → `1024`
- `atilcalc '0.5 ** 2'` → `0.25` (decimal base)
- `atilcalc '2 ** 0'` → `1` (zero exponent)
- `atilcalc '2 ** -1'` → `0.5` (negative exponent, Decimal precision)

### TC-3: AC8 — Unbalanced parens error path (tester-owned, this PR)
**Landed in `test_cli_unbalanced_parens` (parametrised, 3 cases).**
- `atilcalc '(1 + 2'` → stderr shows parse error; exit code non-zero
- `atilcalc '1 + 2)'` → stderr shows parse error; exit code non-zero
- `atilcalc '((1 + 2)'` → stderr shows parse error (nested unbalanced); exit code non-zero

### TC-4: AC9 — Unary minus (tester-owned, this PR)
**Landed in `test_cli_unary_minus` (parametrised, 4 cases).**
- `atilcalc '-5 + 3'` → `-2` (unary minus binds tighter than binary)
- `atilcalc '5 + -3'` → `2` (unary in second position)
- `atilcalc '--5'` → `5` (double unary)
- `atilcalc '-(2 + 3)'` → `-5` (unary on parenthesized expression)

### TC-5: AC7 — Parametrised regression test suite ≥18 cases (tester-owned, this PR)
**Landed in `test_cli_precedence_regression` (parametrised, 18 cases).**
- 6 operators × 3 cases each (+, -, *, /, **, unary minus) = 18
- Total: 18 cases

### TC-6: AC10 — mypy + ruff on parser module (developer-owned, gated)
**CI gate.**
- `mypy --strict src/atilcalc/parser/` → 0 errors
- `ruff check src/atilcalc/parser/` → 0 errors
- Parser is a separate module (per PM open question: stdlib `re` + recursive descent)

## Adversarial Probes

### Input Validation
- **Deeply nested parens**: `atilcalc '((((((1+2))))))'` → `3` (6 levels)
- **Many operators**: `atilcalc '1+1+1+1+1+...+1'` (1000 additions) → `1000`
- **Mixed precedence chains**: `atilcalc '2*3+4*5-6/2'` → `13` (mixed multi-op)
- **Empty parens**: `atilcalc '()'` → parse error
- **Operator at end**: `atilcalc '1 +'` → parse error
- **Double operators**: `atilcalc '1 ** ** 2'` → parse error

### Security
- **Shell injection in quotes**: `atilcalc '1; rm -rf /'` → treated as literal expression, parse error on `;`
- **Very long expression**: 10k chars → no DoS

### State
- **Parser state pollution**: parser must not leak state between CLI invocations
- **Float vs Decimal**: `2 ** 0.5` (sqrt via power) → Decimal precision, not float

### Performance
- **Linear parse**: 1000-token expression < 100ms
- **Recursive descent depth**: should not stack-overflow on deeply nested parens

## Performance Concerns

- **Parser complexity**: recursive descent is O(n) for well-formed expressions
- **Memory**: parse tree size proportional to expression length
- **Decimal context**: precision must hold through power operator (Decimal handles arbitrary precision natively)

## Regression Risk

- Precedence bugs are subtle (off-by-one in operator table → wrong answers)
- Story-299 (basic arithmetic) must remain green — backward compat
- Sprint 1 STORY-002 engine should be reused (precedence layer is parser, not engine)

## Dependencies

- **Upstream**: STORY-299 (basic arithmetic) — must land first
- **Downstream**: STORY-301 (REPL) — uses precedence

## Test Framework

- **Framework**: `pytest` (parametrised) per ADR-0017
- **CLI driver**: invoke `atilcalc` as subprocess
- **Hermetic**: pytest fixtures, no shared state
- **Coverage target**: ≥90% line coverage on `src/atilcalc/parser/`

## Test Scripts (TDD RED deliverable)

- `scripts/tests/d036b-cli-precedence.sh` — hermetic shell test (18 TUs, ~70 LOC)
- `tests/cli/test_precedence.py` — pytest regression suite (parametrised, 18 cases)

## Acceptance Sign-Off

- All 18 TUs PASS (d036b)
- All 18 pytest cases PASS (test_precedence.py)
- mypy --strict on parser: 0 errors
- ruff check on parser: 0 errors
- STORY-299 tests still PASS (no regression)

— @tester, 2026-06-23T13:35Z, STORY-300 test plan ready, awaiting Sprint 7 launch for TDD RED script write.
