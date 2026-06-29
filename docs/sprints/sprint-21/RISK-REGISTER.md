# Sprint 21 — Risk Register

> **PM draft, 2026-06-29.** Each risk has severity, mitigation, owner, trigger metric.

---

## R1 — Parameterization Scope Creep (P1 — High Probability)

**Description:** 100+ files reference project name (`AtilCalculator`, `atilcan65`, `atilcalc-architect-td012`). Auditing all of them for placeholder coverage is tedious. Some refs may be missed (e.g., binary files, sample data, docs/examples).

**Likelihood:** High (almost certain some will be missed)
**Impact:** Medium (clones have leftover refs, confusing for first-time users)
**Severity:** P1

**Mitigation:**
- S21-004: `audit-project-refs.sh` is the regression guard (CI gates merge on audit failure)
- S21-022: smoke test covers fresh-clone rendering
- S21-023: 2 external fresh-clone validations catch what audit misses
- Architect 9-Lens on init script PRs catches hidden refs

**Trigger metric:** Audit script finds > 5 hardcoded refs post-S21-003 → scope creep confirmed, add 1-2 more stories to fix.

**Owner:** dev (init script), arch (audit design), tester (audit test).

---

## R2 — Doctrine Drift Between Template and AtilCalculator (P1 — Medium Probability)

