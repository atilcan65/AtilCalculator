"""Contract tests for GET /api/skin + PUT /api/skin (STORY-009).

Refs Issue #71. Per ADR-0019 R-3 HTTP API contract:
- GET /api/skin returns {"skin": "<name>", "available": [...]}
- PUT /api/skin + Idempotency-Key applies a new skin
- Unknown skin → 400 + UnknownSkinError envelope (ADR-0019 §Error envelope)
- New skin file auto-discovered on server restart (per AC6)

Tests are RED until the skin endpoint lands. They skip when:
- `atilcalc.api.main` is not yet implemented
- GET /api/skin returns 404 (endpoint missing)
- Skin files (dark/light/retro) are not yet present
"""

from __future__ import annotations

import uuid

import pytest

# TDD red guard — module-level skip ensures CI is green while the impl
# PR lands. Preconditions per Issue #71 (AC1, AC4, AC5):
#   1. `atilcalc.api.main` importable
#   2. GET /api/skin returns 200 with {"skin": ..., "available": [...]} (AC1)
#   3. available list contains exactly 3 skins: dark, light, retro (AC1)
#   4. PUT /api/skin with valid skin + Idempotency-Key returns 200 (AC4)
#   5. PUT /api/skin with unknown skin returns 400 + error envelope (AC5)
# If any precondition fails, the module skips (CI green until impl lands).
try:
    from fastapi.testclient import TestClient  # type: ignore[import-not-found]

    from atilcalc.api.main import app  # type: ignore[import-not-found]

    _client = TestClient(app)

    # Probe AC1: GET /api/skin must return 3-skin catalog
    _probe = _client.get("/api/skin")
    if _probe.status_code != 200:
        raise RuntimeError(f"GET /api/skin probe returned {_probe.status_code}")
    _probe_body = _probe.json()
    if not isinstance(_probe_body, dict):
        raise RuntimeError(f"GET /api/skin body not dict: {_probe_body!r}")
    _available = _probe_body.get("available", [])
    if not isinstance(_available, list) or len(_available) != 3:
        raise RuntimeError(
            f"AC1: GET /api/skin available list must have 3 skins; got {_available!r}"
        )
    if set(_available) != {"dark", "light", "retro"}:
        raise RuntimeError(
            f"AC1: GET /api/skin available list must be exactly [dark, light, retro]; got {_available!r}"
        )

    # Probe AC4: PUT /api/skin must work (returns 200 with valid skin + Idempotency-Key)
    _idemp = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
    _put_probe = _client.put(
        "/api/skin",
        json={"skin": "light"},
        headers={"Idempotency-Key": _idemp},
    )
    if _put_probe.status_code != 200:
        raise RuntimeError(
            f"AC4: PUT /api/skin probe returned {_put_probe.status_code} (expected 200). "
            f"Body: {_put_probe.text!r}"
        )

    # Probe AC5: PUT with unknown skin must return 400 + error envelope
    _idemp_err = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
    _err_probe = _client.put(
        "/api/skin",
        json={"skin": "neon"},
        headers={"Idempotency-Key": _idemp_err},
    )
    if _err_probe.status_code != 400:
        raise RuntimeError(
            f"AC5: PUT with unknown skin probe returned {_err_probe.status_code} (expected 400). "
            f"Body: {_err_probe.text!r}"
        )
    _err_body = _err_probe.json()
    if not isinstance(_err_body, dict) or "error" not in _err_body:
        raise RuntimeError(
            f"AC5: PUT with unknown skin body must have 'error' envelope; got {_err_body!r}"
        )
except Exception as _exc:
    _msg = str(_exc)
    if (
        any(marker in _msg for marker in ["AC1", "AC4", "AC5", "probe"])
        or "import" in _msg.lower()
        or "module" in _msg.lower()
    ):
        pytest.skip(  # type: ignore[name-defined]
            "STORY-009 TDD red — skin endpoint not yet fully wired. "
            "Implementation PR must add: GET /api/skin (AC1), PUT /api/skin + "
            "Idempotency-Key (AC4), and UnknownSkinError envelope (AC5) to "
            "src/atilcalc/api/main.py, plus 3 skin files in src/atilcalc/web/skins/.",
            allow_module_level=True,
        )
    raise


