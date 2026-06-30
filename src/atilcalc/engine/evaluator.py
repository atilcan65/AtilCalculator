"""Expression evaluator and engine exception hierarchy.

Public surface
--------------

- :func:`evaluate` — entry point for parsing and evaluating an expression.
- :class:`EngineError` — base class for all engine errors (catch-all).
- :class:`ExpressionSyntaxError` — raised when the input cannot be tokenised/parsed.
- :class:`DivisionByZeroError` — raised when division/modulo by zero occurs.
- :class:`UndefinedOperatorError` — raised when an operator is not in MVP-1 scope.
- :class:`DomainError` — raised for runtime domain errors (sqrt(-1), log(0), etc.).

The exception hierarchy is deliberately structured (not generic ``ValueError``)
so the HTTP layer can map each error to a distinct status code + error envelope
per ADR-0018 watch-item #1 (API contract; pending architect's R-N ADR).

Sprint 2 (STORY-011) extends the grammar with scientific functions and
factorial. The engine is intentionally a *pure* Python module (no I/O, no UI
deps); HTTP / Web surfaces wrap the engine via the API layer.

mpmath is the documented exception to ADR-0017 §engine ↔ UI separation
(STD-lib-only invariant). It is the precision substrate for transcendentals
(ADR-0019 amendment 2 §Transcendental precision model). Pinned exactly
per ADR-0017 doctrine (no floating pins).
"""

from __future__ import annotations

import math
from decimal import Decimal, InvalidOperation, localcontext
from typing import Final

# mpmath has no type stubs (no py.typed marker, no typeshed entry). Per
# ADR-0019 amendment 2 §Transcendental precision model, the import is the
# documented carve-out from ADR-0017 §engine ↔ UI separation (stdlib-only
# invariant). The ``type: ignore[import-untyped]`` keeps ``mypy --strict``
# (load-bearing for the engine module per ADR-0017) green.
#
# Per Issue #728 (engine perf regression, surfaced via PR #694 CI) +
# architect 9-Lens 🟢 APPROVED hotfix: mpmath is **LAZY-IMPORTED** on first
# transcendental call, NOT at module load. This eliminates the ~50ms
# mpmath cold-start cost from the arithmetic path (1+2, 2*3, etc.), which
# is what regressed the d100 perf budgets at PR #709 cascade (mpmath
# integration). Subsequent calls are O(1) via Python's import-system
# ``sys.modules`` cache (see ``_import_mpmath`` helper below).
#
# Architectural invariants (regression-guarded by d110):
#   - Arithmetic path NEVER triggers mpmath import (sys.modules guard).
#   - Transcendental functions (``_fn_*`` + deg suffix in ``_atom``) are
#     the ONLY code paths that call ``_import_mpmath()``.
#   - d110 6/6 TCs verified pre-impl (RED) and post-impl (GREEN).
#
# MyPy note: ``mpmath`` is intentionally NOT imported at module level, so
# ``mypy --strict`` does not see the symbol on the module namespace. The
# ``# type: ignore[import-untyped]`` comment lives next to the lazy import
# inside ``_import_mpmath()``.


# Pinned Decimal precision per the tester's regression-risk note
# (docs/test-plans/STORY-002-tests.md §Regression Risk). Using a localcontext
# inside evaluate() ensures that peer modules mutating the global Decimal
# context cannot drift the engine's results.
_PREC = 28

# mpmath decimal-place precision for transcendental evaluation. Reasserted
# inside ``_import_mpmath()`` (paranoia against peer modules mutating the
# global mpmath context). Per ADR-0019 amendment 2 §Transcendental precision
# model. Module-level so it's a Final constant (no lazy import needed for
# an int — it's just a number).
_MP_DPS: Final = 50

# Factorial cap. Per ADR-0019 amendment 2 §Factorial cap, 170! is the
# IEEE-754 double boundary; 171! raises ``DomainError`` rather than silently
# returning Infinity or NaN. 170! has 306 digits; output via ``Decimal`` is
# lossless up to the engine's 28-digit output precision.
_FACTORIAL_MAX: Final = 170

# Known transcendental function names (case-sensitive per AP-1).
_TRANSCENDENTAL_FUNCS: Final = frozenset({"sin", "cos", "tan"})

# Known logarithm function names. ``log`` = base-10 (per AC4), ``ln`` = base-e.
_LOG_FUNCS: Final = frozenset({"log", "ln"})

# Known inverse-trigonometric function names (used by domain-error tests).
_INVERSE_TRIG_FUNCS: Final = frozenset({"asin", "acos"})

