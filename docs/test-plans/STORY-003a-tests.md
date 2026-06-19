# Test Plan: STORY-003a — Web shell core (FastAPI + 3 components + keyboard FSM)

> Source: [Issue #30 (STORY-003a)](https://github.com/atilcan65/AtilCalculator/issues/30).
> Author: @tester (this PR). Implementer: @developer.
> TDD discipline: tests in this plan land as **failing pytest contracts** in `tests/api/`
> and `tests/web/` BEFORE the FastAPI / Web Components implementation. The implementer's
> job is to make them pass (TDD GREEN) without breaking the contract.
>
> Sister / dependent items: [STORY-003b (Issue #31)](https://github.com/atilcan65/AtilCalculator/issues/31)
> (deferred components + E2E + LAN-bind), [d007 ship (Issue #35)](https://github.com/atilcan65/AtilCalculator/issues/35)
> (observability static-check regression test, ships in same PR per "test-with-code" pattern).

## Architectural inputs (read first)

- **[ADR-0017](../decisions/ADR-0017-tech-stack.md)** (Accepted) — engine ↔ UI separation; engine is
  stdlib-only pure-Python (`src/atilcalc/engine/`), HTTP wrapper is FastAPI
  (`src/atilcalc/api/`), frontend is vanilla JS + Web Components (`src/atilcalc/web/`).
- **[ADR-0018](../decisions/ADR-0018-front-end-framework.md)** (Accepted) — vanilla JS, no build
  step, dark skin default, CSS custom properties.
- **[ADR-0019](../decisions/ADR-0019-api-contract.md)** (Accepted, PR #33) — `POST /api/evaluate`
  + `GET/PUT /api/skin` + `GET /api/history`; error envelope `{"error": {"type", "message", "request_id"}}`;
  `Decimal` serialised as **string** (lossless); `PUT /api/skin` requires `idempotency_key`.

## Scope

### In scope
- FastAPI app with `GET /` (static SPA shell), `POST /api/evaluate`, `GET /api/history`,
  `GET /api/skin`, `PUT /api/skin` (per ADR-0019)
- 3 Web Components: `<atilcalc-display>`, `<atilcalc-keypad>`, `<atilcalc-history>`
- Keyboard FSM with 3 states (idle / entering / evaluated) + single global listener + key allowlist
- HTML + CSS shell, dark skin default
- Engine roundtrip via `POST /api/evaluate` (depends on STORY-002 — `evaluate()` on main, PR #26 merged)
- Observability harness (structured JSON logs per request: `route`, `request_id`, `latency_ms`, `status`)
- Idempotency on `PUT /api/skin` via `idempotency_key` field
- d007 static-check regression test (Issue #35, ships in same PR)

### Out of scope
- 3 deferred Web Components (`<atilcalc-mode-toggle>`, `<atilcalc-help-popup>`, `<atilcalc-error-toast>`) → STORY-003b (Issue #31)
- Playwright E2E test → STORY-003b
- LAN-bind (`0.0.0.0:PORT` + `192.168.1.199:PORT` access) → STORY-003b (blocked on STORY-001 VM hardening)
- Skin transition logic (light/retro skins) → STORY-003b + Sprint 2
- Persistence (SQLite for history) → Sprint 2 R-5
- Auth → Sprint 2

## FastAPI app structure (executable spec)

The implementer's job is to land `src/atilcalc/api/main.py` with the following shape — the
tests below are the contract.

| Method | Path | Body | Success | Idempotency | Notes |
|---|---|---|---|---|---|
| GET | `/` | — | 200 + `text/html` (SPA shell) | n/a (read) | AC1, AC8 |
| GET | `/healthz` | — | 200 + `{"status": "ok"}` | n/a | matches STORY-001 |
| POST | `/api/evaluate` | `{"expr": "..."}` | 200 + `{"result": "str", "precision": 28, "elapsed_ms": int}` | n/a (read-only) | AC4, AC7 — engine call |
| GET | `/api/history` | — | 200 + `{"history": [...]}` | n/a | last N evals, default 50, max 1000 |
| GET | `/api/skin` | — | 200 + `{"skin": "dark", "available": [...]}` | n/a | current skin |
| PUT | `/api/skin` | `{"skin": "light", "idempotency_key": "..."}` | 200 + `{"skin": "light", "applied_at": "..."}` | **REQUIRED** | state-mutating |

Error envelope (every error response, all endpoints):
```json
{"error": {"type": "<ClassName>", "message": "...", "request_id": "<UUID>"}}
```

Engine exception → HTTP status mapping (per ADR-0019):
| Engine exception | HTTP status |
|---|---|
| `ExpressionSyntaxError` | 400 |
| `DivisionByZeroError` | 400 |
| `UndefinedOperatorError` | 400 |
| `EngineError` (catch-all) | 500 |
| FastAPI `ValidationError` (bad body shape) | 422 |

## Web Component shape (executable spec)

| Custom element | Attributes | Methods | Emits |
|---|---|---|---|
| `<atilcalc-display>` | `value` (string, reflected) | `setInput(s)`, `setResult(s)`, `clear()` | `display:change` (on `value` change) |
| `<atilcalc-keypad>` | — | `onDigit(d)`, `onOp(o)`, `onEnter()`, `onClear()`, `onBackspace()` | `keypad:press` (CustomEvent with `{type, value}`) |
| `<atilcalc-history>` | `limit` (int, default 50) | `pushEntry(expr, result)`, `clear()` | `history:change` |

SPA wiring (in `src/atilcalc/web/index.js` or similar — implementer's choice of file layout):
- One global `keydown` listener; routes to FSM
- FSM state: `'idle' | 'entering' | 'evaluated'`
- Allowed keys: `0-9`, `+ - * /`, `( )`, `Enter`, `Escape`, `Backspace`, `.`
- On `Enter`: fetch `POST /api/evaluate` with current input; update display result
- On `Escape`: clear input
- On `Backspace`: drop last char

## Test files (1:1 to ACs + infrastructure)

| File | Covers AC | Test count target |
|---|---|---|
| `tests/api/__init__.py` | — | package marker |
| `tests/api/conftest.py` | — | `client` fixture (FastAPI `TestClient`) + `history_reset` fixture |
| `tests/api/test_evaluate.py` | AC4, AC7 | ~8 (happy path, AC7 roundtrip, error mapping, large input) |
| `tests/api/test_skin.py` | AC1 (skin=default) | ~6 (GET default, PUT each skin, idempotency replay, unknown skin → 400) |
| `tests/api/test_history.py` | AC1 (history present) | ~3 (empty → 200, push → 200, reverse-chrono) |
| `tests/api/test_errors.py` | AC4 (error envelope) | ~5 (syntax → 400, div/0 → 400, unknown op → 400, validation → 422, EngineError → 500) |
| `tests/api/test_static_serving.py` | AC1, AC8 | ~3 (GET / → 200 + text/html, content has 3 component tags, GET / missing → 404) |
| `tests/api/test_observability.py` | ADR-0019 §Observability | ~3 (request_id emitted, error log on 4xx, latency logged) |
| `tests/web/__init__.py` | — | package marker |
| `tests/web/test_keyboard_fsm.py` | AC2, AC3, AC5, AC6 | ~8 (digits insert, ops insert, Enter evaluates, Esc clears, Backspace drops, FSM transitions idle→entering→evaluated) |
| `tests/web/test_components.py` | AC1 (3 components present) | ~3 (display, keypad, history defined + render) |
| `tests/web/test_engine_integration.py` | AC7 | ~2 (0.1+0.2 roundtrip via fetch, 100+5% roundtrip via fetch) |
| `tests/test_changelog.py` | AC11 | ~1 (CHANGELOG [Unreleased] → Added entry exists for STORY-003a) |
| `scripts/tests/d007-api-observability.sh` | d007 ship (Issue #35) | 5 (T1-T5 per Issue #35 body + T3 enhancement) |

**Total contract suite target**: ~47 failing tests at PR-open time.
**After implementation (TDD GREEN)**: all 47 pass.

## Test Cases (mapping to ACs in Issue #30)

### TC-1: AC1 — GET / serves the SPA shell
**Lands in `test_static_serving.py` (3 parametrised cases).**
- `GET /` → 200 + `Content-Type: text/html`
- Response body contains `<atilcalc-display>`, `<atilcalc-keypad>`, `<atilcalc-history>` tags
- `GET /nonexistent` → 404 (not 500)

### TC-2: AC2 — digit keys insert into input line
**Lands in `test_keyboard_fsm.py` (3 cases).**
- Dispatch `keydown` `5` → `<atilcalc-display>.value === "5"`
- Dispatch `0`,`0`,`.`,`1` → `<atilcalc-display>.value === "00.1"`
- Repeated digit dispatch is append-only (no overwrite, no re-init)

### TC-3: AC3 — operator keys insert into input line
**Lands in `test_keyboard_fsm.py` (3 cases).**
- Dispatch `1`,`+`,`2` → input is `"1+2"`
- Dispatch `*`,`/` → input appends both
- Consecutive operators (e.g. `1`,`+`,`+`,`2`) → input is `"1++2"` (engine will reject; UI doesn't preempt)

### TC-4: AC4 — Enter triggers POST /api/evaluate
**Lands in `test_evaluate.py` + `test_keyboard_fsm.py` (5+1 cases).**
- `POST /api/evaluate {"expr": "2+2"}` → 200 + `{"result": "4", "precision": 28, "elapsed_ms": int}`
- `POST /api/evaluate {"expr": "5/0"}` → 400 + error envelope `{"error": {"type": "DivisionByZeroError", ...}}`
- `POST /api/evaluate {"expr": "2+"}` → 400 + error envelope `{"error": {"type": "ExpressionSyntaxError", ...}}`
- `POST /api/evaluate {"expr": "2^3"}` → 400 + error envelope `{"error": {"type": "UndefinedOperatorError", ...}}`
- `POST /api/evaluate {}` (missing `expr`) → 422 (FastAPI pydantic validation)
- FSM: dispatch `1`,`+`,`2`,`Enter` → `<atilcalc-display>.result === "3"`

### TC-5: AC5 — Esc clears input line
**Lands in `test_keyboard_fsm.py` (2 cases).**
- Input `"1+2"`, dispatch `Escape` → input is `""`
- Input `""`, dispatch `Escape` → still `""` (no error)

### TC-6: AC6 — Backspace drops last char
**Lands in `test_keyboard_fsm.py` (2 cases).**
- Input `"1+2"`, dispatch `Backspace` → input is `"1+"`
- Input `""`, dispatch `Backspace` → still `""`

### TC-7: AC7 — 0.1+0.2 roundtrips exactly as "0.3"
**Lands in `test_engine_integration.py` (2 cases) + `test_evaluate.py` (1 case).**
- `POST /api/evaluate {"expr": "0.1+0.2"}` → 200 + `{"result": "0.3", ...}` (string, no trailing zeros)
- Browser-side: input `0.1+0.2`, dispatch `Enter` → display result is **exactly** `"0.3"` (not `"0.30000000000000004"`)

### TC-8: AC8 — server bound to 127.0.0.1:PORT
**Lands in `test_static_serving.py` (1 case).**
- `GET http://127.0.0.1:<port>/` → 200 + HTML (same as `localhost`)
- `GET http://0.0.0.0:<port>/` → connection refused (NOT 200; this is the LAN-bind check, deferred to 003b)

### TC-9: AC9 — `mypy --strict src/atilcalc/web/` clean
**Not pytest.** CI gate. (Web Components are vanilla JS — `mypy` does not apply to `.js` files.
  The CI gate is `ruff` on Python only + JS lint via `npx eslint` if Sprint 2 lands; for 003a,
  this AC is satisfied by **not introducing Python in `src/atilcalc/web/`**.)

### TC-10: AC10 — `ruff check src/atilcalc/web/` clean
**Not pytest.** CI gate. (Same caveat as TC-9 — the directory is JS-only; ruff is a no-op there
  unless the developer introduces a `__init__.py` Python marker. Recommend: skip the gate
  for JS-only directories via `pyproject.toml` `[[tool.ruff.lint.per-file-ignores]]`.)

### TC-11: AC11 — CHANGELOG.md [Unreleased] → Added entry for STORY-003a
**Lands in `tests/test_changelog.py` (1 case).**
- Read `CHANGELOG.md`; assert a bullet under `[Unreleased]` → `### Added` mentions STORY-003a
  (or web shell, or 3 components — implementer's wording, but it must be there)

### TC-12: d007 ship (Issue #35)
**Lands in `scripts/tests/d007-api-observability.sh` (5 cases).** Per Issue #35 body:
- T1: `src/atilcalc/api/middleware.py` exists + referenced from `main.py`
- T2: every route in `routes.py` has a corresponding log emission
- T3: every error class in `engine/` maps to HTTP status in `routes.py` (with drift-detection: row count matches `grep -E '^class \w+\(EngineError\)' src/atilcalc/engine/evaluator.py | wc -l`)
- T4: every `PUT`/`POST` (state-mutating) endpoint accepts `idempotency_key`
- T5: `pyproject.toml` `requires-python` is `>=3.11` (not `>=3.X`)

## Adversarial Probes

| Probe | Input | Expected |
|---|---|---|
| Empty expression | `POST /api/evaluate {"expr": ""}` | 400 `ExpressionSyntaxError` |
| Whitespace expression | `POST /api/evaluate {"expr": "   "}` | 400 `ExpressionSyntaxError` |
| Very long expression (1MB digits) | `POST /api/evaluate {"expr": "1" * 1_000_000}` | 200 (engine O(n)) or 400 (size cap on body) |
| Unicode operator | `POST /api/evaluate {"expr": "1 − 2"}` | 400 `ExpressionSyntaxError` or `UndefinedOperatorError` |
| Null byte in expression | `POST /api/evaluate {"expr": "1\x002"}` | 400 `ExpressionSyntaxError` |
| Idempotency key replay | `PUT /api/skin` x2 with same key | 200 + identical `applied_at` (no re-apply) |
| Idempotency key without field | `PUT /api/skin {"skin": "light"}` | 400 (state-mutating requires key per ADR-0019) |
| Unknown skin | `PUT /api/skin {"skin": "neon", "idempotency_key": "..."}` | 400 `UnknownSkinError` |
| Malformed body (not JSON) | `POST /api/evaluate "not json"` | 422 (pydantic) |
| SQL injection in `expr` | `POST /api/evaluate {"expr": "'; DROP TABLE--"}` | 400 `ExpressionSyntaxError` (engine has no DB) |
| XSS in `expr` | `POST /api/evaluate {"expr": "<script>alert(1)</script>"}` | 400 `ExpressionSyntaxError` (engine has no HTML) |
| 1000 concurrent `POST /api/evaluate` | load test | all complete in < 100ms each (single-user LAN, in-memory) |
| Skin replay with different `skin` field, same key | `PUT /api/skin {skin: "light", key: k1}` then `{skin: "dark", key: k1}` | 200 with FIRST response (cached, not re-applied) — covers the "what if client changes mind and reuses key" case |

## Performance Concerns

- **POST /api/evaluate** hot path — every `=` keystroke. Target: < 50ms p95 (engine is < 5ms; HTTP + JSON overhead is the rest).
- **No N+1 in history** — `GET /api/history` returns the in-memory deque, no DB.
- **Skin PUT idempotency cache** — in-memory dict, 24h TTL, bounded by request rate (single user).
- **FastAPI app startup** — must be < 500ms cold; no heavy ML models, no DB connection pool warm-up.

## Regression Risk

- The `tests/api/test_evaluate.py` contract pins the engine integration. If the engine exception
  hierarchy changes (renames, base class change), ADR-0019 §Error mapping must be re-verified.
  The d007 T3 enhancement (drift detection) catches this automatically.
- The `tests/web/test_engine_integration.py` AC7 roundtrip is the canonical regression pin for
  the "no float coercion" property. If `Decimal` serialisation breaks, the JS-side test fails
  on `result === "0.3"`.
- The `scripts/tests/d007-*.sh` test is the static-check regression pin for the observability
  path. If `src/atilcalc/api/middleware.py` is removed or a route stops emitting logs, T1/T2 fail.
- The PR #28 / Issue #27 lesson (CI vacuous-green) — the d007 test follows the d006 / d213
  pattern (script that greps the source tree, no live CI roundtrip) to avoid the same failure mode.

## Test Counts (after this PR)

- API: 8 (evaluate) + 6 (skin) + 3 (history) + 5 (errors) + 3 (static) + 3 (observability) = **28**
- Web: 8 (keyboard FSM) + 3 (components) + 2 (engine integration) = **13**
- Meta: 1 (changelog) + 5 (d007) = **6**
- **Total: 47 parametrised / scripted cases**

## PR Conventions

- Branch: `test/story-003a-contract-tests` (this branch)
- Targets: `main` (after dev merges `feat/story-003a-web-shell-core`)
- 4-cat labels: `type:feature` + `status:in-review` + `agent:tester` + `cc:developer` (per ADR-0012)
- Auto-ping: `[TEST→DEV] STORY-003a contract suite TDD-RED, implementation needed`
- This PR is **DRAFT** until the developer opens the implementation PR; both PRs merge as a pair.

## Dependencies (recap for implementer)

To run the contract suite locally, the dev will need to add to `pyproject.toml` `dev` extras:
- `httpx==0.27.2` (FastAPI TestClient backend)
- `fastapi==0.115.6` (already in CHANGELOG as planned runtime dep — also needed for TestClient)
- For Playwright (web E2E, STORY-003b): `playwright==1.49.0` + `pytest-playwright==0.7.0`
- For keyboard FSM tests: `jsdom` (npm) OR Playwright (defer to 003b)

For 003a MVP, the dev can get away with **httpx-only** for the API contract suite; web tests
that need a real browser are deferred to 003b or stubbed with `jsdom` if the dev prefers.
