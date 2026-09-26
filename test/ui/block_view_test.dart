import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_blocks.dart';
import 'package:android_terminal_launcher/ui/agenda_view.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:android_terminal_launcher/ui/block_view.dart';
import 'package:android_terminal_launcher/ui/month_view.dart';
import 'package:android_terminal_launcher/ui/readable_color.dart';
import 'package:android_terminal_launcher/ui/terminal_log.dart';
import 'package:android_terminal_launcher/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/in_memory_local_store.dart';

// Saturday 26 September 2026.
final _month = monthBlock(const [], DateTime(2026, 9), DateTime(2026, 9, 26));

MonthBlock _busyMonth(int eventsOn26) => MonthBlock(
  title: _month.title,
  weekdays: _month.weekdays,
  weeks: [
    for (final week in _month.weeks)
      [
        for (final day in week)
          day == null || day.day != 26
              ? day
              : MonthDay(
                  day: 26,
                  events: eventsOn26,
                  today: true,
                  command: day.command,
                ),
      ],
  ],
  previousCommand: _month.previousCommand,
  nextCommand: _month.nextCommand,
);

const _work = 0xFF1B4FBF;
const _family = 0xFFE67C00;

AgendaBlock _week({String longTitle = 'Standup'}) => AgendaBlock(
  days: [
    const AgendaDay(
      label: 'Fri 25 Sep',
      command: 'cal day 2026-09-25',
      entries: [
        AgendaEntry(
          start: '08:00',
          end: '09:00',
          title: 'Breakfast',
          phase: EntryPhase.past,
        ),
      ],
    ),
    AgendaDay(
      label: 'Sat 26 Sep',
      today: true,
      command: 'cal day 2026-09-26',
      entries: [
        const AgendaEntry(
          start: 'all day',
          title: 'Holiday',
          allDay: true,
          color: _family,
        ),
        AgendaEntry(
          start: '10:00',
          end: '11:30',
          title: longTitle,
          place: 'Room 4',
          color: _work,
          phase: EntryPhase.now,
        ),
      ],
    ),
    const AgendaDay(
      label: 'Sun 27 Sep',
      command: 'cal day 2026-09-27',
      entries: [],
    ),
  ],
  legend: const [
    AgendaCalendar(name: 'Work', color: _work),
    AgendaCalendar(name: 'Family', color: _family),
  ],
);

Future<List<String>> _pumpBlock(
  WidgetTester tester,
  RichBlock block, {
  ThemeChoice theme = ThemeChoice.dark,
  FontSizeChoice fontSize = FontSizeChoice.normal,
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ran = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: themeFor(theme, fontSize),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BlockView(block: block, onRun: ran.add),
          ),
        ),
      ),
    ),
  );
  return ran;
}

/// [foreground] at [alpha] laid over [background], as the eye sees it.
Color _over(Color foreground, Color background, double alpha) =>
    Color.alphaBlend(foreground.withValues(alpha: alpha), background);