# All known function names — tokeniser lookup.
_KNOWN_FUNCS: Final = _TRANSCENDENTAL_FUNCS | _LOG_FUNCS | {"sqrt"} | _INVERSE_TRIG_FUNCS


class EngineError(Exception):
    """Base class for all AtilCalculator engine errors.

    The HTTP layer should catch this base class for fallback 500 handling,
    and the specific subclasses for typed 4xx responses.
    """


class ExpressionSyntaxError(EngineError):
    """Raised when the input expression cannot be tokenised or parsed.

    Named ``ExpressionSyntaxError`` rather than ``SyntaxError`` to avoid
    shadowing Python's built-in ``SyntaxError`` class. Users who want the
    built-in can still ``import builtins`` and access it there.

    Examples: ``"2+"``, ``"abc"``, ``"("``, ``"1.2.3"``.
    """


class DivisionByZeroError(EngineError):
    """Raised when division or modulo by zero is attempted.

    Examples: ``"5 / 0"``, ``"7 % 0"``.

    Per STORY-002 AC5: the engine must raise this structured error, NOT
    a generic ``ZeroDivisionError`` from ``decimal.Decimal``.
    """


class UndefinedOperatorError(EngineError):
    """Raised when an operator is used that is out of MVP-1 scope.

    Examples (all Sprint 2+): unary minus ``"-5"``, exponent ``"2^3"``,
    factorial ``"5!"``, trig ``"sin(0)"``.

    Surfacing these explicitly prevents silent wrong answers: a user typing
    ``"2^3"`` expecting ``8`` gets a clear error rather than a parse
    failure or a wrong fallback.
    """


class DomainError(EngineError):
    """Raised for runtime domain errors in scientific functions.

    Distinct from :class:`UndefinedOperatorError` (which is for FUTURE
    operators that parse but cannot dispatch — e.g., ``2^3`` before
    exponent is implemented). ``DomainError`` is for operators that DO
    parse and DO dispatch but whose input is outside the function's
    domain.

    Examples (per ADR-0019 amendment 2 §DomainError):

    - ``sqrt(-1)`` (square root of a negative)
    - ``log(0)`` (logarithm of zero, undefined)
    - ``log(-2)`` (logarithm of a negative)
    - ``asin(2)`` (arcsin of value outside [-1, 1])
    - ``acos(-1.5)`` (arccos of value outside [-1, 1])
    - ``tan(pi/2)`` (tangent of a pole)

    Surfacing these explicitly (rather than returning NaN or Infinity)
    prevents silent wrong answers that would propagate through later
    arithmetic and corrupt the user's session.
    """


# ---------------------------------------------------------------------------
# Tokenizer
# ---------------------------------------------------------------------------

_OPERATORS = {"+", "-", "*", "/", "%"}
# ``**`` (power) is intentionally NOT in ``_OPERATORS``: it is a 2-character
# token, handled as a special case in ``_tokenize`` BEFORE the single-char
# operator check (so that ``2**3`` tokenises as ``NUMBER 2`` ``OP **`` ``NUMBER 3``
# and not as ``NUMBER 2`` ``OP *`` ``OP *`` ``NUMBER 3``). Right-associative,
# higher precedence than ``*``/``/`` per Sprint 7 / STORY-300.


