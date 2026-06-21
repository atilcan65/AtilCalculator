# Test Plan: STORY-E2E-DEPLOY-VERIFY — Sprint 3 P0 DoD §4/§5 E2E verification harness (refs #188, #189, PR #174, #169)

**Refs**: Issue #188 (this story), Issue #189 (RCA-16 v9 ExecStart fail — currently blocks), Issue #175 (RCA-15 owner pre-req APPLIED ✅), Issue #171 (RCA-14 v9), PR #174 (v9 systemd integration, b260f43), PR #169 (RCA-12 v8, 094997e), ADR-0010 (systemd user-service), ADR-0027 §3 (smoke test + rollback), ADR-0030 (self-hosted runner).

## Scope

### In scope
- `scripts/tests/d019-e2e-deploy-verify.sh` — new regression test (3-5 source-grep cases, parallel to d014/d015/d016/d017/d018)
- Verification of all 7 ACs from Issue #188 (AC1-AC7)
- E2E runbook for 3+ consecutive v9 deploys (not in test file, but referenced)
- Regression verification: d014, d015, d016, d017, d018 still PASS after v9 path lands

### Out of scope
- Multi-host deploy (deferred to Sprint 5+)
- Staging environment (no infra)
- PR with run-ID-based smoke test (deferred)

## Test Cases

### TC-1: d019 source-grep test exists and is executable
- **Setup**: clone fresh main, run `ls scripts/tests/d019-*`
- **Steps**:
  1. `ls -la scripts/tests/d019-e2e-deploy-verify.sh` shows executable bit
  2. `bash scripts/tests/d019-e2e-deploy-verify.sh` exits 0 (all 3-5 TCs GREEN)
- **Expected**: file exists, executable, 3-5 TCs all PASS

### TC-2: AC1 source-grep — deploy-runner.sh exits 0 on v9 success path
- **Setup**: simulate v9 success (unit registered, systemctl start works)
- **Steps**:
  1. `grep -E 'exit 0|exit_code.*0' scripts/deploy-runner.sh` shows multiple exit-0 paths
  2. Header documents "exit code 0 = success"
- **Expected**: deploy-runner.sh has clear exit-0 path; not just `exit $?`

### TC-3: AC2/AC3 source-grep — `ss -tlnp 'sport = :8000'` etimes check is in the post-deploy block
- **Setup**: read deploy-runner.sh
- **Steps**:
  1. `grep -E 'ss -tlnp.*sport.*8000' scripts/deploy-runner.sh` returns hit
  2. `grep -E 'etimes' scripts/deploy-runner.sh` returns hit
  3. `before_match` helper verifies etimes check is AFTER `systemctl --user start`
- **Expected**: post-deploy port-PID-etime check present, in correct source order

### TC-4: AC4 source-grep — `systemctl --user is-active atilcalc-web.service` check exists
- **Setup**: read deploy-runner.sh
- **Steps**:
  1. `grep -E 'systemctl --user is-active atilcalc-web' scripts/deploy-runner.sh` returns hit
  2. Check is in a "between-deploys" or "post-deploy" block (not the preflight)
- **Expected**: explicit is-active check verifies systemd-managed service is healthy

### TC-5: AC5 source-grep — `curl -fsS http://192.168.1.199:8000/healthz` smoke test exists
- **Setup**: read deploy-runner.sh
- **Steps**:
  1. `grep -E 'curl.*healthz|curl.*192.168.1.199:8000' scripts/deploy-runner.sh` returns hit
  2. Smoke test is in the post-deploy block (after `systemctl --user start`)
  3. Smoke test exit code propagates to deploy-runner.sh exit (per ADR-0027 §3)
- **Expected**: smoke test present, exit code propagates

### TC-6: AC7 source-grep — RCA-12 v8 pre-check + post-check preserved
- **Setup**: read deploy-runner.sh
- **Steps**:
  1. `grep -E 'fail.*5.*cross-user|fail.*6.*post-restart' scripts/deploy-runner.sh` returns 2 hits
  2. RCA-12 pre-check is in step 3 (preflight) OR step 4 (restart)
  3. RCA-12 post-check is in step 4 AFTER systemctl start
- **Expected**: both RCA-12 exit codes preserved (5 + 6) on v9 path

### TC-7: RCA-16 regression (if RCA-16 root cause is XDG_RUNTIME_DIR) — user context
- **Setup**: read deploy-runner.sh
- **Steps**:
  1. `grep -E 'sudo -u atilcan|XDG_RUNTIME_DIR' scripts/deploy-runner.sh` returns hit (post RCA-16 fix)
- **Expected**: deploy-runner.sh handles the user-bus isolation (either sudo, env, or unit directive)
- **NOTE**: This TC will be RED until RCA-16 is resolved. Acceptable per #188 AC7 — d019 contract is forward-looking.

## Adversarial Probes

