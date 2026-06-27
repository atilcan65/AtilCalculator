# RETRO-008 — Sprint 13 codifications

> **Status:** Draft (PM lane, owner ratifies per file ownership matrix: docs/retros/ is human-only territory)
> **Trigger:** Sprint 13 cluster work produced 12+ doctrine candidates from 8 PRs + 7 closed Issues
> **Cross-ref:** RETRO-007 watchlist (predecessor, 9 entries), RETRO-008 Issue #480 (PM lane)
> **Sister-pattern:** [Sprint 13 close.md](../sprints/sprint-13/close.md) §6 Lessons Learned
> **Date:** 2026-06-27 (Sprint 13 close, Sprint 14 P1 candidate)

## Summary

Sprint 13 surfaced 12 doctrine candidates across 8 PRs and 7 closed Issues. The candidates cluster around 4 themes:

1. **CI timing & re-run races** (4 candidates) — GitHub Actions + Layer 5 bot + peer-poke timing gaps
2. **State machine coherence** (3 candidates) — Board consistency, WIP cap enforcement, label discipline
3. **Evidence chain precision** (3 candidates) — SHA attribution, merge count, factual drift
4. **Doctrine self-application** (2 candidates) — PM no-self-standby, owner squash boundary

Tier 1 (5 candidates) prioritized for Sprint 14 P1 work; Tier 2 (5 candidates) for Sprint 14 P2; Tier 3 (2 candidates) for Sprint 15+.

## Tier 1 (high-value, multiple instances today)

### §1. CI re-run race condition

**Trigger PRs/Issues:** PR #472 + #475 + #476 + #478 (4 instances today), Issue #466, Issue #480

