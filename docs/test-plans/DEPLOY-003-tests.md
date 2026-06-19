# Test Plan: DEPLOY-003 — GET /healthz + smoke test + auto-rollback

**Refs**: Issue #132 (DEPLOY-003, P0). ADR-0027 §Decision.3 (Smoke test + rollback). ADR-0019 §HTTP API contract (Accepted — new endpoint extends the API surface).

## Scope
- **In scope**: New `GET /healthz` endpoint contract (200 happy path, 503 import-failure path); `git_sha` introspection via `subprocess.run(['git', 'rev-parse', 'HEAD'])`; contract test `tests/api/test_healthz.py`; post-deploy curl smoke test in DEPLOY-001 workflow; auto-rollback step on smoke-test failure; ADR-0019 amendment documenting the new endpoint.
- **Out of scope**: Deep health check (engine eval `2+2`); multi-tier rollback (blue/green); persistent health history.

## Constraints

- **`/healthz` is read-only and idempotent** — it MUST NOT mutate state, MUST NOT touch SQLite, MUST NOT require auth (per ADR-0027 §Decision.3 keep-it-cheap principle).
- **Response MUST be JSON-only** (no Decimal per ADR-0019-amend-2).
- **git_sha is `subprocess.run(['git', 'rev-parse', 'HEAD'])`** — fail-soft if not in a git repo (return `git_sha: null` rather than 500).

## Test Cases

### TC-1: GET /healthz — happy path (200 OK)
- **Setup**: FastAPI server started, engine importable, current commit known.
- **Steps**:
  1. `GET /healthz` (no auth, no body).
  2. Assert response status 200.
  3. Assert body is JSON: `{"status": "ok", "git_sha": "<40-char-hex>", "ts": "<iso-8601>"}`.
  4. Assert `git_sha` matches `git rev-parse HEAD` (length 40, hex chars only).
  5. Assert `ts` is a valid ISO-8601 timestamp (recent, within last 60s).
- **Expected**: 200 with structured health payload.

### TC-2: GET /healthz — engine import failure (503)
- **Setup**: simulate import failure (e.g., `PYTHONPATH` missing, or mock `import atilcalc.engine` raises ImportError).
- **Steps**:
  1. With import broken, `GET /healthz`.
  2. Assert response status 503.
  3. Assert body is JSON: `{"status": "error", "error": "<message>", "ts": "<iso-8601>"}`.
  4. Assert `git_sha` is still populated (git works even if engine import fails).
- **Expected**: 503 with error info; engine state distinguished from infra state.

### TC-3: /healthz response has NO auth requirement
- **Setup**: server started, no auth configured.
- **Steps**:
  1. `GET /healthz` with no Authorization header.
  2. Assert 200 (not 401).
- **Expected**: public endpoint; smoke-test probes don't need to carry creds.

### TC-4: /healthz response shape is JSON (not Decimal-serialized)
- **Setup**: server started.
- **Steps**:
  1. `GET /healthz`.
  2. Assert `Content-Type: application/json`.
  3. Assert response body has no `Decimal` artifacts (per ADR-0019-amend-2): no scientific notation like `1E+1`, no trailing zeros weirdness.
- **Expected**: clean JSON, no Decimal coercion issues.

### TC-5: git_sha is None when not in a git repo
- **Setup**: server started from a non-git directory (e.g., extracted tarball).
- **Steps**:
  1. `chdir` to a non-git tempdir, start server.
  2. `GET /healthz`.
  3. Assert 200.
  4. Assert `git_sha` is `null` (or absent — TBD by impl).
- **Expected**: graceful degradation, not 500.

### TC-6: ts is monotonically increasing across calls
- **Setup**: server started.
- **Steps**:
  1. `GET /healthz`, capture `ts1`.
  2. Sleep 1 second.
  3. `GET /healthz`, capture `ts2`.
  4. Assert `ts2 > ts1`.
- **Expected**: timestamp reflects current time.

