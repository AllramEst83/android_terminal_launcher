import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/mail_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/mail_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_mail_service.dart';

// Saturday 26 September 2026.
final _now = DateTime(2026, 9, 26, 15, 30);

MailMessage _message(int uid, {bool unread = false}) => MailMessage(
  uid: uid,
  from: 'Anna Berg',
  subject: 'Lunch tomorrow?',
  date: DateTime(2026, 9, 26, 14, 5),
  unread: unread,
);

class _Rig {
  final mail = FakeMailService();
  late final Command command = mailCommand(mail);

  Future<CommandResult> run(List<String> args) => command.run(
    CommandContext(
      args: args,
      apps: FakeAppRepository(),
      commands: const [],
      now: () => _now,
    ),
  );
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() || CommandAskSecret() => fail('unexpected result'),
};

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  group('listing', () {
    test('asks for the twenty newest', () async {
      rig.mail.result = const MailMessages([], total: 0, unread: 0);

      await rig.run([]);

      expect(rig.mail.counts, [20]);
    });

    test('shows a summary and two lines a message', () async {
      rig.mail.result = MailMessages(
        [_message(2, unread: true), _message(1)],
        total: 2,
        unread: 1,
      );

      final result = await rig.run([]);

      expect(_lines(result), [
        '2 messages, 1 unread',
        ' 1 * 14:05    Anna Berg',
        '       Lunch tomorrow?',
        ' 2   14:05    Anna Berg',
        '       Lunch tomorrow?',
      ]);
    });

    test('has a card with the same rows', () async {
      rig.mail.result = MailMessages(
        [_message(2, unread: true)],
        total: 1,
        unread: 1,
      );

      final result = await rig.run([]);

      final block = (result as CommandOutput).block! as MailBlock;
      expect(block.summary, '1 message, 1 unread');
      expect(block.rows.single.uid, 2);
      expect(block.rows.single.sender, 'Anna Berg');
      expect(block.rows.single.when, '14:05');
      expect(block.rows.single.unread, isTrue);
    });

    test('--plain gives no card', () async {
      rig.mail.result = MailMessages([_message(1)], total: 1, unread: 0);

      final result = await rig.run(['--plain']);

      expect((result as CommandOutput).block, isNull);
      expect(result.lines, isNotEmpty);
    });

    test('email is another name for it', () {
      expect(rig.command.aliases, contains('email'));
    });

    test('an empty inbox says so', () async {
      rig.mail.result = const MailMessages([], total: 0, unread: 0);

      expect(_lines(await rig.run([])), [Messages.mailEmpty]);
    });

    test('with no account says how to set one up', () async {
      final result = await rig.run([]);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.mailNotSetUp, Messages.mailHowToSetUp]);
    });

    test('a server problem is one line', () async {
      rig.mail.result = const MailUnavailable('imap.gmail.com refused it');

      expect(_lines(await rig.run([])), ['mail: imap.gmail.com refused it']);
    });
  });

  group('setup', () {
    Future<CommandAskSecret> ask(List<String> args) async {
      final result = await rig.run(['setup', ...args]);
      expect(result, isA<CommandAskSecret>(), reason: _describe(result));
      return result as CommandAskSecret;
    }

    test(
      'asks for the password of a known provider, saving nothing yet',
      () async {
        final asked = await ask(['kay@gmail.com']);

        expect(asked.prompt, contains('kay@gmail.com'));
        expect(rig.mail.setUps, isEmpty);
      },
    );

    test('logs in with the guessed server and the password', () async {
      final asked = await ask(['kay@gmail.com']);

      final result = await asked.then('abcd efgh ijkl mnop');

      expect(rig.mail.setUps, [
        ('kay@gmail.com', 'imap.gmail.com', 'abcdefghijklmnop'),
      ]);
      final notice = (result as CommandOutput).block! as NoticeBlock;
      expect(notice.kind, NoticeKind.success);
      expect(notice.message, contains('kay@gmail.com'));
    });

    test('takes the server from the command when there is one', () async {
      final asked = await ask(['kay@example.org', 'mail.example.org:143']);

      await asked.then('secret');

      expect(rig.mail.setUps.single.$2, 'mail.example.org:143');
    });

    test('an unknown domain needs a server', () async {
      final result = await rig.run(['setup', 'kay@example.org']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        "don't know the mail server for example.org",
        Messages.mailGiveServer,
      ]);
    });

    test('the domain is matched without regard to case', () async {
      await ask(['Kay@GMAIL.com']);
    });

    test('something that is not an address is refused', () async {
      final result = await rig.run(['setup', 'kay']);

      expect(_lines(result), ["'kay' is not an email address"]);
    });

    test('a refused login reports why and is not a success', () async {
      rig.mail.setUpProblem = 'imap.gmail.com refused the login';
      final asked = await ask(['kay@gmail.com']);

      final result = await asked.then('wrong');

      expect(result, isA<CommandFailure>());
      expect(_lines(result), ['mail: imap.gmail.com refused the login']);
    });

    test('a password of only spaces is a cancel', () async {
      final asked = await ask(['kay@gmail.com']);

      final result = await asked.then('   ');

      expect(_lines(result), [Messages.secretCancelled]);
      expect(rig.mail.setUps, isEmpty);
    });

    test('the password is never in what the command prints', () async {
      final asked = await ask(['kay@gmail.com']);

      final result = await asked.then('hunter2hunter2');

      expect(_lines(result).join('\n'), isNot(contains('hunter2')));
      expect(asked.prompt, isNot(contains('hunter2')));
    });

    test('needs an address, and no more than a server besides', () async {
      expect(_lines(await rig.run(['setup'])), Messages.mailUsage);
      expect(
        _lines(await rig.run(['setup', 'a@gmail.com', 'b', 'c'])),
        Messages.mailUsage,
      );
    });
  });

  group('forget', () {
    test('removes a saved account', () async {
      rig.mail.saved = const MailAccountInfo(
        email: 'kay@gmail.com',
        host: 'imap.gmail.com',
      );

      final result = await rig.run(['forget']);

      expect(rig.mail.saved, isNull);
      expect(_lines(result), [Messages.mailForgotten]);
    });

    test('with none saved says so, without failing', () async {
      final result = await rig.run(['forget']);

      expect(result, isA<CommandOutput>());
      expect(_lines(result), [Messages.mailNothingToForget]);
    });

    test('takes no arguments', () async {
      expect(_lines(await rig.run(['forget', 'now'])), Messages.mailUsage);
    });
  });

  test('anything else shows the usage', () async {
    expect(_lines(await rig.run(['delete'])), Messages.mailUsage);
  });

  group('suggestions', () {
    test('offers the subcommands by prefix', () {
      final suggest = rig.command.argSuggestions!;

      expect(suggest('', const []), ['rm', 'setup', 'forget']);
      expect(suggest('se', const []), ['setup']);
      expect(suggest('x', const []), isEmpty);
    });

    test('offers nothing after the subcommand', () {
      expect(rig.command.argSuggestions!('setup kay@', const []), isEmpty);
    });
  });
}

String _describe(CommandResult result) => switch (result) {
  CommandOutput(:final lines) ||
  CommandFailure(:final lines) => lines.join('|'),
  _ => '$result',
};
