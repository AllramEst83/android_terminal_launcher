import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_view.dart';
import 'package:android_terminal_launcher/ui/help_view.dart';
import 'package:android_terminal_launcher/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HelpCommand _cmd(
  String name, {
  List<String> aliases = const [],
  String d = '',
}) => HelpCommand(
  name: name,
  aliases: aliases,
  description: d.isEmpty ? 'does $name' : d,
  command: 'help $name',
);

HelpGroup _group(String name, List<String> commands) => HelpGroup(
  name: name,
  command: 'help $name',
  commands: [for (final command in commands) _cmd(command)],
);

final _overview = HelpOverviewBlock(
  groups: [
    _group('system', ['help', 'clear', 'date']),
    _group('apps', ['list', 'open', 'refresh', 'uninstall']),
    _group('tools', ['calc', 'convert']),
  ],
  hint: 'try: help <name>  (e.g. help open)',
);

final _detail = HelpDetailBlock(
  name: 'cal',
  description: 'Show your calendar',
  usage: const ['cal', 'cal week [date]'],
  examples: const ['cal', 'cal tomorrow'],
  notes: const ['date: today, tomorrow, yesterday or 2026-09-30'],
  aliases: const ['calendar'],
  group: _group('personal', ['cal', 'call']),
);

Future<List<String>> _pump(
  WidgetTester tester,
  RichBlock block, {
  ThemeChoice theme = ThemeChoice.dark,
  FontSizeChoice fontSize = FontSizeChoice.normal,
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 2400);
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

void main() {
  group('the overview', () {
    testWidgets('shows every group name and every command as a chip', (
      tester,
    ) async {
      await _pump(tester, _overview);

      for (final group in ['system', 'apps', 'tools']) {
        expect(find.byKey(helpGroupKey(group)), findsOneWidget, reason: group);
      }
      for (final command in [
        'help',
        'clear',
        'date',
        'list',
        'open',
        'refresh',
        'uninstall',
        'calc',
        'convert',
      ]) {
        expect(
          find.byKey(helpChipKey(command)),
          findsOneWidget,
          reason: command,
        );
      }
      expect(find.text('try: help <name>  (e.g. help open)'), findsOneWidget);
    });

    testWidgets('tapping a chip opens that command\'s help', (tester) async {
      final ran = await _pump(tester, _overview);

      await tester.tap(find.byKey(helpChipKey('open')));
      await tester.tap(find.byKey(helpChipKey('calc')));

      expect(ran, ['help open', 'help calc']);
    });

    testWidgets('tapping a group name opens that group\'s help', (
      tester,
    ) async {
      final ran = await _pump(tester, _overview);

      await tester.tap(find.byKey(helpGroupKey('apps')));

      expect(ran, ['help apps']);
    });

    testWidgets('a chip is read out as a button that says what it is for', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _overview);

      final semantics = tester.getSemantics(find.byKey(helpChipKey('open')));
      expect(semantics.label, 'help for open');
      expect(semantics.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('an empty list of groups is only the heading and the hint', (
      tester,
    ) async {
      await _pump(tester, const HelpOverviewBlock(groups: [], hint: 'a hint'));

      expect(find.text('commands'), findsOneWidget);
      expect(find.text('a hint'), findsOneWidget);
    });
  });

  group('a group', () {
    final block = HelpGroupBlock(
      group: HelpGroup(
        name: 'personal',
        command: 'help personal',
        commands: [
          _cmd('cal', aliases: ['calendar'], d: 'Show your calendar'),
          _cmd('sms', d: 'Send a text message'),
        ],
      ),
    );

    testWidgets('shows each command, its alias and what it does', (
      tester,
    ) async {
      await _pump(tester, block);

      expect(find.text('personal'), findsOneWidget);
      expect(find.text('Show your calendar'), findsOneWidget);
      expect(find.text('Send a text message'), findsOneWidget);
      expect(find.textContaining('calendar', findRichText: true), findsWidgets);
    });

    testWidgets('tapping a row opens that command\'s help', (tester) async {
      final ran = await _pump(tester, block);

      await tester.tap(find.byKey(helpRowKey('sms')));

      expect(ran, ['help sms']);
    });
  });

  group('one command', () {
    testWidgets('shows what it is, how to call it, examples and notes', (
      tester,
    ) async {
      await _pump(tester, _detail);

      expect(find.text('cal'), findsWidgets);
      expect(find.text('Show your calendar'), findsOneWidget);
      expect(find.text('cal week [date]'), findsOneWidget);
      expect(find.text('cal tomorrow'), findsOneWidget);
      expect(
        find.text('date: today, tomorrow, yesterday or 2026-09-30'),
        findsOneWidget,
      );
      expect(find.text('also: calendar'), findsOneWidget);
      expect(find.byKey(helpUsageKey), findsOneWidget);
      expect(find.byKey(helpExamplesKey), findsOneWidget);
    });

    testWidgets('names its group, which opens the group\'s help', (
      tester,
    ) async {
      final ran = await _pump(tester, _detail);

      expect(find.text('in personal ›'), findsOneWidget);
      await tester.tap(find.byKey(helpGroupKey('personal')));

      expect(ran, ['help personal']);
    });

    testWidgets('examples are not tappable: they might send a text', (
      tester,
    ) async {
      final ran = await _pump(tester, _detail);

      await tester.tap(find.text('cal tomorrow'));
      await tester.tap(find.text('cal week [date]'));

      expect(ran, isEmpty);
    });

    testWidgets('a command with nothing but a description is short', (
      tester,
    ) async {
      await _pump(
        tester,
        const HelpDetailBlock(
          name: 'clear',
          description: 'Clear the screen',
          usage: ['clear'],
        ),
      );

      expect(find.byKey(helpExamplesKey), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(find.textContaining('also:'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('every theme at every size, on a narrow screen', () {
    final longDetail = HelpDetailBlock(
      name: 'a-command-with-a-very-long-name',
      description:
          'A description that goes on and on, well past the width of a phone',
      usage: const [
        'a-command-with-a-very-long-name <argument> [another-argument] [--flag]',
      ],
      examples: const ['a-command-with-a-very-long-name value another --flag'],
      notes: const [
        'a note that is long enough that it has to wrap onto several lines '
            'on a narrow screen with a large font',
      ],
      aliases: const ['alias-one', 'alias-two', 'alias-three'],
      group: _group('a-group-with-a-long-name', ['x']),
    );
    final wide = HelpOverviewBlock(
      groups: [
        _group('a-group-with-a-long-name', [
          'a-very-long-command-name',
          'another-long-one',
          'x',
          'yy',
          'zzz',
        ]),
      ],
      hint: 'try: help <name>  (e.g. help open)',
    );
    final groupPage = HelpGroupBlock(
      group: HelpGroup(
        name: 'a-group-with-a-long-name',
        command: 'help a',
        commands: [
          _cmd(
            'a-very-long-command-name',
            aliases: ['some', 'long', 'aliases', 'here'],
            d: 'A long description that has to wrap onto another line or two',
          ),
        ],
      ),
    );

    for (final theme in ThemeChoice.values) {
      for (final size in FontSizeChoice.values) {
        testWidgets('${theme.name} ${size.name}: nothing overflows', (
          tester,
        ) async {
          for (final block in [
            _overview,
            wide,
            groupPage,
            longDetail,
            _detail,
          ]) {
            await _pump(
              tester,
              block,
              theme: theme,
              fontSize: size,
              width: 320,
            );
            expect(tester.takeException(), isNull, reason: '$block');
          }
        });
      }
    }
  });
}
