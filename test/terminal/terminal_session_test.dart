import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/app_repository_exception.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
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
}) {
  final session = TerminalSession(
    registry: CommandRegistry(commands ?? defaultCommands),
    apps: apps,
    maxLines: maxLines,
    banner: banner,
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

  test('clear empties the log, including its own echo', () async {
    final session = _session(FakeAppRepository(), banner: ['hello']);
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

  test('notifies listeners once per submitted line', () async {
    final session = _session(FakeAppRepository());
    var notified = 0;
    session.addListener(() => notified++);

    await session.submit('help');

    expect(notified, 1);
  });

  test('a command that throws becomes an error line, not a crash', () async {
    final session = _session(
      FakeAppRepository(listError: const AppRepositoryException('boom')),
    );

    await session.submit('list');

    expect(_texts(session), [r'$ list', Messages.commandFailed('boom')]);
    expect(session.lines.last.kind, LogKind.error);
  });

  test('banner lines seed the log as output', () {
    final session = _session(FakeAppRepository(), banner: ['welcome']);

    expect(_texts(session), ['welcome']);
    expect(session.lines.single.kind, LogKind.output);
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
