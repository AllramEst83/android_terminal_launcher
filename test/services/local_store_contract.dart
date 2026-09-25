import 'dart:convert';

import 'package:android_terminal_launcher/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _NotJson {}

/// What every [LocalStore] must do, so the real store and the fake features
/// are tested against cannot drift apart. [create] is called once per test and
/// must return a store that starts empty.
void localStoreContract(LocalStore Function() create) {
  test('reading a key that was never written gives null', () async {
    expect(await create().read('missing'), isNull);
  });

  test('a written value reads back equal', () async {
    final store = create();
    final value = {
      'title': 'buy milk',
      'done': false,
      'count': 3,
      'tags': ['home', 'food'],
      'nested': {'a': 1.5},
    };

    await store.write('note', value);

    expect(await store.read('note'), value);
  });

  test('every JSON shape is accepted', () async {
    final store = create();

    await store.write('string', 'text');
    await store.write('number', 42);
    await store.write('bool', true);
    await store.write('list', [1, 2, 3]);

    expect(await store.read('string'), 'text');
    expect(await store.read('number'), 42);
    expect(await store.read('bool'), true);
    expect(await store.read('list'), [1, 2, 3]);
  });

  test('writing again replaces the old value', () async {
    final store = create();
    await store.write('k', 'one');

    await store.write('k', 'two');

    expect(await store.read('k'), 'two');
  });

  test('keys are independent', () async {
    final store = create();

    await store.write('a', 1);
    await store.write('b', 2);
    await store.delete('a');

    expect(await store.read('a'), isNull);
    expect(await store.read('b'), 2);
  });

  test('delete removes a value, and a missing key is not an error', () async {
    final store = create();
    await store.write('k', 'v');

    await store.delete('k');
    await store.delete('k');

    expect(await store.read('k'), isNull);
  });

  test(
    'changing a value that was read does not change the stored one',
    () async {
      final store = create();
      await store.write('list', [1, 2]);

      final read = await store.read('list') as List<Object?>;
      read.add(3);

      expect(await store.read('list'), [1, 2]);
    },
  );

  test(
    'changing a value after writing it does not change the stored one',
    () async {
      final store = create();
      final list = [1, 2];
      await store.write('list', list);

      list.add(3);

      expect(await store.read('list'), [1, 2]);
    },
  );

  test('an unencodable value throws and keeps the previous one', () async {
    final store = create();
    await store.write('k', 'old');

    await expectLater(
      store.write('k', _NotJson()),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );

    expect(await store.read('k'), 'old');
  });
}
