import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_app_repository.dart';
import 'fakes/in_memory_local_store.dart';

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

TerminalSession _session() {
  final session = TerminalSession(
    registry: CommandRegistry(defaultCommands),
    apps: FakeAppRepository(),
    banner: [Messages.welcome],
  );
  addTearDown(session.dispose);
  return session;
}

void main() {
  testWidgets('app shows the welcome banner and the prompt', (tester) async {
    await tester.pumpWidget(
      App(session: _session(), themes: _themes(), fontSize: _fontSize()),
    );

    expect(find.text(Messages.welcome), findsOneWidget);
    expect(find.text(Messages.prompt), findsOneWidget);
  });

  testWidgets('back is blocked so the launcher never exits', (tester) async {
    await tester.pumpWidget(
      App(session: _session(), themes: _themes(), fontSize: _fontSize()),
    );

    expect(
      find.byWidgetPredicate((w) => w is PopScope && !w.canPop),
      findsOneWidget,
    );
  });

  testWidgets('changing the theme restyles the running app', (tester) async {
    final themes = _themes();
    await tester.pumpWidget(
      App(session: _session(), themes: themes, fontSize: _fontSize()),
    );
    Color background() =>
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor;
    final before = background();

    await themes.select(ThemeChoice.light);
    await tester.pump();

    expect(before, themeFor(ThemeChoice.dark).scaffoldBackgroundColor);
    expect(background(), themeFor(ThemeChoice.light).scaffoldBackgroundColor);
  });

  testWidgets('changing the font size resizes text in the running app', (
    tester,
  ) async {
    final fontSize = _fontSize();
    await tester.pumpWidget(
      App(session: _session(), themes: _themes(), fontSize: fontSize),
    );
    double promptSize() =>
        tester.widget<Text>(find.text(Messages.prompt)).style!.fontSize!;
    final before = promptSize();

    await fontSize.select(FontSizeChoice.huge);
    await tester.pump();

    expect(promptSize(), greaterThan(before));
  });

  testWidgets('system bars follow the theme', (tester) async {
    final themes = _themes();
    await tester.pumpWidget(
      App(session: _session(), themes: themes, fontSize: _fontSize()),
    );
    SystemUiOverlayStyle? overlay() => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        )
        .value;

    expect(overlay()?.statusBarIconBrightness, Brightness.light);

    await themes.select(ThemeChoice.light);
    await tester.pump();

    expect(overlay()?.statusBarIconBrightness, Brightness.dark);
    expect(
      overlay()?.systemNavigationBarColor,
      themeFor(ThemeChoice.light).scaffoldBackgroundColor,
    );
  });
}
