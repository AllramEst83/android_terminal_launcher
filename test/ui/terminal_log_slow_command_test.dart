import 'dart:async';

import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/in_memory_local_store.dart';

/// A command that finishes when the test says so, like a slow network call.
class _Slow {
  final gate = Completer<void>();

  late final command = Command(
    name: 'slow',
    description: 'waits',
    usage: 'slow',
    run: (context) async {
      await gate.future;
      return const CommandOutput(['done']);
    },
  );
}

final _quick = Command(
  name: 'quick',
  description: 'answers at once',
  usage: 'quick',
  run: (context) async => const CommandOutput(['quick answer']),
);

Future<TerminalSession> _pump(WidgetTester tester, _Slow slow) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(tester.view.resetViewInsets);
  final store = InMemoryLocalStore();
  final themes = ThemeController(store: store);
  addTearDown(themes.dispose);
  final fontSize = FontSizeController(store: store);
  addTearDown(fontSize.dispose);
  final session = TerminalSession(
    registry: CommandRegistry([slow.command, _quick]),
    apps: FakeAppRepository(),
    banner: const ['Welcome'],
  );
  addTearDown(session.dispose);
  await tester.pumpWidget(
    App(session: session, themes: themes, fontSize: fontSize),
  );
  return session;
}

void main() {
  testWidgets('the command is shown at once, while it is still running', (
    tester,
  ) async {
    final slow = _Slow();
    final session = await _pump(tester, slow);

    final running = session.submit('slow');
    await tester.pump();

    expect(find.text(r'$ slow'), findsOneWidget);
    expect(find.text('done'), findsNothing);

    slow.gate.complete();
    await running;
    await tester.pump();

    expect(find.text('done'), findsOneWidget);
  });

  testWidgets(
    'the keyboard opening and closing while a command runs breaks nothing',
    (tester) async {
      final slow = _Slow();
      final session = await _pump(tester, slow);
      // Enough history that the list is longer than the screen, with the
      // keyboard up so less of it is built.
      tester.view.viewInsets = const FakeViewPadding(bottom: 500);
      for (var i = 0; i < 60; i++) {
        await session.submit('quick');
      }
      await tester.pump();

      final running = session.submit('slow');
      for (final inset in [0.0, 500.0, 0.0, 300.0, 0.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      slow.gate.complete();
      await running;
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('done'), findsOneWidget);
    },
  );

  testWidgets('several commands in flight at once keep the log in order', (
    tester,
  ) async {
    final slow = _Slow();
    final session = await _pump(tester, slow);

    final first = session.submit('slow');
    await tester.pump();
    final second = session.submit('quick');
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    slow.gate.complete();
    await Future.wait([first, second]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      session.lines.map((l) => l.text),
      containsAllInOrder([r'$ slow', r'$ quick']),
    );
  });
}
