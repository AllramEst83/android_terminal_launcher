import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/mail_account.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/in_memory_secret_store.dart';

void main() {
  late InMemorySecretStore secrets;
  late MailAccountStore store;
  setUp(() {
    secrets = InMemorySecretStore();
    store = MailAccountStore(secrets);
  });

  test('nothing is saved at first', () async {
    expect(await store.load(), isNull);
    expect(await store.exists(), isFalse);
  });

  test('an account round-trips, password included', () async {
    await store.save(
      const MailAccount(
        email: 'kay@gmail.com',
        host: 'imap.gmail.com',
        password: 'abcdefghijklmnop',
        port: 143,
      ),
    );

    final loaded = (await store.load())!;

    expect(loaded.email, 'kay@gmail.com');
    expect(loaded.host, 'imap.gmail.com');
    expect(loaded.port, 143);
    expect(loaded.password, 'abcdefghijklmnop');
    expect(await store.exists(), isTrue);
  });

  test('everything is one entry, so none of it can be left behind', () async {
    await store.save(
      const MailAccount(email: 'a@b.co', host: 'h', password: 'p'),
    );

    expect(secrets.data, hasLength(1));
    await store.clear();
    expect(secrets.data, isEmpty);
  });

  test(
    'a damaged entry is an error that names the way out, not its text',
    () async {
      secrets.data['mailAccount'] = '{"email": "a@b.co", "password": "hunter2"';

      await expectLater(
        store.load(),
        throwsA(
          isA<LocalStoreException>()
              .having((e) => e.message, 'message', contains('mail forget'))
              .having((e) => e.message, 'message', isNot(contains('hunter2'))),
        ),
      );
      expect(await store.exists(), isTrue);
    },
  );

  test('an entry with a field missing is damaged too', () async {
    secrets.data['mailAccount'] = '{"email": "a@b.co"}';

    await expectLater(store.load(), throwsA(isA<LocalStoreException>()));
  });
}
