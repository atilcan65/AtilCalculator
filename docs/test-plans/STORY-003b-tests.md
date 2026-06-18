# Test Plan: STORY-003b — Deferred Web Components + E2E + LAN-bind

> Source: [Issue #31 (STORY-003b)](https://github.com/atilcan65/AtilCalculator/issues/31).
> Author: @developer (this PR — implementation is dev-owned; tester will write
> the contract suite PR mirroring PR #37 pattern if they want TDD-red separation).
> Sibling: [STORY-003a](docs/test-plans/STORY-003a-tests.md) (3 core components
> + keyboard FSM, already merged via PR #42).

## Scope

### In scope
- 3 deferred Web Components:
  - `<atilcalc-mode-toggle>` (dark / light / retro skin toggle, vision M4)
  - `<atilcalc-help-popup>` (`?` key, lists keyboard shortcuts)
  - `<atilcalc-error-toast>` (engine error display, e.g. `DivisionByZeroError`)
- Skin system infrastructure: CSS custom property swap on `:root`,
  transitions < 500 ms (vision M4)
- Keyboard FSM extensions: `?` opens help, `Esc` closes help / error toast
- LAN-bind: `uvicorn` listens on `0.0.0.0:PORT` (env-driven; default loopback
  for dev safety)
- Playwright E2E contract test: digit entry → result via keyboard
- `CHANGELOG.md` [Unreleased] → Added entry

### Out of scope (handled by STORY-003a)
- FastAPI backend + static SPA shell + 3 core components
- Core keyboard FSM (3 states) + basic ops

## Test Cases (mapping to ACs in Issue #31)

### TC-1: AC1 — `<atilcalc-mode-toggle>` skin swap on click
**Dev-owned; lands in `tests/web/test_mode_toggle.py` (parametrised, 3 skins).**
- `dark` skin: `--calc-bg` resolves to `rgb(18, 18, 18)` (≈ `#121212`)
- `light` skin: `--calc-bg` resolves to `rgb(255, 255, 255)` (≈ `#ffffff`)
- `retro` skin: `--calc-bg` resolves to a greenish tone (vision M4 retro palette)
- All 3 buttons are clickable; clicking sets the active skin class on `<body>`
- Custom element is registered (`customElements.get("atilcalc-mode-toggle")`)
- The active skin persists across navigation (the API `GET /api/skin` returns
  the same value the user set via `PUT /api/skin`)

### TC-2: AC2 — `?` key opens help pop-up listing keyboard shortcuts
**Dev-owned; lands in `tests/web/test_help_popup.py`.**
- `?` (Shift+`/`) on focused page → help pop-up becomes visible (`<dialog open>`)
- Help pop-up lists all 9 FSM shortcuts: `0-9`, `+ - * /`, `(`, `)`, `.`,
  `Enter`, `Escape`, `Backspace`, `?`
- Pressing `Esc` while help is open → help closes
- Clicking outside the dialog → help closes
- Custom element is registered (`customElements.get("atilcalc-help-popup")`)

### TC-3: AC3 — engine error → error-toast (no JS exception)
**Dev-owned; lands in `tests/web/test_error_toast.py`.**
- POST `/api/evaluate` with `{expr: "1/0"}` → response has `error.type = "DivisionByZeroError"`
- The page receives the error, displays it via `<atilcalc-error-toast>`
- No `Uncaught` exception in `page.on("pageerror")` listener
- Error-toast auto-dismisses after the configured duration (5 s default)
- `Esc` dismisses the toast immediately
- Custom element is registered (`customElements.get("atilcalc-error-toast")`)

### TC-4: AC4 — Playwright E2E test for keyboard flow
**Dev-owned; lands in `tests/web/test_e2e_keyboard.py` (Playwright + pytest).**
- Boot the FastAPI app on a free port (loopback default)
- Open `http://127.0.0.1:<port>/` in Chromium
- Dispatch `keydown` events: `1`, `+`, `2`, `Enter`
- Assert `<atilcalc-display>` `.result` text content === `"3"`
- Bonus: dispatch `1`, `+`, `2`, `+`, `3`, `Enter` → result === `"6"`
- Bonus: dispatch `7`, `*`, `8`, `Enter` → result === `"56"`
- Cleanup: close the browser, terminate the uvicorn subprocess

### TC-5: AC5 — LAN-bind (`0.0.0.0:PORT`) — accessible from another host
**Dev-owned; lands in `tests/api/test_lan_bind.py` (unit + subprocess).**
- Unit: `scripts/run-server.sh` (or `uvicorn.run(...)` call) reads
  `ATC_HOST` and `ATC_PORT` env vars; defaults to `127.0.0.1:8000`
- Subprocess: launch the server with `ATC_HOST=0.0.0.0 ATC_PORT=<free>`,
  assert `GET /healthz` succeeds on `http://<lan-ip>:<port>/healthz`
  (loopback-only assertion in CI; LAN assertion in the operator's manual
  test plan via `192.168.1.199:PORT` from the owner's laptop — per
  Issue #31, AC5 explicit)
- Negative: with `ATC_HOST=127.0.0.1`, `0.0.0.0` is NOT in the bind list

### TC-6: AC6 — Skin transition <500ms, no visual flicker
**Dev-owned; lands in `tests/web/test_skin_transition.py` (Playwright).**
- Start on `dark` skin, click `light` button
- Read `getComputedStyle(document.body).transitionDuration`; assert it
  contains `200ms` (or any value < 500ms) for `background` and `color`
- Capture screenshot mid-transition; no half-painted frames
- Total transition time measured from `transitionstart` to `transitionend`
  is < 500ms

### TC-7: AC7 — `CHANGELOG.md` [Unreleased] → ### Added entry
**Dev-owned; lands as a grep-based check in `tests/docs/test_changelog.py`.**
- `CHANGELOG.md` contains the string `STORY-003b` in the `[Unreleased]`
  section under `### Added`
- Entry references Issue #31 and PR #N (filled in at PR-open time)

## Adversarial Probes (input validation + UX)

| Probe | Input | Expected |
|---|---|---|
| `?` typed into an `<input>` | text field | help pop-up does NOT open (FSM ignores keys when input is focused) |
| `?` typed twice rapidly | keyboard | help opens once (no double-event flicker) |
| Rapid skin toggling (dark → light → dark → retro in <1s) | click | final state is `retro`; no in-flight transition error |
| Error-toast triggered twice in <100ms | `1/0` then `2/0` | only the most recent error message is visible (or queued) |
| Playwright test with the server already shut down | boot failure | test fails with a clear `ConnectionError`, not a hang |
| `ATC_HOST` set to invalid value (e.g. `not-an-ip`) | env | uvicorn exits non-zero with a clear error message |
| `ATC_PORT` set to non-numeric (e.g. `abc`) | env | server fails to start with `ValueError` (caught and re-raised) |
| LAN-bind attempted with `ATC_HOST=127.0.0.1` and operator's manual LAN test | env mismatch | operator's manual test from `192.168.1.199` fails with `ConnectionRefused` — clearly attributed to the `127.0.0.1` bind, not a bug |

## Performance Concerns

- **Skin transition**: must complete in < 500 ms per AC6. Avoid animating
  expensive properties (`box-shadow`, `filter`); prefer `background` and
  `color` (compositor-only).
- **Playwright boot**: the E2E test boots a fresh uvicorn process. Keep
  boot < 2 s to keep CI snappy. Use the in-process TestClient (from
  `fastapi.testclient`) for fast unit tests; reserve the subprocess
  launch for the E2E suite.
- **LAN-bind startup**: setting `ATC_HOST=0.0.0.0` should not measurably
  change boot time vs `127.0.0.1`.

## Regression Risk

- The keyboard FSM is extended (new states `help-open`, `error-toast`).
  This must not regress the existing 3-state FSM (idle/entering/evaluated)
  covered by STORY-003a contract tests. Existing tests in
  `tests/web/test_keyboard_fsm.py` (landed in PR #42) must still pass
  unmodified.
- The skin system swaps CSS custom properties at runtime. If a downstream
  story (Sprint 2) adds a skin-specific JS branch, it must not break
  the no-build-step rule (ADR-0018).
- LAN-bind is a security-sensitive change. The default MUST remain
  `127.0.0.1` (loopback) for dev safety; `0.0.0.0` is opt-in via env
  only. Document this in `scripts/run-server.sh` and the README.
- Playwright is a new dev dependency. Pin exact versions per ADR-0017
  (`playwright==1.49.0 + pytest-playwright==0.7.0`). The browser
  download step is a one-time `playwright install chromium` (document
  in README; not in CI for now — too slow and brittle).

## Test Counts (after this PR)

- AC1 (mode-toggle): 3 parametrised + 2 structural = 5
- AC2 (help-popup): 4 scenarios (open by ?, close by Esc, close by click-outside, custom-element-registered) = 4
- AC3 (error-toast): 4 scenarios + 1 console-error check = 5
- AC4 (E2E): 3 keyboard sequences = 3
- AC5 (LAN-bind): 2 (unit + subprocess) + 1 negative = 3
- AC6 (transition): 1 duration + 1 mid-frame = 2
- AC7 (changelog): 1 grep check = 1
- **Total: 23 scenarios + 1 console-error pin**

The 30-case floor from STORY-002 doesn't apply here (that was engine);
this story's contract is structural + UX, not a large parametrised
matrix. The Playwright E2E (TC-4) covers the most important
end-to-end behaviour with disproportionate value.

## PR Conventions

- Branch: `feat/story-003b-deferred-components-e2e-lan-bind`
- Targets: `main` (after STORY-003a merge at 123a0fd)
- 4-cat labels: `type:feature` + `status:in-review` + `agent:developer`
  + `cc:tester` + `needs-tester-signoff` (D2.2 wake label)
- Auto-ping: `[DEV→TEST+ARCH] PR #N ready for review`
- Commit count: 7 (per dev plan in Issue #31 comment of 2026-06-18T06:02:24Z)

## Open Questions (escalated to @architect, 2h timeout)

1. **Mode-toggle UI**: button group (default) vs dropdown vs radio
2. **Help-popup**: modal via `<dialog>` (default) vs inline panel
3. **Error-toast duration**: 5s auto-dismiss (default) vs 3s vs persistent
4. **LAN-bind default**: env-driven with 127.0.0.1 fallback (default) vs
   0.0.0.0 LAN-ready

Defaults above will be implemented if no architect response by 2h after
the plan-comment timestamp (2026-06-18T08:02:24Z).
