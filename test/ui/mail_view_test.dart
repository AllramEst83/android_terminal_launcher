import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/block_view.dart';
import 'package:android_terminal_launcher/ui/mail_view.dart';
import 'package:android_terminal_launcher/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/in_memory_local_store.dart';

const _block = MailBlock(
  summary: 'latest 20 of 1,234, 7 unread',
  rows: [
    MailRow(
      uid: 3,
      sender: 'Anna Berg',
      subject: 'Lunch tomorrow?',
      when: '14:05',
      unread: true,
      removeCommand: 'mail rm #3',
    ),
    MailRow(
      uid: 2,
      sender: 'noreply@shop.example',
      subject: 'Your order has shipped',
      when: 'Fri',
      unread: false,
      removeCommand: 'mail rm #2',
    ),
  ],
);

Future<List<String>> _pump(
  WidgetTester tester,
  MailBlock block, {
  ThemeChoice theme = ThemeChoice.dark,
  FontSizeChoice fontSize = FontSizeChoice.normal,
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final filled = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: themeFor(theme, fontSize),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BlockView(
              block: block,
              onRun: (_) => fail('a tap in the inbox must not run anything'),
              onFill: filled.add,
            ),
          ),
        ),
      ),
    ),
  );
  return filled;
}

void main() {
  group('the card', () {
    testWidgets('shows the summary and each message', (tester) async {
      await _pump(tester, _block);

      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('latest 20 of 1,234, 7 unread'), findsOneWidget);
      for (final text in [
        'Anna Berg',
        'Lunch tomorrow?',
        '14:05',
        'noreply@shop.example',
        'Your order has shipped',
        'Fri',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('the bin puts the remove command in the prompt, not more', (
      tester,
    ) async {
      final filled = await _pump(tester, _block);

      await tester.tap(find.byKey(mailRemoveKey(2)));
      await tester.pump();

      expect(filled, ['mail rm #2']);
    });

    testWidgets('each row has its own bin', (tester) async {
      final filled = await _pump(tester, _block);

      await tester.tap(find.byKey(mailRemoveKey(3)));
      await tester.tap(find.byKey(mailRemoveKey(2)));

      expect(filled, ['mail rm #3', 'mail rm #2']);
    });

    testWidgets('a row without a remove command has no bin', (tester) async {
      await _pump(
        tester,
        const MailBlock(
          summary: '1 message',
          rows: [
            MailRow(
              uid: 1,
              sender: 'Bo',
              subject: 'Hi',
              when: '',
              unread: false,
            ),
          ],
        ),
      );

      expect(find.byKey(mailRemoveKey(1)), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('the bin is announced as a button that names the message', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _block);

      expect(
        find.bySemanticsLabel('Move to trash: Lunch tomorrow?'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('marks only the unread message, in bold', (tester) async {
      await _pump(tester, _block);

      expect(find.byKey(mailUnreadKey(3)), findsOneWidget);
      expect(find.byKey(mailUnreadKey(2)), findsNothing);
      final unread = tester.widget<Text>(find.text('Anna Berg'));
      final read = tester.widget<Text>(find.text('noreply@shop.example'));
      expect(unread.style?.fontWeight, FontWeight.bold);
      expect(read.style?.fontWeight, isNot(FontWeight.bold));
    });

    testWidgets('lines the two rows up whether or not there is a dot', (
      tester,
    ) async {
      await _pump(tester, _block);

      expect(
        tester.getTopLeft(find.text('Anna Berg')).dx,
        tester.getTopLeft(find.text('noreply@shop.example')).dx,
      );
    });

    testWidgets('says what a screen reader needs for each row', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _block);

      expect(
        find.bySemanticsLabel('unread, from Anna Berg, 14:05, Lunch tomorrow?'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'from noreply@shop.example, Fri, Your order has shipped',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a message with no date is announced without one', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const MailBlock(
          summary: '1 message',
          rows: [
            MailRow(
              uid: 1,
              sender: 'Bo',
              subject: 'Hello',
              when: '',
              unread: false,
            ),
          ],
        ),
      );

      expect(find.bySemanticsLabel('from Bo, Hello'), findsOneWidget);
      handle.dispose();
    });

    for (final theme in ThemeChoice.values) {
      for (final size in FontSizeChoice.values) {
        testWidgets('${theme.name} ${size.name}: nothing overflows at 320', (
          tester,
        ) async {
          await _pump(
            tester,
            MailBlock(
              summary: 'latest 20 of 1,234,567, 999 unread',
              rows: [
                for (var i = 0; i < 3; i++)
                  MailRow(
                    uid: i,
                    sender:
                        'An Extremely Long Display Name Of A Sender $i '
                        '<someone.with.a.long.address@a-long-domain.example>',
                    subject:
                        'A subject that just keeps going and going, well past '
                        'anything a phone could show on one or two lines $i',
                    when: 'Dec 2025',
                    unread: i.isEven,
                    removeCommand: 'mail rm #$i',
                  ),
              ],
            ),
            theme: theme,
            fontSize: size,
            width: 320,
          );

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('the hidden prompt', () {
    late TerminalSession session;

    Future<void> pumpApp(WidgetTester tester) async {
      session = TerminalSession(
        registry: CommandRegistry([
          Command(
            name: 'login',
            description: 'asks for a secret',
            usage: 'login',
            run: (context) async => CommandAskSecret(
              'password?',
              (secret) async => CommandOutput(['got ${secret.length}']),
            ),
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
    }

    Future<void> type(WidgetTester tester, String input) async {
      await tester.enterText(find.byType(TextField), input);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    bool obscured(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).obscureText;

    testWidgets('hides what is typed, then shows the prompt normally again', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(obscured(tester), isFalse);

      await type(tester, 'login');
      expect(find.text('password?'), findsOneWidget);
      expect(obscured(tester), isTrue);

      await type(tester, 'hunter2');
      expect(obscured(tester), isFalse);
      expect(find.text('got 7'), findsOneWidget);
    });

    testWidgets('never puts the secret on the screen', (tester) async {
      await pumpApp(tester);
      await type(tester, 'login');

      await type(tester, 'hunter2');

      expect(find.textContaining('hunter2'), findsNothing);
      expect(
        find.text('${Messages.prompt}${Messages.secretEcho}'),
        findsOneWidget,
      );
    });

    testWidgets('does not turn a double space into a full stop while hidden', (
      tester,
    ) async {
      await pumpApp(tester);
      await type(tester, 'login');

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.enterText(find.byType(TextField), 'ab ');
      await tester.enterText(find.byType(TextField), 'ab  ');

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'ab  ',
      );
    });
  });
}
