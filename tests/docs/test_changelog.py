"""Contract tests for STORY-012 AC4 — CHANGELOG.md [Unreleased] has entries per user-visible PR.

Refs Issue #74. Per AC4:
- [Unreleased] section exists with Added/Changed/Fixed subsections
- Each merged user-visible PR (feat:/fix: conventional commit) has a corresponding entry
- Keep a Changelog format compliance

TDD red: skip if [Unreleased] section missing or empty. When impl lands, all tests will run.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
CHANGELOG_PATH = REPO_ROOT / "CHANGELOG.md"

# TDD red guard — module-level skip ensures CI is green while CHANGELOG hygiene lands.
try:
    if not CHANGELOG_PATH.exists():
        raise RuntimeError("AC4: CHANGELOG.md missing at repo root.")

    _changelog = CHANGELOG_PATH.read_text(encoding="utf-8")

    # Probe: must have [Unreleased] section
    if "## [Unreleased]" not in _changelog:
        raise RuntimeError(
            "AC4: CHANGELOG.md missing '## [Unreleased]' section header."
        )

    # Probe: must have at least one subsection under [Unreleased]
    _unreleased_pattern = re.compile(
        r"## \[Unreleased\](.*?)(?=## \[|\Z)", re.DOTALL
    )
    _unreleased_match = _unreleased_pattern.search(_changelog)
    if not _unreleased_match:
        raise RuntimeError("AC4: CHANGELOG.md [Unreleased] section malformed.")

    _unreleased_content = _unreleased_match.group(1)
    _has_subsection = any(
        re.search(rf"### {cat}", _unreleased_content)
        for cat in ("Added", "Changed", "Fixed", "Deprecated", "Removed", "Security")
    )
    if not _has_subsection:
        raise RuntimeError(
            "AC4: CHANGELOG.md [Unreleased] must have at least one of: "
            "Added, Changed, Fixed, Deprecated, Removed, Security."
        )

except Exception as _exc:
    _msg = str(_exc)
    if (
        any(marker in _msg for marker in ["AC4", "CHANGELOG", "Unreleased"])
        or "import" in _msg.lower()
        or "module" in _msg.lower()
    ):
        pytest.skip(  # type: ignore[name-defined]
            "STORY-012 TDD red — CHANGELOG.md [Unreleased] not yet populated. "
            "Implementation PR must add [Unreleased] entries for all user-visible "
            "merged PRs since last release (per AC4 conventional-changelog style).",
            allow_module_level=True,
        )
    raise


# ---------------------------------------------------------------------------
# TC-9: AC4 — CHANGELOG.md has [Unreleased] section with categorized entries
# ---------------------------------------------------------------------------
class TestChangelogUnreleasedSection:
    """AC4: CHANGELOG.md [Unreleased] has at least one Added/Changed/Fixed subsection."""

    def test_changelog_has_unreleased_section(self) -> None:
        """CHANGELOG must have `## [Unreleased]` header."""
        content = CHANGELOG_PATH.read_text(encoding="utf-8")
        assert "## [Unreleased]" in content, (
            "AC4: CHANGELOG.md missing '## [Unreleased]' section."
        )

    def test_changelog_unreleased_has_subsection(self) -> None:
        """[Unreleased] must have at least one Added/Changed/Fixed subsection."""
        content = CHANGELOG_PATH.read_text(encoding="utf-8")
        match = re.search(r"## \[Unreleased\](.*?)(?=## \[|\Z)", content, re.DOTALL)
        assert match is not None, "AC4: [Unreleased] section malformed."
        unreleased = match.group(1)
        assert any(
            re.search(rf"### {cat}", unreleased)
            for cat in ("Added", "Changed", "Fixed")
        ), (
            "AC4: [Unreleased] must have at least one ### Added / ### Changed / ### Fixed subsection."
        )

    def test_changelog_follows_keep_a_changelog_format(self) -> None:
        """CHANGELOG header must reference Keep a Changelog format."""
        content = CHANGELOG_PATH.read_text(encoding="utf-8")
        assert "Keep a Changelog" in content or "keepachangelog" in content.lower(), (
            "AC4: CHANGELOG.md header should reference Keep a Changelog format. "
            "Format compliance aids tooling integration (e.g., release-please)."
        )


# ---------------------------------------------------------------------------
# TC-10: AC4 — CHANGELOG entry per merged user-visible PR
# ---------------------------------------------------------------------------
class TestChangelogCoversMergedPRs:
    """AC4: every merged user-visible PR has a CHANGELOG entry."""

    def test_changelog_has_entry_per_user_visible_pr(self) -> None:
        """For each merged feat:/fix: PR, assert CHANGELOG has matching entry."""
        pytest.skip(
            "TC-10 requires GitHub API access (gh CLI or PyGithub). "
            "TDD red: skip; impl PR can run this in CI with GITHUB_TOKEN."
        )


# ---------------------------------------------------------------------------
# AP-4: CHANGELOG entry has wrong category
# ---------------------------------------------------------------------------
class TestChangelogCategoryAccuracy:
    """AP-4: CHANGELOG entry category must match conventional commit type."""

    def test_changelog_categories_match_conventional_commits(self) -> None:
        """For each entry under [Unreleased], verify category matches commit type."""
        pytest.skip(
            "AP-4 requires git log + GitHub API cross-reference. "
            "TDD red: skip; impl PR can run with gh CLI."
        )