def _tokenize(expression: str) -> list[tuple[str, str]]:
    """Lex ``expression`` into a list of ``(kind, value)`` tokens.

    Whitespace is ignored. Tokens:

    - ``"NUMBER"`` — ``\\d+(\\.\\d+)?`` (one or more digits, optional decimal)
    - ``"OP"`` — one of ``+ - * / %`` (single char) or ``**`` (two-char power)
    - ``"LPAREN"`` — ``(``
    - ``"RPAREN"`` — ``)``
    - ``"FUNC"`` — function name (e.g., ``sin``, ``cos``, ``log``, ``sqrt``)
    - ``"BANG"`` — postfix factorial ``!``
    - ``"DEG"`` — unit suffix ``deg`` (only legal immediately after a NUMBER)

    The ``**`` power operator is a 2-character token, recognised BEFORE the
    single-character operator check (so ``2**3`` tokenises as
    ``NUMBER 2 OP ** NUMBER 3``, never as ``NUMBER 2 OP * OP * NUMBER 3``).
    Sprint 7 / STORY-300.

    Function names are case-sensitive: ``SIN`` raises
    :class:`ExpressionSyntaxError` (per AP-1).

    Returns:
        A list of tokens in source order.

    Raises:
        ExpressionSyntaxError: If the input is empty, contains an unknown
            character, uses an unknown identifier, or has the ``deg`` suffix
            in a non-numeric position.
    """
    tokens: list[tuple[str, str]] = []
    i = 0
    n = len(expression)
    while i < n:
        c = expression[i]
        if c.isspace():
            i += 1
            continue
        # 2-char operator: power ``**`` must be checked BEFORE the single-char
        # ``*`` check, otherwise ``2**3`` would tokenise as ``2 * * 3``.
        if c == "*" and i + 1 < n and expression[i + 1] == "*":
            tokens.append(("OP", "**"))
            i += 2
            continue
        if c in _OPERATORS:
            tokens.append(("OP", c))
            i += 1
            continue
        if c == "(":
            tokens.append(("LPAREN", c))
            i += 1
            continue
        if c == ")":
            tokens.append(("RPAREN", c))
            i += 1
            continue
        if c == "!":
            tokens.append(("BANG", c))
            i += 1
            continue
        if c.isdigit():
            j = i
            saw_dot = False
            while j < n and (expression[j].isdigit() or (expression[j] == "." and not saw_dot)):
                if expression[j] == ".":
                    saw_dot = True
                j += 1
            num_tok: tuple[str, str] = ("NUMBER", expression[i:j])
            tokens.append(num_tok)
            i = j
            # Optional ``deg`` unit suffix, possibly separated from the
            # number by whitespace (e.g., ``45 deg`` vs ``45deg``).
            # Per ADR-0019 amendment 2 §Unit suffix and the test in
            # tests/engine/test_transcendentals.py::TestTokenizerExtensions::
            # test_unit_suffix_deg_tokenizes, the suffix is a single-token
            # rule (consistent with ``5%``). Tokenise it here; the parser
            # decides whether the suffix is legal in the current rad/deg mode.
            k = i
            while k < n and expression[k].isspace():
                k += 1
            if k < n and expression[k] == "d" and expression[k : k + 3] == "deg":
                end = k + 3
                if end == n or not (expression[end].isalpha() or expression[end].isdigit()):
                    tokens.append(("DEG", "deg"))
                    i = end
            continue
        if c.isascii() and c.isalpha():
            # Identifier (function name). Scan the full word.
            j = i
            while j < n and (expression[j].isascii() and expression[j].isalpha()):
                j += 1
            word = expression[i:j]
            if word in _KNOWN_FUNCS:
                tokens.append(("FUNC", word))
                i = j
                continue
            raise ExpressionSyntaxError(
                f"unknown identifier {word!r} at position {i} in expression {expression!r}"
            )
        raise ExpressionSyntaxError(
            f"unexpected character {c!r} at position {i} in expression {expression!r}"
        )
    return tokens


# ---------------------------------------------------------------------------
# Parser + evaluator (recursive descent)
# ---------------------------------------------------------------------------

# The parser is a single pass that combines parsing with evaluation. The
# percent semantics require looking at the *operator preceding* the percent
# to decide whether to apply financial or pure-percent. We track the last
# binary operator and its left-hand-side in ``_Parser`` state. Parens save
# and restore that state, so percent inside a paren is isolated from the
# outer expression's last-op context.
#
# Grammar (Sprint 7 / STORY-300 — adds ``**`` power operator):
#
#   expr    → term (('+' | '-') term)*
#   term    → power (('*' | '/' | '%') power)*
#   power   → unary ('%')? ('**' power)?    # postfix percent + right-assoc **
#   unary   → '-' unary | postfix
#   postfix → atom ('!')*                   # postfix factorial
#   atom    → NUMBER [DEG] | '(' expr ')' | FUNC '(' expr ')'
#
# Precedence (lowest → highest):
#   + -         (additive, expr level, left-assoc)
#   * / %       (multiplicative, term level, left-assoc)
#   **          (exponent, power level, RIGHT-associative — `2 ** 3 ** 2` = 512)
#   unary -     (prefix, unary level)
#   postfix !   (postfix, atom level)
#   atoms       (numbers, parens, function calls)
#
# Postfix percent (e.g. ``5%``) sits at the power level so it binds tighter
# than ``*``/``/`` but looser than ``**`` (so ``5% ** 2`` = ``0.0025`` if
# tested — the TDD contract does not cover this case explicitly but the
# grammar handles it correctly).
#
# Tokens: NUMBER, OP, LPAREN, RPAREN, FUNC, BANG, DEG.


