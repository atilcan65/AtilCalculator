# STORY-014: d058 d-test impl — claim-next-ready work-stream awareness (RETRO-008 §3 fix)

## User Story
As a **P2 — Dev (operator of scripts/claim-next-ready.sh, ADR-0038 §Work-Stream Awareness consumer)**,
I want **scripts/claim-next-ready.sh to count work-streams instead of issues (PR cluster = 1 stream, not 2 issues) + scripts/tests/d058-claim-wip-workstream.sh to verify the work-stream rule with 9/9 TCs green**,
So that **the wip_overflow false positive on legitimate 2-issue concurrent work (e.g., PR-A closes #N + #M simultaneously) is eliminated in CI per RETRO-008 §3, per ADR-0038 §Work-Stream Awareness amendment (PR #504 squash @ a45c613, owner-ratified 2026-06-27T11:28:27Z)**.

## Why now

Sprint 14 P1 cluster shipped 5/6 (PR #500/#501/#502/#499/#504 MERGED). PR #504 carries the ADR-0038 amendment that codified work-stream awareness doctrine (Layer 2 spec §work-stream-rule). The amendment is doctrinal; the implementation gap remains — `scripts/claim-next-ready.sh` still counts issues, not work-streams. Without d058, the doctrine is unenforced and the wip_overflow false positive (RETRO-008 §3 origin) can re-occur on next PR cluster cycle. Sprint 14 P1 #6 AC2 (Issue #497) explicitly requires the d-test as part of the AC1 + AC2 + AC3 + AC4 close-out. Per architect reassessment, combined impl + d-test = 1.0 SP (sister-pattern to PR #504's 2.5-2.75 SP joint sizing for the doctrine amendment alone).

## Acceptance Criteria

- **AC1** — `scripts/claim-next-ready.sh` Layer 2 updated with work-stream awareness:
  - GIVEN a PR cluster (PR-A closes #N + #M, both with `agent:developer` label) is open WHEN `claim-next-ready.sh developer` runs THEN the script counts work-streams (WIP=1, not 2) per work-stream rule
  - GIVEN a single standalone issue (#N) with `agent:developer` is open WHEN `claim-next-ready.sh developer` runs THEN WIP=1 (unchanged behavior, no regression)
  - Layer 2 spec per ADR-0038 §Work-Stream Awareness amendment applied (PR cluster detection + work-stream collapse rule)
- **AC2** — `scripts/tests/d058-claim-wip-workstream.sh` d-test impl with 9/9 TCs green per ADR-0044 RED-first (sister-pattern to d031-claim-next-ready.sh which has 5+2=7 TCs):
  - TC1: PR cluster (PR-A closes #N + #M) → WIP=1 per work-stream rule (core)
  - TC2: 2 standalone issues same priority → claim oldest (age tie-break, work-stream=issue, unchanged)
  - TC3: 1 PR cluster + 1 standalone → WIP=2 (PR cluster counts 1, standalone counts 1)
  - TC4: 2 PR clusters → WIP=2 (each cluster counts 1)
  - TC5: WIP limit reached (≥2 in-progress) → exit 3, no claim (work-stream-aware, not issue-aware)
  - TC6: 0 ready items → exit 1, no claim (negative)
  - TC7: usage error (no role arg) → exit 2
  - TC8: invalid role → exit 2
  - TC9: PR cluster with closed-dep (PR-A closes #N where #N is already closed) → WIP=1 (cluster collapse still works, dep filter applied)
- **AC3** — Sister-pattern to ADR-0038 §Work-Stream Awareness amendment (PR #504 squash @ a45c613, on main as of 2026-06-27T11:28:27Z):
  - Layer 2 spec §work-stream-rule implemented and verified
  - d058 d-test contract mirrors the spec line-by-line (no interpretation drift)
- **AC4** — Joint sizing verdict: arch + dev + tester sign-off per ADR-0024 (1.0 SP per architect reassessment, combined impl + d-test; tester lane = 0.25 SP for d-test sign-off only, separate story)
- **AC5** — CI integration follow-up issue filed by PM for HUMAN lane (separate scope: d058 owner merge gate per ADR-0012 4-cat invariant, scripts/tests/INDEX.md registration, 0.5 SP per arch)

## Out of scope

- Auto-claim protocol overhaul (separate scope, ADR-0038 amendment is the doctrinal home)
- agent-watch.sh non-wip heuristics (orthogonal concern, Issue #238 doctrine origin)
- d031-claim-next-ready.sh update (sister-pattern, but d031 already covers base Layer 2; d058 is the work-stream extension)
- d094 (watcher self-cc-skip behavioral) — separate story, separate d-test
- Sprint 14 P1 #2 engine perf d-test (orthogonal, candidate for d057 sister-pattern per Issue #497 §Open questions)

## Open questions

- [ ] **Architect**: Work-stream collapse rule — should the parser inspect `closes #N` body field, or look at the PR cross-ref label, or both? Sister-pattern to ADR-0053 codification (PR cluster detection). → architect @ d058 impl
- [ ] **Architect**: WIP limit semantics — does WIP=2 mean "2 work-streams in flight" or "2 issues across all work-streams in flight"? (Recommendation: 2 work-streams per ADR-0038 amendment + RETRO-008 §3 origin.) → architect @ d058 impl
- [ ] **Developer**: d-test TC ordering — should work-stream rules (TC1/TC3/TC4/TC9) come before sanity checks (TC6/TC7/TC8) for readability, or follow d031's 5+2 pattern? → developer @ d058 impl
- [ ] **Tester**: d-test sign-off timing — should d031 + d058 be signed off together (Layer 2 coverage suite, 14 TCs total) or sequentially? → tester @ AC4

## Mockups / references

- `scripts/tests/d031-claim-next-ready.sh` — sister-pattern (5+2 TCs, claim-next-ready base Layer 2)
- `scripts/claim-next-ready.sh` (PR #271 implementation, Issue #276 STUB replacement) — impl home
- ADR-0038 §Work-Stream Awareness amendment (PR #504 squash @ a45c613) — doctrinal home
- ADR-0044 RED-first TDD discipline (tester sign-off lane)
- ADR-0049 d-test framework (sister-pattern family: d046/d048/d050b/d051/d052/d053/d054/d058 = 8-sister)
- RETRO-008 §3 (wip_overflow false positive origin)
- Issue #497 (Sprint 14 P1 #6, AC2 = d058 d-test impl)
- Issue #238 (no self-justified pauses doctrine, RETRO-008 §3 carrier)

## Dependencies

- **Upstream**:
  - PR #504 squash @ a45c613 (ADR-0038 amendment on main, 2026-06-27T11:28:27Z) — doctrinal prerequisite ✅ DONE
  - ADR-0038 §Auto-Claim Protocol (Layer 2 base) — already on main ✅ DONE
  - `scripts/claim-next-ready.sh` (PR #271) — impl home exists ✅ DONE
  - `scripts/tests/d031-claim-next-ready.sh` (sister-pattern template) ✅ DONE
- **Downstream**:
  - d031 update (tester lane, 0.25 SP, post-d058 — sister-pattern TC harmonization)
  - scripts/tests/INDEX.md registration (P2 #9 carry-forward)
  - CI integration for d058 (HUMAN lane, 0.5 SP per arch — d058 owner merge gate)
- **Sister-pattern**:
  - d031-claim-next-ready.sh (5+2=7 TCs, base Layer 2)
  - d054-closes-anchor-strict-format.sh (PR #499 sister)
  - d055 + d056 (PR #503 + PR #504 codifier d-tests, Issue #495 + #497 AC3 close on owner squash)

## Metrics of success

- wip_overflow false positive eliminated in CI per RETRO-008 §3 (leading)
- claim-next-ready.sh exit code 3 (WIP cap) triggers on 2 work-streams, not 2 issues (leading)
- d058 d-test 9/9 TCs green (leading)
- d-test family coverage: 8-sister pattern (d046/d048/d050b/d051/d052/d053/d054/d058) all merged (lagging)

## Cross-refs

- docs/sprints/sprint-14/plan.md §Committed stories #6 (Sprint 14 P1 #6 home)
- Issue #497 (Sprint 14 P1 #6, closes on PR #504 squash ✅ DONE, d058 = AC2 follow-on)
- PR #504 squash @ a45c613 (ADR-0038 amendment, doctrinal prerequisite)
- ADR-0038 §Work-Stream Awareness (PR #504 home)
- ADR-0044 RED-first TDD discipline
- ADR-0049 d-test framework
- RETRO-008 §3 (wip_overflow false positive origin)
- RETRO-008 §4 LIVE INSTANCES table (PR #504 = 6th Layer 5 race instance, sister to d058 codifier)
- Issue #238 (no self-justified pauses, doctrine origin)
- scripts/claim-next-ready.sh (impl home)
- scripts/tests/d031-claim-wip-workstream-stub.sh (if exists, may need to deprecate)
- ADR-0024 (joint sizing verdict SLA)

— @product-manager, 2026-06-27T11:33+03:00, Sprint 14 P1 #6 dev lane (claim-next-ready work-stream awareness + d058 d-test, 1.0 SP per arch reassessment)