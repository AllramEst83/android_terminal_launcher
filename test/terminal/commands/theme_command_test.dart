import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/theme_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_theme_settings.dart';

Future<CommandResult> _theme(FakeThemeSettings settings, List<String> args) {
  return themeCommand(settings).run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() || CommandAskSecret() => fail('unexpected clear'),
};

void main() {
  test('lists every theme and stars the current one', () async {
    final lines = _lines(
      await _theme(FakeThemeSettings(current: ThemeChoice.light), []),
    );

    expect(lines.first, Messages.themeHeader);
    expect(lines, hasLength(1 + ThemeChoice.values.length));
    final starred = lines.where((l) => l.startsWith('*')).toList();
    expect(starred, hasLength(1));
    expect(starred.single, contains('light'));
    expect(starred.single, contains(ThemeChoice.light.description));
  });

  test('"list" behaves like no argument', () async {
    final settings = FakeThemeSettings();

    expect(
      _lines(await _theme(settings, ['LIST'])).first,
      Messages.themeHeader,
    );
    expect(settings.selected, isEmpty);
  });

  test('a name switches the theme', () async {
    final settings = FakeThemeSettings();

    final result = await _theme(settings, ['coffee']);

    expect(settings.selected, [ThemeChoice.coffee]);
    expect(_lines(result), [Messages.themeChanged('coffee')]);
  });

  test('theme names are case-insensitive', () async {
    final settings = FakeThemeSettings();

    await _theme(settings, ['Light']);

    expect(settings.selected, [ThemeChoice.light]);
  });

  test('an unknown name lists what is available and changes nothing', () async {
    final settings = FakeThemeSettings();

    final result = await _theme(settings, ['neon']);

    expect(result, isA<CommandFailure>());
    expect(_lines(result).single, contains("'neon'"));
    expect(_lines(result).single, contains('dark, light, coffee'));
    expect(settings.selected, isEmpty);
  });

  test('too many arguments print the usage', () async {
    final result = await _theme(FakeThemeSettings(), ['dark', 'light']);

    expect(result, isA<CommandFailure>());
    expect(_lines(result), [Messages.themeUsage]);
  });

  test('a failed save still reports the change, and the warning', () async {
    final settings = FakeThemeSettings(
      saveError: const LocalStoreException('disk full'),
    );

    final result = await _theme(settings, ['coffee']);

    expect(result, isA<CommandOutput>());
    expect(_lines(result), [
      Messages.themeChanged('coffee'),
      Messages.themeNotSaved('disk full'),
    ]);
    expect(settings.current, ThemeChoice.coffee);
  });

  group('the three newer themes', () {
    for (final name in ['unicorn', 'pastel', 'cyberpunk']) {
      test('$name can be switched to', () async {
        final settings = FakeThemeSettings();

        final result = await _theme(settings, [name]);

        expect(settings.selected, [ThemeChoice.parse(name)]);
        expect(_lines(result), [Messages.themeChanged(name)]);
      });
    }

    test('every listing line fits a phone screen', () async {
      for (final line in _lines(await _theme(FakeThemeSettings(), []))) {
        expect(line.length, lessThanOrEqualTo(36), reason: line);
      }
    });

    test('the help notes name every theme, on short lines', () {
      final notes = themeCommand(FakeThemeSettings()).notes;

      for (final choice in ThemeChoice.values) {
        expect(notes.join(' '), contains(choice.name));
      }
      for (final line in notes) {
        expect(line.length + 2, lessThanOrEqualTo(36), reason: line);
      }
    });
  });

  group('argument suggestions', () {
    final suggest = themeCommand(FakeThemeSettings()).argSuggestions!;

    test('offer list and every theme for an empty argument', () {
      expect(suggest('', const []), [
        'list',
        'dark',
        'light',
        'coffee',
        'unicorn',
        'pastel',
        'cyberpunk',
      ]);
    });

    test('narrow by prefix, ignoring case', () {
      expect(suggest('co', const []), ['coffee']);
      expect(suggest('L', const []), ['list', 'light']);
      expect(suggest('zzz', const []), isEmpty);
    });
  });
}
