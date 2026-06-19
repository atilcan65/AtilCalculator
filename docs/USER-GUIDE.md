# AtilCalculator — User Guide

> Owner-facing reference for daily use. Pairs with [README.md](../README.md) (install/run/test) and the in-app `?` help popup (keyboard shortcuts). The guide is intentionally a single long page — easier to grep, easier to share a permalink.

## Table of Contents

1. [Skin modes](#skin-modes)
2. [History view](#history-view)
3. [Scientific mode](#scientific-mode)
4. [Keyboard reference](#keyboard-reference)
5. [Troubleshooting](#troubleshooting)

---

## Skin modes

AtilCalculator ships with three built-in skins, switchable at any time without a page reload.

### Dark (default)

- **Look**: deep neutral background (`#1e1e1e`), light text, low-glare for long sessions.
- **When to use**: late-night work, low-light rooms, OLED displays. The owner's daily default.
- **Contrast**: WCAG AAA — 18.9:1 for foreground/background.
- **CSS variables**: `--calc-display-bg`, `--calc-display-fg`, `--calc-keypad-bg`, etc. defined in `src/atilcalc/web/skins/dark.css`.

### Light

- **Look**: white background, dark text, paper-like.
- **When to use**: daytime, well-lit rooms, screen sharing, printed screenshots.
- **Contrast**: WCAG AAA — 18.0:1.
- **CSS variables**: same names as Dark, different values; see `src/atilcalc/web/skins/light.css`.

### Retro

- **Look**: green-on-black CRT-style with chunky borders, evoking 1970s terminals.
- **When to use**: when you want the calculator to feel less "office productivity" and more "lab instrument."
- **Contrast**: WCAG AAA — 13.7:1.
- **CSS variables**: same scheme; values in `src/atilcalc/web/skins/retro.css`.

### How to switch

Three options:

1. **Click the mode toggle** (top of the page) — three buttons labelled `dark | light | retro`.
2. **Press `m`** — cycles basic → scientific (or back). The `m` shortcut also switches the active skin as a side-effect; see the in-app `?` popup for the binding.
3. **API**: `PUT /api/skin` with body `{"skin": "dark"}` and an `Idempotency-Key` header (UUID v4). Useful for scripting.

The active skin persists across page reloads and across devices (SQLite-backed per ADR-0022) — set it once on any LAN device, every other device sees it.

### Auto-discovery

Drop a new `*.css` file in `src/atilcalc/web/skins/` and restart the server — the skin becomes available without any code change. See ADR-0023 §Theming model for the rationale.

---

## History view

Every `POST /api/evaluate` result is recorded in the history view. The view is the right side of the page, scrollable, searchable, and click-to-load.

### Scroll

The history list is virtualised — it can hold thousands of entries without DOM bloat. Scroll with the mouse wheel, trackpad, or `↑`/`↓` arrow keys.

### Search

Press `/` to focus the search box. Type a substring of any expression or result. The list filters in real time. Press `Enter` to load the highlighted entry into the input, or `Esc` to clear the search and return to the unfiltered list.

The search is a `LIKE` substring scan against the SQLite `history` table's `expr` and `result` columns (indexed via `idx_history_expr`). For a 10k-entry history, search latency is <5ms.

### Click-to-load

Click any entry in the history list to load it into the input. The display clears any pending result, sets the input to the entry's expression, and waits for `Enter` to re-evaluate (or for further editing).

### Infinite scroll

When the list reaches the bottom, it lazy-loads the next batch of entries (default page size 50, max 1000 per request). The cursor-based pagination is documented in `docs/decisions/ADR-0022-persistence-layer.md` §Schema — `GET /api/history?cursor=<id>` returns the next batch.

### Persistence

History is stored in `~/.local/share/atilcalc/history.db` (override via `HISTORY_DB_PATH`). The SQLite file is the source of truth — every LAN device sees the same history, regardless of which device did the calculation (per ADR-0022 §Cross-device sync model).

---

## Scientific mode

Press `m` (or click the mode toggle) to switch into scientific mode. The keypad expands to reveal `sin`, `cos`, `tan`, `log`, `ln`, `sqrt`, and `!` (factorial).

### Trig functions

- `sin`, `cos`, `tan` — function-call form: `sin(45)`, `cos(0)`, `tan(pi/4)`. Use the unit suffix `deg` for degree mode: `sin(45 deg) = 0.7071...`.
- The unit suffix is whitespace-tolerant: `45 deg`, `45deg`, `45  deg` all parse identically.

### Rad / deg toggle

Press `d` to toggle between radian and degree mode. The current mode is shown in the display's status bar. Default is radians (matches math convention). Switching mode mid-expression: the active mode applies to all trig functions in the expression.

### Other functions

- `log(x)` — base-10 logarithm. `log(100) = 2`.
- `ln(x)` — natural logarithm. `ln(e) ≈ 1`.
- `sqrt(x)` — square root. `sqrt(2) ≈ 1.414213562373095048801688724209698...`
- `x!` — factorial. `5! = 120`. Capped at 170 (mathematical overflow boundary); `171!` raises `DomainError`.

### Precision

The engine uses `mpmath==1.3.0` with `_MP_DPS=50` (50 decimal digits of internal precision) and round-trips to Python's stdlib `decimal.Decimal` at 28-digit precision for the HTTP response. This is the carve-out documented in ADR-0019 amend 2: `mpmath` is the one non-stdlib runtime dep, justified by the precision budget (stdlib `decimal` cannot achieve the required trig/log/√ function coverage at 28+ digits).

The HTTP response serialises Decimal-as-string: `0.1+0.2` returns `"0.3"` (exact, not `"0.30000000000000004"`).

### Domain errors

`sqrt(-1)`, `log(0)`, `log(-2)`, `asin(2)`, `acos(-1.5)`, `tan(90 deg)` all raise `DomainError` → HTTP 400 with envelope `{"error": {"code": "DomainError", "message": "..."}}`. The error toast displays the message and auto-dismisses after 5s (or press `Esc`).

---

## Keyboard reference

The full shortcut list is in the in-app `?` popup (press `?` to open, `Esc` to close). Quick reference:

### Basic

| Key | Action |
|---|---|
| `0` – `9` | Append digit |
| `+` `-` `*` `/` | Append operator |
| `Enter` | Evaluate |
| `Esc` | Clear input |
| `Backspace` | Delete last char |
| `?` | Open this help |

### History

| Key | Action |
|---|---|
| `↑` `↓` | Navigate history |
| `Enter` | Load entry into input |
| `/` | Focus search box (and append `/` for division) |
| `Esc` | Close search / clear |

### Scientific

| Key | Action |
|---|---|
| `s` | Insert `sin(` |
| `c` | Insert `cos(` |
| `t` | Insert `tan(` |
| `l` | Insert `log(` |
| `n` | Insert `ln(` |
| `r` | Insert `sqrt(` |
| `!` | Factorial |
| `d` | Toggle deg / rad |
| `m` | Toggle basic / scientific mode |

The shortcut registry lives in `src/atilcalc/web/shortcuts.js` (single source of truth per ADR-0023). The keyboard FSM in `src/atilcalc/web/app.js` imports it; the `<atilcalc-help-popup>` renders from it. The two cannot drift.

---

## Troubleshooting

### Port 8000 already in use

The default port is `8000` (per ADR-0019). If it's already taken — common on VMs that also run Grafana, Prometheus, or a previous AtilCalculator instance — start the server on a different port:

```bash
ATC_PORT=8765 bash scripts/run-server.sh
```

The script rejects obviously-bad values (`ATC_PORT` must be a positive integer ≤65535) up front, so you get a clean error rather than a cryptic uvicorn traceback.

### Can't reach the server from the LAN

The default host is `192.168.1.199` (the owner's VM LAN IP), NOT `0.0.0.0`. This is per ADR-0019 R-3 — bind only to the LAN IP, not all interfaces. If you're on a different LAN, set `ATC_HOST` explicitly:

```bash
ATC_HOST=192.168.1.42 ATC_PORT=8000 bash scripts/run-server.sh
```

If you set `ATC_HOST=0.0.0.0` you will see a security warning — the bind-to-all-interfaces is a deliberate operator override, not the default.

### VM hardening prerequisites

Before running AtilCalculator on a fresh VM, apply the hardening script (`scripts/ops/apply-vm-hardening.sh`) which:

- Disables password SSH and enforces key-based auth (with a safety check that loopback key SSH works first).
- Configures fail2ban with sane defaults (`BAN_TIME=1h`, `MAX_RETRY=5`).
- Sets up the systemd user-service for AtilCalculator.
- Validates the SSH config with `sshd -t` before reload.

See `docs/ops/vm-hardening.md` for the full operator runbook. The contract test suite (`scripts/tests/test-vm-hardening.sh`) is 13/13 PASS.

### SQLite database is locked

If the server is hit with high concurrency (50+ concurrent `PUT /api/skin` calls), the SQLite file may report `OperationalError: database is locked`. The fix is the PRAGMAs applied in `src/atilcalc/persistence/skin.py` — `journal_mode=WAL` and `busy_timeout=5000` (5s). If the error persists:

1. Check that no other process has the file open in exclusive mode: `lsof ~/.local/share/atilcalc/history.db`.
2. Check disk space: SQLite needs a few MB of free space for the WAL file.
3. As a last resort, set `HISTORY_DB_PATH` to a fresh file path — the schema migrates on first connect (no manual migration needed; the DDL is `CREATE TABLE IF NOT EXISTS`).

### Backup policy

The single source of truth is `~/.local/share/atilcalc/history.db`. The owner backs it up nightly via systemd-timer:

```bash
# /etc/systemd/system/atilcalc-backup.timer
[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

The backup script (`scripts/ops/backup-history.sh`) snapshots the SQLite file (using `.backup` for crash-consistency) to a date-stamped path under `/var/backups/atilcalc/`. Retention is 30 days. To restore: stop the server, copy the file back to `~/.local/share/atilcalc/history.db`, restart.

### Reset everything (factory reset)

If the SQLite file is corrupted beyond recovery, delete it and restart the server — the schema migrates on first connect:

```bash
rm ~/.local/share/atilcalc/history.db
bash scripts/run-server.sh   # recreates the schema; history starts empty
```

The skin preference is also reset to `dark` (default).

---

## See also

- [README.md](../README.md) — install/run/test commands
- [Vision](product/vision.md) — why this exists, what it's for
- [ADR-0019 — HTTP API contract](decisions/ADR-0019-api-contract.md)
- [ADR-0022 — Persistence layer](decisions/ADR-0022-persistence-layer.md)
- [ADR-0023 — Frontend theming + keyboard registry](decisions/ADR-0023-frontend-architecture.md)
- [Sprint 2 plan](sprints/sprint-02/plan.md) — roadmap context