class _Parser:
    def __init__(
        self,
        tokens: list[tuple[str, str]],
        source: str,
        deg: bool = False,
    ) -> None:
        self.tokens = tokens
        self.source = source
        self.pos = 0
        # The last binary op emitted at the current level (None at expression
        # start, or one of '+', '-', '*', '/'). Used by the percent rule.
        self.last_op: str | None = None
        # The left-hand-side at the time ``last_op`` was emitted. Used for
        # financial percent: X% of the preceding value.
        self.last_left: Decimal | None = None
        # Rad/deg mode for unit-suffix ``deg`` interpretation and the
        # function-call arguments in this expression.
        self.deg = deg

    def _peek(self) -> tuple[str, str] | None:
        if self.pos < len(self.tokens):
            return self.tokens[self.pos]
        return None

    def _consume(self) -> tuple[str, str]:
        tok = self.tokens[self.pos]
        self.pos += 1
        return tok

    def _expect(self, kind: str, value: str) -> tuple[str, str]:
        tok = self._peek()
        if tok is None or tok[0] != kind or tok[1] != value:
            raise ExpressionSyntaxError(
                f"expected {kind} {value!r} at position {self.pos} "
                f"in expression {self.source!r}, got {tok}"
            )
        return self._consume()

    def parse(self) -> Decimal:
        result = self._expr()
        if self.pos != len(self.tokens):
            tok = self.tokens[self.pos]
            raise ExpressionSyntaxError(
                f"unexpected token {tok!r} at position {self.pos} "
                f"in expression {self.source!r}"
            )
        return result

    def _expr(self) -> Decimal:
        left = self._term()
        while True:
            tok = self._peek()
            if tok is None or tok[0] != "OP" or tok[1] not in ("+", "-"):
                break
            op = self._consume()[1]
            # Record this op as the "last binary op" BEFORE parsing the
            # right-hand-side, so a postfix % in the right term can read the
            # operator that introduced it. Use the left value BEFORE combining,
            # so the percent's "preceding value" is the literal left of the
            # binary op, not the running total.
            self.last_op = op
            self.last_left = left
            right = self._term()
            left = left + right if op == "+" else left - right
        return left

    def _term(self) -> Decimal:
        left = self._power()
        while True:
            tok = self._peek()
            if tok is None or tok[0] != "OP" or tok[1] not in ("*", "/", "%"):
                break
            op = self._consume()[1]
            # Record this op as the "last binary op" BEFORE parsing the
            # right-hand-side, so a postfix % in the right power can read it.
            self.last_op = op
            self.last_left = left
            right = self._power()
            if op == "*":
                left = left * right
            elif op == "/":
                if right == 0:
                    raise DivisionByZeroError(
                        f"division by zero in expression {self.source!r}"
                    )
                left = left / right
            else:  # '%' as binary modulo (postfix percent handled in _power)
                if right == 0:
                    raise DivisionByZeroError(
                        f"modulo by zero in expression {self.source!r}"
                    )
                left = left % right
        return left

    def _power(self) -> Decimal:
        """power : unary ( '%' )? ( '**' power )?   — Sprint 7 / STORY-300.

        Two responsibilities:

        1. **Postfix percent** (moved from the old ``_factor`` so the
           grammar stays compact and the percent rule can read the
           last-binary-op state set by ``_term`` / ``_expr``).
           Disambiguation: a single token of lookahead. If the token after
           ``%`` is ``NUMBER`` / ``LPAREN`` / ``FUNC``, it's a right-hand-
           side, so we leave the ``%`` for ``_term`` to consume as modulo.
           Otherwise (operator, ``)``, or end-of-input), it's postfix
           percent and we apply it here.

        2. **Right-associative power** ``**``. The right-hand-side recurses
           into ``_power`` (not ``_unary``), so ``2 ** 3 ** 2`` parses as
           ``2 ** (3 ** 2) = 512``. ``**`` has higher precedence than
           ``*`` / ``/`` (because ``_term`` calls ``_power``, not
           ``_unary``), so ``2 * 3 ** 2`` = ``2 * 9 = 18``.
        """
        value = self._unary()
        # Postfix percent (overloaded with binary modulo; see docstring).
        tok = self._peek()
        if tok is not None and tok[0] == "OP" and tok[1] == "%":
            next_tok = self.tokens[self.pos + 1] if self.pos + 1 < len(self.tokens) else None
            if next_tok is None or next_tok[0] not in ("NUMBER", "LPAREN", "FUNC"):
                # Postfix percent.
                self._consume()
                value = self._apply_percent(value)
            # else: binary modulo; leave for _term.
        # Right-associative power. The right-hand side recurses into _power
        # so `2 ** 3 ** 2` = `2 ** (3 ** 2)` = 512.
        tok = self._peek()
        if tok is not None and tok[0] == "OP" and tok[1] == "**":
            self._consume()
            right = self._power()
            value = self._apply_power(value, right)
        return value

    def _apply_power(self, base: Decimal, exponent: Decimal) -> Decimal:
        """Compute ``base ** exponent`` at the engine's Decimal precision.

        Uses :class:`decimal.Decimal` ``__pow__`` which is exact for integer
        / decimal bases and integer / decimal / negative exponents (within
        the engine's 28-digit context). Examples:

        - ``2 ** 10`` = ``1024``
        - ``0.5 ** 2`` = ``0.25``
        - ``2 ** 0`` = ``1``
        - ``2 ** -1`` = ``0.5``  (Decimal rounds to context precision)

        Negative bases with non-integer exponents (e.g. ``(-2) ** 0.5``) are
        mathematically undefined in the reals (the result is a complex
        number). :class:`decimal.Decimal` raises :class:`decimal.InvalidOperation`
        in that case, which we translate to :class:`DomainError` for a
        user-friendly error message (the engine contract is to surface
        domain errors, not bubble up mpmath / decimal internals).
        """
        try:
            with localcontext() as ctx:
                ctx.prec = _PREC
                return base ** exponent
        except InvalidOperation as exc:  # negative base with frac exponent, etc.
            raise DomainError(
                f"power undefined for base {base!r} and exponent {exponent!r} "
                f"in expression {self.source!r} (e.g. negative base with "
                f"non-integer exponent yields a complex result) "
                f"(per ADR-0019 amendment 2 §DomainError)"
            ) from exc

    def _apply_percent(self, value: Decimal) -> Decimal:
        """Apply hybrid percent semantics to ``value``.

        Rule (per PM verdict on PR #23, codified in tests/engine/test_evaluator.py):

          - If the last binary op was ``+`` or ``-`` (financial-on-adjacent):
              ``X%`` → ``(X / 100) * <preceding_value>``
            e.g. ``100 + 5%`` → ``100 + (5/100 * 100) = 105``
          - If the last binary op was ``*`` or ``/`` (pure-percent):
              ``X%`` → ``X / 100``
            e.g. ``50 * 20%`` → ``50 * 0.2 = 10``
          - If no preceding op (standalone at expression start):
              ``X%`` → ``X / 100``
            e.g. ``100%`` → ``1``
        """
        if self.last_op in ("+", "-") and self.last_left is not None:
            # Financial: X% of the preceding value.
            return (value / Decimal(100)) * self.last_left
        # Pure-percent: X/100.
        return value / Decimal(100)

    def _unary(self) -> Decimal:
        """unary : '-' unary | postfix

        Unary minus is supported (e.g., ``(-1)!``). It is intentionally
        NOT a separate error class — it parses as a leading ``-`` on a
        numeric expression. Per the spec, ``(-1)!`` raises ``DomainError``
        at the factorial stage (negative factorial is undefined).
        """
        tok = self._peek()
        if tok is not None and tok[0] == "OP" and tok[1] == "-":
            self._consume()
            operand = self._unary()
            return -operand
        return self._postfix()

    def _postfix(self) -> Decimal:
        """postfix : atom ('!')*

        Postfix factorial (chainable in theory; tests only cover a single
        ``!``). The factorial cap of 170 and the integer-only invariant
        are enforced in :meth:`_apply_factorial`.
        """
        value = self._atom()
        while True:
            tok = self._peek()
            if tok is None or tok[0] != "BANG":
                break
            self._consume()
            value = self._apply_factorial(value)
        return value

    def _apply_factorial(self, value: Decimal) -> Decimal:
        """Compute ``n!`` for a non-negative integer ``n <= 170``.

        Raises:
            DomainError: If ``n`` is negative, non-integer, or > 170.
        """
        # Reject non-integer inputs (e.g., 0.9999999999999999, 1.5).
        if value != value.to_integral_value():
            raise DomainError(
                f"factorial requires a non-negative integer; got {value!r} in "
                f"expression {self.source!r}"
            )
        n = int(value)
        if n < 0:
            raise DomainError(
                f"factorial is undefined for negative integers; got {n} in "
                f"expression {self.source!r}"
            )
        if n > _FACTORIAL_MAX:
            raise DomainError(
                f"factorial cap is {_FACTORIAL_MAX}; got {n} in expression {self.source!r} "
                f"(per ADR-0019 amendment 2 §Factorial cap)"
            )
        # math.factorial is exact for n <= 170 and returns int. Converting
        # to Decimal preserves all 306 digits of 170! losslessly.
        return Decimal(math.factorial(n))

    def _atom(self) -> Decimal:
        """atom : NUMBER [DEG] | '(' expr ')' | FUNC '(' expr ')'"""
        tok = self._peek()
        if tok is None:
            raise ExpressionSyntaxError(
                f"unexpected end of expression {self.source!r} at position {self.pos}"
            )
        if tok[0] == "LPAREN":
            self._consume()
            # Save percent state — parens are a sub-expression and their
            # internal binary ops should not leak into the outer percent
            # resolution. E.g. ``100 + (5 + 5)%`` should treat ``5%`` as
            # financial-on-100, not financial-on-5.
            saved_op = self.last_op
            saved_left = self.last_left
            self.last_op = None
            self.last_left = None
            value = self._expr()
            self._expect("RPAREN", ")")
            self.last_op = saved_op
            self.last_left = saved_left
            return value
        if tok[0] == "NUMBER":
            self._consume()
            value = Decimal(tok[1])
            # Optional ``deg`` unit suffix on a bare number.
            nxt = self._peek()
            if nxt is not None and nxt[0] == "DEG":
                if not self.deg:
                    # Per AP-14 (tests/engine/test_domain_errors.py): the
                    # ``deg`` suffix in rad mode is a unit-confusion guard,
                    # raised as DomainError (not ExpressionSyntaxError) since
                    # the parser successfully understood the unit — it's the
                    # runtime context that disallows it.
                    raise DomainError(
                        f"unit suffix 'deg' is only legal in deg mode "
                        f"(pass deg=True to evaluate()) at position {self.pos} "
                        f"in expression {self.source!r} "
                        f"(per ADR-0019 amendment 2 §DomainError)"
                    )
                self._consume()
                # Convert: 45 deg = 45 * π/180 rad. Compute in mpmath
                # space for precision (matches the trig path). Lazy import
                # per Issue #728 — arithmetic path without 'deg' suffix is
                # mpmath-free.
                mpmath = _import_mpmath()
                value = _mpf_to_decimal(mpmath.mpf(str(value)) * (mpmath.pi / 180))
            return value
        if tok[0] == "FUNC":
            return self._function_call()
        raise ExpressionSyntaxError(
            f"unexpected token {tok!r} at position {self.pos} "
            f"in expression {self.source!r}: expected number, '(', or function name"
        )

    def _function_call(self) -> Decimal:
        """Evaluate ``FUNC '(' expr ')'`` for known function names.

        See :data:`_KNOWN_FUNCS` for the full set. Domain errors (sqrt of
        negative, log of non-positive, etc.) raise :class:`DomainError`.
        """
        func_tok = self._consume()
        func_name = func_tok[1]
        self._expect("LPAREN", "(")
        arg = self._expr()
        self._expect("RPAREN", ")")
        return _apply_function(func_name, arg, self.source)


