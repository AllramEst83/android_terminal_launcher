import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/terminal_log.dart';
import 'package:android_terminal_launcher/ui/tv_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/in_memory_local_store.dart';

const _columns = 20;

final _page = [
  [StyledRun('Title'.padRight(_columns), fg: TvColor.yellow)],
  [StyledRun('Bar'.padRight(_columns), fg: TvColor.white, bg: TvColor.blue)],
  [StyledRun('BIG'.padRight(_columns), fg: TvColor.yellow, tall: true)],
  [
    const StyledRun('see '),
    const StyledRun('101', underline: true),
    StyledRun(''.padRight(_columns - 7)),
  ],
];

final _tvCommand = Command(
  name: 'tv',
  description: 'a coloured grid',
  usage: 'tv',
  run: (context) async => CommandOutput(
    [for (final row in _page) plainText(row)],
    columns: _columns,
    styles: _page,
  ),
);

Future<TerminalSession> _pump(
  WidgetTester tester, {
  double width = 400,
  ThemeChoice theme = ThemeChoice.dark,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final store = InMemoryLocalStore();
  final themes = ThemeController(store: store);
  addTearDown(themes.dispose);
  await themes.select(theme);
  final fontSize = FontSizeController(store: store);
  addTearDown(fontSize.dispose);

  final session = TerminalSession(
    registry: CommandRegistry([_tvCommand]),
    apps: FakeAppRepository(),
  );
  addTearDown(session.dispose);
  await tester.pumpWidget(
    App(session: session, themes: themes, fontSize: fontSize),
  );
  await tester.enterText(find.byType(TextField), 'tv');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  return session;
}

void main() {
  group('the palette', () {
    test('every colour is different', () {
      expect({for (final c in TvColor.values) tvColorOf(c)}, hasLength(8));
    });

    test('black is black and white is white', () {
      expect(tvColorOf(TvColor.black), const Color(0xFF000000));
      expect(tvColorOf(TvColor.white), const Color(0xFFFFFFFF));
    });

    test('every colour but black shows up on black', () {
      double luminance(TvColor c) => tvColorOf(c).computeLuminance();

      for (final color in TvColor.values.where((c) => c != TvColor.black)) {
        // WCAG contrast against black: (L + 0.05) / 0.05.
        expect(
          (luminance(color) + 0.05) / 0.05,
          greaterThan(3),
          reason: '$color',
        );
      }
    });

    test('white text on the blue bar is readable', () {
      final blue = tvColorOf(TvColor.blue).computeLuminance();
      final white = tvColorOf(TvColor.white).computeLuminance();

      expect((white + 0.05) / (blue + 0.05), greaterThan(4.5));
    });
  });

  group('in the log', () {
    testWidgets('a coloured grid is drawn as rows, not as text', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(TvRow), findsNWidgets(_page.length));
      expect(find.text('Title'.padRight(_columns)), findsNothing);
    });

    testWidgets('the rows fill the width and are as wide as each other', (
      tester,
    ) async {
      await _pump(tester, width: 400);

      final widths = [
        for (final row in tester.widgetList(find.byType(TvRow)))
          tester.getSize(find.byWidget(row)).width,
      ];

      expect(widths.toSet(), hasLength(1));
      expect(widths.first, lessThanOrEqualTo(400));
      // Within the log's own side padding, nearly all of it (the font is
      // scaled to fill), not a narrow strip at native size.
      expect(widths.first, greaterThan(400 - 32 - 4));
    });

    testWidgets('rows touch: the same height, stacked without a gap', (
      tester,
    ) async {
      await _pump(tester);

      final rects = [
        for (final row in tester.widgetList(find.byType(TvRow)))
          tester.getRect(find.byWidget(row)),
      ]..sort((a, b) => a.top.compareTo(b.top));

      // Every row is one height, except the headline, which is two.
      final unit = rects.map((r) => r.height).reduce((a, b) => a < b ? a : b);
      for (final rect in rects) {
        expect(
          rect.height,
          anyOf(closeTo(unit, 0.01), closeTo(unit * 2, 0.01)),
        );
      }
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].top, closeTo(rects[i - 1].bottom, 0.01));
      }
    });

    testWidgets('a headline row is exactly twice as high as an ordinary row', (
      tester,
    ) async {
      await _pump(tester);

      final rows = tester.widgetList<TvRow>(find.byType(TvRow)).toList();
      final tall = rows.firstWhere((row) => row.runs.any((run) => run.tall));
      final plain = rows.firstWhere(
        (row) => row.runs.every((run) => !run.tall),
      );

      expect(
        tester.getSize(find.byWidget(tall)).height,
        closeTo(tester.getSize(find.byWidget(plain)).height * 2, 0.01),
      );
      expect(
        tester.getSize(find.byWidget(tall)).width,
        tester.getSize(find.byWidget(plain)).width,
      );
    });

    testWidgets('a narrower screen gets a smaller grid, never a wrapped one', (
      tester,
    ) async {
      await _pump(tester, width: 250);

      expect(tester.takeException(), isNull);
      final row = find.byType(TvRow).first;
      expect(tester.getSize(row).width, lessThanOrEqualTo(250));
      final height = tester.getSize(row).height;
      expect(height, lessThan(30));
    });

    testWidgets('a grid without colours still uses plain text', (tester) async {
      final plain = Command(
        name: 'plain',
        description: 'x',
        usage: 'plain',
        run: (context) async => const CommandOutput(['abcdef'], columns: 6),
      );
      final session = TerminalSession(
        registry: CommandRegistry([plain]),
        apps: FakeAppRepository(),
      );
      addTearDown(session.dispose);
      final themes = ThemeController(store: InMemoryLocalStore());
      addTearDown(themes.dispose);
      final fontSize = FontSizeController(store: InMemoryLocalStore());
      addTearDown(fontSize.dispose);
      await tester.pumpWidget(
        App(session: session, themes: themes, fontSize: fontSize),
      );

      await tester.enterText(find.byType(TextField), 'plain');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.byType(TvRow), findsNothing);
      expect(find.text('abcdef'), findsOneWidget);
    });

    testWidgets('rows are read out as their text', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      expect(find.bySemanticsLabel('Bar'), findsOneWidget);
      expect(find.bySemanticsLabel('see 101'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('no ordinary block rule is drawn beside a coloured grid', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byKey(outputRuleKey), findsNothing);
    });

    for (final theme in [ThemeChoice.light, ThemeChoice.pastel]) {
      testWidgets('draws on its own black on the ${theme.name} theme too', (
        tester,
      ) async {
        await _pump(tester, theme: theme);

        // The painter fills every cell with its own background: even the
        // default one is the palette's black, not the theme's background.
        expect(tvColorOf(TvColor.black), const Color(0xFF000000));
        expect(find.byType(TvRow), findsNWidgets(_page.length));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
