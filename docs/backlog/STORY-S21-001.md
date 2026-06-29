# STORY-S21-001: Template Flag + "Use this template" Button

> **PM draft, Sprint 21.** Example story file (one of 25). Other stories follow same template, authored in `STORY-MAP.md`.

---

## User Story

As a **solo developer / founder (P1)**,
I want **the template repo to have `is_template=true`**,
So that **GitHub UI shows "Use this template" button and `gh repo create --template` works**.

---

## Why now

Without this flag, no one can clone from template. This is the FIRST blocker for all downstream template usage. Without template flag, S21-002..S25 are unreachable for end users.

---

## Acceptance Criteria

- **AC1** — GIVEN a fresh template repo WHEN owner runs `gh api -X PATCH repos/<owner>/dev-studio-template -f is_template=true` THEN exit code 0 AND `is_template: true` in repo metadata.
- **AC2** — GIVEN template flag set WHEN user visits repo homepage on github.com THEN "Use this template" green button is visible.
- **AC3** — GIVEN template flag set WHEN user runs `gh repo create test-clone --template <owner>/dev-studio-template --clone` THEN new repo is created with template contents.

---

## Out of scope

- Custom template description, social preview image (deferred to Sprint 22+).
- Multiple template variants (Sprint 23+ candidate).

---

## Open questions

- [ ] Template repo name (Q2 in OPEN-QUESTIONS.md) — owner decides.
- [ ] Visibility default (Q3 in OPEN-QUESTIONS.md) — affects whether `gh repo create --template` defaults to `--public`.

---

## Mockups / references

N/A (config change, no UI mockup).

---

## Dependencies

- **Upstream:** none.
- **Downstream:** All other Sprint 21 stories depend on template flag being set (template must exist before cloning).

---

## Metrics of success

- **Leading:** `gh api repos/<owner>/dev-studio-template | jq .is_template` returns `true` within 24h of story merge.
- **Lagging:** First external clone via `--template` flag succeeds (S21-023 fresh-clone validation captures this).

---

## Sizing

- **Hint:** 1 point (config change).
- **Final size:** TBD by architect + developer + tester joint sizing per ADR-0021.

---

## Lane

- **Author:** developer (config change)
- **Reviewer:** architect (9-Lens per ADR-0045)
- **Tester:** developer-self (no test, just config verification)
- **PM:** @product-manager (story author)

---

**Drafted by:** @product-manager
**Date:** 2026-06-29
**Status:** DRAFT (final size + AC acceptance pending joint sizing)