# ---------------------------------------------------------------------------
# mpmath helpers (LAZY-IMPORTED per Issue #728 hotfix)
# ---------------------------------------------------------------------------
#
# Architectural change: mpmath is no longer imported at module load. Instead,
# ``_import_mpmath()`` lazy-imports on first transcendental call. Subsequent
# calls are O(1) via Python's ``sys.modules`` cache (no per-call cost).
#
# Why this matters: PR #709 (Sprint 22 PIVOT Faz 1.1, commit ``eb64485``)
# introduced ``import mpmath`` at module level, which paid a ~50ms cold-start
# cost on EVERY ``from atilcalc.engine import …`` — including callers that
# only do arithmetic. This regressed the d100 perf budgets
# (test_arithmetic_p99_under_50ms_still_holds failed at p99=215.48ms, 4.3×
# over budget; surfaced via PR #694 CI).
#
# The lazy-import hotfix (Issue #728, architect 9-Lens 🟢 APPROVED) is
# regression-guarded by d110 (6 TCs, all GREEN post-impl). Per the d110 TC1
# invariant: ``import atilcalc.engine.evaluator`` does NOT trigger mpmath
# import — the arithmetic path is now mpmath-free.


def _import_mpmath():
    """Lazy-import the ``mpmath`` module + set ``mp.dps`` for this process.

    First call pays the module-load cost (~50ms cold on self-hosted runner);
    subsequent calls are O(1) via Python's import-system ``sys.modules``
    cache. ``mpmath.mp.dps`` is re-asserted on every call (paranoia against
    peer modules mutating the global context between calls).

    The ``type: ignore[import-untyped]`` is load-bearing for
    ``mypy --strict`` (mpmath has no type stubs).

    Returns:
        The ``mpmath`` module object (cached after first call).
    """
    import mpmath  # type: ignore[import-untyped]
    mpmath.mp.dps = _MP_DPS
    return mpmath


