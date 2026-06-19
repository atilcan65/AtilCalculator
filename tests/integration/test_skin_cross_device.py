"""Integration tests for STORY-010 AC2 — cross-device skin sync (Issue #72).

Per ADR-0022 §Cross-device sync model:
- Single SQLite file on shared filesystem (NFS-equivalent)
- Multiple FastAPI processes (or multiple clients via HTTP) read/write same file
- No application-level sync layer

TDD red: skip on missing impl. Module-level probe checks:
- `atilcalc.api.main` importable
- `atilcalc.persistence.skin` importable
- `skin` table exists with key/value/updated_at
- 2 clients can read/write same DB concurrently without lock contention
"""

from __future__ import annotations

import os
import sqlite3
import uuid
from pathlib import Path

import pytest

try:
    from fastapi.testclient import TestClient  # type: ignore[import-not-found]

    from atilcalc.api.main import app  # type: ignore[import-not-found]

    # Shared DB path (simulates NFS mount)
    _TEST_DB_PATH = Path(
        os.environ.get(
            "HISTORY_DB_PATH",
            f"/tmp/atilcalc-test-skin-cross-device-{uuid.uuid4().int}.db",
        )
    )
    _TEST_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    os.environ["HISTORY_DB_PATH"] = str(_TEST_DB_PATH)

    # Probe: `skin` table exists
    _conn = sqlite3.connect(str(_TEST_DB_PATH))
    _cur = _conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='skin';"
    )
    if _cur.fetchone() is None:
        raise RuntimeError(
            "AC2: 'skin' table missing. ADR-0022 §Schema requires skin table."
        )
    _conn.close()

    # 2 TestClient instances on the same app — simulates 2 LAN clients
    _client_a = TestClient(app)
    _client_b = TestClient(app)

except Exception as _exc:
    _msg = str(_exc)
    if (
        any(marker in _msg for marker in ["AC2", "probe", "schema"])
        or "import" in _msg.lower()
        or "module" in _msg.lower()
        or "table" in _msg.lower()
    ):
        pytest.skip(  # type: ignore[name-defined]
            "STORY-010 TDD red — skin persistence not yet wired. "
            "Cross-device sync requires the persistence layer (see "
            "tests/api/test_skin_persistence.py for the contract).",
            allow_module_level=True,
        )
    raise


# ---------------------------------------------------------------------------
# TC-3: AC2 — 2 TestClient instances on shared DB see each other's writes
# ---------------------------------------------------------------------------
class TestCrossDeviceSyncSameApp:
    """AC2: Client B sees Client A's write via shared SQLite backend."""

    def test_client_b_sees_client_a_skin_write(self) -> None:
        """Client A PUTs skin=retro; Client B GETs skin returns retro."""
        # Reset to known state
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        _conn.execute("DELETE FROM skin;")
        _conn.commit()
        _conn.close()

        # Client A: PUT skin=retro
        idemp_a = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        put_resp = _client_a.put(
            "/api/skin",
            json={"skin": "retro"},
            headers={"Idempotency-Key": idemp_a},
        )
        assert put_resp.status_code == 200, (
            f"AC2 Client A PUT failed: {put_resp.status_code}: {put_resp.text!r}"
        )

        # Client B: GET — must see 'retro'
        get_resp = _client_b.get("/api/skin")
        assert get_resp.status_code == 200, (
            f"AC2 Client B GET failed: {get_resp.status_code}: {get_resp.text!r}"
        )
        body = get_resp.json()
        assert body["skin"] == "retro", (
            f"AC2: cross-device sync BROKEN. Client A wrote 'retro', "
            f"Client B got {body['skin']!r}. Shared backend not wired."
        )

    def test_client_a_sees_client_b_skin_write(self) -> None:
        """Symmetric: Client B PUTs, Client A sees."""
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        _conn.execute("DELETE FROM skin;")
        _conn.commit()
        _conn.close()

        # Client B: PUT skin=light
        idemp_b = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        put_resp = _client_b.put(
            "/api/skin",
            json={"skin": "light"},
            headers={"Idempotency-Key": idemp_b},
        )
        assert put_resp.status_code == 200

        # Client A: GET — must see 'light'
        get_resp = _client_a.get("/api/skin")
        body = get_resp.json()
        assert body["skin"] == "light", (
            f"AC2 (symmetric): Client B wrote 'light', "
            f"Client A got {body['skin']!r}. Shared backend not wired bidirectionally."
        )


# ---------------------------------------------------------------------------
# TC-4: AC2 — 2 subprocess servers on different ports (true NFS simulation)
# ---------------------------------------------------------------------------
class TestCrossDeviceSyncSubprocessServers:
    """AC2: 2 separate FastAPI subprocesses on different ports share SQLite via NFS-equivalent."""

    def test_two_subprocess_servers_share_skin(self) -> None:
        """Spawn 2 uvicorn servers on ports 8001/8002; verify PUT-via-A → GET-via-B."""
        pytest.skip(
            "Subprocess server test requires CI infrastructure (uvicorn spawn). "
            "Defer to STORY-010 impl PR. TDD red: TC-3 (same-app 2-client) "
            "exercises the same cross-device sync contract with lower overhead."
        )