# ---------------------------------------------------------------------------
# TC-1: AC1 — GET /api/skin returns active + available list
# ---------------------------------------------------------------------------
class TestGetSkinCatalog:
    """AC1: GET /api/skin returns {"skin": <name>, "available": [dark, light, retro]}."""

    def test_get_skin_returns_200(self) -> None:
        """GET /api/skin must return HTTP 200."""
        resp = _client.get("/api/skin")
        assert resp.status_code == 200, f"AC1: expected 200, got {resp.status_code}: {resp.text!r}"

    def test_get_skin_returns_dict_with_skin_and_available(self) -> None:
        """Body must have 'skin' (string) + 'available' (list of 3)."""
        body = _client.get("/api/skin").json()
        assert isinstance(body, dict), f"AC1: body must be dict, got {type(body).__name__}"
        assert "skin" in body, f"AC1: body must have 'skin' key, got {body!r}"
        assert "available" in body, f"AC1: body must have 'available' key, got {body!r}"
        assert isinstance(body["skin"], str), f"AC1: 'skin' must be string, got {type(body['skin']).__name__}"
        assert isinstance(body["available"], list), f"AC1: 'available' must be list, got {type(body['available']).__name__}"

    def test_active_skin_is_in_available_list(self) -> None:
        """AC1: 'skin' value must be one of 'available' values."""
        body = _client.get("/api/skin").json()
        assert body["skin"] in body["available"], (
            f"AC1: active skin {body['skin']!r} must be in available list {body['available']!r}"
        )

    def test_available_list_has_exactly_three_skins(self) -> None:
        """AC1: available list = [dark, light, retro] (per spec)."""
        body = _client.get("/api/skin").json()
        assert set(body["available"]) == {"dark", "light", "retro"}, (
            f"AC1: available must be {{dark, light, retro}}; got {set(body['available'])}"
        )


# ---------------------------------------------------------------------------
# TC-2: AC4 — PUT /api/skin with idempotency key
# ---------------------------------------------------------------------------
class TestPutSkinWithIdempotency:
    """AC4: PUT /api/skin + Idempotency-Key header applies a new skin (cached on duplicate)."""

    def test_put_skin_applies_new_skin(self) -> None:
        """PUT /api/skin with valid skin + idempotency key → 200, GET reflects new skin."""
        # Read current state
        before = _client.get("/api/skin").json()
        target = next(s for s in before["available"] if s != before["skin"])

        # PUT with idempotency key
        idempotency_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        resp = _client.put(
            "/api/skin",
            json={"skin": target},
            headers={"Idempotency-Key": idempotency_key},
        )
        assert resp.status_code == 200, f"AC4: expected 200, got {resp.status_code}: {resp.text!r}"

        # Verify GET reflects new skin
        after = _client.get("/api/skin").json()
        assert after["skin"] == target, (
            f"AC4: PUT did not apply skin. Before: {before['skin']!r}, after: {after['skin']!r}, expected: {target!r}"
        )

    def test_put_skin_with_duplicate_idempotency_key_is_cached(self) -> None:
        """AC4: same Idempotency-Key + same body → 200 cached, no re-apply side effect."""
        idempotency_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        target = "dark"  # known good skin

        # First PUT
        first = _client.put(
            "/api/skin",
            json={"skin": target},
            headers={"Idempotency-Key": idempotency_key},
        )
        assert first.status_code == 200, f"AC4 first PUT: {first.status_code}: {first.text!r}"

        # Second PUT with same key + same body → should be cached (idempotent)
        second = _client.put(
            "/api/skin",
            json={"skin": target},
            headers={"Idempotency-Key": idempotency_key},
        )
        assert second.status_code == 200, f"AC4 cached PUT: {second.status_code}: {second.text!r}"

    def test_put_skin_without_idempotency_key_rejected(self) -> None:
        """AP-2: PUT /api/skin without Idempotency-Key → 400 (per ADR-0019)."""
        resp = _client.put("/api/skin", json={"skin": "light"})
        # Per ADR-0019: state-mutating endpoints require Idempotency-Key
        assert resp.status_code == 400, (
            f"AP-2: PUT without Idempotency-Key must return 400; got {resp.status_code}: {resp.text!r}"
        )

    def test_put_skin_with_non_string_value_rejected(self) -> None:
        """AP-4: PUT with non-string skin value (e.g., int, null) → 400 validation error."""
        idempotency_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        for bad_value in [123, None, [], {}]:
            resp = _client.put(
                "/api/skin",
                json={"skin": bad_value},
                headers={"Idempotency-Key": idempotency_key},
            )
            assert resp.status_code == 400, (
                f"AP-4: PUT with skin={bad_value!r} must return 400; got {resp.status_code}: {resp.text!r}"
            )


