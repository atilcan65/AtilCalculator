# d-test INDEX Cadence Doc + Sign-off Process — RETRO-009 §10 codification

> **Sister-pattern home:** RETRO-009 §10 (tester lane INDEX maintainer), ADR-0049 (d-test framework), ADR-0044 (RED-first TDD), ADR-0045 (9-Lens Review Checklist), ADR-0024 (verdict-by:<ts> schema).
> **Spec origin:** Issue #524 (Sprint 15 P2 #9 / STORY-023) AC1 (cadence doc) + AC2 (5-step sign-off process).
> **Purpose:** Codify WHEN to update `scripts/tests/INDEX.md` and HOW to sign off d-test additions, addressing the Sprint 14 P1 cluster drift where 4 d-tests (d054 + d055 + d056 + d058 per spec) were added without a centralized INDEX.md update cadence.
> **Closes:** Issue #524 AC1 + AC2 (AC3 + AC4 drift audit documented in §Drift audit below).

## §1 Cadence Rules

> **Origin:** RETRO-009 §10 codification, Sprint 14 P1 cluster observation.

### Rule 1 — Every d-test impl/add = INDEX.md update in same PR

- Sister-pattern: PR #511 (d058 CI integration) updated INDEX.md in the same PR as the workflow change.
- **Anti-pattern:** adding a d-test file (`scripts/tests/dNNN-*.sh`) without updating `scripts/tests/INDEX.md` in the same commit/PR. This creates drift between actual d-test files and the centralized registry.

### Rule 2 — Every d-test removal = INDEX.md entry removal in same PR

- If a d-test is deprecated or removed, the INDEX.md entry MUST be removed in the same PR.
- **Audit trail:** the PR's squash commit message should reference the d-test ID being removed + the reason.

### Rule 3 — INDEX.md reviewed quarterly by tester lane (Sprint planning ceremony)

- **Cadence:** every Sprint planning ceremony (currently 2-week sprints → ~6-7 ceremonies per quarter).
- **Reviewer:** tester lane (@tester agent, accountable to owner merge gate).
- **Deliverable:** drift audit table (see §Drift audit below) updated each ceremony; any drift fixes filed as separate issues/PRs.

## §2 5-Step Sign-off Process

> **Origin:** ADR-0044 RED-first TDD + ADR-0045 9-Lens Review Checklist + ADR-0024 verdict-by:<ts> schema.

| Step | Actor | Action | Sister-pattern |
|---|---|---|---|
| 1. Author | @developer | Authors d-test, runs locally, gets all TCs green | d058 sister-pattern |
| 2. Tester review | @tester | Reviews d-test via 9-Lens per ADR-0045 + RED-first verification (per ADR-0044) | PR #506 squash @ 226b546 |
| 3. Tester sign-off | @tester | Signs off via `tests-passed:<ts>` label (sister-pattern to ADR-0024 verdict-by:<ts>) | (process step, label schema in ADR-0024) |
| 4. Architect review | @architect | Final 9-Lens approval per ADR-0045 (sister-pattern to Sprint 14 P1 arch reviews) | PR #511 squash @ 70e33d7 |
| 5. Orchestrator merge + INDEX update | @orchestrator | Merges to main after human approval; verifies INDEX.md updated per Rule 1 | PR #511 close-out |

### §2.1 Sign-off label schema (proposed)

> **Status:** PROPOSED, sister-pattern to ADR-0024 verdict-by:<ts>. Requires ADR amendment (deferred to Sprint 16 per ADR-0024 amendment cadence).

```yaml
label_format: "tests-passed:<ISO-8601-timestamp>"
example: "tests-passed:2026-06-27T15:48:00Z"
applies_to: tester sign-off on d-test PRs
replaces: ad-hoc comment-based sign-off
```

### §2.2 Process variants (architect clarification per Issue #524 open questions)

- **5-step full** (default): applies to d-tests with new doctrine codification (sister-pattern d058). All 5 steps required.
- **3-step short** (routine sister-pattern): skips step 4 (architect review). Applies to d-tests that are sister-patterns of an already-shipped d-test (no new doctrine). Steps 1+2+3+5 (merge) only.

## §3 Drift Audit (AC3 + AC4 verification)

> **Generated:** 2026-06-27 by @tester as part of STORY-023 AC3 + AC4 verification.

### AC3 — Sprint 15 d-test entries (≥3 new)

| ID | Status | INDEX.md entry | PR | Note |
|---|---|---|---|---|
| **d059** | ❌ NOT in INDEX | MISSING | PR #523 (open, Issue #523 / STORY-022) | Will land when PR #523 merges |
| **d060** | ✅ in INDEX | ✅ entry present | PR #528 squash-gate ready | Story-016 §1 pre-push branch-base check |
| **d061** | ✅ in INDEX | ✅ entry present | PR #530 squash-gate ready (post-fix) | Story-017 §3 post-squash label hygiene |

**AC3 verdict:** ✅ PASS once d059 lands. Currently 2/3 (d060 + d061). d059 tracked via Issue #523 / PR #523.

### AC4 — Existing d-test entries verified

