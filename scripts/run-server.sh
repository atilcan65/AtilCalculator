#!/usr/bin/env bash
# scripts/run-server.sh — launch the AtilCalculator FastAPI service.
#
# AC5 (STORY-003b) — LAN-bind is env-driven, with the ADR-0019 default
# (192.168.1.199:8000) so the owner's VM is reachable from the LAN
# out-of-the-box. Devs can override:
#
#   ATC_HOST=127.0.0.1 ATC_PORT=8765 scripts/run-server.sh   # loopback dev
#   ATC_HOST=0.0.0.0   ATC_PORT=8000 scripts/run-server.sh   # any-interface test
#
# The default of 192.168.1.199 (not 0.0.0.0) is the security boundary
# per ADR-0019 R-3: bind only to the LAN IP, not all interfaces. If
# the operator wants to test from a different LAN they MUST set
# ATC_HOST explicitly — accidental 0.0.0.0 binding is a security hole.

set -euo pipefail

ATC_HOST="${ATC_HOST:-192.168.1.199}"
ATC_PORT="${ATC_PORT:-8000}"

# Reject obviously-bad values up front so the operator gets a clear
# error rather than a cryptic uvicorn traceback.
case "${ATC_PORT}" in
  ''|*[!0-9]*) echo "ATC_PORT must be a positive integer, got: ${ATC_PORT}" >&2; exit 2 ;;
esac
if [ "${ATC_PORT}" -lt 1 ] || [ "${ATC_PORT}" -gt 65535 ]; then
  echo "ATC_PORT must be in [1, 65535], got: ${ATC_PORT}" >&2
  exit 2
fi

# Detect a running interpreter (uv run > system python3 > python).
#
# ISSUE #771 RCA-20 fix: `uv run python` installs only the BASE package
# (atilcalc + mpmath, ~2 pkgs) — no fastapi, no uvicorn. The fresh venv
# then fails on `python -m uvicorn atilcalc.api.main:app` with
# `No module named uvicorn`. Fix: pass `--extra web` so uv installs the
# [web] extra (fastapi==0.115.6 + uvicorn[standard]==0.32.1, pinned per
# ADR-0017). The [web] extra is the prod runtime surface per AP-23c
# "exactly one place" doctrine — single source of truth for the runtime
# pins lives in pyproject.toml [web], NOT duplicated here.
if command -v uv >/dev/null 2>&1; then
  PYTHON=(uv run --extra web python)
elif command -v python3 >/dev/null 2>&1; then
  PYTHON=(python3)
else
  echo "Neither uv nor python3 is on PATH. Install one and retry." >&2
  exit 2
fi

echo "[atilcalc] launching FastAPI on ${ATC_HOST}:${ATC_PORT}" >&2
exec "${PYTHON[@]}" -m uvicorn atilcalc.api.main:app \
  --host "${ATC_HOST}" \
  --port "${ATC_PORT}"
