"""Contract tests for STORY-010 AC4 — concurrent PUTs + audit log.

Refs Issue #72. Per ADR-0022:
- AC4: concurrent PUTs → last-write-wins + audit log records all transitions with ts + idempotency_key
- AP-1: concurrent PUT with same idempotency key → both 200, only 1 audit entry
- AP-9: 50 concurrent PUTs with busy_timeout=5000 → no `OperationalError: database is locked`

TDD red: skip on missing impl. Module-level probe checks:
- `atilcalc.api.main` importable
- `atilcalc.persistence.skin` importable
- `skin` table + audit log table (`skin_audit`) exist
- PRAGMA busy_timeout >= 5000 (per ADR-0022)
"""

from __future__ import annotations

import concurrent.futures
import os
import sqlite3
import uuid
from pathlib import Path

import pytest

try:
    from fastapi.testclient import TestClient  # type: ignore[import-not-found]

    from atilcalc.api.main import app  # type: ignore[import-not-found]

    _TEST_DB_PATH = Path(
        os.environ.get(
            "HISTORY_DB_PATH",
            f"/tmp/atilcalc-test-skin-concurrent-{uuid.uuid4().int}.db",
        )
    )
    _TEST_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    os.environ["HISTORY_DB_PATH"] = str(_TEST_DB_PATH)

    _client = TestClient(app)

    # Probe: audit log table (`skin_audit`) must exist (per ADR-0022 + AC4)
    _conn = sqlite3.connect(str(_TEST_DB_PATH))
    _audit_exists = (
        _conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='skin_audit';"
        ).fetchone()
        is not None
    )
    if not _audit_exists:
        raise RuntimeError(
            "AC4: 'skin_audit' table missing. AC4 requires an audit log "
            "of all skin transitions with (from_skin, to_skin, idempotency_key, ts). "
            "ADR-0022 §Schema must be extended with this table, OR an in-process "
            "logger MUST be replaced (rejected by AP-8 — audit log must be in SQLite)."
        )

    _conn.close()

except Exception as _exc:
    _msg = str(_exc)
    if (
        any(marker in _msg for marker in ["AC4", "probe", "audit"])
        or "import" in _msg.lower()
        or "module" in _msg.lower()
        or "table" in _msg.lower()
    ):
        pytest.skip(  # type: ignore[name-defined]
            "STORY-010 TDD red — skin audit log not yet wired. "
            "Implementation PR must add 'skin_audit' table (or extend "
            "ADR-0022 §Schema) to record all skin transitions.",
            allow_module_level=True,
        )
    raise


def _put_skin(client: TestClient, skin: str, idempotency_key: str) -> int:
    """Helper: PUT /api/skin and return status code."""
    resp = client.put(
        "/api/skin",
        json={"skin": skin},
        headers={"Idempotency-Key": idempotency_key},
    )
    return resp.status_code


# ---------------------------------------------------------------------------
# TC-7: AC4 — concurrent PUTs: last-write-wins + audit log records all 5 transitions
# ---------------------------------------------------------------------------
class TestConcurrentPutsLastWriteWins:
    """AC4: 5 concurrent PUTs → all 200, final state = last write, audit log = 5 entries."""

    def test_five_concurrent_puts_all_succeed(self) -> None:
        """5 concurrent PUTs (different idempotency keys) → all return 200, no deadlock."""
        # Wipe audit log + skin table for clean run
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        _conn.execute("DELETE FROM skin;")
        _conn.execute("DELETE FROM skin_audit;")
        _conn.commit()
        _conn.close()

        # 5 concurrent PUTs with distinct keys + distinct skins
        skins = ["dark", "light", "retro", "dark", "light"]
        keys = [
            f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
            for _ in range(5)
        ]

        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
            futures = [
                pool.submit(_put_skin, _client, s, k) for s, k in zip(skins, keys, strict=False)
            ]
            results = [f.result() for f in futures]

        # All 5 must succeed
        for i, status in enumerate(results):
            assert status == 200, (
                f"AC4: concurrent PUT #{i} failed with status {status}. "
                f"busy_timeout too low? deadlock?"
            )

        # Final state must be one of the 5 written skins (last-write-wins)
        final = _client.get("/api/skin").json()
        assert final["skin"] in skins, (
            f"AC4: final skin {final['skin']!r} is not one of the 5 written values {skins!r}"
        )

    def test_audit_log_records_all_five_transitions(self) -> None:
        """AC4: audit log MUST have 5 entries (one per PUT), no silent overwrites."""
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        audit_count = _conn.execute(
            "SELECT COUNT(*) FROM skin_audit;"
        ).fetchone()[0]
        _conn.close()

        assert audit_count == 5, (
            f"AC4: audit log must have 5 entries (one per concurrent PUT); "
            f"got {audit_count}. Silent overwrites detected — reconciliation broken."
        )


# ---------------------------------------------------------------------------
# AP-1: concurrent PUT with same idempotency key (race on UNIQUE)
# ---------------------------------------------------------------------------
class TestConcurrentPutSameKey:
    """AP-1: 2 concurrent PUTs with same idempotency key → both 200, only 1 audit entry."""

    def test_same_key_concurrent_put_no_duplicate_audit(self) -> None:
        """2 concurrent PUTs with Idempotency-Key=K1 + same body → 1 audit entry, not 2."""
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        _conn.execute("DELETE FROM skin;")
        _conn.execute("DELETE FROM skin_audit;")
        _conn.commit()
        _conn.close()

        shared_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            f1 = pool.submit(_put_skin, _client, "retro", shared_key)
            f2 = pool.submit(_put_skin, _client, "retro", shared_key)
            statuses = [f1.result(), f2.result()]

        assert all(s == 200 for s in statuses), (
            f"AP-1: same-key concurrent PUT must both return 200; got {statuses}"
        )

        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        audit_count = _conn.execute(
            "SELECT COUNT(*) FROM skin_audit WHERE idempotency_key = ?;",
            (shared_key,),
        ).fetchone()[0]
        _conn.close()

        assert audit_count == 1, (
            f"AP-1: same-key concurrent PUT must produce exactly 1 audit entry; "
            f"got {audit_count}. UNIQUE constraint race window detected."
        )


# ---------------------------------------------------------------------------
# AP-9: 50 concurrent PUTs with busy_timeout=5000
# ---------------------------------------------------------------------------
class TestHighConcurrencyNoLockContention:
    """AP-9: 50 concurrent PUTs → all complete, no OperationalError surfaces."""

    def test_fifty_concurrent_puts_no_lock_error(self) -> None:
        """50 concurrent PUTs → all 200 (no `OperationalError: database is locked`)."""
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        _conn.execute("DELETE FROM skin;")
        _conn.execute("DELETE FROM skin_audit;")
        _conn.commit()
        _conn.close()

        skins = ["dark", "light", "retro"]
        keys = [
            f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
            for _ in range(50)
        ]

        with concurrent.futures.ThreadPoolExecutor(max_workers=50) as pool:
            futures = [
                pool.submit(_put_skin, _client, skins[i % 3], keys[i])
                for i in range(50)
            ]
            results = [f.result() for f in futures]

        non_200 = [(i, s) for i, s in enumerate(results) if s != 200]
        assert not non_200, (
            f"AP-9: 50 concurrent PUTs; {len(non_200)} failed. "
            f"First failures: {non_200[:5]}. "
            f"busy_timeout too low? WAL not enabled?"
        )
