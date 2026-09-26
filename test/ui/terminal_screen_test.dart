import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/ascii_banner.dart';
import 'package:android_terminal_launcher/ui/suggestion_bar.dart';
import 'package:android_terminal_launcher/ui/terminal_log.dart';
import 'package:android_terminal_launcher/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/in_memory_local_store.dart';

ThemeController _themes() {
  final themes = ThemeController(store: InMemoryLocalStore());
  addTearDown(themes.dispose);
  return themes;
}

FontSizeController _fontSize() {
  final fontSize = FontSizeController(store: InMemoryLocalStore());
  addTearDown(fontSize.dispose);
  return fontSize;
}

Future<TerminalSession> _pumpApp(
  WidgetTester tester, {
  FakeAppRepository? apps,
  int maxLines = 500,
  List<String> banner = const [],
}) async {
  final session = TerminalSession(
    registry: CommandRegistry(defaultCommands),
    apps: apps ?? FakeAppRepository(),
    maxLines: maxLines,
    banner: banner,
  );
  addTearDown(session.dispose);
  await tester.pumpWidget(
    App(session: session, themes: _themes(), fontSize: _fontSize()),
  );
  return session;
}

Future<void> _type(WidgetTester tester, String input) async {
  await tester.enterText(find.byType(TextField), input);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

FocusNode _inputFocus(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode;

void main() {
  testWidgets('submitting a command echoes it and shows its output', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _type(tester, 'help');

    expect(find.text(r'$ help'), findsOneWidget);
    expect(find.text(Messages.helpHeader), findsOneWidget);
  });

  testWidgets('list shows the installed apps', (tester) async {
    await _pumpApp(
      tester,
      apps: FakeAppRepository(
        apps: const [
          AppInfo(label: 'Clock', packageName: 'clock'),
          AppInfo(label: 'Maps', packageName: 'maps'),
        ],
      ),
    );

    await _type(tester, 'list');

    expect(find.text('Clock'), findsOneWidget);
    expect(find.text('Maps'), findsOneWidget);
  });

  testWidgets('open launches the app', (tester) async {
    final apps = FakeAppRepository(
      apps: const [AppInfo(label: 'Clock', packageName: 'clock')],
    );
    await _pumpApp(tester, apps: apps);

    await _type(tester, 'open clock');

    expect(apps.launched, ['clock']);
    expect(find.text(Messages.opening('Clock')), findsOneWidget);
  });

  testWidgets('errors are drawn in the theme error colour', (tester) async {
    await _pumpApp(tester);

    await _type(tester, 'nope');

    final text = tester.widget<Text>(find.text('unknown command: nope'));
    expect(text.style?.color, themeFor(ThemeChoice.dark).colorScheme.error);
  });

  testWidgets('input is cleared and keeps focus after submit', (tester) async {
    await _pumpApp(tester);
    await tester.pump();

    await _type(tester, 'help');

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
    expect(_inputFocus(tester).hasFocus, isTrue);
  });

  testWidgets('input regains focus when the app resumes', (tester) async {
    await _pumpApp(tester);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(_inputFocus(tester).hasFocus, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(_inputFocus(tester).hasFocus, isTrue);
  });

  testWidgets('clear empties the log', (tester) async {
    await _pumpApp(tester);
    await _type(tester, 'help');

    await _type(tester, 'clear');

    expect(find.text(Messages.helpHeader), findsNothing);
    expect(find.text(r'$ help'), findsNothing);
  });

  group('suggestions', () {
    const clock = AppInfo(label: 'Clock', packageName: 'clock');
    const firefox = AppInfo(label: 'Firefox', packageName: 'ff');

    Future<void> typeText(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
    }

    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('appear as you type', (tester) async {
      await _pumpApp(tester);

      await typeText(tester, 'op');

      expect(find.byType(SuggestionBar), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'open'), findsOneWidget);
    });

    testWidgets('tapping one fills the input instead of running it', (
      tester,
    ) async {
      final apps = FakeAppRepository(apps: const [clock, firefox]);
      await _pumpApp(tester, apps: apps);
      await typeText(tester, 'open fi');

      await tester.tap(find.widgetWithText(InkWell, 'Firefox'));
      await tester.pump();

      expect(fieldText(tester), 'open Firefox');
      expect(apps.launched, isEmpty);
      expect(find.text(r'$ open Firefox'), findsNothing);
    });

    testWidgets('keeps focus and puts the cursor at the end', (tester) async {
      await _pumpApp(tester, apps: FakeAppRepository(apps: const [firefox]));
      await tester.pump();
      await typeText(tester, 'open fi');

      await tester.tap(find.widgetWithText(InkWell, 'Firefox'));
      await tester.pump();

      expect(_inputFocus(tester).hasFocus, isTrue);
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(controller.selection, const TextSelection.collapsed(offset: 12));
    });

    testWidgets('a filled suggestion can be edited, then run', (tester) async {
      final apps = FakeAppRepository(apps: const [firefox]);
      await _pumpApp(tester, apps: apps);
      await typeText(tester, 'open fi');
      await tester.tap(find.widgetWithText(InkWell, 'Firefox'));
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(apps.launched, ['ff']);
    });

    testWidgets('choosing a command leads on to its arguments', (tester) async {
      await _pumpApp(tester, apps: FakeAppRepository(apps: const [clock]));
      await typeText(tester, 'op');

      await tester.tap(find.widgetWithText(InkWell, 'open'));
      await tester.pump();

      expect(fieldText(tester), 'open ');
      expect(find.widgetWithText(InkWell, 'Clock'), findsOneWidget);
    });

    testWidgets('disappear once the line is submitted', (tester) async {
      await _pumpApp(tester);
      await typeText(tester, 'op');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('are gone when nothing matches', (tester) async {
      await _pumpApp(tester);
      await typeText(tester, 'zzz');

      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('block separation', () {
    testWidgets('the banner has no block markers of its own', (tester) async {
      await _pumpApp(tester, banner: ['welcome']);

      expect(find.text('welcome'), findsOneWidget);
      expect(find.byType(AsciiBanner), findsOneWidget);
      expect(find.byKey(blockDividerKey), findsNothing);
      expect(find.byKey(outputRuleKey), findsNothing);
    });

    testWidgets('a command with nothing above it has no divider', (
      tester,
    ) async {
      await _pumpApp(tester);

      await _type(tester, 'help');

      expect(find.byKey(blockDividerKey), findsNothing);
    });

    testWidgets('each command after the first gets a divider above it', (
      tester,
    ) async {
      await _pumpApp(tester);

      await _type(tester, 'date');
      await _type(tester, 'date');
      await _type(tester, 'date');

      expect(find.byKey(blockDividerKey), findsNWidgets(2));
    });

    testWidgets('a command right after the banner is divided from it', (
      tester,
    ) async {
      await _pumpApp(tester, banner: ['welcome']);

      await _type(tester, 'date');

      expect(find.byKey(blockDividerKey), findsOneWidget);
    });

    testWidgets('output and errors get a rule, echoed input does not', (
      tester,
    ) async {
      await _pumpApp(tester);

      await _type(tester, 'help');
      final helpLines = find.byKey(outputRuleKey).evaluate().length;
      await _type(tester, 'nope');

      expect(helpLines, greaterThan(1));
      expect(find.byKey(outputRuleKey), findsNWidgets(helpLines + 1));
      expect(
        find.ancestor(
          of: find.text(r'$ help'),
          matching: find.byKey(outputRuleKey),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('unknown command: nope'),
          matching: find.byKey(outputRuleKey),
        ),
        findsOneWidget,
      );
    });

    testWidgets('clearing the log removes the markers', (tester) async {
      await _pumpApp(tester, banner: ['welcome']);
      await _type(tester, 'date');

      await _type(tester, 'clear');

      expect(find.byKey(blockDividerKey), findsNothing);
      expect(find.byKey(outputRuleKey), findsNothing);
    });

    testWidgets('clear brings the banner back instead of an empty screen', (
      tester,
    ) async {
      await _pumpApp(tester, banner: ['welcome']);
      await _type(tester, 'date');

      await _type(tester, 'clear');

      expect(find.byType(AsciiBanner), findsOneWidget);
      expect(find.text('welcome'), findsOneWidget);
    });
  });

  group('fixed-width grids', () {
    final gridCommand = Command(
      name: 'grid',
      description: 'prints a 40 column grid',
      usage: 'grid',
      run: (context) async =>
          CommandOutput(['A' * 40, '', 'B' * 20], columns: 40),
    );

    Future<TerminalSession> pumpGrid(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = TerminalSession(
        registry: CommandRegistry([gridCommand]),
        apps: FakeAppRepository(),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        App(session: session, themes: _themes(), fontSize: _fontSize()),
      );
      await _type(tester, 'grid');
      return session;
    }

    double fontSize(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style!.fontSize!;

    testWidgets('shrinks the font to fit a narrow screen, without wrapping', (
      tester,
    ) async {
      await pumpGrid(tester, 300);

      final line = find.text('A' * 40);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(line).width, lessThanOrEqualTo(300));
      expect(fontSize(tester, 'A' * 40), lessThan(16));
      // One line tall, not wrapped onto a second.
      expect(
        tester.getSize(line).height,
        lessThan(fontSize(tester, 'A' * 40) * 2),
      );
    });

    testWidgets('every line of the grid gets the same font size', (
      tester,
    ) async {
      await pumpGrid(tester, 300);

      expect(fontSize(tester, 'B' * 20), fontSize(tester, 'A' * 40));
    });

    testWidgets('grows the font to fill a screen wider than the grid needs', (
      tester,
    ) async {
      await pumpGrid(tester, 1200);

      final size = fontSize(tester, 'A' * 40);
      expect(size, greaterThan(16));
      expect(size, lessThanOrEqualTo(16 * gridUpscaleLimit));
    });

    testWidgets('a grid is not indented with the ordinary output rule', (
      tester,
    ) async {
      await pumpGrid(tester, 300);

      expect(find.byKey(outputRuleKey), findsNothing);
    });

    testWidgets('a blank line in the grid keeps its height', (tester) async {
      await pumpGrid(tester, 300);

      final blank = find.byWidgetPredicate(
        (w) => w is Text && w.data == ' ' && w.maxLines == 1,
      );
      expect(blank, findsOneWidget);
      expect(tester.getSize(blank).height, greaterThan(0));
    });

    testWidgets('ordinary output still wraps as before', (tester) async {
      tester.view.physicalSize = const Size(300, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpApp(tester);

      await _type(tester, 'x' * 60);

      final line = find.text('unknown command: ${'x' * 60}');
      expect(tester.getSize(line).height, greaterThan(30));
    });
  });

  testWidgets('the log stays pinned to the newest line', (tester) async {
    await _pumpApp(tester, maxLines: 500);

    for (var i = 0; i < 60; i++) {
      await _type(tester, 'cmd$i');
    }

    expect(find.text('unknown command: cmd59'), findsOneWidget);
    expect(find.text('unknown command: cmd0'), findsNothing);
  });
}
