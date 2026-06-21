# Test Plan: STORY-013 — Implicit first operand from history (calc-ans style)

## Scope
- **In scope**: Engine support for implicit first operand (when expression starts with `+`, `-`, `*`, `/`, `^`, engine uses `last_result` as left operand). HTTP layer wiring to fetch last successful history record. History query for "last successful result" semantics. Audit-style history record (resolved expr, not terse input). Error handling for empty history (AC4), error-history skip (AC5), no regression (AC6). Performance budget parity with explicit-operand path (<50ms p99 per ADR-0019).
- **Out of scope**: Multi-step implicit chains (only most recent result); named variables / memory registers (TI `M+`/`MR`/`Ans`); implicit-operand on CLI surface (`atilcalc eval` Typer); implicit-operand on scientific functions (`sin`, `cos`, `log` — unary, no left operand); history manipulation (delete/mark/pin); per-session vs cross-device `ans` (server-side from SQLite per STORY-007).

## Source contracts (ADR + issue pinning)
- **Issue #179** (story): 10 Gherkin ACs covering happy path (AC1-AC3), error edges (AC4-AC5), no-regression (AC6), audit history (AC7), keyboard FSM (AC8), e2e coverage (AC9), engine purity (AC10).
- **PR #180** (docs/backlog): PM-authored backlog entry + 10 ACs Gherkin spec. Sprint 5+ target (Sprint 4 capacity full per PR #178).
- **ADR-0019**: POST /api/evaluate contract (body shape, error envelope, idempotency).
- **ADR-0017**: engine purity invariant (pure-Python module, no I/O, no UI deps). New `last_result` parameter MUST be a separate keyword arg, NOT string munging.
- **ADR-0019 amendment 2**: mpmath pinned runtime dep; Decimal precision byte-exact; error envelope taxonomy.
- **STORY-007** (DONE): persistent history backend (SQLite).
- **STORY-011** (DONE): scientific functions (unary, no implicit-operand semantics).
- **Sprint 4 P0 E2E-DEPLOY-VERIFY** (in-flight per PR #178): AC9 test coverage contract.

## Test Cases

### TC-1: Engine happy path — `+ 12` after `42 + 8 = 50` returns `62`
- **Setup**: `from atilcalc.engine.evaluator import evaluate, EngineError`
- **Steps**:
  1. `evaluate("+ 12", last_result=Decimal("50"))` → `Decimal("62")`
  2. `evaluate("+  12", last_result=Decimal("50"))` (double space) → `Decimal("62")` (whitespace tolerant)
  3. `evaluate("+12", last_result=Decimal("50"))` (no space) → `Decimal("62")` (per AC8 PM rec)
- **Expected**: All three return `Decimal("62")` exactly. Whitespace + no-whitespace both acceptable per AC8 owner-question resolution.
- **Pins**: AC1, AC8

### TC-2: Engine Decimal precision — `(0.1 + 0.2) * 4` chain preserves precision
- **Setup**: chain via two `evaluate()` calls using last_result
- **Steps**:
  1. `r1 = evaluate("0.1 + 0.2")` → `Decimal("0.3")` (no implicit path)
  2. `r2 = evaluate("* 4", last_result=r1)` → `Decimal("1.2")` (implicit path)
  3. Assert `str(r2) == "1.2"` byte-exact (not `1.2000000000000000000000000001`)
- **Expected**: Decimal precision byte-exact per ADR-0019 §Decimal serialization. No floating-point drift.
- **Pins**: AC2, ADR-0019 §Decimal serialization

### TC-3: Engine exponentiation — `^ 2` after 5 returns `25`
- **Setup**: chain via two `evaluate()` calls
- **Steps**:
  1. `r1 = evaluate("5")` → `Decimal("5")`
  2. `r2 = evaluate("^ 2", last_result=r1)` → `Decimal("25")`
  3. `r3 = evaluate("^ 0.5", last_result=Decimal("25"))` → `Decimal("5")` (square root via fractional exponent)
- **Expected**: `^` operator honors implicit-operand path. Negative exponent works: `evaluate("^ -1", last_result=Decimal("2"))` → `Decimal("0.5")`.
- **Pins**: AC3

### TC-4: Engine empty-history guard — `last_result=None` raises `NoHistoryError`
- **Setup**: new exception subclass `NoHistoryError(EngineError)` per PM open question 2
- **Steps**:
  1. `evaluate("+ 5", last_result=None)` → raises `NoHistoryError`
  2. `evaluate("+ 5")` (no `last_result` arg, default None) → raises `NoHistoryError`
  3. `evaluate("+ 5", last_result=Decimal("0"))` → `Decimal("5")` (zero IS a valid last_result, even if unusual)
- **Expected**: `NoHistoryError` raised when no implicit operand available. Zero IS valid (don't reject `0` as "no history").
- **Pins**: AC4

### TC-5: HTTP layer — empty history → 400 NoHistoryError envelope
- **Setup**: FastAPI test client; Sprint 4 P0 E2E-DEPLOY-VERIFY harness; history table empty (first-ever request)
- **Steps**:
  1. `POST /api/evaluate {"expr": "+ 5"}` → 400
  2. Response body: `{"error": {"code": "NoHistoryError", "message": "No previous result to use as implicit operand; submit a full expression first.", "request_id": "..."}}`
- **Expected**: HTTP 400, error envelope with `code: "NoHistoryError"`, message is user-actionable. NOT 500. NOT misleading 0.
- **Pins**: AC4, ADR-0019 §Error envelope

### TC-6: HTTP layer — error-entry skip → use last SUCCESSFUL result
- **Setup**: history table has 3 records: `[success(50), error(1/0), success(8)]` (success at idx 0, error at idx 1, success at idx 2). The most recent is `success(8)`. But AC5 says "use last SUCCESSFUL" — implementation choice: skip error entries, find last success.
- **Steps**:
  1. `POST /api/evaluate {"expr": "+ 5"}` → 200 with `{"result": "13"}` (8 + 5, NOT 5+5 which would be wrong if using error entry)
  2. `POST /api/evaluate {"expr": "+ 5"}` (after history: `[success(50), error, success(8), success(13)]`) → 200 with `{"result": "18"}` (13 + 5, last success is 13)
- **Expected**: Engine receives `last_result=Decimal("8")` for step 1 (last success skipping the error). For step 2, receives `Decimal("13")`. Error entries are never used as implicit operand.
- **Pins**: AC5

### TC-7: HTTP layer — all-history-is-errors → 400 NoHistoryError
- **Setup**: history table has only error records: `[error, error, error]`
- **Steps**:
  1. `POST /api/evaluate {"expr": "+ 5"}` → 400 with `code: "NoHistoryError"`
- **Expected**: When NO successful result exists, behavior matches AC4 (empty history). Engine receives `last_result=None`.
- **Pins**: AC5 fallback

### TC-8: HTTP layer — no-regression on normal expressions (AC6)
- **Setup**: FastAPI test client; history table has 1+ success records
- **Steps**:
  1. `POST /api/evaluate {"expr": "50 + 12"}` → 200 with `{"result": "62"}` (explicit-operand path, same as Sprint 2)
  2. `POST /api/evaluate {"expr": "5 * 4"}` → 200 with `{"result": "20"}`
  3. `POST /api/evaluate {"expr": "sqrt(16)"}` → 200 with `{"result": "4"}`
- **Expected**: All three return identical responses to Sprint 2 behavior. `last_result` is fetched but only USED when expression starts with operator. Performance parity: p99 <50ms per ADR-0019.
- **Pins**: AC6

### TC-9: HTTP layer — audit-style history record (AC7)
- **Setup**: history table has `success(50)`; submit implicit-operand `+ 12`
- **Steps**:
  1. `POST /api/evaluate {"expr": "+ 12"}` → 200 with `{"result": "62"}`
  2. Query history table for the NEW record (the one just created)
  3. Assert the new record's `expr` field is `"50 + 12"` (the **resolved** expression), NOT `"+ 12"` (the user's terse input)
  4. Assert `result` is `"62"` and `idempotency_key` follows ADR-0019 (hash of resolved expr + request_id)
- **Expected**: History record shows what was computed, not what was typed. Audit-friendly for retroactive debugging. Idempotency key uses resolved expr (so user can retry same implicit `+ 12` from same last_result and get same history record).
- **Pins**: AC7

### TC-10: Engine purity — `last_result` is a SEPARATE parameter (AC10)
- **Setup**: inspect `evaluate()` signature
- **Steps**:
  1. `import inspect; sig = inspect.signature(evaluate)`
  2. Assert `"last_result" in sig.parameters` (new keyword arg)
  3. Assert `sig.parameters["last_result"].default is None` (default = no implicit)
  4. Assert NO string munging happens in HTTP layer (no `"+ 12".replace(...)` patterns)
  5. Grep `src/atilcalc/engine/evaluator.py` for non-stdlib imports beyond `mpmath` — assert ONLY mpmath (per ADR-0019 amendment 2 carve-out)
- **Expected**: `last_result: Decimal | None = None` is the clean pure-function design per PM rec. HTTP layer passes it as-is; engine composes the full expression internally (e.g., `"Decimal('50') + Decimal('12')"` via Decimal arithmetic, NOT string concat).
- **Pins**: AC10, ADR-0017 §engine ↔ UI separation

### TC-11: HTTP layer perf parity — implicit path p99 <50ms (ADR-0019 budget)
- **Setup**: 1000 sequential `POST /api/evaluate {"expr": "+ 5"}` calls with last_result=`Decimal("10")`
- **Steps**:
  1. Warm up: 10 calls (excluded from timing)
  2. Time 1000 calls with `time.perf_counter()`
  3. Assert p99 < 50ms
  4. Compare to explicit-operand baseline (1000 calls of `POST /api/evaluate {"expr": "10 + 5"}`) — assert implicit path is WITHIN 10% of explicit path
- **Expected**: Implicit path adds <5ms overhead (history fetch + Decimal composition). p99 <50ms per ADR-0019 budget. Parity with explicit path within 10%.
- **Pins**: AC6 (no-regression) + ADR-0019 §Performance budgets

### TC-12: HTTP layer error mapping — NoHistoryError → 400 (NOT 500)
- **Setup**: FastAPI test client; history empty
- **Steps**:
  1. `POST /api/evaluate {"expr": "+ 5"}` → 400 (assert response.status_code == 400)
  2. Response body has `error.code == "NoHistoryError"` (NOT `UndefinedOperatorError`, NOT `EngineError`)
  3. NO 500 in logs for this path (graceful error mapping)
- **Expected**: HTTP 400 with clean error envelope. Distinct error code from existing taxonomy. Logs show graceful handling, not stack trace.
- **Pins**: AC4 + ADR-0019 §Error envelope taxonomy

### TC-13: Keyboard FSM — `+12` (no space) parses identically to `+ 12` (AC8)
- **Setup**: HTTP layer (or engine direct)
- **Steps**:
  1. `POST /api/evaluate {"expr": "+12"}` → 200 with `{"result": "62"}` (50 + 12)
  2. `POST /api/evaluate {"expr": "+ 12"}` → 200 with `{"result": "62"}` (50 + 12)
  3. Both history records have `expr: "50 + 12"` (resolved, audit-style)
- **Expected**: Both inputs accepted, identical result. Owner-question resolution per AC8 = "operator followed by operand on same line" (space optional). macOS Calculator parity.
- **Pins**: AC8

### TC-14: All 5 binary operators support implicit-operand
- **Setup**: last_result = `Decimal("10")`
- **Steps**:
  1. `evaluate("+ 5", last_result=Decimal("10"))` → `Decimal("15")`
  2. `evaluate("- 3", last_result=Decimal("10"))` → `Decimal("7")`
  3. `evaluate("* 4", last_result=Decimal("10"))` → `Decimal("40")`
  4. `evaluate("/ 2", last_result=Decimal("10"))` → `Decimal("5")`
  5. `evaluate("^ 2", last_result=Decimal("10"))` → `Decimal("100")`
- **Expected**: All 5 binary operators (`+`, `-`, `*`, `/`, `^`) honor implicit-operand path. Negative-result cases: `evaluate("- 15", last_result=Decimal("10"))` → `Decimal("-5")`.
- **Pins**: AC1-AC3 + scope (§all 5 binary operators, not just `+`)

### TC-15: Persistence layer — "last successful result" query (open question resolution)
- **Setup**: history table has mixed records; query `get_last_successful_result()` from persistence module
- **Steps**:
  1. Insert 5 records: `[success, error, success, error, success]` (most recent is success)
  2. `result = get_last_successful_result()` → returns the MOST RECENT success record's `result` field
  3. Insert another error: `[success, error, success, error, success, error]` (most recent is error)
  4. `result = get_last_successful_result()` → STILL returns the most recent SUCCESS (skips the trailing error)
- **Expected**: Query correctly skips error records and returns the latest success. Implementation choice: either (a) dedicated `last_successful_result` column maintained on every insert, OR (b) query-time filter `WHERE status='success' ORDER BY created_at DESC LIMIT 1`. Architect's call at sizing.
- **Pins**: AC5 + PM open question 2

### TC-16: Regression — Sprint 1+2+3 stories still pass (no operator semantics drift)
- **Setup**: full pytest suite
- **Steps**:
  1. `pytest tests/engine/ -v` → all Sprint 2 STORY-002/003/011 engine tests still pass
  2. `pytest tests/api/ -v` → all STORY-007 (history backend) + STORY-008 (history UI) + STORY-011 (transcendentals) HTTP tests still pass
  3. `pytest tests/cli/ -v` → CLI surface (`atilcalc eval`) tests pass (no implicit-operand on CLI per scope)
- **Expected**: Zero regression on existing 6 deployed stories. New `last_result` parameter is purely additive (default=None preserves Sprint 2/3 behavior).
- **Pins**: AC6 + Sprint 1+2+3 regression suite

## Adversarial Probes

- **AP-1** — Empty expression with implicit: `evaluate("", last_result=Decimal("10"))` → `ExpressionSyntaxError` (NOT NoHistoryError — the user provided input, just empty)
- **AP-2** — Whitespace-only expression: `evaluate("   ", last_result=Decimal("10"))` → `ExpressionSyntaxError`
- **AP-3** — Operator-only with no operand: `evaluate("+", last_result=Decimal("10"))` → `ExpressionSyntaxError` (operator needs operand)
- **AP-4** — Multiple leading operators: `evaluate("++ 5", last_result=Decimal("10"))` → either `ExpressionSyntaxError` (no prefix increment) OR `Decimal("15")` if `++` treated as `+ (+ 5)`. Architect's call; document behavior.
- **AP-5** — Unicode operator: `evaluate("× 5", last_result=Decimal("10"))` → `ExpressionSyntaxError` (ASCII-only policy, same as Sprint 1-2)
- **AP-6** — Unicode digit: `evaluate("+ ٥", last_result=Decimal("10"))` (Arabic 5) → `ExpressionSyntaxError` (ASCII-only)
- **AP-7** — Very large last_result: `evaluate("+ 1", last_result=Decimal("1E+100"))` → `Decimal("1.000000000000000000000000000E+100")` (Decimal precision preserved at scale)
- **AP-8** — Negative last_result: `evaluate("+ 5", last_result=Decimal("-10"))` → `Decimal("-5")` (negative IS valid)
- **AP-9** — Zero last_result with positive operand: `evaluate("+ 5", last_result=Decimal("0"))` → `Decimal("5")` (zero is valid)
- **AP-10** — Very small last_result (Decimal underflow): `evaluate("+ 1", last_result=Decimal("1E-100"))` → `Decimal("1.000000000000000000000000000E-100")` (precision preserved)
- **AP-11** — Concurrent requests with different last_result: 100 parallel `POST /api/evaluate` from different sessions → each gets ITS OWN last_result from its session history (not cross-contaminated). FSM is per-session, race-safe.
- **AP-12** — History record deleted between read and write: AC7 audit record relies on last_result that was just read. If another request deletes that record concurrently, idempotency_key still works (hash of resolved expr + request_id, not history record id). Audit record IS created with resolved expr.
- **AP-13** — Scientific function with implicit: `evaluate("sin", last_result=Decimal("10"))` → `ExpressionSyntaxError` (unary, no implicit per scope §Out of scope)
- **AP-14** — Modulo with implicit: `evaluate("% 3", last_result=Decimal("10"))` → `Decimal("1")` (10 % 3 = 1, if `%` is in scope; verify Sprint 1 scope)
- **AP-15** — Cross-session implicit: User A submits `42 + 8 = 50`, User B submits `+ 5` on the SAME backend → User B gets NoHistoryError (User B's history is empty, NOT User A's). Per-server vs per-session is a design choice; architect's call at sizing.
- **AP-16** — Race condition: User A reads last_result=50, User A's request arrives at engine, User B submits `+ 1` from 51 first, history now has `[50, 51]`. User A's request resolves `50 + 5 = 55` (with the snapshot they read), but the new history record will be INSERTED AFTER User B's `[50, 51, 55]`. Idempotency: User A can retry the same request and get the same result (because engine receives explicit `last_result=50`, not history fetch at insert time).

## Performance Concerns

- **Engine call**: `evaluate("+ 5", last_result=Decimal("50"))` is ~1ms slower than `evaluate("50 + 5")` due to keyword-arg unpacking + Decimal composition. Negligible.
- **History query**: `get_last_successful_result()` is `SELECT ... ORDER BY created_at DESC LIMIT 1` with optional `WHERE status='success'`. Indexed on `(status, created_at DESC)` per STORY-007 schema. ~1-2ms cold, <0.1ms warm (SQLite page cache).
- **API overhead**: FastAPI + pydantic adds ~1-2ms. Negligible vs engine.
- **Total p99 budget**: ~5ms (history fetch) + ~3ms (engine) + ~2ms (API) = ~10ms. Well under 50ms budget per ADR-0019.
- **Audit record insert**: history INSERT after response computed is on the request path (synchronous). Adds ~1ms. If async/background is preferred, architect's call at sizing.

## Regression Risk

- **Sprint 2 STORY-002 engine arithmetic** (PR #26): `evaluate("50 + 12")` path must remain identical. New `last_result` parameter is purely additive (default=None preserves behavior).
- **STORY-007 history backend**: query API gets a new method `get_last_successful_result()`. Existing `get_recent_history(limit=N)` unchanged.
- **STORY-011 transcendentals** (mpmath pinned): no impact — scientific functions are unary, out of implicit-operand scope.
- **ADR-0019 amendment 2 Decimal serialization**: implicit-operand chain must preserve byte-exact Decimal. `(0.1 + 0.2) * 4` chain via last_result must equal `Decimal("1.2")` byte-exact.
- **Sprint 3 P0 E2E-DEPLOY-VERIFY harness** (AC9): new E2E test for implicit-operand path added to the harness. Test runs as part of the 3+ consecutive deploys verification.
- **No CLI surface change**: `atilcalc eval` Typer command stays explicit-operand for scripting clarity (per scope §Out of scope).
- **No regression on UI components**: `<atilcalc-history>` shows the resolved expr (e.g., "50 + 12") instead of user's input ("+ 12"). If UI has any regex/parser on the `expr` field, it must be re-verified. PM open question 3 explicitly asks tester to verify no UI regression.

## Test File Mapping

| TC | File |
|---|---|
| TC-1, TC-2, TC-3, TC-4, TC-14 | `tests/engine/test_implicit_operand.py` (engine contract — happy path, precision, exponentiation, empty-history guard) |
| TC-10 | `tests/engine/test_engine_signature.py` (verify `last_result` param + ADR-0017 purity) |
| TC-15 | `tests/persistence/test_last_successful_result.py` (history query — error-skip semantics) |
| TC-5, TC-6, TC-7, TC-8, TC-9, TC-11, TC-12, TC-13 | `tests/api/test_evaluate_implicit_operand.py` (HTTP layer — error mapping, audit record, perf parity) |
| TC-16 | (full pytest suite — `pytest tests/`) |
| AP-1 through AP-16 | `tests/engine/test_implicit_operand_adversarial.py` + `tests/api/test_implicit_operand_adversarial.py` |

## Open Questions for Implementation PR

1. **Architect — engine parameter vs HTTP string munging** (PM open question 1): PM rec is `last_result: Decimal | None = None` parameter. Architect signoff needed.
2. **Architect — "last successful result" persistence semantics** (PM open question 2): dedicated column vs query-time filter? Architect's call at sizing.
3. **Tester — AC7 UI regression check** (PM open question 3): verify `<atilcalc-history>` component handles audit-style expr (resolved) without breaking display. Sprint 5+ story for any UI work needed.
4. **Owner — AC8 space handling** (PM open question 4): `+12` (no space) vs `+ 12` (space) — owner preference. PM rec: both work (macOS Calculator parity). TC-13 documents the PM rec; owner can amend at sizing.
5. **AP-15 cross-session semantics**: per-server (all users share last_result) vs per-session (each user has their own)? Architect's call. Default rec: per-server (single-user MVP per vision §Scope).
6. **AP-4 multiple leading operators**: `++ 5` syntax error vs `+(+5)` interpretation? Architect's call. Default rec: `ExpressionSyntaxError` (no prefix increment).

## References

- `docs/backlog/STORY-013.md` (spec, AC1-AC10) — PR #180
- `docs/decisions/ADR-0017.md` §engine ↔ UI separation (engine purity invariant)
- `docs/decisions/ADR-0019.md` §POST /api/evaluate contract + §Error envelope taxonomy
- `docs/decisions/ADR-0019-amendment-2-decimal-and-envelope.md` §Decimal precision + §Transcendental precision model
- `docs/test-plans/STORY-007-tests.md` (history backend test patterns)
- `docs/test-plans/STORY-011-tests.md` (engine purity + Decimal precision patterns)
- PR #178 (Sprint 4 plan, 18.5 SP — STORY-013 deferred to Sprint 5+)
- Issue #175 (RCA-15 — Sprint 3 P0 carry, must close before E2E-DEPLOY-VERIFY which AC9 depends on)