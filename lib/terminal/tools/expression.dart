import 'dart:math' as math;

import 'package:android_terminal_launcher/messages.dart';

/// The expression could not be evaluated; [message] says why, in words a user
/// can act on.
class ExpressionException implements Exception {
  const ExpressionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Evaluates an arithmetic expression such as `2*(3+4)^2` or `sqrt(16) + pi`.
///
/// Operators: `+ - * / % ^` (`%` is modulo, `^` is right-associative, unary
/// minus binds looser than `^` so `-2^2` is -4) and parentheses. Numbers may
/// use `.` or `,` as the decimal mark. Functions take one argument, in
/// radians for trigonometry. Throws [ExpressionException] for anything it
/// cannot evaluate; the result is always finite.
double evaluateExpression(String source) => _Parser(source).parse();

const _maxDepth = 200;

final _number = RegExp(r'(\d+([.,]\d*)?|[.,]\d+)([eE][+-]?\d+)?');
final _name = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');

const _constants = {'pi': math.pi, 'e': math.e};

final Map<String, double Function(double)> _functions = {
  'sqrt': math.sqrt,
  'abs': (x) => x.abs(),
  'sin': math.sin,
  'cos': math.cos,
  'tan': math.tan,
  'asin': math.asin,
  'acos': math.acos,
  'atan': math.atan,
  'ln': (x) => x <= 0 ? double.nan : math.log(x),
  'log': (x) => x <= 0 ? double.nan : math.log(x) / math.ln10,
  'exp': math.exp,
  'floor': (x) => x.floorToDouble(),
  'ceil': (x) => x.ceilToDouble(),
  'round': (x) => x.roundToDouble(),
};

class _Parser {
  _Parser(this._source);

  final String _source;
  int _pos = 0;
  int _depth = 0;

  double parse() {
    final value = _expression();
    _skipSpace();
    if (_pos < _source.length) {
      throw ExpressionException(Messages.exprUnexpected(_source[_pos]));
    }
    return value;
  }

  // expression := term (('+' | '-') term)*
  double _expression() => _nested(() {
    var value = _term();
    while (true) {
      final op = _peek();
      if (op == '+') {
        _pos++;
        value = _finite(value + _term());
      } else if (op == '-') {
        _pos++;
        value = _finite(value - _term());
      } else {
        return value;
      }
    }
  });

  // term := unary (('*' | '/' | '%') unary)*
  double _term() {
    var value = _unary();
    while (true) {
      final op = _peek();
      if (op == '*') {
        _pos++;
        value = _finite(value * _unary());
      } else if (op == '/' || op == '%') {
        _pos++;
        final divisor = _unary();
        if (divisor == 0) {
          throw const ExpressionException(Messages.exprDivideByZero);
        }
        value = _finite(op == '/' ? value / divisor : value % divisor);
      } else {
        return value;
      }
    }
  }

  // unary := ('+' | '-') unary | power
  double _unary() => _nested(() {
    final op = _peek();
    if (op == '-') {
      _pos++;
      return -_unary();
    }
    if (op == '+') {
      _pos++;
      return _unary();
    }
    return _power();
  });

  // power := primary ('^' unary)?
  double _power() {
    final base = _primary();
    if (_peek() != '^') return base;
    _pos++;
    final exponent = _unary();
    if (base == 0 && exponent < 0) {
      throw const ExpressionException(Messages.exprDivideByZero);
    }
    return _finite(math.pow(base, exponent).toDouble());
  }

  // primary := number | name | name '(' expression ')' | '(' expression ')'
  double _primary() {
    final next = _peek();
    if (next == null) {
      throw const ExpressionException(Messages.exprUnexpectedEnd);
    }
    if (next == '(') {
      _pos++;
      final value = _expression();
      _expectClose();
      return value;
    }
    final number = _number.matchAsPrefix(_source, _pos);
    if (number != null) {
      final text = number.group(0)!;
      _pos = number.end;
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value == null) {
        throw ExpressionException(Messages.exprBadNumber(text));
      }
      return _finite(value);
    }
    final name = _name.matchAsPrefix(_source, _pos);
    if (name != null) return _named(name.group(0)!, name.end);
    throw ExpressionException(Messages.exprUnexpected(next));
  }

  double _named(String name, int end) {
    final key = name.toLowerCase();
    _pos = end;
    if (_peek() == '(') {
      final function = _functions[key];
      if (function == null) {
        throw ExpressionException(Messages.exprUnknownName(name));
      }
      _pos++;
      final argument = _expression();
      _expectClose();
      return _finite(function(argument));
    }
    final constant = _constants[key];
    if (constant == null) {
      throw ExpressionException(Messages.exprUnknownName(name));
    }
    return constant;
  }

  void _expectClose() {
    if (_peek() != ')') {
      throw const ExpressionException(Messages.exprMissingParen);
    }
    _pos++;
  }

  /// The next non-space character without consuming it, or null at the end.
  String? _peek() {
    _skipSpace();
    return _pos < _source.length ? _source[_pos] : null;
  }

  void _skipSpace() {
    while (_pos < _source.length && _source[_pos].trim().isEmpty) {
      _pos++;
    }
  }

  /// Bounds recursion so a pasted wall of `(` or `-` is an error, not a crash.
  double _nested(double Function() body) {
    if (++_depth > _maxDepth) {
      throw const ExpressionException(Messages.exprTooDeep);
    }
    try {
      return body();
    } finally {
      _depth--;
    }
  }

  double _finite(double value) {
    if (value.isNaN) {
      throw const ExpressionException(Messages.exprNotReal);
    }
    if (value.isInfinite) {
      throw const ExpressionException(Messages.exprTooLarge);
    }
    return value;
  }
}
