import 'package:android_terminal_launcher/terminal/tools/double_space.dart';
import 'package:flutter_test/flutter_test.dart';

/// Types one space at [cursor] into [before] and asks what should happen.
DoubleSpaceEdit? _type(String before, {int? at}) {
  final cursor = at ?? before.length;
  final after = '${before.substring(0, cursor)} ${before.substring(cursor)}';
  return periodOnDoubleSpace(before, after, cursor + 1);
}

void main() {
  test('the example: two spaces after a sentence end it with ". "', () {
    final edit = _type('Test sentence ');

    expect(edit?.text, 'Test sentence. ');
    expect(edit?.cursor, 'Test sentence. '.length);
  });

  test('the cursor ends after the space, ready for the next sentence', () {
    final edit = _type('one two ')!;

    expect(edit.cursor, edit.text.length);
    expect(edit.text.endsWith('. '), isTrue);
  });

  test('in the middle of the text, the stop goes at the end', () {
    // "hello |there friend" with a space typed at the cursor.
    final edit = _type('hello there friend', at: 6);

    expect(edit?.text, 'hello there friend. ');
    expect(edit?.cursor, 'hello there friend. '.length);
  });

  test('a double space between two words does not glue them together', () {
    final edit = _type('one two three', at: 8);

    expect(edit?.text, 'one two three. ');
  });

  test('a typed space next to existing spaces still counts as a double', () {
    // "one |two": the cursor sits after the first space, another is typed.
    expect(_type('one two three', at: 4)?.text, 'one two three. ');
  });

  test('a single space is left alone', () {
    expect(_type('Test'), isNull);
    expect(_type('Test sentence'), isNull);
  });

  test('a single word is left alone, so a command is never given a period', () {
    expect(_type('list '), isNull);
    expect(_type('help '), isNull);
  });

  test('two spaces at the very start are left alone', () {
    expect(_type(' '), isNull);
    expect(_type(''), isNull);
  });

  test('after punctuation it is one plain space, never a double stop', () {
    for (final end in ['.', '!', '?', ':', ',', ';']) {
      final edit = _type('Test sentence$end ');

      expect(edit?.text, 'Test sentence$end ', reason: end);
    }
  });

  test('a quote or bracket closing the text still gets its stop after it', () {
    expect(_type('note add "buy milk" ')?.text, 'note add "buy milk". ');
  });

  test('text after the cursor is kept, and the stop moves past it', () {
    final edit = _type('note add "buy milk" tomorrow', at: 9);

    expect(edit?.text, 'note add "buy milk" tomorrow. ');
  });

  test('anything that is not one typed space is ignored', () {
    // A paste of several characters.
    expect(periodOnDoubleSpace('a b', 'a b  c ', 7), isNull);
    // A deletion.
    expect(periodOnDoubleSpace('a b  ', 'a b ', 4), isNull);
    // A letter typed after a space.
    expect(periodOnDoubleSpace('a b ', 'a b x', 5), isNull);
    // A cursor outside the text.
    expect(periodOnDoubleSpace('a b', 'a b ', 9), isNull);
    expect(periodOnDoubleSpace('a b', 'a b ', 1), isNull);
  });

  test('trailing spaces already there do not pile up', () {
    final edit = periodOnDoubleSpace('a b   ', 'a b    ', 5);

    expect(edit?.text, 'a b. ');
  });
}