**Instance count:** 4 distinct PRs observed CI re-run race in single sprint (PR #472 1st run label-check FAIL @ 07:52:31Z, 2nd run SUCCESS; PR #475 1st run label-check FAIL @ 05:32:33Z, 2nd-4th runs SUCCESS; PR #476 1st run label-check FAIL @ 05:34:16Z + sync-status FAIL @ 05:34:32Z, 2nd-4th runs SUCCESS; PR #478 1st run label-check FAIL @ 05:57:01Z + sync-status FAIL @ 05:56:53Z, 2nd-4th runs SUCCESS)

**Doctrine:**
> **Rule:** When a CI status check is queried, treat the FIRST observed `FAILURE` as potentially transient. Within 60 seconds of first FAIL, re-query via `gh run watch <ID> --exit-status` or until-loop polling. If subsequent run reports `SUCCESS`, the FAIL was a CI re-run race (not a real defect).
>
> **Why:** GitHub Actions status labels can be stale for 30-60s. A check that reports `FAILURE` in the first poll may report `SUCCESS` in the second poll, even though the underlying state has not changed (e.g., label-check bot races with manual `gh issue edit`).

**Cross-refs:** ADR-0045 (architectural verdicts), ADR-0049 (3-layer d-test defense), Issue #480 codification

---

### §2. Engine perf flake vs regression distinction

**Trigger PRs/Issues:** PR #472 Lint & Test FAIL @ 04:50:09Z (initial), Issue #329 (perf test baseline), Issue #480 codification

**Instance count:** 1 instance (PR #472, single flake — not a pattern)

**Doctrine:**
> **Rule:** A single CI FAIL on a perf test is a **flake** (not a regression) if:
> 1. The flake is >2.8% over the documented budget (Issue #329 hypothesis threshold)
> 2. The local reproduction passes (engine code GREEN)
> 3. The CI rerun passes within 4 minutes of the first FAIL
>
> **Action:** Re-run CI; do NOT escalate to P1. If the pattern recurs (3+ instances across distinct PRs), open a P3 issue and codify in next RETRO.

**Cross-refs:** Issue #329, PR #472, Issue #480, RETRO-008 §Peer-poke CI timing gap (sister-pattern)

**Note:** PM misattributed p99=143ms as deterministic regression; dev reproduced locally (engine code GREEN, p99=0.03ms) and re-ran CI (PASS in 51s). Root cause: CI infra flake, not engine code. Sister-pattern: §Timing window (re-query within 30s).

---

### §3. wip_overflow false positive

**Trigger PRs/Issues:** Synthetic wake events (multiple instances today)

**Instance count:** 3-5 wip_overflow false positives today (e.g., agent_count=4, cc_count=5 — not a real WIP overflow)

**Doctrine:**
> **Rule:** A `wip_overflow` alert from the synthetic-wake proactive-scan is **informational, not actionable**, unless the real WIP count (active issues with `agent:<role> AND status:in-progress`) exceeds the WIP cap (2 per ADR-0038).
>
> **Why:** The proactive-scan counts both `agent:<role>` AND `cc:<role>` issues, which inflates the count. The real WIP cap is `agent:<role> AND status:in-progress`, not `cc:<role>`.

**Action:** When a wip_overflow alert fires, query the real WIP via `gh issue list --label "agent:<role>,status:in-progress"`. If count ≤ WIP cap (2), the alert is a false positive; do not pause.

**Cross-refs:** ADR-0038 (WIP cap), ADR-0002 (Autonomy Loop), Issue #238 (no-self-standby)

---

### §4. Layer 5 race pattern (status:ready auto-add races with manual label flip)

**Trigger PRs/Issues:** PR #472 (status:ready auto-promoted after PM flipped to status:in-review), PR #476 (similar), PR #478 (similar) — 5 instances today

**Instance count:** 5 PRs observed Layer 5 race in single sprint

**Doctrine:**
> **Rule:** The Layer 5 bot auto-adds `status:ready` to PRs when CI passes. This race can override a manual `status:in-review` flip. Treat the bot's auto-add as **idempotent** — i.e., if `status:in-review` is the desired state, the bot's `status:ready` is a transient that the bot will re-correct within 60s.
>
> **Action:** If the bot overrides a manual flip, re-flip and wait 60s. If the bot overrides again, escalate to orchestrator (state machine driver).

**Cross-refs:** ADR-0012 (4-cat label invariant), ADR-0015 (atomic 4-flag hand-off), Layer 5 bot config

---

### §5. Peer-poke CI timing gap

**Trigger PRs/Issues:** PR #465 ship ACK @ 05:25Z (dev claimed CI SUCCESS at FAILURE moment), Issue #480

**Instance count:** 1 instance (dev claim temporal contradiction)

**Doctrine:**
> **Rule:** When posting a peer-poke or verdict that references a CI status, re-query the CI status within 30s of posting. Do NOT trust `gh run list --limit 3 --json conclusion` output for an in-progress run — the `conclusion` field will be empty or stale.
>
> **Fix:** Use `gh run watch <ID> --exit-status` OR `until gh run view <ID> --json conclusion -q '.conclusion' | grep -qE 'success|failure'` polling.

**Cross-refs:** §Timing window (RETRO-007 #6, codified in PR #472), Issue #430 (PM §Pre-verdict cross-check)

**Sister-pattern:** §Timing window applies to BOTH peer-poke + CI re-query (RETRO-008 §5 + RETRO-008 §1 are sister-pattern).

---

## Tier 2 (medium-value, 1-2 instances)

### §6. Agent factual ground-truth drift

**Trigger:** Tester initially recommended 'PR #474 CLOSE-AS-SUPERSEDED' (WRONG; PR #474 was arch design doc, not closed)

**Doctrine:** Before recommending a fix path, verify the PR's dependency graph and content via `gh pr view <N> --json files,title,body,labels`. Do NOT infer from prior comments.

**Cross-refs:** Issue #430 (PM §Pre-verdict cross-check), ADR-0049 §3-layer d-test

---

### §7. stale_cc deadlock pattern

**Trigger:** PR #474 + #475 cc:orchestrator unchanged 916s/1074s/1490s (deadlock-breaker wake fires)

**Doctrine:** A `stale_cc` wake indicates an **intentional hold pattern during dependency block** (e.g., waiting on arch review, waiting on owner squash). It is NOT a real deadlock unless the hold reason has changed (e.g., dependency resolved but review still pending).

**Action:** On `stale_cc` wake, query the PR for the current state. If the dependency is still in flight (e.g., arch hasn't reviewed yet, owner hasn't squashed yet), the hold is intentional. Do NOT escalate.

**Cross-refs:** Issue #238 (no-self-standby), §wip_overflow false positive (sister-pattern)

---

### §8. SHA attribution precision

**Trigger:** Dev 'd054 design @ 987d0ad5' was file SHA, commit was 36c4fd454c

**Doctrine:** When citing a SHA in an evidence chain, specify the SHA type: `commit:<sha>`, `file:<sha>`, or `blob:<sha>`. Default to `commit:<sha>` unless otherwise noted.

**Cross-refs:** ADR-0049 (evidence chains), d046 (jq-filter guard)

---

### §9. merge-count arithmetic

**Trigger:** Dev 'squash chain 5/5' was actually 7 PRs (counted wrong)

**Doctrine:** When counting merged PRs, use `gh pr list --state merged --json number --jq 'length'`, not estimates. Estimates are unreliable; the count via `gh api` is ground truth.

**Cross-refs:** §Flake vs regression (sister-pattern: trust re-query, not inference)

---

### §10. Peer label discipline (BUG-3)

**Trigger:** Tester correctly refused to flip arch's labels. Doctrine: peers do NOT touch other agents' `agent:*` labels; orchestrator is sole state machine driver.

**Doctrine:**
> **Rule:** Peer agents (architect / developer / tester / PM) MUST NOT touch other agents' `agent:*` labels on PRs or Issues. The orchestrator is the sole state machine driver for `agent:*` flips.
>
> **Why:** The `agent:*` label indicates ownership. Touching another agent's `agent:*` label corrupts the ownership signal and breaks the auto-claim cycle (ADR-0038).
>
> **Exception:** The responsible agent (per the `agent:*` label) MAY flip their own `agent:*` label as part of the atomic 4-flag hand-off (ADR-0015).

**Cross-refs:** ADR-0012 (4-cat label invariant), ADR-0015 (atomic 4-flag hand-off), ADR-0038 (auto-claim), Issue #113 (soul doctrine)

---

## Tier 3 (new, this pickup)

### §11. d-test persistence verification

**Trigger:** d054 self-test green post-merge confirms d-test behavioral assertion holds after squash

**Doctrine:** A d-test (d046, d048, d050b, d051, d052, d053, d054) that is GREEN post-merge confirms the d-test's behavioral assertion holds in the merged state. This is the d-test's primary validation: it must catch violations BOTH pre-merge (in CI) AND post-merge (in production).

**Action:** After owner squash + merge, re-run d-tests via `pytest tests/ -k d0XX` to confirm persistence. If a d-test passes pre-merge but fails post-merge, file a P1 issue (d-test regression).

**Cross-refs:** ADR-0049 (3-layer d-test defense: content-anchor + syntactic + behavioral), ADR-0050 (C9 strict format)

---

### §12. owner squash boundary doctrine

**Trigger:** Arch asked for clarification 2026-06-27T06:13Z on whether arch can self-squash a PR after test pass.

**Doctrine:**
> **Rule:** `gh pr merge --squash` is **OWNER territory ONLY** (per CLAUDE.md Hard Rules: "Merge their own PRs" — NEVER). This applies to all non-human roles: arch / dev / tester / PM / orchestrator MUST NOT self-squash. Even with all checks green and all peer reviews APPROVED, the merge decision is the owner's.
>
> **Why:** Owner squash gate is the last verification step before production. The owner reviews the full PR (description, diff, peer reviews, CI status) and makes the final call. Agents proposing self-squash would bypass this gate.
>
> **Clarification:** "Never approve a PR" (Hard Rules) extends to all non-human roles for the `merge` action. Approval (in the review sense) is a peer action; merge is an owner action.

**Cross-refs:** CLAUDE.md Hard Rules "Merge their own PRs" — NEVER, file ownership matrix, Issue #113 (soul doctrine)

---

## Cross-References

- **Issue #480** — [RETRO-008] Sprint 13 codification (PM lane, owner ratifies)
- **Sprint 13 close.md** — `docs/sprints/sprint-13/close.md` §6 Lessons Learned (sister-pattern)
- **RETRO-007** — 9-entry watchlist (predecessor, 5 closed in Sprint 13)
- **ADR-0049** — 3-layer d-test defense (d046, d048, d050b, d051, d052, d053, d054 family)
- **ADR-0050** — Pre-merge 4-cat verification (C1-C9 doctrinal checks)
- **Issue #238** — no-self-standby (PM doctrine)
- **Issue #329** — perf test flake hypothesis
- **Issue #430** — PM §Pre-verdict cross-check (comments[] AND reviews[])
- **PR #472** — §Pre-verdict cross-check timing window codification (RETRO-007 #6)
- **PR #473** — Sprint 13 PM lane definition amendment (RETRO-007 #9)
- **PR #475** — §Dispatch Discipline post-amend re-query rule (RETRO-007 #8)

— @product-manager, 2026-06-27T09:34+03:00, RETRO-008 draft (PM lane, owner ratifies per docs/retros/ human-only territory)
