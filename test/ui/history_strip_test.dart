import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_history.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/in_memory_local_store.dart';

class _Ran {
  final lines = <String>[];
}

Command _echo(String name, _Ran ran) => Command(
  name: name,
  description: name,
  usage: '$name [x]',
  run: (context) async {
    ran.lines.add([name, ...context.args].join(' '));
    return CommandOutput(['ran $name']);
  },
);

Future<({TerminalSession session, CommandHistory history, _Ran ran})> _pump(
  WidgetTester tester, {
  List<String> remembered = const [],
}) async {
  final store = InMemoryLocalStore();
  final history = CommandHistory(store: store);
  for (final line in remembered) {
    await history.record(line);
  }
  final ran = _Ran();
  final session = TerminalSession(
    registry: CommandRegistry([_echo('weather', ran), _echo('cal', ran)]),
    apps: FakeAppRepository(),
    history: history,
  );
  addTearDown(session.dispose);
  final themes = ThemeController(store: InMemoryLocalStore());
  final fontSize = FontSizeController(store: InMemoryLocalStore());
  addTearDown(themes.dispose);
  addTearDown(fontSize.dispose);
  await tester.pumpWidget(
    App(session: session, themes: themes, fontSize: fontSize),
  );
  await tester.pump();
  return (session: session, history: history, ran: ran);
}

Future<void> _type(WidgetTester tester, String input) async {
  await tester.enterText(find.byType(TextField), input);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

String _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('an empty prompt shows what was used before, from the start', (
    tester,
  ) async {
    await _pump(tester, remembered: ['weather gothenburg', 'cal week']);

    expect(find.text('weather gothenburg'), findsOneWidget);
    expect(find.text('cal week'), findsOneWidget);
  });

  testWidgets('with no history there is no strip', (tester) async {
    await _pump(tester);

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('tapping a chip fills the prompt and runs nothing', (
    tester,
  ) async {
    final rig = await _pump(tester, remembered: ['weather gothenburg']);

    await tester.tap(find.text('weather gothenburg'));
    await tester.pump();

    expect(_field(tester), 'weather gothenburg');
    expect(rig.ran.lines, isEmpty);
  });

  testWidgets(
    'a command just run appears in the strip once the prompt clears',
    (tester) async {
      await _pump(tester);
      expect(find.text('cal week'), findsNothing);

      await _type(tester, 'cal week');

      expect(_field(tester), isEmpty);
      expect(find.widgetWithText(InkWell, 'cal week'), findsOneWidget);
    },
  );

  testWidgets(
    'typing swaps the chips for suggestions, and clearing brings them back',
    (tester) async {
      await _pump(tester, remembered: ['weather gothenburg']);

      await tester.enterText(find.byType(TextField), 'ca');
      await tester.pump();
      await tester.pump();
      expect(find.widgetWithText(InkWell, 'weather gothenburg'), findsNothing);
      expect(
        find.widgetWithText(InkWell, 'cal'),
        findsOneWidget,
        reason: 'the command itself is suggested instead',
      );

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.pump();
      expect(
        find.widgetWithText(InkWell, 'weather gothenburg'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a remembered line is offered as you type its start', (
    tester,
  ) async {
    await _pump(tester, remembered: ['weather gothenburg']);

    await tester.enterText(find.byType(TextField), 'wea');
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(InkWell, 'weather gothenburg'), findsOneWidget);
  });

  testWidgets('a tap in the strip then Enter runs it, and counts again', (
    tester,
  ) async {
    final rig = await _pump(tester, remembered: ['cal week']);

    await tester.tap(find.widgetWithText(InkWell, 'cal week'));
    await tester.pump();
    await _type(tester, _field(tester));

    expect(rig.ran.lines, ['cal week']);
    expect(rig.history.scoreNow(rig.history.top(1).single), greaterThan(1.5));
  });
}
