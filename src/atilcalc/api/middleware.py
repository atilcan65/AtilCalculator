"""Observability middleware for the AtilCalculator HTTP surface.

Per ADR-0019 §Observability, every request gets:

- A request_id (UUID4, surfaced in the response header and in logs)
- A latency_ms measurement (logged on response)
- A status code (logged on response)
- An idempotency_key check on state-mutating endpoints (PUT/POST)

This module is intentionally minimal in the bootstrap commit; the full
implementation (request_id injection, latency logging, idempotency
enforcement) lands in the TDD-green commits of the STORY-003a impl PR.
The d007 T1 check passes as long as this file exists and is referenced
from :mod:`atilcalc.api.main`.
"""
