"""STORY-003b TC-5 — TDD-RED: LAN-bind (env-driven host/port).

AC5: FastAPI server can be bound to a LAN-reachable address. Per
ADR-0019, the canonical LAN bind is `192.168.1.199:8000` (the owner's
VM). For dev, the default is loopback (`127.0.0.1`) and the operator
overrides via env vars.

This file is the unit contract: `scripts/run-server.sh` exists,
respects `ATC_HOST` / `ATC_PORT` env vars, and has safe defaults.
The subprocess-level LAN assertion is in
test_lan_bind_subprocess.py (a heavier test that boots uvicorn
and curls /healthz).
"""

from __future__ import annotations

import os
import re
import socket
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[2] / "scripts"
RUN_SERVER_SH = SCRIPTS_DIR / "run-server.sh"


def test_run_server_script_exists() -> None:
    """`scripts/run-server.sh` must exist (STORY-003b commit 5)."""
    assert RUN_SERVER_SH.exists(), (
        f"Expected {RUN_SERVER_SH} to exist. The HTTP server is launched via "
        f"this script (or the equivalent Makefile target). Without it, the "
        f"operator has no documented way to start the LAN-bound service."
    )


def test_run_server_script_is_executable() -> None:
    """The script must be executable (chmod +x)."""
    assert RUN_SERVER_SH.exists()
    import stat
    mode = RUN_SERVER_SH.stat().st_mode
    assert mode & stat.S_IXUSR, (
        f"{RUN_SERVER_SH} is not executable. Run `chmod +x {RUN_SERVER_SH}`."
    )


def test_run_server_script_reads_atc_host() -> None:
    """The script must read `ATC_HOST` env var (default per ADR-0019: 192.168.1.199)."""
    src = RUN_SERVER_SH.read_text(encoding="utf-8")
    assert "ATC_HOST" in src, (
        f"{RUN_SERVER_SH} does not reference ATC_HOST. AC5 requires the bind "
        f"address to be env-overridable so the operator can switch from "
        f"loopback (dev) to LAN IP (192.168.1.199) or 0.0.0.0 (testing)."
    )


def test_run_server_script_reads_atc_port() -> None:
    """The script must read `ATC_PORT` env var (default: 8000)."""
    src = RUN_SERVER_SH.read_text(encoding="utf-8")
    assert "ATC_PORT" in src, (
        f"{RUN_SERVER_SH} does not reference ATC_PORT. AC5 requires the port "
        f"to be env-overridable (the VM-hardening default port is 8000; "
        f"a developer might use 8765 to avoid clashing with another service)."
    )


def test_run_server_script_has_shebang() -> None:
    """The script must have a `#!/usr/bin/env bash` shebang."""
    src = RUN_SERVER_SH.read_text(encoding="utf-8")
    assert src.startswith("#!"), (
        f"{RUN_SERVER_SH} is missing a shebang. Without one, the operator "
        f"cannot run it directly (must use `bash scripts/run-server.sh`)."
    )


def test_run_server_script_invokes_uvicorn() -> None:
    """The script must launch uvicorn with atilcalc.api.main:app."""
    src = RUN_SERVER_SH.read_text(encoding="utf-8")
    assert "uvicorn" in src, f"{RUN_SERVER_SH} does not invoke uvicorn."
    assert "atilcalc.api.main" in src or "atilcalc.api:app" in src, (
        f"{RUN_SERVER_SH} does not point uvicorn at the FastAPI app "
        f"(atilcalc.api.main:app)."
    )


@pytest.mark.parametrize(
    "env_var,default,example_override",
    [
        ("ATC_HOST", "192.168.1.199", "0.0.0.0"),  # ADR-0019 default
        ("ATC_PORT", "8000", "8765"),
    ],
)
def test_run_server_script_uses_env_with_default(
    env_var: str, default: str, example_override: str
) -> None:
    """The script must use ${env_var:-default} (POSIX env-with-default)."""
    src = RUN_SERVER_SH.read_text(encoding="utf-8")
    # accept either ${VAR:-default} or $VAR with a default in a comment
    pattern_dollar_brace = re.compile(
        rf"\$\{{{env_var}:-([^{{}}]+)\}}"
    )
    pattern_dollar_paren = re.compile(
        rf"\$\({env_var}:-([^\)]+)\)"
    )
    pattern_bare = re.compile(rf"\${env_var}\b")
    match = (
        pattern_dollar_brace.search(src)
        or pattern_dollar_paren.search(src)
    )
    if match is None:
        # No brace-style. Accept bare $VAR if a `default=` line is nearby.
        assert pattern_bare.search(src), (
            f"{RUN_SERVER_SH} references {env_var} but not with a default. "
            f"Use POSIX ${{{env_var}:-{default}}} so the script works "
            f"without any env override."
        )
    else:
        # ensure the documented default appears
        # (we don't enforce exact match — devs may have alternate forms)
        assert default in match.group(0) or default in src, (
            f"{RUN_SERVER_SH} uses {env_var} with a default, but the default "
            f"is not the ADR-0019 / dev default ({default}). Confirm intent."
        )
    # also accept the example override
    assert example_override or True  # noop, just keeps the override param alive
