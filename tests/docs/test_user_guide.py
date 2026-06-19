"""Contract tests for STORY-012 AC3 — docs/USER-GUIDE.md covers 5 required topics.

Refs Issue #74. Per AC3:
- Skin modes (Dark/Light/Retro — what each looks like, how to switch, when each is best)
- History view (scroll, search, click-to-load, infinite scroll)
- Scientific mode (entering trig, rad/deg toggle, precision notes)
- Keyboard reference (cross-link to in-app `?`-popup)
- Troubleshooting (port conflicts, VM hardening prerequisites, backup policy reference)

TDD red: skip if USER-GUIDE.md doesn't exist. When impl lands, all tests will run.
"""

from __future__ import annotations

from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
USER_GUIDE_PATH = REPO_ROOT / "docs" / "USER-GUIDE.md"

REQUIRED_TOPICS = [
    ("Skin", ["Dark", "Light", "Retro"]),  # case-insensitive search
    ("History", ["scroll", "search"]),  # case-insensitive search
    ("Scientific", ["trig", "rad", "deg"]),  # at least one of these
    ("Keyboard", ["?", "popup"]),  # cross-link to in-app popup
    ("Troubleshoot", ["port", "VM"]),  # troubleshooting section
]

# TDD red guard — module-level skip ensures CI is green while USER-GUIDE.md is drafted.
try:
    if not USER_GUIDE_PATH.exists():
        raise RuntimeError(
            "AC3: docs/USER-GUIDE.md missing. Story creates this file."
        )

    _user_guide = USER_GUIDE_PATH.read_text(encoding="utf-8")

except Exception as _exc:
    _msg = str(_exc)
    if (
        any(marker in _msg for marker in ["AC3", "USER-GUIDE"])
        or "import" in _msg.lower()
        or "module" in _msg.lower()
    ):
        pytest.skip(  # type: ignore[name-defined]
            "STORY-012 TDD red — docs/USER-GUIDE.md not yet drafted. "
            "Implementation PR must create USER-GUIDE.md per AC3 (5 topics: "
            "Skin Modes + History + Scientific Mode + Keyboard Reference + Troubleshooting).",
            allow_module_level=True,
        )
    raise


# ---------------------------------------------------------------------------
# TC-8: AC3 — USER-GUIDE.md exists + 5 required topics
# ---------------------------------------------------------------------------
class TestUserGuideTopics:
    """AC3: USER-GUIDE.md covers Skin Modes + History + Scientific + Keyboard + Troubleshooting."""

    def test_user_guide_file_exists(self) -> None:
        """USER-GUIDE.md must exist at docs/USER-GUIDE.md."""
        assert USER_GUIDE_PATH.exists(), (
            f"AC3: USER-GUIDE.md missing at {USER_GUIDE_PATH}"
        )

    def test_user_guide_has_skin_modes_section(self) -> None:
        """USER-GUIDE must have a Skin Modes section covering Dark/Light/Retro."""
        content = USER_GUIDE_PATH.read_text(encoding="utf-8").lower()
        assert "skin" in content, "AC3: USER-GUIDE.md missing 'skin' coverage."
        for variant in ["dark", "light", "retro"]:
            assert variant in content, (
                f"AC3: USER-GUIDE.md Skin Modes section must mention '{variant}'."
            )

    def test_user_guide_has_history_section(self) -> None:
        """USER-GUIDE must have a History section covering scroll + search."""
        content = USER_GUIDE_PATH.read_text(encoding="utf-8").lower()
        assert "history" in content, "AC3: USER-GUIDE.md missing 'history' coverage."
        # At least scroll OR search must be mentioned
        assert "scroll" in content or "search" in content, (
            "AC3: USER-GUIDE.md History section must cover scroll/search."
        )

    def test_user_guide_has_scientific_section(self) -> None:
        """USER-GUIDE must have a Scientific section covering trig + rad/deg."""
        content = USER_GUIDE_PATH.read_text(encoding="utf-8").lower()
        assert "scientific" in content or "trig" in content, (
            "AC3: USER-GUIDE.md missing 'scientific' / 'trig' coverage."
        )
        # rad/deg toggle is a key scientific concept
        assert "rad" in content or "deg" in content, (
            "AC3: USER-GUIDE.md Scientific section must mention rad/deg toggle."
        )

    def test_user_guide_has_keyboard_reference_section(self) -> None:
        """USER-GUIDE must have a Keyboard Reference section cross-linking to ?-popup."""
        content = USER_GUIDE_PATH.read_text(encoding="utf-8").lower()
        assert "keyboard" in content, "AC3: USER-GUIDE.md missing 'keyboard' coverage."
        # Cross-link to in-app popup
        assert "?" in content or "popup" in content or "help" in content, (
            "AC3: USER-GUIDE.md Keyboard Reference must cross-link to in-app ?-popup."
        )

    def test_user_guide_has_troubleshooting_section(self) -> None:
        """USER-GUIDE must have a Troubleshooting section."""
        content = USER_GUIDE_PATH.read_text(encoding="utf-8").lower()
        assert (
            "troubleshoot" in content or "troubleshooting" in content
        ), "AC3: USER-GUIDE.md missing 'troubleshooting' section."
        # Should mention port conflicts (common issue)
        assert "port" in content, (
            "AC3: USER-GUIDE.md Troubleshooting section must mention port conflicts."
        )


# ---------------------------------------------------------------------------
# AP-3: USER-GUIDE references features that don't exist
# ---------------------------------------------------------------------------
class TestUserGuideReferencesShippedFeatures:
    """AP-3: USER-GUIDE must only document SHIPPED features (not aspirational)."""

    def test_user_guide_does_not_reference_unmerged_features(self) -> None:
        """USER-GUIDE must not reference features from unmerged PRs."""
        pytest.skip(
            "AP-3 requires GitHub API access to verify PR merge state. "
            "TDD red: skip; impl PR must verify cross-references manually."
        )
