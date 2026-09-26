import 'package:android_terminal_launcher/services/imap_mail_service.dart';
import 'package:android_terminal_launcher/services/mail_account.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/commands/mail_command.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_imap_server.dart';
import '../../fakes/in_memory_secret_store.dart';

const _password = 'abcd efgh ijkl mnop';

/// The whole way: the session, the command and the real IMAP client, against a
/// local server that keeps a Trash folder.
void main() {
  late FakeImapServer server;
  late TerminalSession session;

  setUp(() async {
    server = FakeImapServer(
      user: 'kay@example.com',
      password: _password,
      messages: const [
        FakeImapMessage(
          uid: 101,
          subject: '"First"',
          date: 'Fri, 25 Sep 2026 10:00:00 +0000',
          address: 'a@example.com',
          name: 'Anna',
        ),
        FakeImapMessage(
          uid: 102,
          subject: '"Second"',
          date: 'Sat, 26 Sep 2026 08:30:00 +0200',
          address: 'b@example.com',
        ),
        FakeImapMessage(
          uid: 103,
          subject: '"Third"',
          date: 'Sat, 26 Sep 2026 09:15:00 +0000',
          address: 'c@example.com',
        ),
      ],
    );
    await server.start();
    final mail = ImapMailService(
      accounts: MailAccountStore(InMemorySecretStore()),
      secure: false,
      timeout: const Duration(seconds: 5),
    );
    expect(
      await mail.setUp(
        email: 'kay@example.com',
        host: '127.0.0.1:${server.port}',
        password: _password,
      ),
      isNull,
    );
    session = TerminalSession(
      registry: CommandRegistry([mailCommand(mail)]),
      apps: FakeAppRepository(),
    );
  });

  tearDown(() async {
    session.dispose();
    await server.stop();
  });

  List<String> texts() => [for (final line in session.lines) line.text];

  test('the card\'s button, once sent, moves that message to Trash', () async {
    await session.submit('mail');
    final card = session.lines.last.block! as MailBlock;
    // Newest first: 103, 102, 101. The button on the second row:
    final command = card.rows[1].removeCommand!;
    expect(command, 'mail rm #102');

    await session.submit(command);

    expect(session.lines.last.text, contains('moved to Trash: Second'));
    expect([for (final m in server.inbox) m.uid], [101, 103]);
    expect([for (final m in server.trash) m.uid], [102]);
  });

  test('a typed number goes by the list that was on screen', () async {
    await session.submit('mail');
    // Mail arrives after the list was shown: number 1 is still what it was.
    server.inbox.add(
      const FakeImapMessage(
        uid: 104,
        subject: '"Fourth"',
        date: 'Sat, 26 Sep 2026 12:00:00 +0000',
        address: 'd@example.com',
      ),
    );

    await session.submit('mail rm 1');

    expect([for (final m in server.trash) m.uid], [103]);
    expect([for (final m in server.inbox) m.uid], [101, 102, 104]);
  });

  test('a second try at the same message does not reach the server', () async {
    await session.submit('mail');
    await session.submit('mail rm 2');
    final commandsBefore = server.received.length;

    await session.submit('mail rm 2');

    expect(session.lines.last.text, 'already moved to Trash');
    expect(server.received.length, commandsBefore);
  });

  test(
    'a message removed elsewhere is reported gone, nothing else moves',
    () async {
      await session.submit('mail');
      server.inbox.removeWhere((m) => m.uid == 102);

      await session.submit('mail rm #102');

      expect(texts().last, 'that message is no longer in the inbox');
      expect(server.trash, isEmpty);
      expect([for (final m in server.inbox) m.uid], [101, 103]);
    },
  );

  test('a renumbered inbox stops it, and nothing moves', () async {
    await session.submit('mail');
    server.uidValidity = 2;

    await session.submit('mail rm 1');

    expect(texts().last, contains('renumbered'));
    expect(server.trash, isEmpty);
    expect(server.inbox, hasLength(3));
  });

  test('nothing is ever removed without a mail rm', () async {
    await session.submit('mail');
    await session.submit('mail');

    expect(server.trash, isEmpty);
    expect(server.inbox, hasLength(3));
    expect(
      server.received.where((c) => c.contains('MOVE') || c.contains('STORE')),
      isEmpty,
    );
  });

  test('the command is tagged for the spinner', () {
    final command = mailCommand(
      ImapMailService(accounts: MailAccountStore(InMemorySecretStore())),
    );

    expect(command, isA<Command>().having((c) => c.spinner, 'spinner', isTrue));
  });
}
