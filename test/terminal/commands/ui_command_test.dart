import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/view_mode.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/ui_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_view_mode_settings.dart';

Future<CommandResult> _ui(FakeViewModeSettings settings, List<String> args) {
  return uiCommand(settings).run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() => fail('unexpected clear'),
};

void main() {
  test('lists the views and stars the current one', () async {
    final lines = _lines(
      await _ui(FakeViewModeSettings(current: ViewMode.plain), []),
    );

    expect(lines.first, Messages.uiHeader);
    expect(lines, hasLength(1 + ViewMode.values.length));
    final starred = lines.where((l) => l.startsWith('*')).toList();
    expect(starred.single, contains('plain'));
    expect(starred.single, contains(ViewMode.plain.description));
  });

  test('a name switches the view, ignoring case', () async {
    final settings = FakeViewModeSettings();

    final result = await _ui(settings, ['PLAIN']);

    expect(settings.selected, [ViewMode.plain]);
    expect(_lines(result), [Messages.uiChanged('plain')]);
  });

  test('an unknown name lists what is available and changes nothing', () async {
    final settings = FakeViewModeSettings();

    final result = await _ui(settings, ['fancy']);

    expect(result, isA<CommandFailure>());
    expect(_lines(result).single, contains("'fancy'"));
    expect(_lines(result).single, contains('rich, plain'));
    expect(settings.selected, isEmpty);
  });

  test('too many arguments print the usage', () async {
    final result = await _ui(FakeViewModeSettings(), ['rich', 'plain']);

    expect(result, isA<CommandFailure>());
    expect(_lines(result), [Messages.uiUsage]);
  });

  test('a failed save still reports the change, and the warning', () async {
    final settings = FakeViewModeSettings(
      saveError: const LocalStoreException('disk full'),
    );

    final result = await _ui(settings, ['plain']);

    expect(result, isA<CommandOutput>());
    expect(_lines(result), [
      Messages.uiChanged('plain'),
      Messages.uiNotSaved('disk full'),
    ]);
    expect(settings.current, ViewMode.plain);
  });

  test('argument suggestions narrow by prefix', () {
    final suggest = uiCommand(FakeViewModeSettings()).argSuggestions!;

    expect(suggest('', const []), ['rich', 'plain']);
    expect(suggest('P', const []), ['plain']);
    expect(suggest('zzz', const []), isEmpty);
  });
}
