import 'package:android_terminal_launcher/terminal/tokenizer.dart';
import 'package:android_terminal_launcher/terminal/tools/quote.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the tokenizer makes of `cmd <quoted>`: the one argument it reads back.
List<String> _read(String quoted) =>
    const Tokenizer().tokenize('cmd $quoted').args;

void main() {
  test('a plain word is left alone', () {
    expect(quoteArg('firefox'), 'firefox');
    expect(quoteArg('070-1234567'), '070-1234567');
    expect(quoteArg('+46701234567'), '+46701234567');
    expect(quoteArg('åäö'), 'åäö');
  });

  test('words with spaces, quotes or backslashes are quoted', () {
    expect(quoteArg('Play Store'), '"Play Store"');
    expect(quoteArg(''), '""');
    expect(quoteArg("McDonald's"), '"McDonald\'s"');
    expect(quoteArg('say "hi"'), r'"say \"hi\""');
    expect(quoteArg(r'a\b'), r'"a\\b"');
  });

  test('whatever it makes, the tokenizer reads back as one argument', () {
    for (final text in [
      'firefox',
      'Play Store',
      '',
      "McDonald's",
      'say "hi"',
      r'a\b',
      r'trailing\',
      '"',
      "'",
      'tab\there',
      '  padded  ',
      'Anna Andersson',
      'ünï cödé',
      r'\"',
      r'both \ and "',
    ]) {
      expect(_read(quoteArg(text)), [text], reason: 'for "$text"');
    }
  });

  test('several quoted arguments stay several', () {
    final args = const Tokenizer()
        .tokenize('sms ${quoteArg('Anna Andersson')} ${quoteArg('on my way')}')
        .args;

    expect(args, ['Anna Andersson', 'on my way']);
  });
}
