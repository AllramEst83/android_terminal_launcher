import 'dart:async';

import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/spinner_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/in_memory_local_store.dart';

Future<({TerminalSession session, Completer<void> gate})> _pump(
  WidgetTester tester,
) async {
  final gate = Completer<void>();
  final session = TerminalSession(
    registry: CommandRegistry([
      Command(
        name: 'slow',
        description: 'waits',
        usage: 'slow',
        spinner: true,
        run: (context) async {
          await gate.future;
          return const CommandOutput(['done']);
        },
      ),
    ]),
    apps: FakeAppRepository(),
  );
  addTearDown(session.dispose);
  final themes = ThemeController(store: InMemoryLocalStore());
  final fontSize = FontSizeController(store: InMemoryLocalStore());
  addTearDown(themes.dispose);
  addTearDown(fontSize.dispose);
  await tester.pumpWidget(
    App(session: session, themes: themes, fontSize: fontSize),
  );
  return (session: session, gate: gate);
}

void main() {
  testWidgets('the bar turns through its four frames and comes round', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SpinnerText())),
    );

    final seen = <String>[];
    for (var i = 0; i < 5; i++) {
      seen.add(tester.widget<Text>(find.byType(Text)).data!);
      await tester.pump(spinnerStep);
    }

    expect(seen, ['[|]', '[/]', '[-]', r'[\]', '[|]']);
  });

  testWidgets('with animations off it stands still', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: SpinnerText())),
      ),
    );

    await tester.pump(spinnerStep * 3);

    expect(find.text('[|]'), findsOneWidget);
  });

  testWidgets('says it is working to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SpinnerText())),
    );

    expect(find.bySemanticsLabel('working'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('is on screen while a slow command runs, then gone', (
    tester,
  ) async {
    final rig = await _pump(tester);

    unawaited(rig.session.submit('slow'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SpinnerText), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(SpinnerText), findsOneWidget);
    expect(find.text('[|]'), findsOneWidget);
    await tester.pump(spinnerStep);
    expect(find.text('[/]'), findsOneWidget);

    rig.gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byType(SpinnerText), findsNothing);
    expect(find.text('done'), findsOneWidget);
    // The timer went with it: nothing is left pending when the test ends.
  });
}
