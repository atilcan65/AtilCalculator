"""Contract tests for STORY-010 AC5 — idempotency-key retry semantics.

Refs Issue #72. Per ADR-0019 §Idempotency keys + ADR-0022 §Idempotency contract:
- TC-8: same key + same body → cached response, NO re-apply, NO duplicate audit log
- TC-9: same key + DIFFERENT body → 409 Conflict (no silent overwrite)
- AP-2: empty idempotency key → 400 Bad Request
- AP-7: idempotency-key collision across skin + history endpoints → 409 OR 400

TDD red: skip on missing impl. Module-level probe checks:
- `atilcalc.api.main` importable
- `atilcalc.persistence.skin` importable
- `skin_audit` table exists with idempotency_key column
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

    _TEST_DB_PATH = Path(
        os.environ.get(
            "HISTORY_DB_PATH",
            f"/tmp/atilcalc-test-skin-idempotency-{uuid.uuid4().int}.db",
        )
    )
    _TEST_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    os.environ["HISTORY_DB_PATH"] = str(_TEST_DB_PATH)

    _client = TestClient(app)

    # Probe: skin_audit table has idempotency_key column
    _conn = sqlite3.connect(str(_TEST_DB_PATH))
    _cols = {
        row[1]
        for row in _conn.execute("PRAGMA table_info(skin_audit);").fetchall()
    }
    if "idempotency_key" not in _cols:
        raise RuntimeError(
            "AC5: 'skin_audit.idempotency_key' column missing. "
            "AC4 + AC5 require tracking idempotency_key for replay dedup."
        )
    _conn.close()

except Exception as _exc:
    _msg = str(_exc)
    if (
        any(marker in _msg for marker in ["AC5", "probe", "audit", "idempotency"])
        or "import" in _msg.lower()
        or "module" in _msg.lower()
        or "table" in _msg.lower()
    ):
        pytest.skip(  # type: ignore[name-defined]
            "STORY-010 TDD red — skin idempotency layer not yet wired. "
            "Implementation PR must extend skin_audit schema with "
            "idempotency_key column and enforce per-endpoint scope.",
            allow_module_level=True,
        )
    raise


# ---------------------------------------------------------------------------
# TC-8: AC5 — same key + same body → cached, no re-apply, no audit log dup
# ---------------------------------------------------------------------------
class TestIdempotencyKeyReplaySameBody:
    """AC5: replay PUT with same key + same body → cached, audit log has 1 entry."""

    def test_replay_same_key_same_body_no_duplicate_audit(self) -> None:
        """First PUT: 200 + audit entry. Second PUT same key+body: 200 + no new audit entry."""
        # Reset
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        _conn.execute("DELETE FROM skin;")
        _conn.execute("DELETE FROM skin_audit;")
        _conn.commit()
        _conn.close()

        shared_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"

        # First PUT: apply
        first = _client.put(
            "/api/skin",
            json={"skin": "retro"},
            headers={"Idempotency-Key": shared_key},
        )
        assert first.status_code == 200, (
            f"AC5 first PUT: {first.status_code}: {first.text!r}"
        )

        # Capture updated_at for replay assertion
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        first_updated_at = _conn.execute(
            "SELECT updated_at FROM skin WHERE key='current';"
        ).fetchone()[0]
        _conn.close()

        # Wait briefly to ensure updated_at would differ if re-applied
        import time

        time.sleep(0.05)

        # Replay: same key + same body
        second = _client.put(
            "/api/skin",
            json={"skin": "retro"},
            headers={"Idempotency-Key": shared_key},
        )
        assert second.status_code == 200, (
            f"AC5 replay PUT: {second.status_code}: {second.text!r}. "
            f"Must return cached 200, not re-apply."
        )

        # Audit log: exactly 1 entry for shared_key (NOT 2)
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        audit_count = _conn.execute(
            "SELECT COUNT(*) FROM skin_audit WHERE idempotency_key = ?;",
            (shared_key,),
        ).fetchone()[0]
        replay_updated_at = _conn.execute(
            "SELECT updated_at FROM skin WHERE key='current';"
        ).fetchone()[0]
        _conn.close()

        assert audit_count == 1, (
            f"AC5: replay must NOT create new audit entry; got {audit_count} entries "
            f"for key {shared_key!r}. Idempotency violated — duplicate transition logged."
        )

        # updated_at must NOT have changed (replay is not a re-apply)
        assert first_updated_at == replay_updated_at, (
            f"AC5: replay bumped updated_at from {first_updated_at!r} to "
            f"{replay_updated_at!r}. Replay must be a no-op (no timestamp bump)."
        )


# ---------------------------------------------------------------------------
# TC-9: AC5 (negative) — same key + DIFFERENT body → 409 Conflict
# ---------------------------------------------------------------------------
class TestIdempotencyKeyReplayDifferentBody:
    """AC5 (negative): same key + different body → 409 Conflict, no silent overwrite."""

    def test_same_key_different_body_returns_409(self) -> None:
        """PUT K1+retro → 200. PUT K1+light → 409 (NOT silent overwrite to light)."""
        # Reset
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        _conn.execute("DELETE FROM skin;")
        _conn.execute("DELETE FROM skin_audit;")
        _conn.commit()
        _conn.close()

        shared_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"

        # First PUT: retro
        first = _client.put(
            "/api/skin",
            json={"skin": "retro"},
            headers={"Idempotency-Key": shared_key},
        )
        assert first.status_code == 200

        # Replay with DIFFERENT body
        conflict = _client.put(
            "/api/skin",
            json={"skin": "light"},
            headers={"Idempotency-Key": shared_key},
        )
        assert conflict.status_code == 409, (
            f"AC5 (negative): same key + different body MUST return 409 Conflict "
            f"(per ADR-0019 §Idempotency + ADR-0022 §Idempotency contract); "
            f"got {conflict.status_code}: {conflict.text!r}. "
            f"Silent overwrite detected."
        )

        # Body should still be 'retro' (not overwritten)
        _conn = sqlite3.connect(str(_TEST_DB_PATH))
        current_value = _conn.execute(
            "SELECT value FROM skin WHERE key='current';"
        ).fetchone()[0]
        _conn.close()

        assert current_value == "retro", (
            f"AC5 (negative): silent overwrite. Expected 'retro' preserved; "
            f"got {current_value!r}."
        )


# ---------------------------------------------------------------------------
# AP-2: empty idempotency key → 400 Bad Request
# ---------------------------------------------------------------------------
class TestEmptyIdempotencyKeyRejected:
    """AP-2: empty Idempotency-Key header → 400 (per ADR-0019 §Idempotency)."""

    def test_empty_idempotency_key_returns_400(self) -> None:
        """PUT with Idempotency-Key='' → 400."""
        resp = _client.put(
            "/api/skin",
            json={"skin": "light"},
            headers={"Idempotency-Key": ""},
        )
        assert resp.status_code == 400, (
            f"AP-2: empty Idempotency-Key MUST return 400 (per ADR-0019); "
            f"got {resp.status_code}: {resp.text!r}."
        )


# ---------------------------------------------------------------------------
# AP-7: idempotency-key collision across skin + history endpoints
# ---------------------------------------------------------------------------
class TestIdempotencyKeyCrossEndpointCollision:
    """AP-7: same key used on /api/skin and /api/history → 409 or 400 (no silent conflict)."""

    def test_same_key_on_skin_then_history_returns_error(self) -> None:
        """PUT /api/skin K1 + POST /api/history K1 → second request must error explicitly."""
        pytest.skip(
            "Cross-endpoint idempotency scope test depends on /api/history "
            "contract (STORY-007). Defer until both impls land. TDD red: "
            "see test_skin_idempotency.py TC-8/TC-9 for per-endpoint cases."
        )
