import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/choice_view.dart';
import 'package:android_terminal_launcher/ui/contacts_view.dart';
import 'package:android_terminal_launcher/ui/prompt_filler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/in_memory_local_store.dart';

const _anna = ContactCard(
  name: 'Anna Andersson',
  numbers: [
    ContactNumber(
      label: 'mobile',
      number: '070-123 45 67',
      callCommand: 'call 0701234567',
      smsCommand: 'sms 0701234567 "',
    ),
  ],
);

final _contact = Command(
  name: 'contact',
  description: 'a contact',
  usage: 'contact',
  run: (context) async => const CommandOutput([
    'Anna Andersson',
  ], block: ContactsBlock(contacts: [_anna])),
);

/// A failure that asks the user to pick: what several matches produce.
final _pick = Command(
  name: 'pick',
  description: 'fails with a picker',
  usage: 'pick',
  run: (context) async => const CommandFailure(
    ['several match', '  One', '  Two'],
    block: ChoiceBlock(
      title: 'several match',
      groups: [
        ChoiceGroup(
          options: [
            ChoiceOption(label: 'One', command: 'echo one'),
            ChoiceOption(label: 'Two', command: 'call "Two"', fill: true),
          ],
        ),
      ],
    ),
  ),
);

final _echo = Command(
  name: 'echo',
  description: 'says its first argument',
  usage: 'echo',
  run: (context) async => CommandOutput([context.args.first]),
);

Future<TerminalSession> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = InMemoryLocalStore();
  final themes = ThemeController(store: store);
  addTearDown(themes.dispose);
  final fontSize = FontSizeController(store: store);
  addTearDown(fontSize.dispose);
  final session = TerminalSession(
    registry: CommandRegistry([_contact, _pick, _echo]),
    apps: FakeAppRepository(),
  );
  addTearDown(session.dispose);
  await tester.pumpWidget(
    App(session: session, themes: themes, fontSize: fontSize),
  );
  return session;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

TextField _prompt(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  group('PromptFiller', () {
    test('does nothing until a prompt has attached', () {
      PromptFiller().fill('call 1');
    });

    test('hands the text to the attached prompt', () {
      final filler = PromptFiller();
      final got = <String>[];
      filler.attach(got.add);

      filler.fill('call 1');

      expect(got, ['call 1']);
    });

    test('does nothing again once the prompt has detached', () {
      final filler = PromptFiller();
      final got = <String>[];
      filler.attach(got.add);
      filler.detach(got.add);

      filler.fill('call 1');

      expect(got, isEmpty);
    });

    test('a prompt that is replaced is not detached by the old one', () {
      final filler = PromptFiller();
      final old = <String>[];
      final fresh = <String>[];
      filler.attach(old.add);
      filler.attach(fresh.add);

      filler.detach(old.add);
      filler.fill('x');

      expect(fresh, ['x']);
    });
  });

  group('on the screen', () {
    testWidgets('a call button puts the command in the prompt, not run', (
      tester,
    ) async {
      final session = await _pump(tester);
      await _type(tester, 'contact');

      await tester.tap(find.byKey(contactCallKey('070-123 45 67')));
      await tester.pump();

      final field = _prompt(tester);
      expect(field.controller!.text, 'call 0701234567');
      expect(field.controller!.selection.baseOffset, 'call 0701234567'.length);
      expect(field.focusNode!.hasFocus, isTrue);
      // Nothing was submitted: only the lookup is in the log.
      expect(
        session.lines.where((l) => l.text.startsWith(r'$ ')).map((l) => l.text),
        [r'$ contact'],
      );
    });

    testWidgets('an sms button leaves an open quote for the text', (
      tester,
    ) async {
      await _pump(tester);
      await _type(tester, 'contact');

      await tester.tap(find.byKey(contactSmsKey('070-123 45 67')));
      await tester.pump();

      expect(_prompt(tester).controller!.text, 'sms 0701234567 "');
    });

    testWidgets('a fill replaces what was typed, and can be edited', (
      tester,
    ) async {
      await _pump(tester);
      await _type(tester, 'contact');
      await tester.enterText(find.byType(TextField), 'half typed');

      await tester.tap(find.byKey(contactCallKey('070-123 45 67')));
      await tester.pump();
      expect(_prompt(tester).controller!.text, 'call 0701234567');

      await tester.enterText(find.byType(TextField), 'call 0701234568');
      expect(_prompt(tester).controller!.text, 'call 0701234568');
    });

    testWidgets('a failure with a picker is drawn as one, not as red lines', (
      tester,
    ) async {
      final session = await _pump(tester);
      await _type(tester, 'pick');

      expect(find.byKey(choiceKey('One')), findsOneWidget);
      expect(find.text('  One'), findsNothing);
      // One log entry for the whole failure, still an error.
      final failure = session.lines.last;
      expect(failure.block, isA<ChoiceBlock>());
      expect(failure.text, 'several match\n  One\n  Two');
    });

    testWidgets('in a picker, one option runs and another fills', (
      tester,
    ) async {
      final session = await _pump(tester);
      await _type(tester, 'pick');

      await tester.tap(find.byKey(choiceKey('Two')));
      await tester.pump();
      expect(_prompt(tester).controller!.text, 'call "Two"');

      await tester.tap(find.byKey(choiceKey('One')));
      await tester.pump();
      await tester.pump();

      expect(session.lines.map((l) => l.text), contains(r'$ echo one'));
      expect(session.lines.last.text, 'one');
    });

    testWidgets('the suggestions still fill the prompt as they did', (
      tester,
    ) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'con');
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('contact').last);
      await tester.pump();

      expect(_prompt(tester).controller!.text, 'contact');
    });
  });
}
