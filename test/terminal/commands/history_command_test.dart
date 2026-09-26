import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_history.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/history_command.dart';
import 'package:android_terminal_launcher/terminal/providers/history_provider.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/in_memory_local_store.dart';

class _Rig {
  final store = InMemoryLocalStore();
  DateTime now = DateTime(2026, 9, 26, 12);
  late final history = CommandHistory(store: store, clock: () => now);
  late final Command command = historyCommand(history);

  Future<CommandResult> run(List<String> args) => command.run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() || CommandAskSecret() => fail('unexpected result'),
};

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  test('an empty history says so', () async {
    final result = await rig.run([]);

    final notice = (result as CommandOutput).block! as NoticeBlock;
    expect(notice.message, Messages.historyEmpty);
    expect(notice.kind, NoticeKind.info);
  });

  test('lists the lines, most used first, under a count', () async {
    await rig.history.record('cal');
    await rig.history.record('weather gothenburg');
    await rig.history.record('weather gothenburg');

    final result = await rig.run([]);

    expect(_lines(result), [
      'history: 2 commands',
      '  weather gothenburg',
      '  cal',
    ]);
  });

  test('as a card whose taps fill the prompt and never run', () async {
    await rig.history.record('sms-like risky "thing"');
    await rig.history.record('weather');

    final result = await rig.run([]);

    final card = (result as CommandOutput).block! as ChoiceBlock;
    final options = card.groups.single.options;
    expect(
      [for (final o in options) o.command],
      ['sms-like risky "thing"', 'weather'],
    );
    expect(options.every((o) => o.fill), isTrue);
    expect(card.footer, Messages.historyFooter);
  });

  test('lists no more than twenty', () async {
    for (var i = 0; i < 30; i++) {
      await rig.history.record('cmd $i');
    }

    final result = await rig.run([]);

    expect(_lines(result), hasLength(1 + historyListed));
    expect(_lines(result).first, 'history: 30 commands');
  });

  test('one command is not plural', () async {
    await rig.history.record('cal');

    expect(_lines(await rig.run([])).first, 'history: 1 command');
  });

  test('clear forgets everything, in the store too', () async {
    await rig.history.record('cal');

    final result = await rig.run(['clear']);

    expect(_lines(result), [Messages.historyCleared]);
    expect(rig.history.length, 0);
    expect(await rig.store.read(CommandHistory.key), isNull);
  });

  test('anything else shows the usage', () async {
    expect(_lines(await rig.run(['wipe'])), Messages.historyUsage);
    expect(_lines(await rig.run(['clear', 'now'])), Messages.historyUsage);
  });

  test('offers clear as a subcommand', () {
    final suggest = rig.command.argSuggestions!;

    expect(suggest('', const []), ['clear']);
    expect(suggest('cl', const []), ['clear']);
    expect(suggest('x', const []), isEmpty);
    expect(suggest('clear ', const []), isEmpty);
  });

  test('looking at the history does not add to it', () async {
    final session = TerminalSession(
      registry: CommandRegistry.fromProviders([HistoryProvider(rig.history)]),
      apps: FakeAppRepository(),
      history: rig.history,
    );
    addTearDown(session.dispose);

    await session.submit('history');
    await session.submit('history clear');

    expect(rig.history.length, 0);
  });

  test('is in the system help group', () {
    expect(HistoryProvider(rig.history).name, 'system');
  });
}