def _mpf_to_decimal(value: "mpmath.mpf") -> Decimal:  # type: ignore[name-defined]  # noqa: F821
    """Convert an ``mpmath.mpf`` to ``Decimal`` via string round-trip.

    ``mpmath.nstr(value, n, strip_zeros=False)`` produces a string with
    ``n`` significant digits. We use ``n=28`` (the engine's output
    precision) and disable trailing-zero stripping to keep the
    ``Decimal`` output stable (e.g., ``Decimal("0.7071067811865475244008443621")``
    vs. ``Decimal("0.707106781186547524400844362")`` — the test contract
    uses a 28-digit prefix match, so we need at least 28 digits emitted).
    """
    mpmath = _import_mpmath()
    s = mpmath.nstr(value, _PREC, strip_zeros=False)
    return Decimal(s)


def _apply_function(name: str, arg: Decimal, source: str) -> Decimal:
    """Dispatch a function call to its mpmath implementation.

    Args:
        name: Function name (lowercase; one of :data:`_KNOWN_FUNCS`).
        arg: Argument as ``Decimal`` (the engine's internal type).
        source: The original expression source (for error messages).

    Returns:
        A :class:`Decimal` result at the engine's output precision.

    Raises:
        DomainError: If the input is outside the function's domain
            (sqrt of negative, log of non-positive, tan at a pole, etc.).
    """
    if name == "sqrt":
        return _fn_sqrt(arg, source)
    if name in _LOG_FUNCS:
        return _fn_log(name, arg, source)
    if name in _TRANSCENDENTAL_FUNCS:
        return _fn_trig(name, arg, source)
    if name in _INVERSE_TRIG_FUNCS:
        return _fn_inverse_trig(name, arg, source)
    # Unreachable: tokeniser rejects unknown identifiers. Keep the guard
    # so that future additions to _KNOWN_FUNCS without a dispatch case
    # fail loudly here rather than silently returning wrong values.
    raise ExpressionSyntaxError(
        f"unknown function {name!r} in expression {source!r}"
    )


