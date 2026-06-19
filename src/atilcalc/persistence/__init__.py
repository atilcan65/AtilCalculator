"""Persistence layer for AtilCalculator (STORY-007, STORY-010).

Per ADR-0017 §engine ↔ UI separation + ADR-0022 (R-5, MERGED via PR #82):
- Engine NEVER imports this module (enforced by ``tests/engine/test_no_io_imports.py``).
- This module NEVER imports ``atilcalc.engine``.
- Pure stdlib: ``sqlite3`` + ``threading``. No new runtime deps for MVP-1.

Submodules
----------

- :mod:`atilcalc.persistence.history` — STORY-007 history table.
- :mod:`atilcalc.persistence.skin` — STORY-010 skin + skin_audit tables.

Public surface (re-exports)
---------------------------

- :func:`atilcalc.persistence.history.init_db` — idempotent history schema setup.
- :func:`atilcalc.persistence.history.insert_record` — write a record.
- :func:`atilcalc.persistence.history.get_records` — read newest-first.
- :func:`atilcalc.persistence.history.get_record_by_idempotency_key` — replay detection.
- :func:`atilcalc.persistence.history.reset_for_tests` — DELETE all rows.
- :func:`atilcalc.persistence.history.is_uuid_v4` — Idempotency-Key format check.
- :class:`atilcalc.persistence.history.IdempotencyConflictError` — replay conflict.
- :func:`atilcalc.persistence.skin.init_db` — idempotent skin schema setup.
- :func:`atilcalc.persistence.skin.get_current_skin` — read active skin.
- :func:`atilcalc.persistence.skin.set_current_skin` — atomic UPDATE + audit INSERT.
- :func:`atilcalc.persistence.skin.get_audit_by_idempotency_key` — replay detection.
- :func:`atilcalc.persistence.skin.reset_for_tests` — DELETE skin + audit rows.
"""