### TC-7: Post-deploy smoke test in workflow (DEPLOY-001 integration)
- **Setup**: DEPLOY-001 workflow merged (TC-1 of DEPLOY-001).
- **Steps**:
  1. Read DEPLOY-001's workflow YAML post-deploy step.
  2. Assert it includes `curl -fsS http://$DEPLOY_HOST:PORT/healthz` (PORT per ADR-0010 systemd unit, default 8000).
  3. Assert `-fsS` flags (fail-on-error, silent, show-errors).
  4. Assert response is parsed for `git_sha` matching `${{ github.sha }}` (the just-deployed commit).
- **Expected**: smoke test validates the deploy succeeded.

### TC-8: Auto-rollback on smoke-test failure
- **Setup**: DEPLOY-001 workflow merged.
- **Steps**:
  1. Read the workflow YAML for the rollback step.
  2. Assert it includes `git reset --hard HEAD@{1}` (per ADR-0027 §Decision.3).
  3. Assert it includes `systemctl --user restart atilcalc-web.service` (rollback restart).
  4. Assert it retries `curl /healthz` once after rollback.
  5. Assert it pages owner via `scripts/notify.sh -l human` if second smoke test fails.
- **Expected**: automatic rollback + owner-page on persistent failure.

### TC-9: ADR-0019 amendment documents /healthz
- **Setup**: post-impl.
- **Steps**:
  1. Read `docs/decisions/ADR-0019-api-contract.md` (or new amendment file).
  2. Assert `/healthz` is listed in the endpoint table.
  3. Assert response shape is documented.
  4. Assert 200/503 status codes are documented.
- **Expected**: contract surface is canonical and discoverable.

## Adversarial Probes

### AP-1: /healthz leaks secrets in response
- Setup: check response for SSH keys, env vars, DB paths, internal IPs.
- Expected: only status + git_sha + ts. No infra details.

### AP-2: /healthz DoS via expensive git_sha lookup
- Setup: mock `git rev-parse` to take 30s.
- Expected: still returns 200 within 1s (per ADR-0027 §Open questions "keep it cheap"). If too slow, contract fails and impl must cache.

### AP-3: Subprocess injection via git binary hijack
- Setup: `$PATH` has a malicious `git` script before the real one.
- Expected: impl uses absolute path `/usr/bin/git` or validates via `shutil.which()` + `subprocess.run([absolute_path, ...])` (no shell=True).

### AP-4: Auto-rollback loops forever
- Setup: simulate scenario where HEAD@{1} also has a broken engine.
- Expected: workflow retries ONCE then pages owner; does not infinite-loop (would exhaust GH Action minutes).

### AP-5: Engine eval `2+2` deep health check (out of scope, but adversarial)
- Setup: if impl adds deep health check, ensure it doesn't add >100ms latency.
- Expected: per ADR-0027 §Open questions, "import-check + git_sha only" — deep eval is out of scope. If added, contract fails.

## Performance Concerns

- `/healthz` should respond <50ms p99 (cheap import-check + git rev-parse).
- 1000 concurrent requests under pytest-bench: p99 <200ms.
- No DB I/O — pure in-memory + subprocess.

## Regression Risk

- New endpoint does not modify existing endpoints (`/api/evaluate`, `/api/history`, `/api/skin`).
- Engine import path unchanged.
- API surface additive — no breaking changes per ADR-0019.

## Implementation Hints (for developer)

- File: `src/atilcalc/api/routes.py` (add `/healthz` route) OR new `src/atilcalc/api/health.py` (preferred for separation).
- Contract test: `tests/api/test_healthz.py` (TDD-red authored by tester in this PR).
- git_sha lookup: `subprocess.run(['git', 'rev-parse', 'HEAD'], capture_output=True, text=True, timeout=1, check=False)` — fail-soft on non-zero exit.
- ts: `datetime.now(timezone.utc).isoformat()`.
- 503 path: try-except around `from atilcalc.engine import evaluate` (or equivalent import check).
- ADR-0019 amendment: add a row to the endpoint table; cite ADR-0027 §Decision.3.

## Sprint 3 Sequencing

- DEPLOY-003's `/healthz` endpoint can land BEFORE DEPLOY-001 (workflow) and DEPLOY-002 (secrets).
- The contract tests in this plan are **immediately runnable** once the endpoint is implemented — no workflow YAML needed.
- TC-7 + TC-8 (workflow integration) are blocked on DEPLOY-001's merge — those tests TDD-red skip until then.
