import 'dart:async';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/app_repository_exception.dart';
import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/log_line.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';

TerminalSession _session(
  FakeAppRepository apps, {
  int maxLines = 500,
  List<String> banner = const [],
  Iterable<Command>? commands,
  DateTime Function()? clock,
}) {
  final session = TerminalSession(
    registry: CommandRegistry(commands ?? defaultCommands),
    apps: apps,
    maxLines: maxLines,
    banner: banner,
    clock: clock ?? systemNow,
  );
  addTearDown(session.dispose);
  return session;
}

List<String> _texts(TerminalSession session) =>
    session.lines.map((l) => l.text).toList();

void main() {
  test('echoes the input, then appends the command output', () async {
    final session = _session(
      FakeAppRepository(
        apps: const [AppInfo(label: 'Clock', packageName: 'clock')],
      ),
    );

    await session.submit('list');

    expect(_texts(session), [r'$ list', 'Clock']);
    expect(session.lines.first.kind, LogKind.input);
    expect(session.lines.last.kind, LogKind.output);
  });

  test('unknown commands print an error naming the command', () async {
    final session = _session(FakeAppRepository());

    await session.submit('frobnicate now');

    expect(_texts(session), [
      r'$ frobnicate now',
      'unknown command: frobnicate',
    ]);
    expect(session.lines.last.kind, LogKind.error);
  });

  test('command lookup is case-insensitive', () async {
    final session = _session(FakeAppRepository());

    await session.submit('HELP');

    expect(session.lines.last.text, isNot(startsWith('unknown command')));
  });

  test('blank input is ignored', () async {
    final session = _session(FakeAppRepository());
    var notified = 0;
    session.addListener(() => notified++);

    await session.submit('   ');

    expect(session.lines, isEmpty);
    expect(notified, 0);
  });

  test('clear replaces the log with the banner, not with nothing', () async {
    final session = _session(FakeAppRepository(), banner: ['hello']);
    await session.submit('help');

    await session.submit('clear');

    expect(_texts(session), ['hello']);
    expect(session.lines.single.kind, LogKind.banner);
  });

  test('clear empties the log when there is no banner', () async {
    final session = _session(FakeAppRepository());
    await session.submit('help');

    await session.submit('clear');

    expect(session.lines, isEmpty);
  });

  test('the log is capped, dropping the oldest lines', () async {
    final session = _session(FakeAppRepository(), maxLines: 3);

    await session.submit('a');
    await session.submit('b');

    // Each submit adds an echo and an error: four lines, capped at three.
    expect(_texts(session), [
      'unknown command: a',
      r'$ b',
      'unknown command: b',
    ]);
  });

  test('line ids stay unique and increasing after the cap trims', () async {
    final session = _session(FakeAppRepository(), maxLines: 2);

    await session.submit('a');
    await session.submit('b');

    final ids = session.lines.map((l) => l.id).toList();
    expect(ids, [2, 3]);
  });

  test('tells listeners about the echo and again about the result', () async {
    final session = _session(FakeAppRepository());
    final seen = <int>[];
    session.addListener(() => seen.add(session.lines.length));

    await session.submit('help');

    // First just the echoed command, then the command and what it printed.
    expect(seen, hasLength(2));
    expect(seen.first, 1);
    expect(seen.last, greaterThan(seen.first));
  });

  test('a line that never runs a command is announced once', () async {
    final session = _session(FakeAppRepository());
    var notified = 0;
    session.addListener(() => notified++);

    await session.submit('frobnicate');
    await session.submit('echo "unterminated');

    expect(notified, 2);
  });

  test('the log is never longer than the last announcement said', () async {
    final gate = Completer<void>();
    final session = _session(
      FakeAppRepository(),
      commands: [
        Command(
          name: 'wait',
          description: 'waits',
          usage: 'wait',
          run: (context) async {
            await gate.future;
            return const CommandOutput(['done']);
          },
        ),
      ],
    );
    var announced = 0;
    session.addListener(() => announced = session.lines.length);

    final running = session.submit('wait');

    // While it runs, what the UI was told is what the log holds.
    expect(announced, session.lines.length);
    gate.complete();
    await running;
    expect(announced, session.lines.length);
  });

  test('a command that throws becomes an error line, not a crash', () async {
    final session = _session(
      FakeAppRepository(listError: const AppRepositoryException('boom')),
    );

    await session.submit('list');

    expect(_texts(session), [r'$ list', Messages.commandFailed('boom')]);
    expect(session.lines.last.kind, LogKind.error);
  });

  test('banner lines seed the log', () {
    final session = _session(FakeAppRepository(), banner: ['welcome']);

    expect(_texts(session), ['welcome']);
    expect(session.lines.single.kind, LogKind.banner);
  });

  test('date runs through the session clock, also via its alias', () async {
    final session = TerminalSession(
      registry: CommandRegistry(defaultCommands),
      apps: FakeAppRepository(),
      clock: () => DateTime(2026, 9, 25, 16, 30, 12),
    );
    addTearDown(session.dispose);

    await session.submit('time');

    expect(session.lines.last.text, 'Fri 2026-09-25 16:30:12');
  });

  test('refresh re-queries the repository', () async {
    final apps = FakeAppRepository(
      apps: const [AppInfo(label: 'Clock', packageName: 'clock')],
    );
    final session = _session(apps);

    await session.submit('refresh');

    expect(apps.refreshCalls, 1);
    expect(session.lines.last.text, Messages.refreshed(1));
  });

  test('a grid output marks its lines with their column count', () async {
    final session = _session(
      FakeAppRepository(),
      commands: [
        Command(
          name: 'grid',
          description: 'grid',
          usage: 'grid',
          run: (context) async =>
              const CommandOutput(['ab', 'cd'], columns: 40),
        ),
        Command(
          name: 'plain',
          description: 'plain',
          usage: 'plain',
          run: (context) async => const CommandOutput(['ef']),
        ),
      ],
    );

    await session.submit('grid');
    await session.submit('plain');

    expect(session.lines.map((l) => l.columns), [null, 40, 40, null, null]);
  });

  test('styles on a grid output are kept on the log lines', () async {
    final styles = [
      [const StyledRun('ab', fg: TvColor.yellow, bg: TvColor.blue)],
      [const StyledRun('cd')],
    ];
    final session = _session(
      FakeAppRepository(),
      commands: [
        Command(
          name: 'tv',
          description: 'tv',
          usage: 'tv',
          run: (context) async =>
              CommandOutput(const ['ab', 'cd'], columns: 2, styles: styles),
        ),
      ],
    );

    await session.submit('tv');

    expect(session.lines.map((l) => l.runs), [null, styles[0], styles[1]]);
  });

  test('styles that do not match the lines one to one are dropped', () async {
    final session = _session(
      FakeAppRepository(),
      commands: [
        Command(
          name: 'tv',
          description: 'tv',
          usage: 'tv',
          run: (context) async => const CommandOutput(
            ['ab', 'cd'],
            columns: 2,
            styles: [
              [StyledRun('ab')],
            ],
          ),
        ),
      ],
    );

    await session.submit('tv');

    expect(session.lines.map((l) => l.runs), [null, null, null]);
    expect(session.lines.skip(1).map((l) => l.text), ['ab', 'cd']);
  });

  test('an unterminated quote prints an error and runs nothing', () async {
    final apps = FakeAppRepository(
      apps: const [AppInfo(label: 'Firefox', packageName: 'ff')],
    );
    final session = _session(apps);

    await session.submit('open "fire');

    expect(session.lines.last.text, Messages.unterminatedQuote);
    expect(session.lines.last.kind, LogKind.error);
    expect(apps.launched, isEmpty);
  });

  test('a quoted app name opens that app', () async {
    final apps = FakeAppRepository(
      apps: const [AppInfo(label: 'Google Chrome', packageName: 'chrome')],
    );
    final session = _session(apps);

    await session.submit('open "Google Chrome"');

    expect(apps.launched, ['chrome']);
  });

  test('a command that throws an Error also becomes an error line', () async {
    final session = _session(
      FakeAppRepository(),
      commands: [
        Command(
          name: 'boom',
          description: 'always fails',
          usage: 'boom',
          run: (context) async => throw StateError('bad state'),
        ),
      ],
    );

    await session.submit('boom');

    expect(session.lines.last.kind, LogKind.error);
    expect(session.lines.last.text, contains('bad state'));
  });

  group('suggest', () {
    test('offers command names and installed apps', () async {
      final session = _session(
        FakeAppRepository(
          apps: const [AppInfo(label: 'Firefox', packageName: 'ff')],
        ),
      );

      expect((await session.suggest('op')).map((s) => s.completion), ['open ']);
      expect((await session.suggest('open fi')).map((s) => s.completion), [
        'open Firefox',
      ]);
    });

    test('blank input suggests nothing and does not query apps', () async {
      final apps = FakeAppRepository();
      final session = _session(apps);

      expect(await session.suggest('  '), isEmpty);
      expect(apps.listCalls, 0);
    });

    test('still suggests commands when the app list cannot load', () async {
      final session = _session(
        FakeAppRepository(listError: const AppRepositoryException('boom')),
      );

      expect(await session.suggest('cl'), isNotEmpty);
      expect(await session.suggest('open '), isEmpty);
    });

    test('does not re-query a failing app list on every keystroke', () async {
      var now = DateTime(2026);
      final apps = FakeAppRepository(
        listError: const AppRepositoryException('boom'),
      );
      final session = _session(apps, clock: () => now);

      await session.suggest('open ');
      await session.suggest('open f');
      await session.suggest('open fi');
      expect(apps.listCalls, 1);

      now = now.add(const Duration(seconds: 6));
      await session.suggest('open fir');
      expect(apps.listCalls, 2);
    });

    test('recovers as soon as the app list loads again', () async {
      var now = DateTime(2026);
      final apps = FakeAppRepository(
        apps: const [AppInfo(label: 'Firefox', packageName: 'ff')],
        listError: const AppRepositoryException('boom'),
      );
      final session = _session(apps, clock: () => now);
      expect(await session.suggest('open f'), isEmpty);

      apps.listError = null;
      now = now.add(const Duration(seconds: 6));

      expect((await session.suggest('open f')).map((s) => s.completion), [
        'open Firefox',
      ]);
      // A success clears the failure, so the next call is not held back.
      expect(await session.suggest('open fi'), isNotEmpty);
    });

    test('still returns nothing when a command suggester throws', () async {
      final session = _session(
        FakeAppRepository(),
        commands: [
          Command(
            name: 'bad',
            description: 'broken suggester',
            usage: 'bad <x>',
            run: (context) async => const CommandOutput(['ok']),
            argSuggestions: (partial, apps) => throw StateError('nope'),
          ),
        ],
      );

      expect(await session.suggest('bad x'), isEmpty);
    });

    test('does not touch the log', () async {
      final session = _session(FakeAppRepository());

      await session.suggest('op');

      expect(session.lines, isEmpty);
    });
  });

  test('uninstall goes through the repository', () async {
    final apps = FakeAppRepository(
      apps: const [AppInfo(label: 'Firefox', packageName: 'ff')],
    );
    final session = _session(apps);

    await session.submit('uninstall fire');

    expect(apps.uninstalled, ['ff']);
    expect(apps.launched, isEmpty);
    expect(session.lines.last.text, Messages.uninstallStarted('Firefox'));
  });

  test('open launches through the repository', () async {
    final apps = FakeAppRepository(
      apps: const [AppInfo(label: 'Firefox', packageName: 'ff')],
    );
    final session = _session(apps);

    await session.submit('open fire');

    expect(apps.launched, ['ff']);
    expect(session.lines.last.text, Messages.opening('Firefox'));
  });
}
