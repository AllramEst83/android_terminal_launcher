import 'package:android_terminal_launcher/services/imap_mail_service.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/mail_account.dart';
import 'package:android_terminal_launcher/services/mail_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_imap_server.dart';
import '../fakes/in_memory_secret_store.dart';

const _password = 'abcd efgh ijkl mnop';

void main() {
  late FakeImapServer server;
  late InMemorySecretStore secrets;
  late ImapMailService mail;

  Future<void> boot(List<FakeImapMessage> messages) async {
    server = FakeImapServer(
      user: 'kay@example.com',
      password: _password,
      messages: messages,
    );
    await server.start();
    secrets = InMemorySecretStore();
    mail = ImapMailService(
      accounts: MailAccountStore(secrets),
      secure: false,
      timeout: const Duration(seconds: 5),
    );
  }

  Future<String?> setUp({String password = _password}) => mail.setUp(
    email: 'kay@example.com',
    host: '127.0.0.1:${server.port}',
    password: password,
  );

  group('splitHostPort', () {
    test('defaults to the IMAPS port', () {
      expect(splitHostPort('imap.gmail.com'), (
        host: 'imap.gmail.com',
        port: 993,
      ));
    });

    test('takes a port after a colon', () {
      expect(splitHostPort('mail.example.com:143'), (
        host: 'mail.example.com',
        port: 143,
      ));
    });

    test('leaves a colon that is not followed by a number in the host', () {
      expect(splitHostPort('odd:host').host, 'odd:host');
    });
  });

  group('set up', () {
    tearDown(() => server.stop());

    test('with the right password saves the account', () async {
      await boot(const []);
      expect(await mail.account(), isNull);

      expect(await setUp(), isNull);

      final info = await mail.account();
      expect(info?.email, 'kay@example.com');
      expect(info?.host, '127.0.0.1');
      expect(secrets.data, hasLength(1));
    });

    test('with the wrong password saves nothing and says so', () async {
      await boot(const []);

      final problem = await setUp(password: 'nope');

      expect(problem, contains('refused the login'));
      expect(problem, isNot(contains('nope')));
      expect(secrets.data, isEmpty);
      expect(await mail.account(), isNull);
    });

    test('with nobody listening says it cannot reach the host', () async {
      await boot(const []);
      final port = server.port;
      await server.stop();

      final problem = await mail.setUp(
        email: 'kay@example.com',
        host: '127.0.0.1:$port',
        password: _password,
      );

      expect(problem, contains("can't reach"));
      expect(secrets.data, isEmpty);
    });

    test('reports a store that fails, after a good login', () async {
      await boot(const []);
      secrets.failure = const LocalStoreException('keystore is locked');

      expect(await setUp(), 'keystore is locked');
    });

    test('forget removes the account', () async {
      await boot(const []);
      await setUp();

      expect(await mail.forget(), isTrue);

      expect(await mail.account(), isNull);
      expect(secrets.data, isEmpty);
      expect(await mail.forget(), isFalse); // and forgetting nothing is fine
    });
  });

  group('latest', () {
    tearDown(() => server.stop());

    const inbox = [
      FakeImapMessage(
        uid: 101,
        subject: '"Lunch tomorrow?"',
        date: 'Fri, 25 Sep 2026 10:00:00 +0000',
        address: 'anna@example.com',
        name: 'Anna Berg',
        seen: true,
      ),
      FakeImapMessage(
        uid: 102,
        subject: '"=?UTF-8?Q?Sm=C3=B6rg=C3=A5s?="',
        date: 'Sat, 26 Sep 2026 08:30:00 +0200',
        address: 'noreply@shop.example',
      ),
      FakeImapMessage(
        uid: 103,
        subject: 'NIL',
        date: 'Sat, 26 Sep 2026 09:15:00 +0000',
        address: 'bo@example.com',
        name: 'Bo',
      ),
    ];

    test('without an account is not set up', () async {
      await boot(inbox);

      expect(await mail.latest(), isA<MailNotSetUp>());
      expect(server.connections, 0);
    });

    test('lists the newest first with sender, subject and state', () async {
      await boot(inbox);
      await setUp();

      final result = await mail.latest();

      final found = result as MailMessages;
      expect(found.total, 3);
      expect(found.unread, 2);
      expect([for (final m in found.messages) m.uid], [103, 102, 101]);
      final lunch = found.messages.last;
      expect(lunch.from, 'Anna Berg');
      expect(lunch.subject, 'Lunch tomorrow?');
      expect(lunch.unread, isFalse);
      expect(lunch.date, DateTime.utc(2026, 9, 25, 10).toLocal());
    });

    test(
      'uses the address when there is no name, and decodes subjects',
      () async {
        await boot(inbox);
        await setUp();

        final found = await mail.latest() as MailMessages;

        final shop = found.messages[1];
        expect(shop.from, 'noreply@shop.example');
        expect(shop.subject, 'Smörgås');
        expect(shop.unread, isTrue);
        expect(shop.date, DateTime.utc(2026, 9, 26, 6, 30).toLocal());
        expect(found.messages.first.subject, isEmpty);
      },
    );

    test('asks for exactly the newest few, and only their envelopes', () async {
      await boot(inbox);
      await setUp();

      final found = await mail.latest(count: 2) as MailMessages;

      expect([for (final m in found.messages) m.uid], [103, 102]);

      final fetches = server.received.where((c) => c.startsWith('FETCH'));
      expect(fetches, ['FETCH 2:3 (UID FLAGS ENVELOPE)']);
    });

    test('only reads: nothing that changes the mailbox is ever sent', () async {
      await boot(inbox);
      await setUp();

      await mail.latest();

      const changing = ['STORE', 'EXPUNGE', 'DELETE', 'COPY', 'MOVE', 'APPEND'];
      for (final command in server.received) {
        expect(changing, isNot(contains(command.split(' ').first)));
      }
    });

    test('an empty inbox is an empty list', () async {
      await boot(const []);
      await setUp();

      final found = await mail.latest() as MailMessages;

      expect(found.messages, isEmpty);
      expect(found.total, 0);
      expect(found.unread, 0);
    });

    test('a server error becomes a message without the password', () async {
      await boot(inbox);
      await setUp();
      server.failSelect = true;

      final result = await mail.latest();

      final failed = result as MailUnavailable;
      expect(failed.reason, startsWith('127.0.0.1'));
      expect(failed.reason, isNot(contains('efgh')));
    });

    test('hangs up after each call', () async {
      await boot(inbox);
      await setUp();

      await mail.latest();

      expect(server.received, contains('LOGOUT'));
    });

    test('an unreadable saved account says how to recover', () async {
      await boot(inbox);
      secrets.data['mailAccount'] = 'not json';

      final result = await mail.latest();

      expect(result, isA<MailUnavailable>());
      expect((result as MailUnavailable).reason, contains('mail forget'));
    });
  });

  group('moveToTrash', () {
    tearDown(() => server.stop());

    const inbox = [
      FakeImapMessage(
        uid: 101,
        subject: '"One"',
        date: 'Fri, 25 Sep 2026 10:00:00 +0000',
        address: 'one@example.com',
      ),
      FakeImapMessage(
        uid: 102,
        subject: '"Two"',
        date: 'Sat, 26 Sep 2026 08:30:00 +0200',
        address: 'two@example.com',
      ),
      FakeImapMessage(
        uid: 103,
        subject: '"Three"',
        date: 'Sat, 26 Sep 2026 09:15:00 +0000',
        address: 'three@example.com',
      ),
    ];

    List<int> uids(List<FakeImapMessage> list) => [for (final m in list) m.uid];

    /// The commands that change something, whatever they are called.
    Iterable<String> changes() => server.received.where(
      (c) =>
          RegExp(r'^(UID )?(MOVE|COPY|STORE|EXPUNGE|DELETE|APPEND)')
              .hasMatch(c),
    );

    test('moves the message and only that one, to the Trash folder', () async {
      await boot(inbox);
      await setUp();

      final result = await mail.moveToTrash(102);

      expect(result, isA<MailMoved>());
      expect((result as MailMoved).folder, 'Trash');
      expect(uids(server.inbox), [101, 103]);
      expect(uids(server.trash), [102]);
      expect(changes(), ['UID MOVE 102 [Gmail]/Trash']);
    });

    test('quotes a Trash folder whose name has a space in it', () async {
      await boot(inbox);
      server.trashName = 'Deleted Messages';
      await setUp();

      final result = await mail.moveToTrash(102);

      expect((result as MailMoved).folder, 'Deleted Messages');
      expect(changes(), ['UID MOVE 102 "Deleted Messages"']);
    });

    test('never sends a delete, whatever happens', () async {
      await boot(inbox);
      await setUp();

      await mail.moveToTrash(102);
      await mail.moveToTrash(999);

      for (final command in server.received) {
        expect(command, isNot(startsWith('DELETE')));
        expect(command, isNot(contains('EXPUNGE')));
        expect(command, isNot(contains('STORE')));
      }
    });

    test('without MOVE it copies, flags and expunges that uid alone', () async {
      await boot(inbox);
      server.capabilities = 'IMAP4rev1 UIDPLUS';
      await setUp();

      final result = await mail.moveToTrash(102);

      expect(result, isA<MailMoved>());
      expect(uids(server.inbox), [101, 103]);
      expect(uids(server.trash), [102]);
      expect(changes(), [
        'UID COPY 102 [Gmail]/Trash',
        r'UID STORE 102 +FLAGS.SILENT (\Deleted)',
        'UID EXPUNGE 102',
      ]);
      expect(
        server.received.where((c) => c == 'EXPUNGE'),
        isEmpty,
        reason: 'a plain EXPUNGE would remove everything flagged deleted',
      );
    });

    test('without MOVE or UIDPLUS it refuses and changes nothing', () async {
      await boot(inbox);
      server.capabilities = 'IMAP4rev1';
      await setUp();

      final result = await mail.moveToTrash(102);

      expect(result, isA<MailMoveFailed>());
      expect(
        (result as MailMoveFailed).reason,
        contains('nothing was changed'),
      );
      expect(uids(server.inbox), [101, 102, 103]);
      expect(changes(), isEmpty);
    });

    test('with no Trash folder it refuses rather than delete', () async {
      await boot(inbox);
      server.hasTrash = false;
      await setUp();

      final result = await mail.moveToTrash(102);

      expect((result as MailMoveFailed).reason, contains('no Trash folder'));
      expect(uids(server.inbox), [101, 102, 103]);
      expect(changes(), isEmpty);
    });

    test('a message that is no longer there is gone, not an error', () async {
      await boot(inbox);
      await setUp();

      final result = await mail.moveToTrash(555);

      expect(result, isA<MailGone>());
      expect(uids(server.inbox), [101, 102, 103]);
      expect(changes(), isEmpty);
    });

    test('a list read under another UIDVALIDITY is not acted on', () async {
      await boot(inbox);
      await setUp();
      final read = await mail.latest() as MailMessages;
      expect(read.validity, 1);
      server.uidValidity = 2; // the server renumbered everything

      final result = await mail.moveToTrash(102, validity: read.validity);

      expect(result, isA<MailMoveFailed>());
      expect((result as MailMoveFailed).reason, contains('renumbered'));
      expect(uids(server.inbox), [101, 102, 103]);
      expect(changes(), isEmpty);
    });

    test('the same validity goes ahead', () async {
      await boot(inbox);
      await setUp();
      final read = await mail.latest() as MailMessages;

      final result = await mail.moveToTrash(102, validity: read.validity);

      expect(result, isA<MailMoved>());
    });

    test('with no account it says so and connects to nothing', () async {
      await boot(inbox);

      expect(await mail.moveToTrash(102), isA<MailMoveNotSetUp>());
      expect(server.connections, 0);
    });

    test('a server error is a message without the password', () async {
      await boot(inbox);
      await setUp();
      server.failSelect = true;

      final result = await mail.moveToTrash(102);

      final failed = result as MailMoveFailed;
      expect(failed.reason, startsWith('127.0.0.1'));
      expect(failed.reason, isNot(contains('efgh')));
      expect(uids(server.inbox), [101, 102, 103]);
    });

    test('hangs up afterwards', () async {
      await boot(inbox);
      await setUp();

      await mail.moveToTrash(102);

      expect(server.received, contains('LOGOUT'));
    });
  });
}
