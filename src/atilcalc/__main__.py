"""Allow ``python -m atilcalc`` to invoke the CLI.

Per docs/test-plans/STORY-299-tests.md, the TDD RED tests invoke the CLI via
``python -m atilcalc <expr>`` for portability (no install step required from
a fresh checkout). This file is the entry point for that invocation.
"""

from atilcalc.cli import main

if __name__ == "__main__":
    raise SystemExit(main())
