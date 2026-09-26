import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_history.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/suggestion.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/in_memory_local_store.dart';

Command _ok(String name, {HistoryPolicy history = HistoryPolicy.line}) =>
    Command(
      name: name,
      description: name,
      usage: '$name [x]',
      history: history,
      run: (context) async => CommandOutput(['ran $name']),
    );

class _Rig {
  _Rig({bool withHistory = true}) {
    history = CommandHistory(store: store, clock: () => now);
    session = TerminalSession(
      registry: CommandRegistry([
        _ok('weather'),
        _ok('cal'),
        _ok('note', history: HistoryPolicy.name),
        _ok('sms', history: HistoryPolicy.none),
        Command(
          name: 'fail',
          description: 'always fails',
          usage: 'fail',
          run: (context) async => CommandFailure.single('nope'),
        ),
        Command(
          name: 'boom',
          description: 'throws',
          usage: 'boom',
          run: (context) async => throw StateError('boom'),
        ),
        Command(
          name: 'login',
          description: 'asks for a secret',
          usage: 'login',
          history: HistoryPolicy.name,
          run: (context) async =>
              CommandAskSecret('password?', (s) async => CommandOutput([s])),
        ),
      ]),
      apps: FakeAppRepository(),
      history: withHistory ? history : null,
    );
    addTearDown(session.dispose);
  }

  final store = InMemoryLocalStore();
  DateTime now = DateTime(2026, 9, 26, 12);
  late final CommandHistory history;
  late final TerminalSession session;

  List<String> get kept => [for (final e in history.top(20)) e.line];

  Future<List<String>> chips(String input) async => [
    for (final s in await session.suggest(input)) s.completion,
  ];
}

