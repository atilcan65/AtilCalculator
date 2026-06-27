# d-test INDEX — RETRO-008 §11 registry

> **Sister-pattern home:** RETRO-008 §11 (d-test persistence), ADR-0049 (d-test framework), ADR-0044 (TDD RED contract).
> **Spec origin:** Issue #508 AC2 ("`scripts/tests/INDEX.md` registration entry for d058 added") — AC2 of Sprint 14 P1 #6 AC5 follow-up.
> **Purpose:** Persistent registry of all d-tests, their TCs, sister-pattern lineage, and spec refs. Future d-test additions follow this template.

## d058 — claim-next-ready work-stream awareness ✅ ACTIVE (CI-integrated)

| Field | Value |
|---|---|
| **ID** | d058 |
| **Title** | claim-next-ready work-stream awareness |
| **File path** | `scripts/tests/d058-claim-wip-workstream.sh` |
| **TCs** | 9/9 (TC1 PR cluster, TC2/TC2b age tie-break, TC3 cluster+standalone, TC4 2 clusters, TC5 WIP cap, TC6 0 ready, TC7 no role, TC8 invalid role, TC9 closed-dep) |
| **Sister-pattern** | `d031-claim-next-ready.sh` (base Layer 2, 5+2=7 TCs) — d058 EXTENDS d031 with work-stream awareness |
| **Spec ref** | ADR-0038 §Work-Stream Awareness amendment (PR #504 squash @ a45c613) |
| **CI integration** | `.github/workflows/lint-and-test.yml` — runs on push to main + every PR |
| **Doctrinal origin** | RETRO-008 §3 (wip_overflow false positive); Issue #238 (no self-justified pauses) |
| **Status** | SHIPPED (PR #506 squash @ 226b546 on main, 2026-06-27T12:03:07Z) |

## Sister-pattern lineage — d-test impls ALREADY on main, CI integration planned

d058 is the **first d-test integrated into CI** (per AC5 follow-up Issue #508, 2026-06-27). The 10-sister d-test family impls are already on main (PR #506 squash + earlier PRs). What is **planned for future sprints** is **CI integration** of the remaining sisters — not their impl.

| ID | Title | File path | TCs | Sister-pattern | Spec ref | CI status |
|---|---|---|---|---|---|---|
| **d015** | dev-idle prevention (Katman 1+2) | `scripts/tests/d015-dev-idle-prevention.sh` | (impl on main, TBD count) | Issue #238 / #119 wake-gap | RETRO-008 §14 codification | NOT yet CI-integrated |
| **d031** | claim-next-ready base Layer 2 | `scripts/tests/d031-claim-next-ready.sh` | 7/7 (5+2 sanity) — impl on main | d058 work-stream extension | ADR-0038 §Auto-Claim Protocol | NOT yet CI-integrated |
| **d046** ⚠️ | ADR-0044 / cross-soul parity / syntactic-check (3-way ID collision) | `scripts/tests/d046-expansion-adr-0044-literal-form.sh` + `d046-js-syntactic-check.sh` + `d046-peer-poke-canonical-parity.sh` | (3 impls on main, TBD counts) | Issue #413 + #430 + #467 | ADR-0044 + Issue #430 | NOT yet CI-integrated — **rename to d046a/d046b/d046c pending per arch verdict on Issue #533** |
| **d048** | ADR-0012 status:ready gating canonical guard | `scripts/tests/d048-adr-0012-status-ready-gating.sh` | (impl on main, TBD count) | ADR-0012 Layer 5 + ADR-0050 | Issue #425, ADR-0050 §C9 | NOT yet CI-integrated |
| **d050b** | behavioral workflow test framework | `scripts/tests/d050b-behavioral-workflow-test.sh` | (impl on main, TBD count) | Issue #440 + ADR-0049 | Issue #440 | NOT yet CI-integrated |
| **d051** | 5-soul §Dispatch Discipline regression anchor | `scripts/tests/d051-5-soul-dispatch-discipline.sh` | (impl on main, TBD count) | Issue #414 + RETRO-005 #26 | RETRO-005 #26 | NOT yet CI-integrated |
| **d052** | agent-watch hardening (T1-T4) | `scripts/tests/d052-agent-watch-hardening.sh` | (impl on main, TBD count) | T1 self-wake / T2 re-query / T3 REPRIME / T4 stale-state | Issue #461 | NOT yet CI-integrated |
| **d053** | pre-merge 4-cat verification | `scripts/tests/d053-pre-merge-4-cat-verification.sh` | (impl on main, TBD count) | ADR-0050 + ADR-0012 §C9 | Issue #463, ADR-0050 | NOT yet CI-integrated |
| **d054** | Closes-anchor strict format | `scripts/tests/d054-closes-anchor-strict-format.sh` | (impl on main, TBD count) | PR #499 sister; ADR-0050 §C9 deep-narrow | Issue #468 | NOT yet CI-integrated |

### Future CI integration pattern

Each d-test integration PR follows the **d058 sister-pattern** (set by PR #511):

1. **Workflow addition:** Add a new step (or new job) to `.github/workflows/lint-and-test.yml` for the specific d-test.
2. **SHA pin:** All `actions/*` references use SHA-pinned versions (lens h per ADR-0043).
3. **9-Lens (i) 8 sub-categories:** Document trigger / timeout / permissions / concurrency / secrets / network / artifact / Layer 5 race awareness per ADR-0043.
4. **INDEX.md registration:** Add a new entry to this file under the "ACTIVE" section (move from "planned" table).
5. **PR contract:** Draft PR with 4-cat labels per ADR-0012 + dual-channel `scripts/ping.sh` peer notification per ADR-0033.

## Cross-refs

- **Issue #508** — Sprint 14 P1 #6 AC5 follow-up (CI integration spec, 0.5 SP HUMAN lane, owner merge gate)
- **PR #506** — d058 impl + d-test on main (squash @ 226b546, 2026-06-27T12:03:07Z)
- **PR #504** — ADR-0038 §Work-Stream Awareness amendment (squash @ a45c613, on main 2026-06-27T11:28:27Z)
- **ADR-0038** — Auto-Claim Protocol §Work-Stream Awareness (doctrinal home)
- **ADR-0044** — TDD RED contract discipline (d-test sign-off lane)
- **ADR-0049** — d-test framework (sister-pattern family definition)
- **ADR-0043** — 9-Lens Review Checklist (workflow discipline: lens h SHA pin + lens i 8 sub-categories)
- **ADR-0051** — engine perf flake vs regression codification (3-condition discriminator)
- **ADR-0053** — Layer 5 race pattern codification (CI guard vs status gate distinction)
- **RETRO-008 §3** — wip_overflow false positive origin (d058 doctrinal genesis)
- **RETRO-008 §11** — d-test persistence (this INDEX's doctrinal home)

— @developer, 2026-06-27T12:21+03:00, Sprint 14 P1 #6 AC5 close-out (d058 CI integration + INDEX registry creation, 2-commit split per arch verdict cmt 4817385451 fix protocol)