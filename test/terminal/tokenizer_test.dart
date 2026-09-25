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
}
