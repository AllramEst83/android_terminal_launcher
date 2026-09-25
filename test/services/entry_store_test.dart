import 'package:android_terminal_launcher/services/entry.dart';
import 'package:android_terminal_launcher/services/entry_store.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/in_memory_local_store.dart';

const _key = 'notes';

class _Clock {
  DateTime now = DateTime.utc(2026, 9, 25, 12);

  DateTime call() => now;
}

EntryStore _entries(
  InMemoryLocalStore store, {
  _Clock? clock,
  String key = _key,
}) {
  return EntryStore(store: store, key: key, now: (clock ?? _Clock()).call);
}

void main() {
  group('entries', () {
    test('a new store is empty', () async {
      final entries = _entries(InMemoryLocalStore());

      expect(await entries.all(), isEmpty);
      expect(await entries.find(1), isNull);
    });

    test('add numbers entries from 1 and keeps them in order', () async {
      final entries = _entries(InMemoryLocalStore());

      final first = await entries.add('one');
      final second = await entries.add('two');

      expect([first.id, second.id], [1, 2]);
      expect((await entries.all()).map((e) => e.text), ['one', 'two']);
      expect((await entries.find(2))?.text, 'two');
    });

    test('add stamps creation and update time from the clock', () async {
      final clock = _Clock();
      final entries = _entries(InMemoryLocalStore(), clock: clock);

      final entry = await entries.add('one');

      expect(entry.createdAt, clock.now);
      expect(entry.updatedAt, clock.now);
      expect(entry.done, isFalse);
    });

    test('ids are never reused after a removal', () async {
      final entries = _entries(InMemoryLocalStore());
      await entries.add('one');
      await entries.add('two');
      await entries.remove(2);

      final third = await entries.add('three');

      expect(third.id, 3);
    });

    test('update changes the text and the edit time', () async {
      final clock = _Clock();
      final entries = _entries(InMemoryLocalStore(), clock: clock);
      await entries.add('old');
      clock.now = clock.now.add(const Duration(hours: 1));

      final changed = await entries.update(1, text: 'new');

      expect(changed?.text, 'new');
      expect(changed?.updatedAt, clock.now);
      expect(changed?.createdAt, isNot(clock.now));
      expect((await entries.find(1))?.text, 'new');
    });

    test('ticking done does not count as an edit', () async {
      final clock = _Clock();
      final entries = _entries(InMemoryLocalStore(), clock: clock);
      final added = await entries.add('task');
      clock.now = clock.now.add(const Duration(hours: 1));

      final changed = await entries.update(1, done: true);

      expect(changed?.done, isTrue);
      expect(changed?.updatedAt, added.updatedAt);
    });

    test('update and remove report a missing id with null', () async {
      final entries = _entries(InMemoryLocalStore());
      await entries.add('one');

      expect(await entries.update(9, text: 'x'), isNull);
      expect(await entries.remove(9), isNull);
      expect((await entries.all()).single.text, 'one');
    });

    test('remove returns what it removed', () async {
      final entries = _entries(InMemoryLocalStore());
      await entries.add('one');
      await entries.add('two');

      final removed = await entries.remove(1);

      expect(removed?.text, 'one');
      expect((await entries.all()).map((e) => e.id), [2]);
    });

    test(
      'removeWhere counts, and writes nothing when nothing matches',
      () async {
        final store = InMemoryLocalStore();
        final entries = _entries(store);
        await entries.add('a');
        await entries.add('b');
        await entries.update(1, done: true);
        final writes = store.writes;

        expect(await entries.removeWhere((e) => e.text == 'zzz'), 0);
        expect(store.writes, writes);
        expect(await entries.removeWhere((e) => e.done), 1);
        expect((await entries.all()).map((e) => e.text), ['b']);
      },
    );

    test('all returns a list that cannot be changed', () async {
      final entries = _entries(InMemoryLocalStore());
      await entries.add('one');

      final list = await entries.all();

      expect(() => list.clear(), throwsUnsupportedError);
    });
  });

  group('persistence', () {
    test('entries survive a new instance on the same store', () async {
      final store = InMemoryLocalStore();
      await _entries(store).add('one');

      final again = _entries(store);
      final next = await again.add('two');

      expect((await again.all()).map((e) => e.text), ['one', 'two']);
      expect(next.id, 2);
    });

    test('a different key is a separate list with its own numbering', () async {
      final store = InMemoryLocalStore();
      final notes = _entries(store);
      final todos = _entries(store, key: 'todos');

      await notes.add('note');
      final todo = await todos.add('todo');

      expect(todo.id, 1);
      expect(await notes.all(), hasLength(1));
      expect((await todos.all()).single.text, 'todo');
    });

    test('times survive a restart', () async {
      final store = InMemoryLocalStore();
      final clock = _Clock();
      await _entries(store, clock: clock).add('one');

      final loaded = (await _entries(store).all()).single;

      expect(loaded.createdAt.toUtc(), clock.now);
    });
  });

  group('concurrent calls', () {
    test('quick adds that are not awaited all land with unique ids', () async {
      final entries = _entries(InMemoryLocalStore());

      final added = await Future.wait([
        for (var i = 0; i < 20; i++) entries.add('entry $i'),
      ]);

      expect(added.map((e) => e.id).toSet(), hasLength(20));
      final stored = await entries.all();
      expect(stored, hasLength(20));
      expect(stored.map((e) => e.id), [for (var i = 1; i <= 20; i++) i]);
    });

    test('mixed changes are applied in call order', () async {
      final entries = _entries(InMemoryLocalStore());

      await Future.wait([
        entries.add('a'),
        entries.add('b'),
        entries.remove(1),
        entries.update(2, text: 'B'),
        entries.add('c'),
      ]);

      expect((await entries.all()).map((e) => '${e.id}:${e.text}'), [
        '2:B',
        '3:c',
      ]);
    });
  });

  group('bad stored data', () {
    Future<void> expectUnexpected(Object stored) async {
      final store = InMemoryLocalStore();
      await store.write(_key, stored);
      final entries = _entries(store);
      final writes = store.writes;

      await expectLater(entries.all(), throwsA(isA<LocalStoreException>()));
      await expectLater(entries.add('x'), throwsA(isA<LocalStoreException>()));
      expect(
        store.writes,
        writes,
        reason: 'must not overwrite what it cannot read',
      );
    }

    test('a value that is not an object is refused, not overwritten', () async {
      await expectUnexpected('oops');
      await expectUnexpected([1, 2]);
    });

    test('an object without the expected fields is refused', () async {
      await expectUnexpected({'items': []});
      await expectUnexpected({'nextId': 1});
      await expectUnexpected({'nextId': 'x', 'items': []});
    });

    test('an entry with missing or mistyped fields is refused', () async {
      await expectUnexpected({
        'nextId': 2,
        'items': [
          {'id': 1},
        ],
      });
      await expectUnexpected({
        'nextId': 2,
        'items': ['not an object'],
      });
    });

    test('a damaged counter can never hand out an id in use', () async {
      final store = InMemoryLocalStore();
      await store.write(_key, {
        'nextId': 1,
        'items': [
          {
            'id': 5,
            'text': 'kept',
            'done': false,
            'created': '2026-09-25T12:00:00.000Z',
            'updated': '2026-09-25T12:00:00.000Z',
          },
        ],
      });

      final added = await _entries(store).add('new');

      expect(added.id, 6);
    });
  });

  group('storage failures', () {
    test(
      'a failing store throws, changes nothing, and the queue recovers',
      () async {
        final store = InMemoryLocalStore();
        final entries = _entries(store);
        await entries.add('one');

        store.failure = const LocalStoreException('disk full');
        await expectLater(
          entries.add('two'),
          throwsA(isA<LocalStoreException>()),
        );
        await expectLater(entries.all(), throwsA(isA<LocalStoreException>()));

        store.failure = null;
        final next = await entries.add('three');

        expect(next.id, 2, reason: 'the failed add never took id 2');
        expect((await entries.all()).map((e) => e.text), ['one', 'three']);
      },
    );
  });

  group('Entry', () {
    Entry entry() => Entry(
      id: 3,
      text: 'buy milk',
      done: true,
      createdAt: DateTime.utc(2026, 9, 25, 12),
      updatedAt: DateTime.utc(2026, 9, 26, 8, 30),
    );

    test('survives a JSON round trip', () {
      final back = Entry.fromJson(entry().toJson());

      expect(back.id, 3);
      expect(back.text, 'buy milk');
      expect(back.done, isTrue);
      expect(back.createdAt, entry().createdAt);
      expect(back.updatedAt, entry().updatedAt);
    });

    test('done defaults to false when absent', () {
      final json = entry().toJson()..remove('done');

      expect(Entry.fromJson(json).done, isFalse);
    });

    test('rejects shapes it cannot read', () {
      expect(() => Entry.fromJson('x'), throwsFormatException);
      expect(() => Entry.fromJson({'id': 1}), throwsFormatException);
      expect(
        () => Entry.fromJson({...entry().toJson(), 'created': 'yesterday'}),
        throwsFormatException,
      );
    });
  });
}
