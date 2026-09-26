import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_view.dart';
import 'package:android_terminal_launcher/ui/choice_view.dart';
import 'package:android_terminal_launcher/ui/contacts_view.dart';
import 'package:android_terminal_launcher/ui/entries_view.dart';
import 'package:android_terminal_launcher/ui/notice_view.dart';
import 'package:android_terminal_launcher/ui/result_view.dart';
import 'package:android_terminal_launcher/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a pumped block did: the commands it ran, and those it put in the prompt.
class _Taps {
  final ran = <String>[];
  final filled = <String>[];
}

Future<_Taps> _pump(
  WidgetTester tester,
  RichBlock block, {
  ThemeChoice theme = ThemeChoice.dark,
  FontSizeChoice fontSize = FontSizeChoice.normal,
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final taps = _Taps();
  await tester.pumpWidget(
    MaterialApp(
      theme: themeFor(theme, fontSize),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BlockView(
              block: block,
              onRun: taps.ran.add,
              onFill: taps.filled.add,
            ),
          ),
        ),
      ),
    ),
  );
  return taps;
}

ChoiceOption _option(
  String label, {
  String? description,
  bool selected = false,
  bool fill = false,
}) => ChoiceOption(
  label: label,
  description: description,
  selected: selected,
  fill: fill,
  command: 'do $label',
);