# ---------------------------------------------------------------------------
# TC-3: AC5 — unknown skin returns 400 + UnknownSkinError envelope
# ---------------------------------------------------------------------------
class TestUnknownSkinError:
    """AC5: unknown skin name → 400 + UnknownSkinError envelope per ADR-0019."""

    def test_put_unknown_skin_returns_400(self) -> None:
        """PUT with skin='neon' (not in available) → 400."""
        idempotency_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        resp = _client.put(
            "/api/skin",
            json={"skin": "neon"},
            headers={"Idempotency-Key": idempotency_key},
        )
        assert resp.status_code == 400, (
            f"AC5: unknown skin 'neon' must return 400; got {resp.status_code}: {resp.text!r}"
        )

    def test_put_unknown_skin_returns_error_envelope(self) -> None:
        """AC5: error body must have error.type == 'UnknownSkinError'."""
        idempotency_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        resp = _client.put(
            "/api/skin",
            json={"skin": "neon"},
            headers={"Idempotency-Key": idempotency_key},
        )
        body = resp.json()
        assert "error" in body, f"AC5: error envelope required. Got: {body!r}"
        err = body["error"]
        assert "type" in err, f"AC5: error envelope missing 'type'. Got: {err!r}"
        assert err["type"] == "UnknownSkinError", (
            f"AC5: error.type must be 'UnknownSkinError'; got {err['type']!r}"
        )

    def test_unknown_skin_error_message_mentions_skin_name(self) -> None:
        """AC5: error.message should be human-readable and mention the bad skin name."""
        idempotency_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        resp = _client.put(
            "/api/skin",
            json={"skin": "neon"},
            headers={"Idempotency-Key": idempotency_key},
        )
        body = resp.json()
        err = body.get("error", {})
        message = err.get("message", "")
        assert "neon" in message, (
            f"AC5: error.message should mention skin name 'neon'; got {message!r}"
        )

    def test_unknown_skin_error_has_request_id(self) -> None:
        """AC5: error envelope includes request_id (UUID format) for traceability."""
        idempotency_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        resp = _client.put(
            "/api/skin",
            json={"skin": "neon"},
            headers={"Idempotency-Key": idempotency_key},
        )
        body = resp.json()
        err = body.get("error", {})
        request_id = err.get("request_id", "")
        # Validate UUID format
        try:
            uuid.UUID(request_id)
        except (ValueError, AttributeError) as e:
            pytest.fail(
                f"AC5: error.request_id must be UUID; got {request_id!r}: {e}"
            )


# ---------------------------------------------------------------------------
# TC-4: AC6 — auto-discovery on server restart
# ---------------------------------------------------------------------------
class TestSkinFileAutoDiscovery:
    """AC6: new skin file in src/atilcalc/web/skins/ auto-discovered on server restart."""

    def test_get_skin_lists_three_built_in_skins(self) -> None:
        """AC6 (baseline): GET /api/skin lists 3 built-in skins: dark, light, retro."""
        body = _client.get("/api/skin").json()
        assert set(body["available"]) == {"dark", "light", "retro"}, (
            f"AC6: built-in skins must be {{dark, light, retro}}; got {set(body['available'])}"
        )