### AP-1: 3+ consecutive deploys evidence
- **Probe**: AC1 says "3+ consecutive self-hosted auto-deploys succeed". What counts as "consecutive"? Same session? Same day? Same week?
- **Recommendation**: same day, 3 distinct run IDs in the deploy log. Document the 3 run IDs in the PR body for auditability.

### AP-2: 5+ min persistence — what about podman/systemd-restart loops?
- **Probe**: if the unit has `Restart=always` + `StartLimitBurst=3`, a service that crashes within 5 min would be restarted by systemd. The "5+ min LISTEN" check would pass even if the service is in a restart loop.
- **Recommendation**: also check `systemctl --user show atilcalc-web.service -p NRestarts` to ensure no restart loop. Or use the etimes check (AC3) — a restarted service has fresh etimes.

### AP-3: `/healthz` endpoint — what does it actually return?
- **Probe**: is `/healthz` implemented? The current prod page is just the calculator. If the endpoint doesn't exist, AC5 fails on every deploy.
- **Recommendation**: confirm `/healthz` is in the codebase BEFORE running the 3 deploys. If not, add as a Sprint 4 P1 follow-up.

### AP-4: PR #187 (the "main @ 8365daaa" in RCA-16 deploy log)
- **Probe**: PR #187 was merged at 19:58:36Z, just before RCA-16 fail. What was in PR #187? Did it change deploy-runner.sh or the systemd unit? If yes, PR #187 may be a co-conspirator.
- **Recommendation**: read PR #187 diff as part of RCA-16 triage. If PR #187 changed the unit file, that may be the actual root cause (not the 3 likely causes in #189).

### AP-5: Race condition between pre-check and start
- **Probe**: between `systemctl --user stop` and `systemctl --user start` (only milliseconds apart per the RCA-16 timeline), the unit may not have fully stopped. The start may fail with "unit is already running" or "unit is being stopped".
- **Recommendation**: add a `sleep 1` or a `systemctl --user is-active` wait loop between stop and start.

## Performance Concerns

- **Deploy time budget**: per RCA-16 timeline, the v9 deploy from pickup to fail was 6 seconds. With the RCA-16 fix, the E2E deploy should be <30 seconds (3 deploys <90 seconds total). The 5+ min persistence check is separate (5 min per deploy = 15 min for 3 deploys).
- **Test runtime budget**: d019 source-grep tests should complete in <5 seconds (no network calls, no deploys).
- **E2E runtime budget**: 3 deploys × (30s deploy + 5 min persistence) = ~16 min minimum. Sprint 3 P0 DoD §4 verification = ~20 min.

## Regression Risk

- **d014 (RCA-9 FAIL-or-CREATE)**: 11 cases — v9 preflight should preserve FAIL-or-CREATE. **Risk: LOW** (RCA-12 v8 is additive, doesn't touch preflight)
- **d015 (Katman 1+2 dev-idle)**: 9 cases — `scripts/dev-idle-monitor.sh` orthogonal to deploy-runner.sh. **Risk: NONE**
- **d016 (RCA-11 runtime deps)**: 8 cases — `[web] extra` in pyproject.toml. **Risk: NONE** (Sprint 3 added, not removed)
- **d017 (RCA-12 cross-user)**: 8 cases — port-defense pre-check + post-check. **Risk: LOW** (v9 changes are additive, not subtractive)
- **d018 (RCA-14 systemd)**: 9 cases — v9 systemd integration. **Risk: HIGH** (RCA-16 may require v10 changes, would invalidate T1-T9 in d018)

## Open Questions

1. **Q1 (architect)**: does d019 need to test RCA-16 (XDG_RUNTIME_DIR) fix, or just the v9 baseline? My recommendation: add a TC-N (currently TC-7) that turns RED until RCA-16 lands, then GREEN. Forward-looking.
2. **Q2 (developer)**: what does `/healthz` actually return? 200 with `{"status":"ok"}`? 200 with HTML? Need to know for AC5 assertion.
3. **Q3 (owner)**: is PR #187 relevant to RCA-16? Should I read its diff?
4. **Q4 (orchestrator)**: d019 + d019-ext pattern (parallel to d094 + d094-ext)? My recommendation: NO — d019 is a single test file (3-5 cases per AC6), not split like d094.

## Done When

- [ ] d019 test file exists, 3-5 TCs, all GREEN
- [ ] RCA-16 resolved (so TC-7 can pass)
- [ ] 3+ consecutive v9 deploys documented with run IDs
- [ ] All 5 d-series tests still PASS (d014, d015, d016, d017, d018)
- [ ] Issue #171 closed (RCA-14 follow-up)
- [ ] Issue #175 closed (RCA-15 follow-up)
- [ ] Sprint 3 P0 DoD §4/§5 close-out

## Test Plan Ownership

- **Author**: @tester (TDD red contract before developer implementation)
- **Reviewer**: @architect (7-lens on the test contract) + @product-manager (AC coverage)
- **Implementer**: @developer (writes the d019 test file based on this contract, may extend with additional cases)
- **Verifier**: @tester (signs off on the final d019 + E2E evidence)
