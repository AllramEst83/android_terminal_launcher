import 'package:android_terminal_launcher/terminal/commands/plain_flag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('takes the flag out wherever it is, and says it was there', () {
    for (final args in [
      ['--plain', 'a', 'b'],
      ['a', '--plain', 'b'],
      ['a', 'b', '--plain'],
    ]) {
      final split = splitPlainFlag(args);

      expect(split.args, ['a', 'b'], reason: '$args');
      expect(split.plain, isTrue, reason: '$args');
    }
  });

  test('leaves other arguments alone when the flag is not there', () {
    final split = splitPlainFlag(['a', '--plainly', 'b']);

    expect(split.args, ['a', '--plainly', 'b']);
    expect(split.plain, isFalse);
  });

  test('no arguments', () {
    final split = splitPlainFlag(const []);

    expect(split.args, isEmpty);
    expect(split.plain, isFalse);
  });
}
