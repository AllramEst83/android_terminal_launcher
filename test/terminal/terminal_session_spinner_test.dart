import 'dart:async';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/log_line.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';

/// Commands that finish when the test says so, like a network call.
class _Rig {
  _Rig({bool autoDispose = true}) {
    session = TerminalSession(
      registry: CommandRegistry([
        Command(
          name: 'slow',
          description: 'waits, and shows a spinner',
          usage: 'slow',
          spinner: true,
          run: (context) async {
            await gate.future;
            if (fail) throw StateError('no network');
            return const CommandOutput(['done']);
          },
        ),
        Command(
          name: 'quiet',
          description: 'waits, and shows nothing',
          usage: 'quiet',
          run: (context) async {
            await gate.future;
            return const CommandOutput(['done']);
          },
        ),
        Command(
          name: 'ask',
          description: 'asks for a secret, then goes online',
          usage: 'ask',
          run: (context) async =>
              CommandAskSecret('secret?', busy: true, (secret) async {
                await gate.future;
                return const CommandOutput(['accepted']);
              }),
        ),
        Command(
          name: 'clear',
          description: 'clears',
          usage: 'clear',
          run: (context) async => const CommandClear(),
        ),
      ]),
      apps: FakeAppRepository(),
    );
    if (autoDispose) addTearDown(session.dispose);
  }

  late final TerminalSession session;
  Completer<void> gate = Completer<void>();
  bool fail = false;

  List<LogKind> get kinds => [for (final line in session.lines) line.kind];
  bool get spinning => kinds.contains(LogKind.progress);
}

const _delay = Duration(milliseconds: 250);

void main() {
  testWidgets('an answer before the delay never shows a spinner', (
    tester,
  ) async {
    final rig = _Rig();

    unawaited(rig.session.submit('slow'));
    await tester.pump(_delay ~/ 2);
    expect(rig.spinning, isFalse);
    rig.gate.complete();
    await tester.pump(_delay);

    expect(rig.spinning, isFalse);
    expect(rig.session.lines.last.text, 'done');
  });

  testWidgets('a slow one shows it once the delay has passed', (tester) async {
    final rig = _Rig();

    unawaited(rig.session.submit('slow'));
    await tester.pump(_delay + const Duration(milliseconds: 1));

    expect(rig.spinning, isTrue);
    expect(rig.session.lines.last.kind, LogKind.progress);
    expect(rig.session.lines.last.text, Messages.working);
    rig.gate.complete();
    await tester.pump();
  });

  testWidgets('the spinner is replaced by the answer in one announcement', (
    tester,
  ) async {
    final rig = _Rig();
    unawaited(rig.session.submit('slow'));
    await tester.pump(_delay * 2);
    final seen = <List<LogKind>>[];
    rig.session.addListener(() => seen.add(rig.kinds));

    rig.gate.complete();
    await tester.pump();

    expect(seen, [
      [LogKind.input, LogKind.output],
    ]);
  });

  testWidgets('a command without the tag never shows one', (tester) async {
    final rig = _Rig();

    unawaited(rig.session.submit('quiet'));
    await tester.pump(_delay * 4);

    expect(rig.spinning, isFalse);
    rig.gate.complete();
    await tester.pump();
    expect(rig.session.lines.last.text, 'done');
  });

  testWidgets('a command that fails takes the spinner away for the error', (
    tester,
  ) async {
    final rig = _Rig()..fail = true;
    unawaited(rig.session.submit('slow'));
    await tester.pump(_delay * 2);
    expect(rig.spinning, isTrue);

    rig.gate.complete();
    await tester.pump();

    expect(rig.spinning, isFalse);
    expect(rig.session.lines.last.kind, LogKind.error);
    expect(rig.session.lines.last.text, contains('no network'));
  });

  testWidgets('two slow commands each have their own spinner', (tester) async {
    final rig = _Rig();
    unawaited(rig.session.submit('slow'));
    unawaited(rig.session.submit('slow'));
    await tester.pump(_delay * 2);

    expect(rig.kinds.where((k) => k == LogKind.progress), hasLength(2));
    rig.gate.complete();
    await tester.pump();

    expect(rig.spinning, isFalse);
    expect(rig.kinds.where((k) => k == LogKind.output), hasLength(2));
  });

  testWidgets('clearing while one runs leaves no stray spinner behind', (
    tester,
  ) async {
    final rig = _Rig();
    unawaited(rig.session.submit('slow'));
    await tester.pump(_delay * 2);
    await rig.session.submit('clear');
    expect(rig.spinning, isFalse);

    rig.gate.complete();
    await tester.pump();

    expect(rig.spinning, isFalse);
    expect(rig.session.lines.last.text, 'done');
  });

  testWidgets('a hidden question that goes online shows one too', (
    tester,
  ) async {
    final rig = _Rig();
    await rig.session.submit('ask');
    unawaited(rig.session.submitFromPrompt('hunter2'));
    await tester.pump(_delay * 2);

    expect(rig.spinning, isTrue);
    expect(
      rig.session.lines.map((l) => l.text).join('\n'),
      isNot(contains('hunter2')),
    );
    rig.gate.complete();
    await tester.pump();

    expect(rig.spinning, isFalse);
    expect(rig.session.lines.last.text, 'accepted');
  });

  testWidgets('disposing while one is pending is quiet', (tester) async {
    final rig = _Rig(autoDispose: false);
    unawaited(rig.session.submit('slow'));
    await tester.pump(_delay * 2);

    rig.session.dispose();
    rig.gate.complete();
    await tester.pump(_delay);
  });
}