**Description:** Sprint 21 ships a template. AtilCalculator is the source. If template drifts from AtilCalculator (e.g., AtilCalculator fixes a bug that doesn't propagate to template), clones get stale doctrine.

**Likelihood:** Medium (any project evolves)
**Impact:** High (doctrine gap = silent agent failure)
**Severity:** P1

**Mitigation:**
- S21-024: `.template-version` enables drift detection
- S21-007: soul files carry template-version header
- `agent-doctor.sh <role>` reports drift
- Sprint 22+ candidate: template-pull mechanism (auto-sync doctrine)

**Trigger metric:** Within 30 days post-Sprint 21, AtilCalculator has 3+ soul file changes that aren't reflected in template → drift confirmed, prioritize Sprint 22 pull mechanism.

**Owner:** PM (drift monitoring), owner (Sprint 22+ prioritization).

---

## R3 — First-Time User Confusion (P1 — Medium Probability)

**Description:** Template works for AtilCalculator's owner (who built it) but may confuse first-time users. ONBOARDING.md is the mitigation but writing a guide that works for someone who hasn't lived the 20-sprint journey is hard.

**Likelihood:** Medium
**Impact:** High (blocks adoption)
**Severity:** P1

**Mitigation:**
- S21-020: ONBOARDING.md validated by ≥ 1 external walkthrough (PM simulates with fresh fixture dir)
- S21-023: 2 fresh-clone validations catch confusion points
- Time-to-first-standup target: ≤ 60 min (PM measures)
- Sprint 22+ candidate: video walkthrough, GIF demo

**Trigger metric:** PM's external walkthrough > 90 min → ONBOARDING.md needs revision.

**Owner:** PM (ONBOARDING author + validator).

---

## R4 — License Ambiguity (P2 — Low Probability)

**Description:** Owner hasn't chosen license yet (Q1 in OPEN-QUESTIONS). Wrong choice blocks adoption or creates legal risk.

**Likelihood:** Low (decision is reversible, default to MIT if no answer)
**Impact:** Medium (adoption delay, not blocker)
**Severity:** P2

**Mitigation:**
- Default to MIT if owner doesn't respond by Day 2 of sprint
- S21-002 references chosen license, easy to swap

**Trigger metric:** Owner license decision > Day 2 of sprint → escalate.

**Owner:** owner (decision).

---

## R5 — GitHub Rate Limit During Init (P2 — High Probability)

**Description:** `dev-studio-init.sh` makes ~10 `gh` API calls (label seed, board setup, secret set). If hit rate limit, init fails partway, leaving clone in inconsistent state.

**Likelihood:** High (rate limit is shared across all tools + agents, easily exhausted)
**Impact:** Medium (init can be retried, but UX is bad)
**Severity:** P2

**Mitigation:**
- Init script uses `gh api` (REST, not GraphQL) for retry/backoff compatibility
- Init script is idempotent (rerun safe)
- ONBOARDING.md step 1 checks rate limit (`gh api rate_limit`) before init
- S21-022 smoke test covers init-under-rate-limit (mocked)

**Trigger metric:** Init fails on rate limit in 1+ fresh-clone validation → add explicit retry logic.

**Owner:** dev (init script).

---

## R6 — Sprint 20 Close-Out Blocks Sprint 21 Kickoff (P2 — Low Probability)

**Description:** Sprint 20 PROJECT CLOSE may not complete before Sprint 21 kicks off. If owner wants sequential (S20 close → S21 kick), Sprint 21 starts late.

**Likelihood:** Low (owner can override sequencing)
**Impact:** Low (1-2 day delay)
**Severity:** P2

**Mitigation:**
- PM notes in OPEN-QUESTIONS.md (Q6) asks owner: sequential or parallel?
- Sprint 21 kickoff can happen with Sprint 20 still in close-out (board has capacity for both)
- Orchestrator handles board sync for both sprints in parallel if needed

**Trigger metric:** Owner doesn't answer Q6 by Day 1 of sprint → assume parallel (default).

**Owner:** owner (decision), orchestrator (board sync).

---

## R7 — Template-PR Review Bottleneck (P2 — Medium Probability)

**Description:** Owner is the only merge-gate. Sprint 21 has ~25 PRs (one per story). Owner bandwidth may be the bottleneck.

**Likelihood:** Medium
**Impact:** Medium (sprint slips)
**Severity:** P2

**Mitigation:**
- Stories cluster into PRs (e.g., S21-006 + S21-007 → 1 PR for soul files)
- Owner reviews in batches (one sitting per epic, not per story)
- Tester + architect pre-merge checks catch most issues before owner review
- PM tracks owner-review SLA, escalates if > 24h

**Trigger metric:** Owner-review SLA > 24h on 3+ PRs → escalate.

**Owner:** owner (merge), PM (SLA tracking).

---

## R8 — Cross-Project Doctrine Conflict (P2 — Low Probability)

**Description:** Sprint 21 may need ADRs that conflict with existing AtilCalculator ADRs (e.g., new ADR-0001 may supersede or contradict an existing one).

**Likelihood:** Low
**Impact:** High (doctrine conflict = agent confusion)
**Severity:** P2

**Mitigation:**
- S21-016 ADR-0001 cross-references existing ADRs, no contradictions
- Architect reviews all new ADRs in 9-Lens for consistency
- PM reviews all doctrine changes for cross-project impact

**Trigger metric:** Architect flags contradiction in any new ADR → resolve before merge.

**Owner:** arch (9-Lens), PM (cross-project impact).

---

## R9 — Missing Files in Template (P3 — Medium Probability)

**Description:** Some files exist in AtilCalculator but were missed in INVENTORY.md. Sprint 21 ships a template that's missing critical files.

**Likelihood:** Medium (inventory audit is manual)
**Impact:** High (template unusable for missing-file feature)
**Severity:** P2 (catches in S21-023 fresh-clone validation)

**Mitigation:**
- S21-023 fresh-clone validation runs ALL d-tests + ALL workflows + ALL issue templates → catches missing files
- S21-022 smoke test includes file-presence check
- PM cross-checks INVENTORY.md against `find` output

**Trigger metric:** Fresh-clone validation finds > 5 missing files → INVENTORY.md audit gap, add stories.

**Owner:** PM (inventory), dev (gap fix).

---

## R10 — Secret Leakage in Template (P3 — Low Probability)

**Description:** Template repo accidentally commits a real secret (PAT, Telegram token) instead of a placeholder.

**Likelihood:** Low (AtilCalculator has secret-canary.yml workflow)
**Impact:** Critical (secret leak)
**Severity:** P0 (if it happens)

**Mitigation:**
- `.github/workflows/secret-canary.yml` already exists, runs on every PR
- Pre-commit hook checks for `ghp_*` patterns
- Init script's first step: scan for `ghp_*`, fail if found
- S21-022 smoke test includes secret-leak check

**Trigger metric:** secret-canary.yml fires on any template PR → halt, scrub, re-render.

**Owner:** dev (pre-commit hook), arch (workflow review).

---

## Summary

| Risk | Severity | Mitigation Story |
|---|---|---|
| R1 Parameterization scope creep | P1 | S21-004, S21-022, S21-023 |
| R2 Doctrine drift | P1 | S21-007, S21-024 |
| R3 First-time user confusion | P1 | S21-020, S21-023 |
| R4 License ambiguity | P2 | S21-002 (default MIT) |
| R5 GitHub rate limit | P2 | init script idempotency, retry |
| R6 Sprint 20 close-out blocks | P2 | Q6 owner decision |
| R7 PR review bottleneck | P2 | cluster PRs by epic |
| R8 Cross-project doctrine conflict | P2 | arch 9-Lens |
| R9 Missing files | P2 | S21-022, S21-023 |
| R10 Secret leakage | P0 | secret-canary, pre-commit |

---

**Drafted by:** @product-manager
**Date:** 2026-06-29
**Status:** DRAFT (awaiting owner ratification)