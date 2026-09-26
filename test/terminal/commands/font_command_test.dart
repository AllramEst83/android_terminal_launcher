import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/font_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_font_size_settings.dart';

Future<CommandResult> _font(FakeFontSizeSettings settings, List<String> args) {
  return fontCommand(settings).run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() || CommandAskSecret() => fail('unexpected clear'),
};

void main() {
  test('lists every size and stars the current one', () async {
    final lines = _lines(
      await _font(FakeFontSizeSettings(current: FontSizeChoice.large), []),
    );

    expect(lines.first, Messages.fontHeader);
    expect(lines, hasLength(1 + FontSizeChoice.values.length));
    final starred = lines.where((l) => l.startsWith('*')).toList();
    expect(starred, hasLength(1));
    expect(starred.single, contains('large'));
    expect(starred.single, contains(FontSizeChoice.large.description));
  });

  test('"list" behaves like no argument', () async {
    final settings = FakeFontSizeSettings();

    expect(_lines(await _font(settings, ['LIST'])).first, Messages.fontHeader);
    expect(settings.selected, isEmpty);
  });

  test('a name switches the size', () async {
    final settings = FakeFontSizeSettings();

    final result = await _font(settings, ['huge']);

    expect(settings.selected, [FontSizeChoice.huge]);
    expect(_lines(result), [Messages.fontChanged('huge')]);
  });

  test('size names are case-insensitive', () async {
    final settings = FakeFontSizeSettings();

    await _font(settings, ['Large']);

    expect(settings.selected, [FontSizeChoice.large]);
  });

  test('an unknown name lists what is available and changes nothing', () async {
    final settings = FakeFontSizeSettings();

    final result = await _font(settings, ['gigantic']);

    expect(result, isA<CommandFailure>());
    expect(_lines(result).single, contains("'gigantic'"));
    expect(_lines(result).single, contains('small, normal, large, huge'));
    expect(settings.selected, isEmpty);
  });

  test('too many arguments print the usage', () async {
    final result = await _font(FakeFontSizeSettings(), ['large', 'huge']);

    expect(result, isA<CommandFailure>());
    expect(_lines(result), [Messages.fontUsage]);
  });

  test('a failed save still reports the change, and the warning', () async {
    final settings = FakeFontSizeSettings(
      saveError: const LocalStoreException('disk full'),
    );

    final result = await _font(settings, ['huge']);

    expect(result, isA<CommandOutput>());
    expect(_lines(result), [
      Messages.fontChanged('huge'),
      Messages.fontNotSaved('disk full'),
    ]);
    expect(settings.current, FontSizeChoice.huge);
  });

  group('argument suggestions', () {
    final suggest = fontCommand(FakeFontSizeSettings()).argSuggestions!;

    test('offer list and every size for an empty argument', () {
      expect(suggest('', const []), [
        'list',
        'small',
        'normal',
        'large',
        'huge',
      ]);
    });

    test('narrow by prefix, ignoring case', () {
      expect(suggest('h', const []), ['huge']);
      expect(suggest('L', const []), ['list', 'large']);
      expect(suggest('zzz', const []), isEmpty);
    });
  });
}
