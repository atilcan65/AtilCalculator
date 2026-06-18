"""AC11: CHANGELOG.md [Unreleased] → Added entry for STORY-003a.

The implementer must add a bullet under ``[Unreleased]`` → ``### Added``
mentioning STORY-003a (or the web shell, or the 3 components — wording is
the implementer's choice, but it must be there).
"""

from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = REPO_ROOT / "CHANGELOG.md"


def test_changelog_has_unreleased_section():
    assert CHANGELOG.exists(), "CHANGELOG.md must exist at repo root"
    text = CHANGELOG.read_text()
    assert "## [Unreleased]" in text, "CHANGELOG.md must have an [Unreleased] section"


def test_changelog_has_added_subsection():
    text = CHANGELOG.read_text()
    # The Added subsection is required for tracking user-visible changes.
    assert "### Added" in text, "CHANGELOG.md must have an '### Added' subsection under [Unreleased]"


def test_changelog_mentions_story_003a():
    """The implementer's bullet must mention STORY-003a (or the web shell)."""
    text = CHANGELOG.read_text()
    # Try multiple phrasings the implementer may have used.
    needles = ["STORY-003a", "Story-003a", "story-003a", "web shell", "Web shell", "STORY 003a"]
    found = [n for n in needles if n in text]
    assert found, (
        "CHANGELOG.md [Unreleased] → Added must mention STORY-003a "
        "(or web shell). Acceptable needles: " + ", ".join(needles)
    )
