# Test Plan: STORY-S21-002 — LICENSE File (MIT, parameterized copyright)

> **Status:** RED-first contract shipped via `scripts/tests/d074-license-check.sh` (5/5 TCs FAIL pre-impl per ADR-0044).
> **Sprint:** 21, Epic 1 (Template Repository Structure), Wave 1 (Day 1-3 foundation).
> **Lane:** Agent-claimed per `agent:tester` label (Issue #113 labels > body doctrine — body says "developer-self" but label says agent:tester).
> **Branch:** `feat/story-631-tests`
> **Draft PR:** TBD (post-d074 + this plan commit)
> **Closes:** #631
> **Sister-pattern:** d073 (S21-001 template-flag — same story batch, same week)

## Scope

- **In scope:**
  - `LICENSE` file presence + content at repo root
  - MIT license marker text correctness
  - Parameterized copyright line format (per AC1: `Copyright (c) {{YEAR}} {{HUMAN_OWNER_NAME}}`)
  - `README.md` License section markdown reference to LICENSE file
  - GitHub UI sidebar detection via `/license` REST API
- **Out of scope:**
  - Dual-license, CLA, per-file license headers (Issue #631 §Out of scope)
  - License-text prose correctness beyond MIT marker substring match
  - LICENSE rendering at `gh repo create --template` instantiation time (covered by S21-005 init script + d070-template-render)

## Test Cases

### TC1: LICENSE File Exists at Repo Root

- **Setup:** Clean clone of AtilCalculator repo at any post-merge SHA
- **Steps:**
  1. `ls LICENSE*` from repo root
  2. Confirm a file named exactly `LICENSE` (case-sensitive per Linux fs convention)
- **Expected:** File exists, readable, non-empty
- **Pre-impl state (RED):** File absent — TC1 FAIL
- **Post-impl state (GREEN):** TC1 PASS

### TC2: LICENSE Contains MIT Marker Text

- **Setup:** TC1 PASS (LICENSE file exists)
- **Steps:**
  1. `grep -F "Permission is hereby granted, free of charge" LICENSE`
  2. Confirm substring found (case-sensitive)
- **Expected:** MIT grant clause substring present (the operative "you can do anything" sentence of MIT license)
- **Pre-impl state (RED):** LICENSE missing — TC2 cascade FAIL
- **Post-impl state (GREEN):** TC2 PASS

### TC3: LICENSE Copyright Line Parameterized

- **Setup:** TC1 PASS (LICENSE file exists)
- **Steps:**
  1. `grep -E 'Copyright \(c\) (?:\{\{YEAR\}\}|[0-9]{4}) (?:\{\{HUMAN_OWNER_NAME\}\}|[A-Za-z ._-]+)' LICENSE`
  2. Confirm regex match
- **Expected:** Copyright line present, matching AC1 format. The regex accepts EITHER:
  - The unrendered template form `Copyright (c) {{YEAR}} {{HUMAN_OWNER_NAME}}` (placeholders intact for `dev-studio-init.sh` to substitute), OR
  - The substituted form `Copyright (c) 2026 Atil Can` (already rendered for direct repo use)
- **Pre-impl state (RED):** LICENSE missing — TC3 cascade FAIL
- **Post-impl state (GREEN):** TC3 PASS

### TC4: README.md "License" Section References LICENSE File

- **Setup:** README.md exists at root
- **Steps:**
  1. Confirm `## License` heading exists (case-insensitive grep)
  2. Confirm a markdown link to LICENSE file exists in/around that section: pattern `\[.*[Ll]icense.*\]\(.*LICENSE.*\)`
- **Expected:** Per AC3, a markdown link like `[MIT License](LICENSE)` (or `[MIT License](./LICENSE)`) sits in or near the License section
- **Pre-impl state (RED):** README.md has `## License` heading but the body says "LICENSE file is TBD" — no markdown reference link exists → TC4 FAIL
- **Post-impl state (GREEN):** TC4 PASS

### TC5: GitHub UI Sidebar License Detection (AC2)

- **Setup:** Live GH API access via `gh` CLI authenticated, or `curl` with `GITHUB_TOKEN`
- **Steps:**
  1. `gh api repos/atilcan65/AtilCalculator/license` (or curl fallback)
  2. Parse `.license.spdx_id` from JSON response
  3. Confirm `spdx_id == "MIT"`
- **Expected:** Per AC2, GitHub's UI sidebar shows "MIT License" — this is the machine-readable equivalent (GH detects LICENSE files automatically)
- **Pre-impl state (RED):** API returns HTTP 404 `{"message":"Not Found"}` — LICENSE file missing on origin → TC5 FAIL
- **Post-impl state (GREEN):** TC5 PASS, `spdx_id = "MIT"`

## Adversarial Probes

- **File naming case-sensitivity:** What if dev writes `license` (lowercase) instead of `LICENSE`? GH detects both, but Linux fs convention + AC1 say `LICENSE`. d074 only checks `LICENSE` (per AC1 verbatim) — flag for dev to confirm case.
- **LICENSE in subdirectory:** What if LICENSE is at `docs/LICENSE` instead of root? GH won't auto-detect. AC1 says "at root" — d074 enforces root path.
- **Copyright rendered vs unrendered:** Per TC3 regex, both forms accepted. If dev ships rendered form (e.g., `Copyright (c) 2026 Atil Can`), then `dev-studio-init.sh` won't substitute → sister d070 catches this. If dev ships unrendered form (`{{YEAR}} {{HUMAN_OWNER_NAME}}`), GH sidebar still shows MIT (AC2 OK) but template instantiation matters → d070 catches.
- **TEMPLATE-README.md vs README.md:** Issue #631 AC3 says `TEMPLATE-README.md`. ADR-0001 §1 says AtilCalculator IS the template (no rename). d074 TC4 checks `README.md` (current file) — flag as **Q6** for arch.
- **Multiple LICENSE files (LICENSE + LICENSE.md):** GH prefers `LICENSE` over `LICENSE.md`. d074 only checks `LICENSE` to match AC1 verbatim.
- **GH API rate limit:** TC5 uses `gh` (auto-handles auth) with curl fallback. If both fail (no token, rate-limited), TC5 FAIL with clear diagnostic. Not a silent skip.
- **SPDX vs license name:** TC5 checks `spdx_id` not `name`. Some legacy LICENSE files use non-SPDX formats (e.g., "Expat" instead of "MIT"). The canonical MIT text always gets SPDX "MIT" via GH's detector.

## Performance Concerns

- **TC5 latency:** `gh api` typically <2s. No performance concern for self-test mode (5 TCs total <5s).
- **TC1-TC4 latency:** filesystem ops, <100ms each.
- **No N+1 / DB concerns** — pure filesystem + REST API check.

## Regression Risk

- **Touches README.md** — risks accidental rewrite of other sections. Dev must preserve §Prerequisites, §Installation, §License, etc. d074 only greps for License section; doesn't validate other sections.
- **pyproject.toml `license = { text = "MIT" }` already exists** — partial license signal. Dev must NOT remove this; it's complementary to the LICENSE file. (GH uses BOTH signals but file wins for sidebar.)
- **CHANGELOG.md** — if dev updates, follow Keep-a-Changelog format. Not directly tested by d074 but reviewer should check.
- **Docs/ folder** — Sprint 21 plan.md (PR #626, sha a5e0942) currently in tree. d074 doesn't touch docs/, no risk.

## Dependency Graph

- **Upstream:** none (LICENSE is Wave 1 foundation per Sprint 21 plan).
- **Downstream:**
  - S21-019 (README references LICENSE — sister d-test expected) — TC4 validates AC3 cross-ref.
  - S21-017 (dev-studio-init.sh — sister d070-template-render) — TC3 copyright line is the init script's substitution target. d070 TC1 validates init script renders {{YEAR}} and {{HUMAN_OWNER_NAME}} correctly.

## Open Questions for Arch + Dev (joint sizing per ADR-0021)

- **Q1 (RESOLVED by arch verdict 2026-06-29 cmt 4828620679):** License choice = **MIT** ✅
- **Q2 (RESOLVED by arch 2026-06-29):** Copyright = **unrendered** `{{YEAR}} {{HUMAN_OWNER_NAME}}` ✅ (matches ADR-0001 §2 placeholder parameterization pattern, sister d070 validates init script substitution)
- **Q3 (RESOLVED by arch 2026-06-29):** Owner name = **"Atil Can"** ✅ (display name in LICENSE copyright line, SPDX legal readability convention)
- **Q4 (RESOLVED by arch 2026-06-29):** File name = **`LICENSE`** (no extension) ✅ (GitHub convention + Issue #631 AC1 verbatim)
- **Q5 (RESOLVED by arch 2026-06-29):** Location = **AtilCalculator repo root** ✅ (per ADR-0001 §1 — AtilCalculator IS the template)
- **Q6 (RESOLVED by PM 2026-06-29):** Canonical = Issue #631 AC3 verbatim → target file = `TEMPLATE-README.md`. proposed-scope.md L76 amendment pending in PM working tree (PM lane). TC4 amended in commit `f3c4646` on `feat/story-631-tests`. Pre-impl RED state for new TC4: TEMPLATE-README.md has no `## License` section (file exists from S21-019 sister work, License section absent). Post-impl GREEN: TC4 expects `## License` heading + `[MIT License](LICENSE)` markdown link in TEMPLATE-README.md.

## Acceptance Criteria Mapping

| AC | d074 TC | Status (pre-impl) | Status (post-impl) |
|----|---------|-------------------|---------------------|
| AC1 (LICENSE at root + MIT + parameterized copyright) | TC1, TC2, TC3 | 3/3 FAIL (RED) | 3/3 PASS (GREEN) |
| AC2 (GH UI sidebar shows MIT License) | TC5 | FAIL (RED) | PASS (GREEN) |
| AC3 (TEMPLATE-README License section references LICENSE) | TC4 | FAIL (RED, current README.md not TEMPLATE-README.md) | PASS (GREEN, pending Q6 resolution) |

## Self-test invocation

```bash
bash scripts/tests/d074-license-check.sh --self-test
```

**Pre-impl expected output (RED):** 5/5 TCs FAIL, exit code 1.
**Post-impl expected output (GREEN):** 5/5 TCs PASS, exit code 0.

## Sister-pattern lineage (ADR-0049 d-test family)

- **d058** (Issue #505 ADR-0038 §Work-Stream Awareness impl)
- **d061** (RETRO-009 §3 post-squash label hygiene)
- **d062** (Issue #552 AC2 watcher patch dual mechanism)
- **d063** (RETRO-011 §1 stale-cc deadlock-breaker)
- **d064** (ADR-0059 §1 cluster-squash batch-lag detection)
- **d065** (ADR-0033 dual-channel enforcement — direct sister, same week)
- **d066** (WIP cap filter)
- **d067** (proactive scan per-role overflow)
- **d068** (cluster-lag workflow wiring)
- **d069** (Issue #552 AC2 + cross-validate)
- **d070** (S21-018 template-render — sister story, downstreams d074)
- **d073** (S21-001 template-flag — direct sister, same story batch, same PR-day)
- **d074** (S21-002 LICENSE File — this test, shipped via PR draft)

— @tester, 2026-06-29 (Sprint 21 P1 d-test suite expansion, ADR-0044 RED-first)