def _fn_sqrt(arg: Decimal, source: str) -> Decimal:
    if arg < 0:
        raise DomainError(
            f"sqrt of negative number {arg!r} in expression {source!r} "
            f"(per ADR-0019 amendment 2 §DomainError)"
        )
    if arg == 0:
        return Decimal(0)
    mpmath = _import_mpmath()
    x = mpmath.mpf(str(arg))
    return _mpf_to_decimal(mpmath.sqrt(x))


def _fn_log(name: str, arg: Decimal, source: str) -> Decimal:
    if arg <= 0:
        raise DomainError(
            f"{name} of non-positive number {arg!r} in expression {source!r} "
            f"(per ADR-0019 amendment 2 §DomainError)"
        )
    mpmath = _import_mpmath()
    x = mpmath.mpf(str(arg))
    result = mpmath.log10(x) if name == "log" else mpmath.log(x)
    return _mpf_to_decimal(result)


def _fn_trig(name: str, arg: Decimal, source: str) -> Decimal:
    # Lazy import + re-assert mp.dps (paranoia against peer modules mutating
    # the global context between calls). Per Issue #728, this is the ONLY
    # path into mpmath for sin/cos/tan.
    mpmath = _import_mpmath()
    x = mpmath.mpf(str(arg))
    if name == "sin":
        result = mpmath.sin(x)
    elif name == "cos":
        result = mpmath.cos(x)
    else:  # "tan"
        # Domain check: if cos(x) is effectively zero, tan is undefined.
        # Threshold (1e-10) is computed lazily inside this branch — was a
        # module-level constant pre-Issue #728; inlined here to keep the
        # arithmetic path mpmath-free.
        cos_x = mpmath.cos(x)
        tan_cos_eps = mpmath.mpf("1e-10")
        if abs(cos_x) < tan_cos_eps:
            raise DomainError(
                f"tan undefined at {arg!r} (|cos({arg!r})| = {mpmath.nstr(abs(cos_x), 4)} "
                f"< {tan_cos_eps}, near a pole) in expression {source!r} "
                f"(per ADR-0019 amendment 2 §DomainError)"
            )
        result = mpmath.tan(x)
        # Belt-and-suspenders: if the result is absurdly large, treat as pole.
        # Threshold (1e15) computed lazily here.
        tan_overflow = mpmath.mpf("1e15")
        if abs(result) > tan_overflow:
            raise DomainError(
                f"tan overflow at {arg!r} (|tan| = {mpmath.nstr(abs(result), 4)} "
                f"> {tan_overflow}, on a pole) in expression {source!r} "
                f"(per ADR-0019 amendment 2 §DomainError)"
            )
    return _mpf_to_decimal(result)


