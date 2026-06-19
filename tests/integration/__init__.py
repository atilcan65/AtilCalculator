"""Integration tests for STORY-010 AC2 — cross-device skin sync.

Refs Issue #72. Per ADR-0022 §Cross-device sync model:
- Single SQLite file on shared filesystem (NFS-equivalent)
- Multiple FastAPI processes (or multiple clients via HTTP) read/write same file
- No application-level sync layer

Two flavors:
- TC-3: 2 TestClient instances on the same app + same _db_path (simulates 2 LAN clients)
- TC-4: 2 subprocess FastAPI servers on different ports, same _db_path (true NFS simulation)

TDD red: skip on missing impl. Module-level probe checks:
- `atilcalc.api.main` importable
- `atilcalc.persistence.skin` importable
- `skin` table exists with key/value/updated_at
- 2 clients can read/write same DB concurrently without lock contention
"""