void main() {
  group('notice', () {
    testWidgets('shows the message and the details, with its icon', (
      tester,
    ) async {
      await _pump(
        tester,
        const NoticeBlock(
          kind: NoticeKind.warning,
          message: 'theme: coffee',
          details: ['could not save it'],
        ),
      );

      expect(find.text('theme: coffee'), findsOneWidget);
      expect(find.text('could not save it'), findsOneWidget);
      expect(find.byKey(noticeIconKey), findsOneWidget);
    });

    testWidgets('each kind has its own icon, a warning in the error colour', (
      tester,
    ) async {
      final icons = <NoticeKind, IconData?>{};
      final colours = <NoticeKind, Color?>{};
      for (final kind in NoticeKind.values) {
        await _pump(tester, NoticeBlock(kind: kind, message: 'm'));
        final icon = tester.widget<Icon>(find.byKey(noticeIconKey));
        icons[kind] = icon.icon;
        colours[kind] = icon.color;
      }

      expect(icons.values.toSet(), hasLength(NoticeKind.values.length));
      final scheme = themeFor(ThemeChoice.dark).colorScheme;
      expect(colours[NoticeKind.warning], scheme.error);
      expect(colours[NoticeKind.success], scheme.onSurface);
    });

    testWidgets('is read out with what kind it is', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const NoticeBlock(kind: NoticeKind.success, message: 'opening Firefox'),
      );

      expect(find.bySemanticsLabel('done, opening Firefox'), findsOneWidget);
      handle.dispose();
    });
  });

  group('result', () {
    testWidgets('shows what was asked and the answer', (tester) async {
      await _pump(
        tester,
        const ResultBlock(
          expression: '100 USD',
          value: '1046.20 SEK',
          details: ['rates from 2026-09-25'],
        ),
      );

      expect(find.text('100 USD'), findsOneWidget);
      expect(find.text('1046.20 SEK'), findsOneWidget);
      expect(find.text('rates from 2026-09-25'), findsOneWidget);
    });

    testWidgets('the answer is larger than the text around it', (tester) async {
      await _pump(tester, const ResultBlock(expression: 'x', value: '42'));

      final value = tester.widget<Text>(find.byKey(resultValueKey));
      final small = tester.widget<Text>(find.text('x'));
      expect(value.style!.fontSize, greaterThan(small.style!.fontSize! * 2));
    });

    testWidgets('a very long number is scaled down, not overflowed', (
      tester,
    ) async {
      await _pump(
        tester,
        ResultBlock(expression: 'big', value: '9' * 40),
        fontSize: FontSizeChoice.huge,
        width: 320,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('is read out as a sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const ResultBlock(expression: '5 km', value: '3.1 mi'),
      );

      expect(find.bySemanticsLabel('5 km is 3.1 mi'), findsOneWidget);
      handle.dispose();
    });
  });

  group('choices', () {
    testWidgets('chips run their command on a tap', (tester) async {
      final taps = await _pump(
        tester,
        ChoiceBlock(
          groups: [
            ChoiceGroup(options: [_option('Camera'), _option('Chrome')]),
          ],
        ),
      );

      await tester.tap(find.byKey(choiceKey('Chrome')));

      expect(taps.ran, ['do Chrome']);
      expect(taps.filled, isEmpty);
    });

    testWidgets('an option that fills puts its command in the prompt', (
      tester,
    ) async {
      final taps = await _pump(
        tester,
        ChoiceBlock(
          groups: [
            ChoiceGroup(options: [_option('Anna', fill: true)]),
          ],
        ),
      );

      await tester.tap(find.byKey(choiceKey('Anna')));

      expect(taps.filled, ['do Anna']);
      expect(taps.ran, isEmpty);
    });

    testWidgets('group headings and the title and footer show', (tester) async {
      await _pump(
        tester,
        ChoiceBlock(
          title: '12 apps',
          footer: 'a footer',
          groups: [
            ChoiceGroup(title: 'C', options: [_option('Camera')]),
            ChoiceGroup(title: 'F', options: [_option('Files')]),
          ],
        ),
      );

      for (final text in ['12 apps', 'a footer', 'C', 'F', 'Camera', 'Files']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.byKey(choiceGroupKey('C')), findsOneWidget);
    });

    testWidgets('the selected chip is filled, in the background colour', (
      tester,
    ) async {
      await _pump(
        tester,
        ChoiceBlock(
          groups: [
            ChoiceGroup(
              options: [_option('one', selected: true), _option('two')],
            ),
          ],
        ),
      );
      final scheme = themeFor(ThemeChoice.dark).colorScheme;

      Color? colourOf(String label) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(choiceKey(label)),
              matching: find.text(label),
            ),
          )
          .style
          ?.color;

      expect(colourOf('one'), scheme.surface);
      expect(colourOf('two'), scheme.onSurface);
    });

    testWidgets('rows show a description, and a radio when one is current', (
      tester,
    ) async {
      await _pump(
        tester,
        ChoiceBlock(
          layout: ChoiceLayout.rows,
          groups: [
            ChoiceGroup(
              options: [
                _option('dark', description: 'green', selected: true),
                _option('light', description: 'navy'),
              ],
            ),
          ],
        ),
      );

      expect(find.text('green'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.text('›'), findsNothing);
    });

    testWidgets('rows with nothing current have a chevron, not radios', (
      tester,
    ) async {
      await _pump(
        tester,
        ChoiceBlock(
          layout: ChoiceLayout.rows,
          groups: [
            ChoiceGroup(options: [_option('a', fill: true), _option('b')]),
          ],
        ),
      );

      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
      expect(find.text('›'), findsNWidgets(2));
    });

    testWidgets('a row taps like a chip', (tester) async {
      final taps = await _pump(
        tester,
        ChoiceBlock(
          layout: ChoiceLayout.rows,
          groups: [
            ChoiceGroup(
              options: [_option('theme'), _option('fill', fill: true)],
            ),
          ],
        ),
      );

      await tester.tap(find.byKey(choiceKey('theme')));
      await tester.tap(find.byKey(choiceKey('fill')));

      expect(taps.ran, ['do theme']);
      expect(taps.filled, ['do fill']);
    });

    testWidgets('a couple of hundred chips lay out without trouble', (
      tester,
    ) async {
      await _pump(
        tester,
        ChoiceBlock(
          groups: [
            ChoiceGroup(
              options: [for (var i = 0; i < 200; i++) _option('App number $i')],
            ),
          ],
        ),
        width: 320,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('todos and notes', () {
    final todos = EntriesBlock(
      title: '3 todos',
      todo: true,
      rows: const [
        EntryRow(
          id: 1,
          text: 'call mom',
          showCommand: 'todo show 1',
          toggleCommand: 'todo done 1',
        ),
        EntryRow(
          id: 2,
          text: 'water the plants',
          showCommand: 'todo show 2',
          toggleCommand: 'todo undo 2',
          done: true,
        ),
      ],
    );

    testWidgets('shows the title, the numbers and the text', (tester) async {
      await _pump(tester, todos);

      expect(find.text('3 todos'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('call mom'), findsOneWidget);
      expect(find.text('water the plants'), findsOneWidget);
    });

    testWidgets('a done todo is struck through and has a ticked box', (
      tester,
    ) async {
      await _pump(tester, todos);

      Text text(String s) => tester.widget<Text>(find.text(s));
      expect(
        text('water the plants').style!.decoration,
        TextDecoration.lineThrough,
      );
      expect(
        text('call mom').style!.decoration,
        isNot(TextDecoration.lineThrough),
      );
      expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    });

    testWidgets('a tap on the row shows it, a tap on the box ticks it', (
      tester,
    ) async {
      final taps = await _pump(tester, todos);

      await tester.tap(find.byKey(entryRowKey(1)).hitTestable());
      await tester.tap(find.byKey(entryBoxKey(2)));
      await tester.tap(find.byKey(entryBoxKey(1)));

      expect(taps.ran, ['todo show 1', 'todo undo 2', 'todo done 1']);
    });

    testWidgets('notes have no boxes', (tester) async {
      await _pump(
        tester,
        const EntriesBlock(
          title: '1 note',
          todo: false,
          rows: [EntryRow(id: 1, text: 'milk', showCommand: 'note show 1')],
        ),
      );

      expect(find.byKey(entryBoxKey(1)), findsNothing);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('a long entry wraps, and ids of several digits fit', (
      tester,
    ) async {
      await _pump(
        tester,
        EntriesBlock(
          title: '1 note',
          todo: false,
          rows: [
            EntryRow(
              id: 1234,
              text: 'a note that goes on ' * 10,
              showCommand: 'x',
            ),
          ],
        ),
        width: 320,
        fontSize: FontSizeChoice.huge,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a row is read out with its number and whether it is done', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, todos);

      expect(find.bySemanticsLabel('open, number 1, call mom'), findsOneWidget);
      expect(
        find.bySemanticsLabel('done, number 2, water the plants'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('one entry', () {
    const todo = EntryDetailBlock(
      kind: 'todo',
      id: 3,
      text: 'call mom',
      created: '2026-09-25 16:30',
      edited: '2026-09-26 09:12',
      done: false,
      toggleCommand: 'todo done 3',
      editCommand: 'todo edit 3 "call mom"',
      removeCommand: 'todo rm 3',
    );

    testWidgets('shows the entry, its state and its dates', (tester) async {
      await _pump(tester, todo);

      expect(find.text('todo #3'), findsOneWidget);
      expect(find.text('open'), findsOneWidget);
      expect(find.text('call mom'), findsOneWidget);
      expect(
        find.text('created 2026-09-25 16:30 · edited 2026-09-26 09:12'),
        findsOneWidget,
      );
    });

    testWidgets('done runs, but edit and remove only fill the prompt', (
      tester,
    ) async {
      final taps = await _pump(tester, todo);

      await tester.tap(find.byKey(entryDoneChipKey));
      await tester.tap(find.byKey(entryEditChipKey));
      await tester.tap(find.byKey(entryRemoveChipKey));

      expect(taps.ran, ['todo done 3']);
      expect(taps.filled, ['todo edit 3 "call mom"', 'todo rm 3']);
    });

    testWidgets('a done todo offers to undo', (tester) async {
      await _pump(
        tester,
        const EntryDetailBlock(
          kind: 'todo',
          id: 3,
          text: 'x',
          created: 'c',
          done: true,
          toggleCommand: 'todo undo 3',
        ),
      );

      expect(find.text('undo'), findsOneWidget);
      expect(find.text('done'), findsOneWidget); // the state, not the button
    });

    testWidgets('a note has no state and no tick button', (tester) async {
      await _pump(
        tester,
        const EntryDetailBlock(
          kind: 'note',
          id: 1,
          text: 'milk',
          created: 'c',
          editCommand: 'note edit 1 milk',
          removeCommand: 'note rm 1',
        ),
      );

      expect(find.byKey(entryDoneChipKey), findsNothing);
      expect(find.text('open'), findsNothing);
      expect(find.byKey(entryEditChipKey), findsOneWidget);
    });
  });

  group('contacts', () {
    const anna = ContactCard(
      name: 'Anna Andersson',
      numbers: [
        ContactNumber(
          label: 'mobile',
          number: '070-123 45 67',
          callCommand: 'call 0701234567',
          smsCommand: 'sms 0701234567 "',
        ),
        ContactNumber(
          label: 'work',
          number: '08-555 01 02',
          callCommand: 'call 085550102',
          smsCommand: 'sms 085550102 "',
        ),
      ],
    );

    testWidgets('shows the name and each number with its label', (
      tester,
    ) async {
      await _pump(tester, const ContactsBlock(contacts: [anna], more: 4));

      expect(find.text('Anna Andersson'), findsOneWidget);
      expect(find.text('070-123 45 67'), findsOneWidget);
      expect(find.text('work'), findsOneWidget);
      expect(find.text('…and 4 more'), findsOneWidget);
    });

    testWidgets('call and sms fill the prompt, and nothing runs', (
      tester,
    ) async {
      final taps = await _pump(tester, const ContactsBlock(contacts: [anna]));

      await tester.tap(find.byKey(contactCallKey('070-123 45 67')));
      await tester.tap(find.byKey(contactSmsKey('08-555 01 02')));

      expect(taps.filled, ['call 0701234567', 'sms 085550102 "']);
      expect(taps.ran, isEmpty, reason: 'a stray tap must never ring or text');
    });

    testWidgets('says nothing about more when there is no more', (
      tester,
    ) async {
      await _pump(tester, const ContactsBlock(contacts: [anna]));

      expect(find.textContaining('more'), findsNothing);
    });

    testWidgets('a button says who it is for when read out', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const ContactsBlock(contacts: [anna]));

      expect(
        find.bySemanticsLabel('call Anna Andersson, mobile'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('text Anna Andersson, work'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('every theme at every size, on a narrow screen', () {
    final blocks = <RichBlock>[
      const NoticeBlock(
        kind: NoticeKind.warning,
        message: 'a message that is long enough to wrap around a narrow phone',
        details: ['and a detail that is long enough to wrap around it as well'],
      ),
      const ResultBlock(
        expression: 'an expression that is rather long, really',
        value: '123456789.123456',
        details: ['rates from 2026-09-25 (ECB reference rates)'],
      ),
      ChoiceBlock(
        title: 'a title that goes on and on for a while',
        footer: 'a footer that goes on and on for a while too',
        layout: ChoiceLayout.rows,
        groups: [
          ChoiceGroup(
            title: 'group',
            options: [
              _option(
                'an option with a long name',
                description: 'and a description that is also quite long indeed',
                selected: true,
              ),
              _option('short'),
            ],
          ),
        ],
      ),
      ChoiceBlock(
        groups: [
          ChoiceGroup(
            options: [
              _option('A very long application name indeed'),
              for (var i = 0; i < 8; i++) _option('App $i'),
            ],
          ),
        ],
      ),
      EntriesBlock(
        title: '2 todos',
        todo: true,
        rows: [
          EntryRow(
            id: 10,
            text: 'a todo with quite a lot of words in it to wrap around',
            showCommand: 'x',
            toggleCommand: 'y',
            done: true,
          ),
        ],
      ),
      const EntryDetailBlock(
        kind: 'todo',
        id: 10,
        text: 'a todo with quite a lot of words in it to wrap around',
        created: '2026-09-25 16:30',
        edited: '2026-09-26 09:12',
        done: false,
        toggleCommand: 't',
        editCommand: 'e',
        removeCommand: 'r',
      ),
      const ContactsBlock(
        more: 12,
        contacts: [
          ContactCard(
            name: 'A Contact With A Rather Long Name Indeed',
            numbers: [
              ContactNumber(
                label: 'mobile',
                number: '+46 (0)70 123 45 67 ext 89',
                callCommand: 'c',
                smsCommand: 's',
              ),
            ],
          ),
        ],
      ),
    ];

    for (final theme in ThemeChoice.values) {
      for (final size in FontSizeChoice.values) {
        testWidgets('${theme.name} ${size.name}: nothing overflows', (
          tester,
        ) async {
          for (final block in blocks) {
            await _pump(
              tester,
              block,
              theme: theme,
              fontSize: size,
              width: 320,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '${block.runtimeType}',
            );
          }
        });
      }
    }
  });
}
