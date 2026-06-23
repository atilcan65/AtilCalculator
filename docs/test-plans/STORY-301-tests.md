# Test Plan: STORY-301 — REPL mode interactive (M3 spirit)

> Source: [Issue #301 (STORY-CLI-003)](https://github.com/atilcan65/AtilCalculator/issues/301).
> Author: @tester (this PR). Implementer: @developer.
> TDD discipline: tests in this plan land in `scripts/tests/d036c-cli-repl.sh` + `tests/cli/test_repl.py` BEFORE
> the REPL implementation (TDD RED). The implementer's job is to make them pass
> (TDD GREEN) without breaking the contract.

## Scope

### In scope
- `atilcalc --repl` interactive mode
- Prompt display (e.g., `atilcalc> `)
- Expression evaluation per line (uses STORY-299 + STORY-300)
- Exit commands (`exit`, `quit`)
- EOF handling (Ctrl-D on Unix, Ctrl-Z + Enter on Windows)
- Slash-commands (`/help`, `/exit`, `/quit`)
- Parse error continuation (REPL does NOT exit on parse error)
- Parametrised session test

### Out of scope
- Session-level history (last-N + arrow recall) — Sprint 8+
- Auto-completion (tab completion) — Sprint 8+
- Syntax highlighting — out of MVP
- Multi-line expressions (continuation with `\` or unclosed parens) — Sprint 8+ or never
- REPL inside HTTP/Web — Sprint 9+
- History persistence across sessions — Sprint 2 STORY-007 (HTTP only); CLI session history is future

## Test Cases (mapping to ACs in Issue #301)

### TC-1: AC1 — REPL prompt display (tester-owned, this PR)
**Landed in `test_repl_prompt_display`.**
- Spawn `atilcalc --repl` as subprocess, capture stdout/stderr
- Send empty input (Enter) — stdout should show `atilcalc> ` prompt
- Process should still be alive (not exited)

### TC-2: AC2 — Basic eval in REPL (tester-owned, this PR)
**Landed in `test_repl_basic_eval` (parametrised, 3 cases).**
- `atilcalc --repl` + send `0.1 + 0.2\n` → stdout `0.3` + new prompt
- `atilcalc --repl` + send `1 + 1\n` → stdout `2` + new prompt
- `atilcalc --repl` + send `2 * 3\n` → stdout `6` + new prompt

### TC-3: AC3 — Precedence eval in REPL (tester-owned, this PR)
**Landed in `test_repl_precedence_eval` (parametrised, 2 cases).**
- `atilcalc --repl` + send `(2 + 3) * 4\n` → stdout `20` (uses STORY-300 precedence)
- `atilcalc --repl` + send `2 + 3 * 4\n` → stdout `14`

### TC-4: AC4 — Exit commands (tester-owned, this PR)
**Landed in `test_repl_exit_commands` (parametrised, 2 cases).**
- `atilcalc --repl` + send `exit\n` → stdout shows goodbye message + exit code 0
- `atilcalc --repl` + send `quit\n` → stdout shows goodbye message + exit code 0

### TC-5: AC5 — EOF handling (tester-owned, this PR)
**Landed in `test_repl_eof_handling` (2 cases — Unix + Windows skip if unavailable).**
- Unix: `atilcalc --repl` + close stdin (EOF) → exit code 0, no error message
- Windows: skip in CI (Ctrl-Z + Enter platform-specific)

### TC-6: AC6 — Parse error continuation (tester-owned, this PR)
**Landed in `test_repl_parse_error_continuation` (parametrised, 2 cases).**
- `atilcalc --repl` + send `1 + + 2\n` → stderr shows parse error, exit code 0 (REPL continues), new prompt appears
- `atilcalc --repl` + send `(1 + 2\n` → stderr shows parse error (unbalanced), REPL continues, new prompt appears
- After error: send `1 + 1\n` → REPL recovers, stdout `2`

### TC-7: AC7 — /help slash-command (tester-owned, this PR)
**Landed in `test_repl_slash_help`.**
- `atilcalc --repl` + send `/help\n` → stdout shows help text with `/help`, `/exit`, `/quit`
- After /help: send `1 + 1\n` → REPL still works (no exit)

### TC-8: AC8 — Session-level test (tester-owned, this PR)
**Landed in `test_repl_session_level`.**
- Drive stdin with sequence: `1 + 1\n`, `2 * 3\n`, `1 + + 2\n` (parse error), `exit\n`
- Verify stdout: `2`, `6`, parse error (stderr), goodbye
- Exit code: 0
- REPL state machine handles 5 events cleanly

### TC-9: AC9 — mypy + ruff on REPL module (developer-owned, gated)
**CI gate.**
- `mypy --strict src/atilcalc/repl/` → 0 errors
- `ruff check src/atilcalc/repl/` → 0 errors
- REPL is a separate module (per PM open question: stdlib `input()` for Sprint 7)

### TC-10: Edge case — Empty input (tester-owned, this PR)
**Landed in `test_repl_empty_input`.**
- `atilcalc --repl` + send `\n` (empty line + Enter) → stdout new prompt (no error, no output)
- REPL continues to next input

## Adversarial Probes

### Input Validation
- **Very long line**: 10k chars → REPL handles without DoS
- **Binary input**: `\x00\x01\x02` → REPL treats as invalid expression, parse error
- **Unicode expression**: `atilcalc --repl` + send `١ + ١\n` → either eval or clear error
- **Mixed line endings**: `\r\n` vs `\n` → REPL normalizes (handle both)

### Security
- **REPL injection**: sending `__import__('os').system('rm -rf /')\n` → no eval (REPL is expression parser, not Python eval)
- **stdin exhaustion**: very long input → REPL handles gracefully (no OOM)
- **Concurrent instances**: 100 parallel `atilcalc --repl` → no shared state corruption

### State
- **Session state**: each REPL instance is independent (no global state pollution)
- **Parse error state**: REPL state machine must not get stuck after error
- **Exit state**: after `exit`, REPL must clean up (close stdin/stdout properly)

### Performance
- **REPL responsiveness**: each prompt should appear <50ms after Enter
- **Session length**: REPL should handle 1000+ expressions without degradation
- **Memory**: REPL session < 50MB RSS for typical use

## Performance Concerns

- **Prompt I/O latency**: stdlib `input()` + stdout flush — measure
- **Parser overhead**: each line parsed independently (no incremental parse)
- **History (future)**: not in Sprint 7 scope, but design must accommodate

## Regression Risk

- REPL must reuse STORY-299 + STORY-300 (basic + precedence)
- Parser must handle line-by-line (not whole-expression only)
- Error handling must not crash REPL (graceful degradation)
- Windows compatibility: skip in CI but design must not exclude

## Dependencies

- **Upstream**: STORY-299 (basic arithmetic) + STORY-300 (precedence) — must both land
- **Downstream**: Sprint 8+ session history; Sprint 9+ HTTP REPL

## Test Framework

- **Framework**: `pytest` (parametrised) per ADR-0017
- **REPL driver**: `subprocess.Popen` with stdin pipe, drive line-by-line via `proc.stdin.write()`
- **Hermetic**: each test spawns fresh REPL subprocess, no shared state
- **Coverage target**: ≥85% line coverage on `src/atilcalc/repl/` (REPL has more edge cases)

## Test Scripts (TDD RED deliverable)

- `scripts/tests/d036c-cli-repl.sh` — hermetic shell test (8 TUs, ~50 LOC)
- `tests/cli/test_repl.py` — pytest session-level tests (8 cases)

## Acceptance Sign-Off

- All 8 TUs PASS (d036c)
- All 8 pytest cases PASS (test_repl.py)
- mypy --strict on repl: 0 errors
- ruff check on repl: 0 errors
- STORY-299 + STORY-300 tests still PASS (no regression)

— @tester, 2026-06-23T13:35Z, STORY-301 test plan ready, awaiting Sprint 7 launch for TDD RED script write.
