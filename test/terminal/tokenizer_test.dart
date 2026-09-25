import 'package:android_terminal_launcher/terminal/tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tokenizer = Tokenizer();

  test('splits the command from its args on whitespace', () {
    final parsed = tokenizer.tokenize('open google chrome');

    expect(parsed.command, 'open');
    expect(parsed.args, ['google', 'chrome']);
  });

  test('collapses repeated and surrounding whitespace', () {
    final parsed = tokenizer.tokenize('  open \t  firefox  ');

    expect(parsed.command, 'open');
    expect(parsed.args, ['firefox']);
  });

  test('a lone command has no args', () {
    final parsed = tokenizer.tokenize('list');

    expect(parsed.command, 'list');
    expect(parsed.args, isEmpty);
  });

  test('blank input yields an empty ParsedInput', () {
    expect(tokenizer.tokenize('').isEmpty, isTrue);
    expect(tokenizer.tokenize('   \t ').isEmpty, isTrue);
  });

  group('quoting', () {
    test('a double-quoted word keeps its spaces', () {
      final parsed = tokenizer.tokenize('note add "buy some milk" now');

      expect(parsed.command, 'note');
      expect(parsed.args, ['add', 'buy some milk', 'now']);
    });

    test('single quotes work the same way', () {
      expect(tokenizer.tokenize("open 'Google Chrome'").args, [
        'Google Chrome',
      ]);
    });

    test('an empty quoted word is kept as an empty argument', () {
      expect(tokenizer.tokenize('note add ""').args, ['add', '']);
    });

    test('the command word itself may be quoted', () {
      expect(tokenizer.tokenize('"open" firefox').command, 'open');
    });

    test('text glued to a closing quote stays in the same word', () {
      expect(tokenizer.tokenize('say "a b"c d').args, ['a bc', 'd']);
    });

    test('a backslash escapes quotes and backslashes inside double quotes', () {
      expect(tokenizer.tokenize(r'say "she said \"hi\" \\ ok"').args, [
        r'she said "hi" \ ok',
      ]);
    });

    test('a backslash is literal in double quotes unless it escapes', () {
      expect(tokenizer.tokenize(r'say "a\nb"').args, [r'a\nb']);
    });

    test('single quotes are fully literal', () {
      expect(tokenizer.tokenize(r"say 'a\b'").args, [r'a\b']);
    });

    test('a backslash escapes a space outside quotes', () {
      expect(tokenizer.tokenize(r'open my\ app').args, ['my app']);
    });

    test('a quote in the middle of a word is an ordinary character', () {
      final parsed = tokenizer.tokenize("open McDonald's app");

      expect(parsed.hasUnterminatedQuote, isFalse);
      expect(parsed.args, ["McDonald's", 'app']);
    });

    test('a trailing backslash is kept literally', () {
      expect(tokenizer.tokenize(r'say a\').args, [r'a\']);
    });

    test('an unclosed quote is reported instead of guessed at', () {
      expect(tokenizer.tokenize('note add "oops').hasUnterminatedQuote, isTrue);
      expect(tokenizer.tokenize("say 'oops").hasUnterminatedQuote, isTrue);
      expect(tokenizer.tokenize('note add "ok"').hasUnterminatedQuote, isFalse);
    });
  });
}