void main() {
  group('what is remembered', () {
    test('a command that worked, as typed', () async {
      final rig = _Rig();

      await rig.session.submit('weather gothenburg');

      expect(rig.kept, ['weather gothenburg']);
    });

    test('is trimmed of the space around it', () async {
      final rig = _Rig();

      await rig.session.submit('  cal week  ');

      expect(rig.kept, ['cal week']);
    });

    test('a failure is not, since a typo is not a habit', () async {
      final rig = _Rig();

      await rig.session.submit('fail');

      expect(rig.kept, isEmpty);
    });

    test('nor a command that threw', () async {
      final rig = _Rig();

      await rig.session.submit('boom');

      expect(rig.kept, isEmpty);
    });

    test('nor one that does not exist, nor an unfinished quote', () async {
      final rig = _Rig();

      await rig.session.submit('nonsense');
      await rig.session.submit('weather "unfinished');

      expect(rig.kept, isEmpty);
    });

    test(
      'with the name only when the command says its arguments are private',
      () async {
        final rig = _Rig();

        await rig.session.submit('note add "buy the ring"');

        expect(rig.kept, ['note']);
      },
    );

    test('not at all for a command that says so', () async {
      final rig = _Rig();

      await rig.session.submit('sms anna "secret plans"');

      expect(rig.kept, isEmpty);
      expect(rig.store.writes, 0);
    });

    test(
      'the text of a private command is nowhere in what is stored',
      () async {
        final rig = _Rig();

        await rig.session.submit('note add "buy the ring"');
        await rig.session.submit('sms anna "secret plans"');

        final stored = (await rig.store.read(CommandHistory.key)).toString();
        expect(stored, isNot(contains('ring')));
        expect(stored, isNot(contains('secret')));
        expect(stored, isNot(contains('anna')));
      },
    );

    test(
      'the answer to a hidden question never is, only the command that asked',
      () async {
        final rig = _Rig();

        await rig.session.submit('login');
        await rig.session.submitFromPrompt('hunter2');

        expect(rig.kept, ['login']);
        expect(
          (await rig.store.read(CommandHistory.key)).toString(),
          isNot(contains('hunter2')),
        );
      },
    );

    test('a tap in a card is run but not remembered', () async {
      final rig = _Rig();

      await rig.session.submit('cal 2026-10-03', remember: false);

      expect(rig.session.lines.last.text, 'ran cal');
      expect(rig.kept, isEmpty);
    });

    test('one typed at the prompt is', () async {
      final rig = _Rig();

      await rig.session.submitFromPrompt('cal 2026-10-03');

      expect(rig.kept, ['cal 2026-10-03']);
    });

    test('a repeat counts up rather than being listed twice', () async {
      final rig = _Rig();

      await rig.session.submit('weather');
      await rig.session.submit('weather');

      expect(rig.kept, ['weather']);
      expect(rig.history.scoreNow(rig.history.top(1).single), closeTo(2, 1e-9));
    });

    test('nothing happens, and nothing breaks, without a history', () async {
      final rig = _Rig(withHistory: false);

      await rig.session.submit('weather');

      expect(rig.session.lines.last.text, 'ran weather');
      expect(rig.store.writes, 0);
    });
  });

  group('the chips for an empty prompt', () {
    test('are what has been used most, best first', () async {
      final rig = _Rig();
      await rig.session.submit('cal');
      await rig.session.submit('weather');
      await rig.session.submit('weather');

      expect(await rig.chips(''), ['weather', 'cal']);
      expect(await rig.chips('   '), ['weather', 'cal']);
    });

    test('carry the whole line, to fill and not to run', () async {
      final rig = _Rig();
      await rig.session.submit('weather gothenburg');

      expect(await rig.session.suggest(''), [
        const Suggestion(
          label: 'weather gothenburg',
          completion: 'weather gothenburg',
        ),
      ]);
    });

    test('are no more than the strip holds', () async {
      final rig = _Rig();
      for (var i = 0; i < 12; i++) {
        await rig.session.submit('weather city$i');
      }

      expect(await rig.chips(''), hasLength(8));
    });

    test('are none without a history, as before', () async {
      final rig = _Rig(withHistory: false);
      await rig.session.submit('weather');

      expect(await rig.chips(''), isEmpty);
    });

    test('are none while a password is asked for', () async {
      final rig = _Rig();
      await rig.session.submit('weather');
      await rig.session.submit('login');

      expect(await rig.chips(''), isEmpty);
    });

    test('are there straight after a restart', () async {
      final rig = _Rig();
      await rig.session.submit('weather gothenburg');

      final again = CommandHistory(store: rig.store, clock: () => rig.now);
      await again.load();
      final restarted = TerminalSession(
        registry: CommandRegistry([_ok('weather')]),
        apps: FakeAppRepository(),
        history: again,
      );
      addTearDown(restarted.dispose);

      expect(
        [for (final s in await restarted.suggest('')) s.completion],
        ['weather gothenburg'],
      );
    });
  });

  group('typing', () {
    test('puts the lines that carry on from it first', () async {
      final rig = _Rig();
      await rig.session.submit('weather gothenburg');

      final chips = await rig.chips('we');

      expect(chips.first, 'weather gothenburg');
      expect(chips, contains('weather '), reason: 'the command itself too');
    });

    test(
      'does not repeat a suggestion the command list already gives',
      () async {
        final rig = _Rig();
        await rig.session.submit('cal');

        final chips = await rig.chips('c');

        expect(chips.where((c) => c.trim() == 'cal'), hasLength(1));
      },
    );

    test('offers nothing extra when nothing matches', () async {
      final rig = _Rig();
      await rig.session.submit('weather gothenburg');

      expect(await rig.chips('ca'), ['cal ']);
    });

    test('is unchanged without a history', () async {
      final rig = _Rig(withHistory: false);

      expect(await rig.chips('we'), ['weather ']);
    });
  });

  test(
    'listeners hear that the history changed, with the command\'s output',
    () async {
      final rig = _Rig();
      var calls = 0;
      rig.session.addListener(() => calls++);

      await rig.session.submit('weather');

      // The echo, then the output with the new history already in place.
      expect(calls, 2);
      expect(await rig.chips(''), ['weather']);
    },
  );
}
