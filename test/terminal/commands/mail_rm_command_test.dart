import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/mail_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/mail_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_mail_service.dart';

final _now = DateTime(2026, 9, 26, 15, 30);

MailMessage _message(int uid, {String subject = 'Lunch tomorrow?'}) =>
    MailMessage(
      uid: uid,
      from: 'Anna Berg',
      subject: subject,
      date: DateTime(2026, 9, 26, 14, 5),
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

  /// A list of three messages, uids 30, 20 and 10, has been shown.
  Future<void> showList({int? validity = 7}) async {
    mail.result = MailMessages(
      [
        _message(30),
        MailMessage(uid: 20, from: 'Bo', subject: 'Second'),
        MailMessage(uid: 10, from: 'Cy', subject: ''),
      ],
      total: 3,
      unread: 0,
      validity: validity,
    );
    await run([]);
  }
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() || CommandAskSecret() => fail('unexpected result'),
};

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  test('moves the numbered message, by its id, to Trash', () async {
    await rig.showList();

    final result = await rig.run(['rm', '2']);

    expect(rig.mail.moves, [(20, 7)]);
    final notice = (result as CommandOutput).block! as NoticeBlock;
    expect(notice.kind, NoticeKind.success);
    expect(notice.message, 'moved to Trash: Second');
    expect(notice.details, [Messages.mailMovedTip]);
  });

  test('hands over the list validity so a renumbering is caught', () async {
    await rig.showList(validity: 42);

    await rig.run(['rm', '1']);

    expect(rig.mail.moves.single.$2, 42);
  });

  test('names the folder the server called its Trash', () async {
    await rig.showList();
    rig.mail.moveResult = const MailMoved('Deleted Messages');

    final result = await rig.run(['rm', '1']);

    expect(_lines(result).first, startsWith('moved to Deleted Messages:'));
    expect(_lines(result).first, endsWith('Lunch tomorrow?'));
  });

  test('a message with no subject is named as such', () async {
    await rig.showList();

    final result = await rig.run(['rm', '3']);

    expect(_lines(result).first, 'moved to Trash: (no subject)');
  });

  test('a long subject is cut', () async {
    rig.mail.result = MailMessages(
      [_message(1, subject: 'x' * 100)],
      total: 1,
      unread: 0,
    );
    await rig.run([]);

    final result = await rig.run(['rm', '1']);

    expect(_lines(result).first.length, lessThan(70));
    expect(_lines(result).first, endsWith('…'));
  });

  test('#id is the message with that id', () async {
    await rig.showList();

    await rig.run(['rm', '#10']);

    expect(rig.mail.moves, [(10, 7)]);
  });

  test('#id keeps meaning one message when the list is shown again', () async {
    await rig.showList();
    // New mail arrives and the list is shown again, so number 1 is another
    // message now. A button on the older card still says #20.
    rig.mail.result = MailMessages(
      [
        _message(40),
        _message(30),
        MailMessage(uid: 20, from: 'Bo', subject: 'Second'),
      ],
      total: 4,
      unread: 0,
      validity: 7,
    );
    await rig.run([]);

    await rig.run(['rm', '#20']);

    expect(rig.mail.moves, [(20, 7)]);
  });

  test('a number is from the last list shown, not an older one', () async {
    await rig.showList();
    rig.mail.result = MailMessages(
      [_message(99)],
      total: 1,
      unread: 0,
      validity: 7,
    );
    await rig.run([]);

    await rig.run(['rm', '1']);

    expect(rig.mail.moves, [(99, 7)]);
  });

  test(
    'an id that was not in the list is refused and nothing is touched',
    () async {
      await rig.showList();

      final result = await rig.run(['rm', '#555']);

      expect(_lines(result), ['message #555 is not in the last list']);
      expect(rig.mail.moves, isEmpty);
    },
  );

  test('a number past the end of the list is refused', () async {
    await rig.showList();

    final result = await rig.run(['rm', '4']);

    expect(_lines(result), ['no message 4 in the last list (1-3)']);
    expect(rig.mail.moves, isEmpty);
  });

  test('nothing to go by before the list has been shown', () async {
    final result = await rig.run(['rm', '1']);

    expect(result, isA<CommandFailure>());
    expect(_lines(result), [Messages.mailNoList]);
    expect(rig.mail.moves, isEmpty);
  });

  test('an empty list has nothing to remove either', () async {
    rig.mail.result = const MailMessages([], total: 0, unread: 0);
    await rig.run([]);

    expect(_lines(await rig.run(['rm', '1'])), [Messages.mailNoList]);
  });

  test('bad targets show the usage and touch nothing', () async {
    await rig.showList();

    for (final bad in ['0', '-1', 'x', '#', '#0', '#x', '1.5', '']) {
      expect(
        _lines(await rig.run(['rm', bad])),
        Messages.mailUsage,
        reason: "'$bad'",
      );
    }
    expect(_lines(await rig.run(['rm'])), Messages.mailUsage);
    expect(_lines(await rig.run(['rm', '1', '2'])), Messages.mailUsage);
    expect(rig.mail.moves, isEmpty);
  });

  test('once moved, doing it again does not ask the server', () async {
    await rig.showList();
    await rig.run(['rm', '2']);

    final again = await rig.run(['rm', '2']);
    final byId = await rig.run(['rm', '#20']);

    expect(_lines(again), [Messages.mailAlreadyMoved]);
    expect(_lines(byId), [Messages.mailAlreadyMoved]);
    expect(rig.mail.moves, hasLength(1));
  });

  test('showing the list again forgets what was moved', () async {
    await rig.showList();
    await rig.run(['rm', '2']);
    await rig.showList();

    await rig.run(['rm', '2']);

    expect(rig.mail.moves, hasLength(2));
  });

  test('a message already gone says so and is not retried', () async {
    await rig.showList();
    rig.mail.moveResult = const MailGone();

    final first = await rig.run(['rm', '1']);
    final second = await rig.run(['rm', '1']);

    expect(_lines(first), [Messages.mailGone]);
    expect(_lines(second), [Messages.mailAlreadyMoved]);
    expect(rig.mail.moves, hasLength(1));
  });

  test('a failure is one line and does not count as moved', () async {
    await rig.showList();
    rig.mail.moveResult = const MailMoveFailed('no Trash folder on x');

    final result = await rig.run(['rm', '1']);
    rig.mail.moveResult = const MailMoved('Trash');
    final retry = await rig.run(['rm', '1']);

    expect(result, isA<CommandFailure>());
    expect(_lines(result), ['mail: no Trash folder on x']);
    expect(retry, isA<CommandOutput>());
  });

  test('with the account removed it says how to set one up', () async {
    await rig.showList();
    rig.mail.moveResult = const MailMoveNotSetUp();

    expect(_lines(await rig.run(['rm', '1'])), [
      Messages.mailNotSetUp,
      Messages.mailHowToSetUp,
    ]);
  });

  test('is offered as a subcommand and listed in the forms', () {
    expect(rig.command.argSuggestions!('r', const []), ['rm']);
    expect(rig.command.usageForms, contains('mail rm <number>'));
  });

  test('uses the numbers the plain list shows', () async {
    rig.mail.result = MailMessages(
      [_message(30), _message(20)],
      total: 2,
      unread: 0,
      validity: 7,
    );

    final listed = _lines(await rig.run(['--plain']));
    await rig.run(['rm', '2']);

    expect(listed[3], startsWith(' 2 '));
    expect(rig.mail.moves.single.$1, 20);
  });
}