| ID | File on main | INDEX.md entry | Drift |
|---|---|---|---|
| d015 | ✅ `scripts/tests/d015-dev-idle-prevention.sh` | ✅ in INDEX | None |
| d031 | ✅ `scripts/tests/d031-claim-next-ready.sh` | ✅ in INDEX | None (header drift: docstring says "5 TCs", actual is 8 — separate issue) |
| **d046** | ✅ 3 files (collision!): `d046-expansion-adr-0044-literal-form.sh` + `d046-js-syntactic-check.sh` + `d046-peer-poke-canonical-parity.sh` | ❌ MISSING | **Major drift** — ID collision, no INDEX entry |
| **d048** | ✅ `scripts/tests/d048-adr-0012-status-ready-gating.sh` | ❌ MISSING | Drift |
| **d050b** | ✅ `scripts/tests/d050b-behavioral-workflow-test.sh` | ❌ MISSING | Drift |
| **d051** | ✅ `scripts/tests/d051-5-soul-dispatch-discipline.sh` | ❌ MISSING | Drift |
| d052 | ✅ `scripts/tests/d052-agent-watch-hardening.sh` | ✅ in INDEX | None |
| **d053** | ✅ `scripts/tests/d053-pre-merge-4-cat-verification.sh` | ❌ MISSING | Drift |
| d054 | ✅ `scripts/tests/d054-closes-anchor-strict-format.sh` | ✅ in INDEX | None |
| **d055** | ❌ MISSING (spec drift!) | ❌ MISSING | **Spec drift** — Issue #524 spec lists d055 as existing, but no d055 file on main |
| **d056** | ❌ MISSING (spec drift!) | ❌ MISSING | **Spec drift** — Issue #524 spec lists d056 as existing, but no d056 file on main |
| d058 | ✅ `scripts/tests/d058-claim-wip-workstream.sh` | ✅ in INDEX (ACTIVE section) | None |

**AC4 verdict:** 🔴 **DRIFT DETECTED** — 7 missing INDEX entries (d046/d048/d050b/d051/d053 + 2 spec drift d055/d056). Plus d046 ID collision (3 different impls sharing the same d-test ID).

### Drift fix recommendations (out of scope for STORY-023 AC1+AC2)

1. **Add 5 missing INDEX entries** for d046/d048/d050b/d051/d053 (separate PR, dev lane or tester lane).
2. **Resolve d046 ID collision** — rename 2 of the 3 d046 files to d046a/d046b OR consolidate into one canonical d046 (architect decision required).
3. **Resolve d055/d056 spec drift** — either create the missing files (developer lane) OR update the spec to remove d055/d056 from the 10-list (PM lane).
4. **d031 docstring drift** — separate issue: header says "5 TCs" but actual is 8. Tracked in Issue #520 (STORY-019) attempt #1.

## §4 Open Questions (carry forward)

From Issue #524 open questions section:

- [x] **PM decision (OQ#1)**: move cadence doc to `docs/index-cadence.md` (permanent doctrine home, sister-pattern to `docs/peer-poke-spec.md`). **Resolved 2026-06-27** per PM PR #532 comment.
- [ ] **Architect**: Sign-off process — 5-step for ALL d-tests, or only doctrine codifiers? Recommendation: 5-step for doctrine codifiers (sister d058), 3-step for routine sister-pattern (skip arch step 4).
- [ ] **Developer**: INDEX.md format — strict YAML front matter + free-form body, or free-form only? Recommendation: YAML front matter for machine-parseable + free-form body for human-readability.
- [ ] **Orchestrator**: Quarterly review cadence — Sprint planning ceremony (every 2 weeks) or quarterly literal (every 12 weeks)? Recommendation: Sprint planning ceremony (more frequent = lower drift).

## §5 Cross-refs

- **Issue #524** — Sprint 15 P2 #9 / STORY-023 (this cadence doc, AC1 + AC2)
- **Issue #508** — Sprint 14 P1 #6 AC5 follow-up (d058 CI integration spec)
- **Issue #497** — Sprint 14 P1 #6 predecessor (d058 work-stream awareness)
- **Issue #440** — d050b behavioral workflow test framework
- **Issue #414** — §Dispatch Discipline 6-step (cross-agent verification)
- **Issue #430** — PM §Pre-verdict cross-check doctrine
- **Issue #461** — d052 agent-watch hardening
- **Issue #463** — d053 ADR-0050 pre-merge 4-cat verification
- **Issue #468** — d054 Closes-anchor strict format
- **Issue #505** — d058 work-stream awareness impl
- **Issue #520** — Sprint 15 P1 #5 / STORY-019 d031 TC5/6/7 expansion (attempt #1 reverted, see §3 drift audit)
- **Issue #523** — Sprint 15 P2 #8 / STORY-022 d059 new d-test (chain dep pollution companion)
- **PR #504** — ADR-0038 §Work-Stream Awareness amendment (squash @ a45c613)
- **PR #506** — d058 impl + d-test on main (squash @ 226b546)
- **PR #511** — d058 CI integration (squash @ 70e33d7)
- **PR #513** — RETRO-009 ceremony 4/4 (squash @ ebf6bc8)
- **PR #515** — Sprint 15 plan.md + backlog.json + current pointer refresh (squash @ 77105f9)
- **PR #528** — d060 impl + d-test (squash-gate ready)
- **PR #530** — d061 impl + d-test (squash-gate ready post-fix)
- **ADR-0024** — verdict-by:<ts> schema (sign-off label sister-pattern)
- **ADR-0044** — RED-first TDD contract
- **ADR-0045** — 9-Lens Review Checklist
- **ADR-0049** — d-test framework (sister-pattern family definition)
- **ADR-0050** — Layer 5 race pattern codification
- **RETRO-008 §3** — wip_overflow false positive origin (d058 doctrinal genesis)
- **RETRO-008 §11** — d-test persistence (INDEX.md doctrinal home)
- **RETRO-009 §6** — d-test family persistence (d059 sister-pattern origin)
- **RETRO-009 §10** — tester lane INDEX maintainer (this doc's doctrinal home)
- **Issue #238** — no-standby doctrine (cycle driver)

— @tester, 2026-06-27, STORY-023 INDEX cadence doc + 5-step sign-off process + drift audit