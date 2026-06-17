#!/usr/bin/env bash
# d007-api-observability.sh — regression test for ADR-0019 §Observability.
#
# Bug-class defended against: "observability path is a no-op" lies (sibling
# of BUG #14 / BUG #25 / BUG #27). If the implementer removes the middleware,
# stops logging, or breaks the engine-error mapping, the static checks below
# fire. The runtime counterpart is tests/api/test_observability.py.
#
# Test cases (per Issue #35 body):
#   T1: src/atilcalc/api/middleware.py exists AND is referenced from main.py
#   T2: every route in routes.py has a corresponding log emission
#   T3: every EngineError subclass in engine/evaluator.py maps to an HTTP
#       status in routes.py; drift-detect: row count matches the number of
#       `^class \w+\(EngineError\)` declarations
#   T4: every PUT/POST (state-mutating) endpoint in routes.py accepts
#       `idempotency_key` (in body or Idempotency-Key header)
#   T5: pyproject.toml requires-python is `>=3.11` (not `>=3.X` — specific
#       per tester P3 #10 on PR #33)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d007-api-observability.sh
# Integrated:     called from scripts/tests/e2e-pilot.sh as T-d007
#                 (wired in by STORY-003a implementation PR per Issue #35
#                 acceptance criteria)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
API_DIR="$REPO_ROOT/src/atilcalc/api"
ENGINE_DIR="$REPO_ROOT/src/atilcalc/engine"
PYPROJECT="$REPO_ROOT/pyproject.toml"

# Colors (TTY-aware)
if [[ -t 1 ]]; then G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else G=""; R=""; B=""; D=""; fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# ============================================================================
# T1: middleware.py exists AND is referenced from main.py
# ============================================================================
section "T1: middleware.py exists + referenced from main.py"

T1_OK=true
MIDDLEWARE="$API_DIR/middleware.py"
MAIN_PY="$API_DIR/main.py"

if [ -f "$MIDDLEWARE" ]; then
  pass "middleware.py exists at $MIDDLEWARE"
else
  fail "middleware.py missing" "expected at $MIDDLEWARE (per ADR-0019 §Observability)"
  T1_OK=false
fi

if [ -f "$MAIN_PY" ]; then
  pass "main.py exists at $MAIN_PY"
else
  fail "main.py missing" "expected at $MAIN_PY (per ADR-0019)"
  T1_OK=false
fi

if [ "$T1_OK" = true ] && [ -f "$MAIN_PY" ] && [ -f "$MIDDLEWARE" ]; then
  # main.py must reference middleware (e.g. `app.add_middleware(...)` or
  # `from atilcalc.api.middleware import ...`).
  if grep -qE 'middleware' "$MAIN_PY"; then
    pass "main.py references middleware"
  else
    fail "main.py does not reference middleware" \
         "add an add_middleware(...) call or import to wire the observability harness"
  fi
else
  fail "cannot check middleware reference (T1 partial fail)" "files missing"
fi

# ============================================================================
# T2: every route in routes.py has a corresponding log emission
# ============================================================================
section "T2: every route in routes.py has a log emission"

ROUTES_PY="$API_DIR/routes.py"
if [ -f "$ROUTES_PY" ]; then
  # Extract route paths. The implementer uses FastAPI's @app.get/post/put
  # decorator style; we grep for the path argument.
  ROUTE_PATHS=$(grep -oE '@app\.(get|post|put|delete|patch)\("(/[^"]+)"' "$ROUTES_PY" | grep -oE '"/[^"]+"' | sort -u)

  if [ -z "$ROUTE_PATHS" ]; then
    fail "no routes found in routes.py" "expected @app.<method>(\"/path\") decorators"
  else
    ROUTE_COUNT=$(echo "$ROUTE_PATHS" | wc -l)
    # Each route should appear at least once in a log.* call within ~30 lines
    # of the decorator (heuristic for "log emission near the route handler").
    # For MVP, we accept a softer check: every route path appears in either
    # the routes file or middleware file with a log.* call.
    UNLOGGED=""
    while IFS= read -r path; do
      # Strip quotes
      p=$(echo "$path" | tr -d '"')
      # Look for log calls near the path
      if ! grep -qE "log\.(info|warning|error|debug).*$p" "$ROUTES_PY" "$MIDDLEWARE" 2>/dev/null; then
        # Soft check: middlewares log all requests, so a path appearing in
        # routes.py is enough if middleware.py logs by path.
        if [ -f "$MIDDLEWARE" ] && grep -qE 'log\.(info|warning|error|debug)' "$MIDDLEWARE"; then
          : # middleware logs all; OK
        else
          UNLOGGED="$UNLOGGED $p"
        fi
      fi
    done <<< "$ROUTE_PATHS"

    if [ -z "$UNLOGGED" ]; then
      pass "all $ROUTE_COUNT routes have log emissions (route or middleware)"
    else
      fail "routes without log emission:$UNLOGGED" \
           "add a log.<level> call near each route, or ensure middleware logs by path"
    fi
  fi