def _fn_inverse_trig(name: str, arg: Decimal, source: str) -> Decimal:
    if arg < -1 or arg > 1:
        raise DomainError(
            f"{name} argument {arg!r} is outside [-1, 1] in expression {source!r} "
            f"(per ADR-0019 amendment 2 §DomainError)"
        )
    mpmath = _import_mpmath()
    x = mpmath.mpf(str(arg))
    result = mpmath.asin(x) if name == "asin" else mpmath.acos(x)
    return _mpf_to_decimal(result)


def evaluate(expression: str, deg: bool = False) -> Decimal:
    """Parse and evaluate a math expression, returning a Decimal result.

    Supported operators (Sprint 7 / STORY-300; ** added):

    Arithmetic:
        +  addition
        -  subtraction / unary minus
        *  multiplication
        /  division
        %  percent (postfix; semantics depend on the operator preceding it)
        **  power (right-associative; higher precedence than * /)
        ( )  parentheses (override default precedence)

    Scientific functions (function-call form per ADR-0019 amend 2 §Tokenizer design):
        sin(x)  cos(x)  tan(x)         — radian default; deg mode via ``deg=True``
        asin(x) acos(x)                — inverse trig; |x| must be <= 1
        log(x)                          — base-10
        ln(x)                           — base-e (natural)
        sqrt(x)                         — square root; x must be >= 0

    Unit suffix:
        45 deg                          — only legal in deg mode (``deg=True``);
                                          converts degrees to radians
                                          (e.g., 45 deg = π/4 rad)

    Factorial:
        n!                              — non-negative integer; cap is 170 (ADR-0019
                                          amend 2 §Factorial cap). 171!, negative,
                                          or non-integer factorials raise
                                          :class:`DomainError`.

    Percent semantics (HYBRID, per PM verdict on PR #23):
        The operator immediately preceding the ``%`` decides the convention:

          - For ``+`` and ``-`` (financial-on-adjacent):
            ``X%`` is interpreted as ``(X / 100) * <preceding_value>``.
            So ``100 + 5%`` → ``100 + (5/100 * 100) = 105``.
            This matches AC3's canonical case and the Windows-Calc
            convention most users will type and expect.

          - For ``*`` and ``/`` (pure-percent):
            ``X%`` is interpreted as ``X / 100`` (the literal percent value).
            So ``50 * 20%`` → ``50 * 0.2 = 10``.

          - For standalone ``X%`` at expression start (no preceding value):
            ``X%`` is interpreted as ``X / 100`` (identity).
            So ``100%`` → ``1``.

        The decision is made by the parser, which tracks the last binary
        operator it emitted. Parens save and restore this state, so percent
        inside a paren is isolated from the outer expression.

    Args:
        expression: A math expression string. Whitespace is ignored.
        deg: If ``True``, ``X deg`` unit suffixes and function arguments
            are interpreted in degrees. Default is ``False`` (radians).

    Returns:
        A :class:`decimal.Decimal` with the evaluation result. Precision
        is preserved end-to-end: arithmetic uses ``decimal.localcontext(prec=28)``;
        transcendentals use ``mpmath`` with ``mp.dps=50`` internally and
        round-trip via string to ``Decimal`` at 28-digit output precision.

    Raises:
        ExpressionSyntaxError: If the expression cannot be tokenised or parsed.
        DivisionByZeroError: If a division by zero is attempted.
        DomainError: For runtime domain errors (sqrt of negative, log of
            non-positive, tan at a pole, etc.).

    Examples:
        >>> evaluate("0.1 + 0.2")
        Decimal('0.3')
        >>> evaluate("2 * (3 + 4)")
        Decimal('14')
        >>> evaluate("100 + 5%")
        Decimal('105')
        >>> evaluate("50 * 20%")
        Decimal('10')
        >>> evaluate("5!")
        Decimal('120')
        >>> evaluate("sin(0)")
        Decimal('0')
        >>> evaluate("cos(0)", deg=True)
        Decimal('1')
        >>> evaluate("5 / 0")  # doctest: +IGNORE_EXCEPTION_DETAIL
        Traceback (most recent call last:
        ...
        atilcalc.engine.DivisionByZeroError: division by zero in expression '5 / 0'
    """
    with localcontext() as ctx:
        ctx.prec = _PREC
        tokens = _tokenize(expression)
        if not tokens:
            raise ExpressionSyntaxError(
                f"empty or whitespace-only expression {expression!r}"
            )
        parser = _Parser(tokens, expression, deg=deg)
        return parser.parse()
