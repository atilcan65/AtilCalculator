"""Persistence layer for AtilCalculator (STORY-007, refs #69).

Per ADR-0017 §engine ↔ UI separation + ADR-0022 (R-5, in-review via PR #82):
- Engine NEVER imports this module (enforced by ``tests/engine/test_no_io_imports.py``).
- This module NEVER imports ``atilcalc.engine``.
- Pure stdlib: ``sqlite3`` + ``threading``. No new runtime deps for MVP-1.

Public surface
--------------

- :func:`atilcalc.persistence.history.init_db` — idempotent schema setup.
- :func:`atilcalc.persistence.history.insert_record` — write a record (UNIQUE on idempotency_key).
- :func:`atilcalc.persistence.history.get_records` — read newest-first, optional substring filter.
- :func:`atilcalc.persistence.history.get_record_by_idempotency_key` — for replay detection.
- :func:`atilcalc.persistence.history.reset_for_tests` — DELETE all rows (test-only).
- :func:`atilcalc.persistence.history.is_uuid_v4` — Idempotency-Key format validation.
- :class:`atilcalc.persistence.history.IdempotencyConflictError` — raised on key reuse with different payload.
"""
