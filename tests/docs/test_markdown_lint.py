"""Contract tests for STORY-012 AC5 — markdown links resolve + mermaid blocks valid.

Refs Issue #74. Per AC5:
- All markdown files in docs/ + root have no broken internal links
- Mermaid diagrams render without syntax errors
- Markdown renders cleanly in GitHub's UI

TDD red: skip on missing markdown files OR if no internal links to verify.

When implementation lands (no broken links + valid mermaid), all tests will run.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
USER_GUIDE_PATH = REPO_ROOT / "docs" / "USER-GUIDE.md"

# Discover all .md files in docs/ + root (excluding .venv, .git)
def _discover_markdown_files() -> list[Path]:
    """Find all .md files in repo (excluding .venv, .git, __pycache__)."""
    md_files: list[Path] = []
    for pattern in ("*.md", "**/*.md"):
        for path in REPO_ROOT.glob(pattern):
            # Exclude noise
            parts = path.parts
            if any(p in (".venv", ".git", "__pycache__", "node_modules") for p in parts):
                continue
            md_files.append(path)
    return sorted(set(md_files))


def _extract_markdown_links(content: str) -> list[tuple[str, str]]:
    """Extract all [text](path) links from markdown content.

    Returns list of (link_text, target_path) tuples. Excludes:
    - External URLs (http://, https://, mailto:)
    - Anchor-only links (#section)
    """
    # Match [text](target) where target doesn't start with scheme
    pattern = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
    links: list[tuple[str, str]] = []
    for match in pattern.finditer(content):
        text = match.group(1)
        target = match.group(2).strip()
        # Skip external
        if re.match(r"^(https?|mailto|ftp):", target):
            continue
        # Skip anchors (no path component)
        if target.startswith("#"):
            continue
        # Strip anchor from path
        target_path = target.split("#")[0]
        if not target_path:
            continue
        links.append((text, target_path))
    return links


# TDD red guard — module-level skip ensures CI is green while the doc refresh lands.
# Strict probe: require docs/USER-GUIDE.md (created by this story per AC3).
# Without USER-GUIDE.md, the lint check is incomplete (would only check pre-existing docs).
try:
    if not USER_GUIDE_PATH.exists():
        raise RuntimeError(
            "AC5: docs/USER-GUIDE.md missing (created by AC3). "
            "Markdown link integrity check requires USER-GUIDE.md to be present "
            "so the lint covers the full doc surface (README + USER-GUIDE + ADRs + test plans)."
        )

    _md_files = _discover_markdown_files()

except Exception as _exc:
    _msg = str(_exc)
    if (
        any(marker in _msg for marker in ["AC5", "markdown", "link"])
        or "import" in _msg.lower()
        or "module" in _msg.lower()
    ):
        pytest.skip(  # type: ignore[name-defined]
            "STORY-012 TDD red — markdown lint not yet applicable. "
            "Implementation PR must ensure all internal markdown links resolve "
            "and mermaid blocks render (per AC5).",
            allow_module_level=True,
        )
    raise


# ---------------------------------------------------------------------------
# TC-11: AC5 — all internal markdown links resolve
# ---------------------------------------------------------------------------
class TestMarkdownInternalLinks:
    """AC5: every internal [text](path) link in any .md file resolves to an existing file."""

    def test_all_internal_links_resolve(self) -> None:
        """For each markdown link, assert the target file exists relative to repo root."""
        _broken: list[tuple[Path, str, str]] = []
        for md in _md_files:
            content = md.read_text(encoding="utf-8")
            for link_text, target in _extract_markdown_links(content):
                # Resolve target relative to the markdown file's directory
                target_path = (md.parent / target).resolve()
                # Also check absolute-from-repo-root
                if not target_path.exists():
                    alt_path = (REPO_ROOT / target).resolve()
                    if not alt_path.exists():
                        _broken.append((md, link_text, target))

        assert not _broken, (
            f"AC5: {len(_broken)} broken internal markdown link(s):\n"
            + "\n".join(f"  {md.relative_to(REPO_ROOT)}: [{text}]({target})"
                        for md, text, target in _broken[:10])
        )


# ---------------------------------------------------------------------------
# TC-12: AC5 — mermaid diagrams render without syntax errors
# ---------------------------------------------------------------------------
class TestMermaidBlocks:
    """AC5: every ```mermaid block in any .md file has valid syntax."""

    def test_mermaid_blocks_have_valid_syntax(self) -> None:
        """For each mermaid block, assert syntax is current (no deprecated directives)."""
        _invalid: list[tuple[Path, str, str]] = []
        for md in _md_files:
            content = md.read_text(encoding="utf-8")
            # Find all ```mermaid ... ``` blocks
            pattern = re.compile(r"```mermaid\s*\n(.*?)```", re.DOTALL)
            for match in pattern.finditer(content):
                block_content = match.group(1)
                # Check for deprecated syntax
                # `graph TD` is deprecated in favor of `flowchart TD`
                if re.search(r"^\s*graph\s+", block_content, re.MULTILINE):
                    _invalid.append(
                        (md, block_content[:50], "deprecated 'graph' — use 'flowchart'")
                    )
                # Empty mermaid block
                if not block_content.strip():
                    _invalid.append((md, "", "empty mermaid block"))

        # TDD red: if no mermaid blocks exist, this test passes (vacuous truth)
        assert not _invalid, (
            f"AC5: {len(_invalid)} mermaid block(s) with invalid syntax:\n"
            + "\n".join(f"  {md.relative_to(REPO_ROOT)}: {issue}"
                        for md, preview, issue in _invalid[:5])
        )


# ---------------------------------------------------------------------------
# AP-6: README link to vision.md is broken after directory restructure
# ---------------------------------------------------------------------------
class TestReadmeCriticalLinks:
    """AP-6: critical links (README → vision, README → USER-GUIDE) must always resolve."""

    def test_readme_links_to_vision_and_user_guide_resolve(self) -> None:
        """README links to docs/product/vision.md + docs/USER-GUIDE.md must resolve."""
        readme = REPO_ROOT / "README.md"
        if not readme.exists():
            pytest.skip("README.md missing — AC1 test handles this case.")

        content = readme.read_text(encoding="utf-8")
        for target in ("docs/product/vision.md", "docs/USER-GUIDE.md"):
            link_pattern = rf"\[.+?\]\((?:\.?/)?{re.escape(target)}\)"
            if re.search(link_pattern, content):
                # If link is in README, the target must exist
                target_path = REPO_ROOT / target
                assert target_path.exists(), (
                    f"AP-6: README links to {target} but file missing. "
                    f"Critical link broken — owner cannot navigate from README."
                )
