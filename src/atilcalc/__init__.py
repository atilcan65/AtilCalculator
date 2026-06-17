"""AtilCalculator — keyboard-first web calculator with decimal-precision arithmetic.

Public API is re-exported from subpackages. The engine module
(:mod:`atilcalc.engine`) is the pure-Python expression evaluator; the
HTTP surface (:mod:`atilcalc.api`, deferred to STORY-002-followup) wraps
it; the CLI (:mod:`atilcalc.cli`, deferred post-MVP-1) is a thin Typer
wrapper around the same engine.

Architectural invariant (ADR-0017 §engine ↔ UI separation):
    The engine module has NO I/O dependencies. CLI and HTTP surfaces
    import from ``engine``; ``engine`` never imports from CLI or HTTP.
"""

__version__ = "0.1.0"
