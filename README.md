# AtilCalculator

> A minimal, keyboard-first, history-keeping, skin-changeable web calculator with scientific function support. Self-hosted on the owner's home Linux server, it serves daily and advanced calculation needs in a single always-open browser tab. Exact decimal arithmetic (no IEEE-754 float drift), persistent cross-device history, switchable dark / light / retro skins, and a `?` keyboard shortcut for inline help.

See the [Vision](docs/product/vision.md) for the full "why this exists" and the [User Guide](docs/USER-GUIDE.md) for day-to-day usage (skins, history, scientific mode, keyboard reference, troubleshooting).

## Prerequisites

- **Python 3.11+** (3.12 recommended; pinned via `.python-version`)
- **Port 8000** available on the host (configurable via `ATC_PORT`)
- **LAN IP** for cross-device access (default `192.168.1.199`; configurable via `ATC_HOST`)
- ~50 MB disk for the SQLite history file + Python deps

## Install

On modern Linux (Debian 12+, Ubuntu 23.04+, Fedora 38+) the system Python refuses package installs without a venv (PEP 668). Set one up first:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

This installs the runtime deps (`fastapi`, `uvicorn[standard]`, `httpx`) and the dev extras (`pytest`, `ruff`, `mypy`, `playwright` for E2E). The engine itself is stdlib-only — `mpmath==1.3.0` is the one carve-out, justified in [ADR-0019 amend 2](docs/decisions/ADR-0019-amendment-2-decimal-and-envelope.md).

If you use `uv` (recommended for speed), the equivalent one-liner is:

```bash
uv venv && source .venv/bin/activate && uv pip install -e ".[dev]"
```

## Run

```bash
uvicorn atilcalc.api.main:app --host 192.168.1.199 --port 8000
```

Or use the wrapper script (validates `ATC_PORT` and `ATC_HOST` up front, defaults to the LAN IP per ADR-0019 R-3):

```bash
bash scripts/run-server.sh
```

Override the host/port with env vars:

```bash
ATC_HOST=127.0.0.1 ATC_PORT=8765 bash scripts/run-server.sh
```

Then open `http://192.168.1.199:8000/` in any browser on the LAN.

## Test

```bash
pytest -q
```

Runs the full test suite: engine (pure-function Decimal arithmetic + transcendentals), API (FastAPI + Idempotency-Key contract), integration (SQLite cross-device sync), and web (Playwright E2E; skipped in headless-only envs).

Targeted runs:

```bash
pytest tests/engine/ -q        # pure-function engine, no I/O
pytest tests/api/ -q           # FastAPI surface, includes Idempotency-Key
pytest tests/integration/ -q   # SQLite cross-device sync
```

Lint and type-check:

```bash
ruff check src/ tests/
mypy --strict src/atilcalc/engine
```

## What's where

```
.
├── src/atilcalc/
│   ├── engine/          # Pure-function Decimal arithmetic + transcendentals
│   │                    # (no I/O, no UI deps — see ADR-0017)
│   ├── persistence/     # SQLite layer (skin + history; ADR-0022)
│   ├── api/             # FastAPI surface (4 endpoints; ADR-0019)
│   └── web/             # Vanilla JS Web Components (ADR-0018)
│       ├── shortcuts.js # Single source of truth for keyboard shortcuts (ADR-0023)
│       ├── app.js       # Keyboard FSM (imports SHORTCUT_KEYS from shortcuts.js)
│       ├── app-deferred.js  # <atilcalc-help-popup> + mode toggle + error toast
│       ├── theme.js     # Skin system
│       └── skins/       # dark.css + light.css + retro.css
├── tests/
│   ├── engine/          # engine contract tests
│   ├── api/             # API contract tests
│   ├── integration/     # SQLite cross-device tests
│   ├── web/             # Playwright E2E
│   └── docs/            # README + USER-GUIDE + CHANGELOG contract tests
├── docs/
│   ├── product/         # vision.md, personas.md
│   ├── backlog/         # user stories per sprint
│   ├── designs/         # per-story design docs
│   ├── decisions/       # ADRs (architectural decisions)
│   ├── sprints/         # sprint plans + standups
│   ├── ops/             # operator runbooks (vm-hardening, backup)
│   └── USER-GUIDE.md    # owner-facing usage reference
├── scripts/             # run-server.sh, agent-watch.sh, notify.sh, ops/
├── .claude/             # Agent definitions (human-only)
└── .github/             # Issue/PR templates, CI workflows (human-only)
```

## Architecture

- **Engine is pure-Python**, no I/O, no UI deps. The HTTP and Web layers wrap the engine — never the reverse. See [ADR-0017 — Tech stack](docs/decisions/ADR-0017-tech-stack.md).
- **Persistence is SQLite**, file-backed, WAL mode, with cross-device visibility via the shared file (NFS-equivalent). See [ADR-0022 — Persistence layer](docs/decisions/ADR-0022-persistence-layer.md).
- **HTTP API is FastAPI**, 4 endpoints (`POST /api/evaluate`, `GET /api/history`, `GET /api/skin`, `PUT /api/skin`), with `Idempotency-Key` header (UUID v4) on all state-mutating endpoints. See [ADR-0019 — HTTP API contract](docs/decisions/ADR-0019-api-contract.md).
- **Frontend is vanilla JS**, no build step, 6 Web Components, dark skin default. See [ADR-0018 — Frontend framework](docs/decisions/ADR-0018-front-end-framework.md).
- **Theming is CSS-variable-driven** (no inline JS palette swap). Keyboard shortcuts are extracted to a single registry file (`src/atilcalc/web/shortcuts.js`) used by both the FSM and the help popup. See [ADR-0023 — Frontend architecture](docs/decisions/ADR-0023-frontend-architecture.md).

## License

Private — internal use only. Default MIT per `pyproject.toml`; a `LICENSE` file is TBD (not required for the owner-self-hosted use case).

## See also

- [User Guide](docs/USER-GUIDE.md) — day-to-day usage
- [Vision](docs/product/vision.md) — what this is and why
- [CHANGELOG.md](CHANGELOG.md) — release notes (Keep a Changelog format)
- [Sprint 2 plan](docs/sprints/sprint-02/plan.md) — current roadmap
- [Architecture decisions](docs/decisions/INDEX.md) — ADRs
- `.claude/CLAUDE.md` (local-only — gitignored per file ownership matrix) — agent doctrine