else
  fail "routes.py missing" "expected at $ROUTES_PY (per ADR-0019)"
fi

# ============================================================================
# T3: every EngineError subclass maps to an HTTP status; drift-detect
# ============================================================================
section "T3: EngineError → HTTP status mapping (with drift-detect)"

EVALUATOR="$ENGINE_DIR/evaluator.py"
if [ -f "$EVALUATOR" ] && [ -f "$ROUTES_PY" ]; then
  # Count EngineError subclasses in evaluator.py
  ENGINE_CLASSES=$(grep -cE '^class \w+\(EngineError\)' "$EVALUATOR" 2>/dev/null || echo 0)
  # Count error-envelope mapping rows in routes.py. Expected shape per ADR-0019:
  #   EngineError → 500  (catch-all)
  #   ExpressionSyntaxError → 400
  #   DivisionByZeroError → 400
  #   UndefinedOperatorError → 400
  # Grep for lines that mention both an EngineError subclass name and a status code.
  MAPPING_ROWS=$(grep -cE '(ExpressionSyntaxError|DivisionByZeroError|UndefinedOperatorError|EngineError).*40[04]|.*500' "$ROUTES_PY" 2>/dev/null || echo 0)

  if [ "$ENGINE_CLASSES" -gt 0 ]; then
    pass "engine has $ENGINE_CLASSES EngineError subclass(es)"
  else
    fail "no EngineError subclasses found in evaluator.py" \
         "expected at least EngineError + 1 subclass per ADR-0019"
  fi

  if [ "$MAPPING_ROWS" -ge "$ENGINE_CLASSES" ]; then
    pass "routes.py has $MAPPING_ROWS mapping row(s) for $ENGINE_CLASSES engine class(es)"
  else
    fail "routes.py mapping rows ($MAPPING_ROWS) < engine classes ($ENGINE_CLASSES)" \
         "drift detected — add a status mapping for each EngineError subclass (ADR-0019 §Error mapping)"
  fi
else
  fail "evaluator.py or routes.py missing" "cannot run drift check"
fi

# ============================================================================
# T4: every PUT/POST (state-mutating) endpoint accepts idempotency_key
# ============================================================================
section "T4: state-mutating endpoints accept idempotency_key"

if [ -f "$ROUTES_PY" ]; then
  # Find all @app.put and @app.post decorators with their path + nearby body
  # Then check that the corresponding handler references idempotency_key
  PUT_POST_HANDLERS=$(grep -nE '@app\.(put|post)\("' "$ROUTES_PY" || true)
  if [ -z "$PUT_POST_HANDLERS" ]; then
    # No mutating endpoints — vacuously true (e.g. for read-only APIs).
    pass "no PUT/POST endpoints; idempotency_key requirement is vacuously satisfied"
  else
    MISSING_KEY=""
    while IFS= read -r line; do
      lineno=$(echo "$line" | cut -d: -f1)
      # Look for `idempotency_key` in the next 30 lines (the handler body)
      handler=$(sed -n "${lineno},$((lineno+30))p" "$ROUTES_PY")
      if ! echo "$handler" | grep -qE 'idempotency_key'; then
        # Extract the path
        path=$(echo "$line" | grep -oE '"/[^"]+"' | tr -d '"')
        MISSING_KEY="$MISSING_KEY $path"
      fi
    done <<< "$PUT_POST_HANDLERS"

    if [ -z "$MISSING_KEY" ]; then
      pass "all PUT/POST handlers reference idempotency_key"
    else
      fail "state-mutating endpoints without idempotency_key:$MISSING_KEY" \
           "ADR-0019 requires idempotency_key on every PUT/POST"
    fi
  fi
else
  fail "routes.py missing" "cannot check idempotency"
fi

# ============================================================================
# T5: pyproject.toml requires-python is >=3.11 (not >=3.X)
# ============================================================================
section "T5: pyproject.toml requires-python is >=3.11"

if [ -f "$PYPROJECT" ]; then
  REQ=$(grep -E '^requires-python' "$PYPROJECT" | head -1 | sed -E 's/.*= *["'\'']([^"'\'']+)["'\''].*/\1/')
  if [ -z "$REQ" ]; then
    fail "requires-python not set" "ADR-0017 pins Python 3.11+"
  elif [ "$REQ" = ">=3.11" ] || [ "$REQ" = ">=3.11,<3.13" ] || [ "$REQ" = ">=3.11,<3.14" ]; then
    pass "requires-python = $REQ (matches ADR-0017)"
  else
    fail "requires-python = $REQ" \
         "expected >=3.11 per ADR-0017; got $REQ"
  fi
else
  fail "pyproject.toml missing" "cannot check requires-python"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
printf "${B}==== d007 summary ====${D}\n"
printf "  TOTAL=%d PASS=%d FAIL=%d\n" "$((PASS+FAIL))" "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
