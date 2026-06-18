# Test Plan: STORY-011 — Scientific functions (trig / log / √ / !)

## Scope
- **In scope**: Engine support for `sin`, `cos`, `tan`, `log` (base-10), `ln` (base-e), `sqrt`, `!` (factorial), constants (`e`, `pi`), rad/deg toggle, and `DomainError` exception subclass. HTTP API perf budget for transcendentals. UI affordance contracts (function-call tokenizer, `deg` unit suffix, mode-toggle wiring).
- **Out of scope**: Custom user-defined functions; programmer mode (hex/binary); complex numbers; symbolic algebra; unit conversion; hyperbolic functions (deferred to Sprint 3+ per vision §Out-of-scope).

## Source contracts (ADR + issue pinning)
- **ADR-0019 amendment 2** (PR #84, in-review): pins `mpmath==1.3.0` runtime dep, `mp.dps=50`, `DomainError(EngineError)` new subclass, factorial cap at `n in [0, 170]`, envelope `{"history": [...], "cursor": ts|null}` (unchanged from base).
- **PR #63** (merged): `UndefinedOperatorError` scope clarification — "reserved for FUTURE operators that parse but cannot dispatch"; domain errors (sqrt(-1), log(-1), etc.) belong to the new `DomainError` subclass.
- **STORY-011 spec** (`docs/backlog/STORY-011.md`): AC1-AC10 parametrised precision contracts.

## Test Cases

### TC-1: Engine trigonometric identity — sin(0) = 0
- **Setup**: import `from atilcalc.engine.evaluator import evaluate`
- **Steps**:
  1. `evaluate("sin(0)")`
- **Expected**: returns `Decimal("0")` exactly (within mpmath precision)
- **Pins**: AC1

### TC-2: Engine rad/deg flag toggle — cos(0) deg = 1, cos(0) rad = 1 (same in both)
- **Setup**: engine exposes rad/deg via context or keyword arg (NOT in expression syntax per AC2)
- **Steps**:
  1. `evaluate("cos(0)", deg=True)` → `Decimal("1")`
  2. `evaluate("cos(0)", deg=False)` → `Decimal("1")` (same value at 0°/0rad)
  3. `evaluate("cos(45 deg)")` → `Decimal("0.7071067811865475244008443621...")` (sqrt(2)/2 to 28 digits)
- **Expected**: rad/deg flag determines interpretation of `deg` suffix
- **Pins**: AC2, AC3

### TC-3: Engine log base-10 — log(100) = 2
- **Setup**: engine distinguishes `log` (base-10) from `ln` (base-e)
- **Steps**:
  1. `evaluate("log(100)")` → `Decimal("2")`
- **Expected**: returns `Decimal("2")` exactly
- **Pins**: AC4

### TC-4: Engine natural log — ln(e) = 1
- **Setup**: engine supports `ln` operator distinct from `log`
- **Steps**:
  1. `evaluate("ln(2.71828182845904523536028747135266249775724709369995)")` → `Decimal("1.0000000000000000000000000000...")` (within mpmath `dps=50`)
- **Expected**: returns `Decimal` close to 1, accurate to mpmath precision
- **Pins**: AC5

### TC-5: Engine sqrt — sqrt(2) to 28 digits
- **Setup**: engine uses mpmath `sqrt` (stdlib Decimal has `sqrt()` natively but precision differs)
- **Steps**:
  1. `evaluate("sqrt(2)")` → `Decimal("1.414213562373095048801688724")` (28-digit precision)
- **Expected**: returns 28-digit Decimal matching the reference value
- **Pins**: AC6

### TC-6: Engine factorial — 5! = 120, 0! = 1, 100! = full precision
- **Setup**: engine implements `!` postfix operator
- **Steps**:
  1. `evaluate("5!")` → `Decimal("120")`
  2. `evaluate("0!")` → `Decimal("1")` (base case)
  3. `evaluate("100!")` → Decimal with 158 digits (precision grows with n)
- **Expected**: factorial returns lossless `Decimal` for `n in [0, 170]`
- **Pins**: AC7

### TC-7: Engine factorial cap — 170! OK, 171! raises DomainError
- **Setup**: ADR-0019 amendment 2 caps factorial at `n=170`
- **Steps**:
  1. `evaluate("170!")` → `Decimal` (huge, ~306 digits)
  2. `evaluate("171!")` → raises `DomainError` (subclass of `EngineError`)
  3. `evaluate("(-1)!")` → raises `DomainError`
- **Expected**: boundary at n=170; DomainError for n>170 OR n<0
- **Pins**: AC7 + amendment 2 §Factorial cap

### TC-8: Engine DomainError — sqrt(-1), log(0), log(-2), asin(2), acos(-1.5)
- **Setup**: `DomainError(EngineError)` is the new exception subclass per ADR-0019 amendment 2
- **Steps**:
  1. `evaluate("sqrt(-1)")` → raises `DomainError`
  2. `evaluate("log(0)")` → raises `DomainError` (log undefined at 0)
  3. `evaluate("log(-2)")` → raises `DomainError`
  4. `evaluate("asin(2)")` → raises `DomainError` (asin undefined for |x|>1)
  5. `evaluate("acos(-1.5)")` → raises `DomainError`
- **Expected**: all 5 raise `DomainError` (subclass of `EngineError`, distinct from `UndefinedOperatorError`)
- **Pins**: AC8 + amendment 2 §DomainError

### TC-9: Engine tan(90 deg) — DomainError (tan(π/2) = ∞)
- **Setup**: in deg mode, tan(90) is undefined
- **Steps**:
  1. `evaluate("tan(90 deg)", deg=True)` → raises `DomainError`
- **Expected**: DomainError, NOT silent Infinity, NOT ZeroDivisionError
- **Pins**: AC8

### TC-10: HTTP layer — DomainError → 400 with error envelope
- **Setup**: FastAPI test client; engine exception mapping per ADR-0019 §Error envelope
- **Steps**:
  1. `POST /api/evaluate {"expr": "sqrt(-1)"}` → 400
  2. response body: `{"error": {"code": "DomainError", "message": "...", "request_id": "..."}}`
- **Expected**: HTTP 400, error envelope with `code: "DomainError"`, NOT 500
- **Pins**: ADR-0019 §Error envelope + AC8

### TC-11: HTTP layer perf budget — transcendental p99 <100ms
- **Setup**: 1000 sequential `POST /api/evaluate {"expr": "sin(0.5)"}` calls
- **Steps**:
  1. Warm up: 10 calls (excluded from timing)
  2. Time 1000 calls with `time.perf_counter()`
  3. Assert p99 < 100ms
- **Expected**: p99 < 100ms (per ADR-0019 amendment 2 §Performance budgets)
- **Pins**: amendment 2 §Performance budgets

### TC-12: mpmath pin exact — pyproject.toml shows mpmath==1.3.0
- **Setup**: read `pyproject.toml`
- **Steps**:
  1. Parse `[project.dependencies]` section
  2. Assert `mpmath==1.3.0` (exact pin, not `>=` or `~=`)
- **Expected**: exact pin per ADR-0017 doctrine (no floating pins)
- **Pins**: amendment 2 §mpmath pin

### TC-13: Tokenizer accepts function-call form — sin(45)
- **Setup**: engine tokenizer
- **Steps**:
  1. Tokenize `"sin(45)"` → `[("FN", "sin"), ("NUM", "45"), ("LPAREN", "("), ("RPAREN", ")")]` or similar
- **Expected**: function name tokenized as identifier or function-name kind
- **Pins**: PM-recommended tokenizer design (per spec §Open questions)

### TC-14: Tokenizer accepts unit suffix — 45 deg
- **Setup**: engine tokenizer
- **Steps**:
  1. Tokenize `"45 deg"` → `[("NUM", "45"), ("UNIT", "deg")]` or similar
- **Expected**: `deg` tokenized as unit suffix (single-token rule per PM rec)
- **Pins**: PM-recommended unit-suffix rule (consistent with Sprint 1 `5%` hybrid)

### TC-15: UI affordance — mode-toggle reveals scientific keys (deferred to STORY-009 review)
- **Setup**: `<atilcalc-mode-toggle>` Web Component
- **Steps**: UI-level test (Playwright); not part of engine TDD red
- **Expected**: STORY-009 test plan owns UI affordance contracts; cross-link here
- **Pins**: AC9 — STORY-009 owns the UI test, STORY-011 test plan cross-references

## Adversarial Probes

- **AP-1** — Unicode function name: `SIN(0)` (uppercase) → `ExpressionSyntaxError` (case-sensitive)
- **AP-2** — Empty parens: `sin()` → `ExpressionSyntaxError`
- **AP-3** — Nested functions: `sin(cos(0))` → `Decimal("0.8414709848078965...")` (correct composition)
- **AP-4** — Operator in wrong place: `5 + sin` → `ExpressionSyntaxError`
- **AP-5** — Float precision loss: `sin(0.1)` matches mpmath `mpf` (not Python `math.sin`)
- **AP-6** — NaN propagation: `sqrt(-1)` MUST raise DomainError, NOT return `Decimal('NaN')`
- **AP-7** — Concurrent rad/deg toggle + evaluation: FSM state is per-request (cookie/header) or per-process; race-safe
- **AP-8** — Unicode in expression: `sin(π)` (using Unicode π char) → either accepted (math.pi shortcut) or ExpressionSyntaxError (ASCII-only policy)
- **AP-9** — Very large factorial: `evaluate("1000!")` → DomainError (cap is 170, not 1000)
- **AP-10** — Negative factorial: `evaluate("(-1)!")` → DomainError
- **AP-11** — Float near boundary: `evaluate("0.9999999999999999!")` → DomainError (n must be integer, not float)
- **AP-12** — `log(0)` vs `log(1e-1000)` — both very small; first is DomainError, second may underflow
- **AP-13** — `deg` suffix without value: `evaluate("deg")` → ExpressionSyntaxError
- **AP-14** — `deg` suffix in rad mode: `evaluate("45 deg", deg=False)` → DomainError OR value silently ignored (architect's call; pin in implementation)

## Performance Concerns

- **Engine compile-time**: `mp.dps=50` global setting affects all `Decimal` arithmetic; startup cost is ~10ms (one-time). Not a perf budget item.
- **Transcendental call**: mpmath `sin/cos/tan/log/exp/sqrt` are 3-5x slower than stdlib Decimal arithmetic. AC11 pins p99 <100ms.
- **Factorial 170!**: integer multiplication chain, ~1ms for n=170. No concern.
- **Tokenizer scan**: linear in expression length. No concern.
- **API overhead**: FastAPI + pydantic adds ~1-2ms per call. Negligible vs mpmath.

## Regression Risk

- **Engine purity invariant** (ADR-0017): adding `mpmath` to runtime deps breaks the stdlib-only invariant at the engine module boundary. ADR-0019 amendment 2 explicitly carves out `mpmath==1.3.0` as a runtime dep, but downstream tests must verify the engine still has zero non-stdlib imports EXCEPT mpmath. CI gate `tests/engine/test_no_io_imports.py` should be updated to allow `mpmath` import.
- **Sprint 1 PR #26 tests**: existing engine tests for arithmetic (`+`, `-`, `*`, `/`, `%`) must still pass. No operator semantics change.
- **PR #63 (UndefinedOperatorError scope)**: amendment reserves UndefinedOperatorError for FUTURE operators that parse but cannot dispatch. DomainError is for runtime domain errors (sqrt(-1), log(0), etc.). Tests must verify the distinction.
- **Precision regression**: switching from stdlib Decimal to mpmath changes precision boundary. `evaluate("0.1 + 0.2")` was `Decimal("0.3")` with stdlib; with mpmath `dps=50`, the result should be `Decimal("0.30000000000000000000000000000000000000000000000000...")` (50 digits). PR #63 trailing-zero rule may need amendment for the new precision.

## Test File Mapping

| TC | File |
|---|---|
| TC-1 through TC-9 | `tests/engine/test_transcendentals.py` (engine contract — sin/cos/tan/log/ln/sqrt) |
| TC-6, TC-7 | `tests/engine/test_factorial.py` (factorial + 170 cap) |
| TC-8, TC-9 | `tests/engine/test_domain_errors.py` (DomainError exception class) |
| TC-10 | `tests/api/test_evaluate_transcendental.py` (HTTP 400 mapping) |
| TC-11 | `tests/api/test_evaluate_transcendental.py` (perf budget p99 <100ms) |
| TC-12 | `tests/engine/test_mpmath_pin.py` (pyproject.toml exact pin) |
| TC-13, TC-14 | `tests/engine/test_tokenizer_extensions.py` (function-call + unit-suffix) |
| TC-15 | (deferred to STORY-009 UI test plan) |

## Open Questions for Implementation PR

1. **Rad/deg flag mechanism**: keyword arg to `evaluate()`, context manager, or per-request API param? PM recommendation: keyword arg `deg: bool = False` (defaults to rad for math convention).
2. **Constants `e` and `pi`**: tokenize as identifiers (multi-char) or atomic symbols? PM recommendation: identifiers (consistent with `sin`/`cos`/`log` function names).
3. **`deg` suffix behavior in rad mode**: silent ignore (current behavior in some calculators) or DomainError? PM recommendation: DomainError (strict mode prevents accidental unit confusion).
4. **AP-8 (Unicode π)**: accept or reject? PM recommendation: reject (ASCII-only engine, keeps tokenizer simple).
5. **UI affordance integration**: `<atilcalc-help-popup>` scientific mode shortcuts list — owned by STORY-009 + STORY-011 cross-link.

## References

- `docs/backlog/STORY-011.md` (spec, AC1-AC10)
- `docs/decisions/ADR-0019-amendment-2-decimal-and-envelope.md` (PR #84, in-review)
- `docs/decisions/ADR-0019.md` §Engine exception taxonomy
- `docs/decisions/ADR-0017.md` §Engine ↔ UI separation
- PR #63 (Decimal trailing-zero rule + UndefinedOperatorError scope)
- PR #26 (STORY-002 engine `evaluate()` API)
