# Test Plan: STORY-019 — d031 TC5/6/7 update (work-stream awareness TC expansion)

> **Owner:** @tester (auto-claimed 2026-06-27T15:16:35Z, WIP=1/2)
> **Branch:** `feat/story-019-d031-tc-expansion`
> **Spec:** Issue #520, AC1 TC5 priority/age work-stream + AC2 TC6 ready=0 work-stream + AC3 TC7 dep work-stream + AC4 10/10 TC count per ADR-0044
> **Sister-pattern:** d058 (`scripts/tests/d058-claim-wip-workstream.sh`, 9 TCs, PR #506 + PR #511)

## Scope

### In scope
- Add 2 work-stream aware TCs (TC9, TC10) to `scripts/tests/d031-claim-next-ready.sh`
- Update d031 docstring header (drift: header says "5+2=7" but actual is 8; target 10 post-merge)
- Add `--self-test` flag (sister-pattern d058)
- Update `scripts/tests/INDEX.md` d031 entry (TC count: 7 → 10)
- Verify `--self-test` runs 10/10 GREEN locally
- Draft PR with 4-cat invariant + dual-channel peer-ping

### Out of scope
- `scripts/claim-next-ready.sh` impl changes (already work-stream aware via ADR-0038 §Work-Stream Awareness amendment, PR #504 squash @ a45c613)
- CI integration of d031 (sister-pattern d058 integration is Story-014 AC5, Issue #508 — already SHIPPED for d058)
- Other d-test family extensions (d059, d060, d061 handled separately)

## Test Cases

### Existing TCs (TC1-TC8, unchanged behavior)

| TC | Name | Status |
|---|---|---|
| TC1 | 3 ready items P0/P1/P2 → claim P0 first (priority sort) | ✅ existing |
| TC2 | 2 ready items same P1, different ages → claim oldest (age tie-break) | ✅ existing |
| TC3 | ready item with open dep → skip; another without dep → claim | ✅ existing |
| TC4 | 2 in-progress + 1 ready → exit 3, no claim (WIP cap, pre-work-stream) | ✅ existing |
| TC5 | 0 ready items → exit 1, no claim (negative) | ✅ existing |
| TC6 | usage error (no role arg) → exit 2 | ✅ existing |
| TC7 | invalid role → exit 2 | ✅ existing |
| TC8 | audit log written on claim (TC1 follow-up) | ✅ existing |

### New TCs (TC9, TC10) — work-stream awareness extension (sister-pattern d058)

#### TC-9: 2 in-progress same work-stream (PR cluster) + 1 ready standalone → claim succeeds

- **Setup**: fake-gh returns `status:in-progress` list with 2 issues that share a Closes-anchor (PR cluster, work-stream=1 per ADR-0038 §Work-Stream Awareness). Plus 1 ready standalone issue (different work-stream).
- **Steps**:
  1. Run `bash scripts/claim-next-ready.sh developer` with fake-gh on PATH.
  2. Assert exit code = 0 (claim succeeded, NOT WIP-capped).
  3. Assert log contains `claimed #<ready-issue>`.
  4. Assert log does NOT contain `WIP limit reached`.
- **Expected**: Work-stream awareness collapses PR cluster to 1 work-stream; ready standalone is in different work-stream → claim succeeds.
- **Sister-pattern**: d058 TC1 (PR cluster → WIP=1 per work-stream rule).

#### TC-10: 2 in-progress standalone + 1 ready standalone (same work-stream type) → exit 3, no claim

- **Setup**: fake-gh returns `status:in-progress` list with 2 standalone issues (no Closes-anchor, work-stream=2). Plus 1 ready standalone issue.
- **Steps**:
  1. Run `bash scripts/claim-next-ready.sh developer` with fake-gh on PATH.
  2. Assert exit code = 3 (WIP cap, work-stream-aware).
  3. Assert stderr contains `WIP limit reached`.
  4. Assert log does NOT contain `EDIT` (no claim edit attempted).
- **Expected**: All 3 issues count as 3 separate work-streams; WIP cap (2/2) hit before claim.
- **Sister-pattern**: d058 TC5 (WIP limit reached → exit 3, work-stream-aware).

## Adversarial Probes

- **Race window**: between `gh issue list` (WIP count) and `gh issue edit` (claim), a peer could claim. d031 doesn't simulate this; mitigation is single-actor + atomic edit.
- **PR cluster collapse**: TC9 covers 2-issues-cluster-to-1-workstream. Adversarial: 3-issues-cluster? Test only covers 2; future TCs if needed.
- **Mixed cluster + standalone in-progress**: not covered in TC9/TC10; d058 TC3 covers this (out of scope here, d058 lane).
- **Audit log edge**: TC8 already verifies content; adversarial: missing AUTO_CLAIM_LOG_DIR env? Mitigated by impl §repo_name branch.

## Fake gh Extension

Current fake-gh factory (TC1-TC8) returns canned JSON for `status:ready` + `status:in-progress`. TC9 + TC10 require the ready/in-progress issues to carry work-stream metadata:

- **PR cluster encoding**: issue body includes `"Closes #N"` for one of the cluster members, OR labels include `cluster:PR-<num>`.
- **Standalone encoding**: no Closes-anchor, no cluster label.

Per ADR-0038 §Work-Stream Awareness, work-stream detection = cluster collapse on shared Closes-anchor. The fake-gh must therefore include the body content (or a label marker) for the impl to detect.

## Docstring Drift Audit

Current d031 header (line 2): `d031-claim-next-ready.sh — ADR-0038 §Layer 2 regression test (5 TCs).`
Actual TCs: TC1-TC8 (8 total, includes TC8 audit log bonus not in header).
AC4 target: 10/10 TC count.

**Drift table**:

| Source | Claim | Actual |
|---|---|---|
| Header line 2 | "5 TCs" | 8 TCs (TC1-TC8) |
| Header "Plus 2 sanity TCs" | TC6, TC7 | TC6, TC7 ✓ |
| Header missing TC8 | (audit log bonus) | TC8 = audit log follow-up |
| AC4 target | 10/10 | 8 → 10 (after TC9+TC10) |

**Fix**: Update header to `d031-claim-next-ready.sh — ADR-0038 §Layer 2 + §Work-Stream Awareness regression test (10 TCs).` with full TC1-TC10 enumeration.

## Performance

- d031 --self-test runtime: ~2s (8 TCs × ~250ms each)
- Post TC9+TC10 target: ~2.5s (10 TCs × ~250ms each)
- No DB / no network — pure bash + fake-gh factory

## Regression Risk

- ✅ d031 is the BASE Layer 2 test; d058 is the EXTENSION. TC9+TC10 add work-stream awareness coverage at the BASE layer (sister-pattern to d058). No impl changes needed; impl already work-stream aware via PR #504.
- ✅ INDEX.md update is additive (no churn to d058 entry).
- ⚠️ TC9 requires fake-gh to emit issue body content (currently emits only labels). Impl detail: impl reads body for Closes-anchor parse, so fake-gh must return body string.

## Sign-off Checklist

- [ ] d031 source has 10 sections (TC1-TC10), all `pass()`/`fail()` invocations
- [ ] d031 --self-test runs 10/10 GREEN locally
- [ ] d031 docstring header updated to "10 TCs" with full TC1-TC10 list
- [ ] INDEX.md d031 entry updated: `7/7 (5+2 sanity)` → `10/10 (5+2+1 audit + 2 work-stream)`
- [ ] Branch `feat/story-019-d031-tc-expansion` pushed
- [ ] Draft PR opened with 4-cat invariant (type:feature + status:in-review + agent:tester + cc:developer, cc:architect)
- [ ] Auto-ping dev + arch + orch (dual-channel per ADR-0033)
- [ ] cc:developer added for impl-pairing review (Lane Transfer Pattern)

## Cross-refs

- **Issue #520** — Sprint 15 P1 #5 / STORY-019 (this story)
- **Issue #505** — Sprint 14 P1 #6 / STORY-014 d058 work-stream awareness impl
- **Issue #497** — Sprint 14 P1 #6 predecessor
- **PR #504** — ADR-0038 §Work-Stream Awareness amendment (squash @ a45c613)
- **PR #506** — d058 impl + d-test on main (squash @ 226b546)
- **PR #511** — d058 CI integration (squash @ 70e33d7)
- **ADR-0038** — Auto-Claim Protocol §Work-Stream Awareness (doctrinal home)
- **ADR-0044** — TDD RED-first contract (sign-off lane)
- **ADR-0049** — d-test framework sister-pattern family
- **RETRO-008 §3** — wip_overflow false positive origin
- **RETRO-009 §6** + **§11** — Sprint 15 RETRO d-test maintenance context
- **Issue #238** — no-standby doctrine (cycle driver)

— @tester, 2026-06-27, STORY-019 test plan