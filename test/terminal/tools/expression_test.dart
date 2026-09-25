import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/tools/expression.dart';
import 'package:flutter_test/flutter_test.dart';

void _expectValue(String source, num expected) {
  expect(evaluateExpression(source), closeTo(expected, 1e-9), reason: source);
}

void _expectError(String source, String message) {
  expect(
    () => evaluateExpression(source),
    throwsA(
      isA<ExpressionException>().having((e) => e.message, 'message', message),
    ),
    reason: source,
  );
}

void main() {
  group('arithmetic', () {
    test('adds, subtracts, multiplies and divides', () {
      _expectValue('1+2', 3);
      _expectValue('10-4', 6);
      _expectValue('6*7', 42);
      _expectValue('10/4', 2.5);
    });

    test('multiplication binds tighter than addition', () {
      _expectValue('2+3*4', 14);
      _expectValue('2*3+4', 10);
    });

    test('parentheses override precedence', () {
      _expectValue('(2+3)*4', 20);
      _expectValue('2*(3+(4-1))', 12);
    });

    test('operators of equal precedence go left to right', () {
      _expectValue('10-3-2', 5);
      _expectValue('100/10/5', 2);
    });

    test('% is modulo', () {
      _expectValue('10%3', 1);
    });

    test('^ is right-associative', () {
      _expectValue('2^3^2', 512);
    });

    test('unary minus binds looser than ^ and can follow an operator', () {
      _expectValue('-2^2', -4);
      _expectValue('2^-1', 0.5);
      _expectValue('2 - -3', 5);
      _expectValue('-(1+2)', -3);
      _expectValue('+5', 5);
    });

    test('spaces are ignored', () {
      _expectValue('  2 * ( 3 + 4 )  ', 14);
    });
  });

  group('numbers', () {
    test('accept a decimal point or comma, and a leading dot', () {
      _expectValue('1.5+1', 2.5);
      _expectValue('1,5+2', 3.5);
      _expectValue('.5*2', 1);
    });

    test('accept scientific notation', () {
      _expectValue('1e3', 1000);
      _expectValue('2.5E-1', 0.25);
    });
  });

  group('functions and constants', () {
    test('constants, in any case', () {
      _expectValue('pi', 3.141592653589793);
      _expectValue('PI*2', 6.283185307179586);
      _expectValue('e', 2.718281828459045);
    });

    test('roots, absolute value and rounding', () {
      _expectValue('sqrt(16)', 4);
      _expectValue('abs(-3)', 3);
      _expectValue('round(2.5)', 3);
      _expectValue('floor(-1.5)', -2);
      _expectValue('ceil(1.2)', 2);
    });

    test('logarithms and exponentials', () {
      _expectValue('ln(e)', 1);
      _expectValue('log(1000)', 3);
      _expectValue('exp(0)', 1);
    });

    test('trigonometry uses radians', () {
      _expectValue('sin(pi/2)', 1);
      _expectValue('cos(0)', 1);
      _expectValue('atan(1)*4', 3.141592653589793);
    });

    test('functions nest and combine', () {
      _expectValue('sqrt(abs(-16)) + 1', 5);
      _expectValue('2*sqrt(9)', 6);
    });
  });

  group('errors', () {
    test('nothing to evaluate', () {
      _expectError('', Messages.exprUnexpectedEnd);
      _expectError('1+', Messages.exprUnexpectedEnd);
    });

    test('unbalanced parentheses', () {
      _expectError('(1+2', Messages.exprMissingParen);
      _expectError('sqrt(4', Messages.exprMissingParen);
      _expectError('1+2)', Messages.exprUnexpected(')'));
    });

    test('stray characters and numbers', () {
      _expectError('2 3', Messages.exprUnexpected('3'));
      _expectError('1.2.3', Messages.exprUnexpected('.'));
      _expectError('2e', Messages.exprUnexpected('e'));
      _expectError('2 \$ 3', Messages.exprUnexpected(r'$'));
    });

    test('division by zero, including modulo and negative powers', () {
      _expectError('1/0', Messages.exprDivideByZero);
      _expectError('5%0', Messages.exprDivideByZero);
      _expectError('0^-1', Messages.exprDivideByZero);
    });

    test('results that are not real numbers', () {
      _expectError('sqrt(-1)', Messages.exprNotReal);
      _expectError('ln(0)', Messages.exprNotReal);
      _expectError('asin(2)', Messages.exprNotReal);
      _expectError('(-8)^0.5', Messages.exprNotReal);
    });

    test('results too large to represent', () {
      _expectError('10^400', Messages.exprTooLarge);
      _expectError('exp(1000)', Messages.exprTooLarge);
    });

    test('unknown names are reported by name', () {
      _expectError('foo', Messages.exprUnknownName('foo'));
      _expectError('foo(1)', Messages.exprUnknownName('foo'));
      _expectError('sqrt', Messages.exprUnknownName('sqrt'));
    });

    test('absurd nesting is an error, not a crash', () {
      _expectError('${'(' * 500}1${')' * 500}', Messages.exprTooDeep);
      _expectError('${'-' * 500}1', Messages.exprTooDeep);
    });
  });
}
