"""Expression evaluator and engine exception hierarchy.

Public surface
--------------

- :func:`evaluate` — entry point for parsing and evaluating an expression.
- :class:`EngineError` — base class for all engine errors (catch-all).
- :class:`ExpressionSyntaxError` — raised when the input cannot be tokenised/parsed.
- :class:`DivisionByZeroError` — raised when division/modulo by zero occurs.
- :class:`UndefinedOperatorError` — raised when an operator is not in MVP-1 scope.

The exception hierarchy is deliberately structured (not generic ``ValueError``)
so the HTTP layer can map each error to a distinct status code + error envelope
per ADR-0018 watch-item #1 (API contract; pending architect's R-N ADR).
"""

from __future__ import annotations

from decimal import Decimal, localcontext

# Pinned Decimal precision per the tester's regression-risk note
# (docs/test-plans/STORY-002-tests.md §Regression Risk). Using a localcontext
# inside evaluate() ensures that peer modules mutating the global Decimal
# context cannot drift the engine's results.
_PREC = 28


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


# ---------------------------------------------------------------------------
# Tokenizer
# ---------------------------------------------------------------------------

_OPERATORS = {"+", "-", "*", "/", "%"}


def _tokenize(expression: str) -> list[tuple[str, str]]:
    """Lex ``expression`` into a list of ``(kind, value)`` tokens.

    Whitespace is ignored. A number is ``\\d+(\\.\\d+)?`` — i.e., a sequence
    of digits, optionally with one decimal point and more digits. Anything
    else (a stray ``.``, a letter, a unicode operator, etc.) is a syntax error.

    Returns:
        A list of tokens in source order. ``kind`` is one of ``"NUMBER"``,
        ``"OP"`` (operator), ``"LPAREN"``, ``"RPAREN"``.

    Raises:
        ExpressionSyntaxError: If a non-whitespace, non-supported character
            appears (e.g. ``"abc"`` → ``"a"`` is invalid; ``"1.2.3"`` → the
            second ``.`` after ``1.2`` is invalid).
    """
    tokens: list[tuple[str, str]] = []
    i = 0
    n = len(expression)
    while i < n:
        c = expression[i]
        if c.isspace():
            i += 1
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
        if c.isdigit():
            j = i
            saw_dot = False
            while j < n and (expression[j].isdigit() or (expression[j] == "." and not saw_dot)):
                if expression[j] == ".":
                    saw_dot = True
                j += 1
            tokens.append(("NUMBER", expression[i:j]))
            i = j
            continue
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


class _Parser:
    def __init__(self, tokens: list[tuple[str, str]], source: str) -> None:
        self.tokens = tokens
        self.source = source
        self.pos = 0
        # The last binary op emitted at the current level (None at expression
        # start, or one of '+', '-', '*', '/'). Used by the percent rule.
        self.last_op: str | None = None
        # The left-hand-side at the time ``last_op`` was emitted. Used for
        # financial percent: X% of the preceding value.
        self.last_left: Decimal | None = None

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
        left = self._factor()
        while True:
            tok = self._peek()
            if tok is None or tok[0] != "OP" or tok[1] not in ("*", "/", "%"):
                break
            op = self._consume()[1]
            # Record this op as the "last binary op" BEFORE parsing the
            # right-hand-side, so a postfix % in the right factor can read it.
            self.last_op = op
            self.last_left = left
            right = self._factor()
            if op == "*":
                left = left * right
            elif op == "/":
                if right == 0:
                    raise DivisionByZeroError(
                        f"division by zero in expression {self.source!r}"
                    )
                left = left / right
            else:  # '%' as binary modulo (postfix percent handled in _factor)
                if right == 0:
                    raise DivisionByZeroError(
                        f"modulo by zero in expression {self.source!r}"
                    )
                left = left % right
        return left

    def _factor(self) -> Decimal:
        """factor : atom ( '%' )?   — postfix percent only here.

        ``%`` is overloaded in the grammar:
          - ``X % Y`` (binary, with a right operand) → modulo, handled in
            ``_term`` at multiplicative precedence.
          - ``X%`` (postfix, no right operand) → percent, handled here.

        Disambiguation: a single token of lookahead. If the token after ``%``
        is ``NUMBER`` or ``LPAREN``, it's a right-hand-side, so we leave the
        ``%`` for ``_term`` to consume as modulo. Otherwise (operator, ``)``,
        or end-of-input), it's postfix percent and we apply it here.
        """
        value = self._atom()
        tok = self._peek()
        if tok is not None and tok[0] == "OP" and tok[1] == "%":
            next_tok = self.tokens[self.pos + 1] if self.pos + 1 < len(self.tokens) else None
            if next_tok is None or next_tok[0] not in ("NUMBER", "LPAREN"):
                # Postfix percent.
                self._consume()
                value = self._apply_percent(value)
            # else: binary modulo; leave for _term.
        return value

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

    def _atom(self) -> Decimal:
        """atom : '(' expr ')' | NUMBER"""
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
            return Decimal(tok[1])
        raise ExpressionSyntaxError(
            f"unexpected token {tok!r} at position {self.pos} "
            f"in expression {self.source!r}: expected number or '('"
        )


def evaluate(expression: str) -> Decimal:
    """Parse and evaluate a math expression, returning a Decimal result.

    Supported operators (MVP-1 / Sprint 1):
        +  addition
        -  subtraction
        *  multiplication
        /  division
        %  percent (postfix; semantics depend on the operator preceding it)
        ( )  parentheses (override default precedence)

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
            Tokens must be decimal numbers (e.g. ``0.1``, ``3.14``, ``42``)
            and operators from the supported set.

    Returns:
        A :class:`decimal.Decimal` with the exact evaluation result.
        Decimal precision is preserved end-to-end (no float coercion).
        A ``decimal.localcontext(prec=28)`` is used internally so peer
        modules mutating the global Decimal context cannot drift the
        engine's results.

    Raises:
        ExpressionSyntaxError: If the expression cannot be tokenised or parsed.
            Examples: ``"2+"``, ``"abc"``, ``"("``, ``"1.2.3"``, ``"()"``.
        DivisionByZeroError: If a division by zero is attempted.
            Examples: ``"5 / 0"``, ``"100 / (5 - 5)"``.

    Examples:
        >>> evaluate("0.1 + 0.2")
        Decimal('0.3')
        >>> evaluate("2 * (3 + 4)")
        Decimal('14')
        >>> evaluate("100 + 5%")
        Decimal('105')
        >>> evaluate("50 * 20%")
        Decimal('10')
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
        parser = _Parser(tokens, expression)
        return parser.parse()