void main() {
  group('month', () {
    testWidgets('shows the title, the weekdays and every day', (tester) async {
      await _pumpBlock(tester, _month);

      expect(find.text('September 2026'), findsOneWidget);
      for (final name in ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']) {
        expect(find.text(name), findsOneWidget);
      }
      for (var day = 1; day <= 30; day++) {
        expect(find.byKey(monthDayKey(day)), findsOneWidget, reason: '$day');
      }
      expect(find.byKey(monthDayKey(31)), findsNothing);
    });

    testWidgets('tapping a day runs its command', (tester) async {
      final ran = await _pumpBlock(tester, _month);

      await tester.tap(find.byKey(monthDayKey(12)));

      expect(ran, ['cal day 2026-09-12']);
    });

    testWidgets('the arrows run the neighbouring months', (tester) async {
      final ran = await _pumpBlock(tester, _month);

      await tester.tap(find.byKey(monthPreviousKey));
      await tester.tap(find.byKey(monthNextKey));

      expect(ran, ['cal 2026-08', 'cal 2026-10']);
    });

    testWidgets('an arrow with no month to go to does nothing', (tester) async {
      final ran = await _pumpBlock(
        tester,
        const MonthBlock(
          title: 'X',
          weekdays: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
          weeks: [],
        ),
      );

      await tester.tap(find.byKey(monthNextKey));

      expect(ran, isEmpty);
    });

    testWidgets('today is the filled cell, in the background colour', (
      tester,
    ) async {
      await _pumpBlock(tester, _month);
      final scheme = Theme.of(tester.element(find.byType(MonthView)))
          .colorScheme;

      Color? colourOf(int day) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(monthDayKey(day)),
              matching: find.text('$day'),
            ),
          )
          .style
          ?.color;

      expect(colourOf(26), scheme.surface);
      expect(colourOf(25), scheme.onSurface);
    });

    testWidgets('a day shows one dot per event, at most three', (tester) async {
      Finder dots() => find.descendant(
        of: find.byKey(monthDayKey(26)),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );

      for (final (events, shown) in [(0, 0), (1, 1), (2, 2), (3, 3), (9, 3)]) {
        await _pumpBlock(tester, _busyMonth(events));
        expect(dots(), findsNWidgets(shown), reason: '$events events');
      }
    });

    testWidgets('a day is read out with its number, today and event count', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpBlock(tester, _busyMonth(2));

      expect(
        tester.getSemantics(find.byKey(monthDayKey(26))).label,
        '26, today, 2 events',
      );
      expect(tester.getSemantics(find.byKey(monthDayKey(25))).label, '25');
      handle.dispose();
    });
  });

  group('agenda', () {
    testWidgets('shows each day, its events and their times', (tester) async {
      await _pumpBlock(tester, _week());

      for (final text in [
        'Fri 25 Sep',
        'Sat 26 Sep',
        'Sun 27 Sep',
        'today',
        'Breakfast',
        'Holiday',
        'Standup',
        'Room 4',
        '08:00',
        '09:00',
        '10:00',
        '11:30',
        'all day',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.byKey(agendaEntryKey), findsNWidgets(3));
    });

    testWidgets('says how many events a day has, or that it has none', (
      tester,
    ) async {
      await _pumpBlock(tester, _week());

      expect(find.text('free'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('tapping a day heading opens that day', (tester) async {
      final ran = await _pumpBlock(tester, _week());

      await tester.tap(find.byKey(agendaDayKey('Sun 27 Sep')));

      expect(ran, ['cal day 2026-09-27']);
    });

    testWidgets('a single day heading does nothing when tapped', (
      tester,
    ) async {
      final ran = await _pumpBlock(
        tester,
        AgendaBlock(days: [_week().days[1]]),
      );

      await tester.tap(find.byKey(agendaDayKey('Sat 26 Sep')));

      expect(ran, isEmpty);
    });

    testWidgets('a long title wraps under itself, not under the times', (
      tester,
    ) async {
      const title =
          'Intervju Mindflower AB Champagne Champagne Champagne Champagne';
      await _pumpBlock(tester, _week(longTitle: title), width: 320);

      final titleBox = tester.getRect(find.text(title));
      final placeBox = tester.getRect(find.text('Room 4'));
      final timeBox = tester.getRect(find.text('10:00'));

      // More than one line high, yet starting where the place starts, and
      // clear of the time column.
      expect(titleBox.height, greaterThan(placeBox.height * 1.5));
      expect(titleBox.left, placeBox.left);
      expect(titleBox.left, greaterThan(timeBox.right));
    });

    testWidgets('an event that is over is dimmed, one under way is not', (
      tester,
    ) async {
      await _pumpBlock(tester, _week());

      double opacityOf(String title) => tester
          .widget<Opacity>(
            find.ancestor(of: find.text(title), matching: find.byType(Opacity)),
          )
          .opacity;

      expect(opacityOf('Breakfast'), blockPastOpacity);
      expect(
        find.ancestor(of: find.text('Standup'), matching: find.byType(Opacity)),
        findsNothing,
      );
    });

    testWidgets('the legend names the calendars when there are several', (
      tester,
    ) async {
      await _pumpBlock(tester, _week());

      expect(find.byKey(agendaLegendKey), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
    });

    testWidgets('and stays away when there is one', (tester) async {
      await _pumpBlock(tester, AgendaBlock(days: _week().days));

      expect(find.byKey(agendaLegendKey), findsNothing);
    });

    testWidgets('an event with no colour still gets a bar', (tester) async {
      await _pumpBlock(
        tester,
        const AgendaBlock(
          days: [
            AgendaDay(
              label: 'Sat 26 Sep',
              command: 'cal day 2026-09-26',
              entries: [AgendaEntry(start: '09:00', title: 'Plain')],
            ),
          ],
        ),
      );

      expect(find.text('Plain'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('every theme at every size, on a narrow screen', () {
    for (final theme in ThemeChoice.values) {
      for (final size in FontSizeChoice.values) {
        testWidgets('${theme.name} ${size.name}: nothing overflows', (
          tester,
        ) async {
          await _pumpBlock(
            tester,
            _week(longTitle: 'A rather long title indeed, for a narrow phone'),
            theme: theme,
            fontSize: size,
            width: 320,
          );
          expect(tester.takeException(), isNull);

          await _pumpBlock(
            tester,
            _busyMonth(3),
            theme: theme,
            fontSize: size,
            width: 320,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final theme in ThemeChoice.values) {
      test('${theme.name}: dimmed text stays readable (WCAG AA)', () {
        final scheme = themeFor(theme).colorScheme;
        final dim = _over(scheme.onSurface, scheme.surface, blockDimAlpha);

        expect(contrastRatio(dim, scheme.surface), greaterThanOrEqualTo(4.5));
      });

      test('${theme.name}: the title of a finished event stays readable', () {
        final scheme = themeFor(theme).colorScheme;
        final past = _over(scheme.onSurface, scheme.surface, blockPastOpacity);

        expect(contrastRatio(past, scheme.surface), greaterThanOrEqualTo(3));
      });
    }
  });

  group('in the log', () {
    final cal = Command(
      name: 'cal',
      description: 'a calendar',
      usage: 'cal',
      run: (context) async => CommandOutput(const [
        'September 2026',
      ], block: context.args.isEmpty ? _month : _week()),
    );

    Future<TerminalSession> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = InMemoryLocalStore();
      final themes = ThemeController(store: store);
      addTearDown(themes.dispose);
      final fontSize = FontSizeController(store: store);
      addTearDown(fontSize.dispose);
      final session = TerminalSession(
        registry: CommandRegistry([cal]),
        apps: FakeAppRepository(),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        App(session: session, themes: themes, fontSize: fontSize),
      );
      await tester.enterText(find.byType(TextField), 'cal');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      return session;
    }

    testWidgets('a block is drawn instead of its text, with no output rule', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(MonthView), findsOneWidget);
      expect(find.byKey(outputRuleKey), findsNothing);
      // The plain line is not drawn as well.
      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('a tap runs its command like typed input, echo and all', (
      tester,
    ) async {
      final session = await pump(tester);

      await tester.tap(find.byKey(monthDayKey(12)));
      await tester.pump();
      await tester.pump();

      expect(
        session.lines.map((l) => l.text),
        contains(r'$ cal day 2026-09-12'),
      );
      expect(find.byType(AgendaView), findsOneWidget);
    });
  });
}
