import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/terminal/command_history.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/in_memory_local_store.dart';

class _Rig {
  _Rig({int maxEntries = 100}) {
    history = CommandHistory(
      store: store,
      clock: () => now,
      maxEntries: maxEntries,
    );
  }

  final store = InMemoryLocalStore();
  DateTime now = DateTime(2026, 9, 26, 12);
  late final CommandHistory history;

  void later(Duration by) => now = now.add(by);

  List<String> top([int count = 20]) => [
    for (final e in history.top(count)) e.line,
  ];

  /// A fresh history over the same store, as after a restart.
  Future<CommandHistory> restart() async {
    final again = CommandHistory(store: store, clock: () => now);
    await again.load();
    return again;
  }
}

void main() {
  group('ranking', () {
    test('starts empty', () {
      final rig = _Rig();

      expect(rig.top(), isEmpty);
      expect(rig.history.length, 0);
    });

    test('the more often a line is run the higher it ranks', () async {
      final rig = _Rig();
      await rig.history.record('cal');
      await rig.history.record('weather');
      await rig.history.record('weather');
      await rig.history.record('weather');
      await rig.history.record('mail');
      await rig.history.record('mail');

      expect(rig.top(), ['weather', 'mail', 'cal']);
    });

    test('a tie goes to the one used last', () async {
      final rig = _Rig();
      await rig.history.record('a');
      rig.later(const Duration(minutes: 1));
      await rig.history.record('b');

      expect(rig.top(), ['b', 'a']);
    });

    test('use fades: this week beats a habit from long ago', () async {
      final rig = _Rig();
      for (var i = 0; i < 5; i++) {
        await rig.history.record('old habit');
      }
      rig.later(const Duration(days: 60));
      await rig.history.record('new habit');
      await rig.history.record('new habit');

      expect(rig.top(), ['new habit', 'old habit']);
    });

    test('a score halves every half-life', () async {
      final rig = _Rig();
      await rig.history.record('x');
      await rig.history.record('x');
      final entry = rig.history.top(1).single;
      expect(rig.history.scoreNow(entry), closeTo(2, 1e-9));

      rig.later(const Duration(days: 14));
      expect(rig.history.scoreNow(entry), closeTo(1, 1e-9));
      rig.later(const Duration(days: 14));
      expect(rig.history.scoreNow(entry), closeTo(0.5, 1e-9));
    });

    test('a use after a gap adds one to what is left', () async {
      final rig = _Rig();
      await rig.history.record('x');
      await rig.history.record('x'); // 2
      rig.later(const Duration(days: 14)); // 1
      await rig.history.record('x');

      expect(rig.history.scoreNow(rig.history.top(1).single), closeTo(2, 1e-9));
    });

    test('top gives no more than asked for', () async {
      final rig = _Rig();
      for (final line in ['a', 'b', 'c', 'd']) {
        await rig.history.record(line);
      }

      expect(rig.top(2), hasLength(2));
      expect(rig.top(0), isEmpty);
    });

    test('lines are trimmed, and blank ones ignored', () async {
      final rig = _Rig();
      await rig.history.record('  weather  ');
      await rig.history.record('weather');
      await rig.history.record('   ');
      await rig.history.record('');

      expect(rig.top(), ['weather']);
      expect(rig.history.length, 1);
    });

    test('the lowest scoring go when there are too many', () async {
      final rig = _Rig(maxEntries: 3);
      await rig.history.record('keep');
      await rig.history.record('keep');
      await rig.history.record('keep');
      for (final line in ['a', 'b', 'c']) {
        rig.later(const Duration(minutes: 1));
        await rig.history.record(line);
      }

      expect(rig.history.length, 3);
      expect(rig.top(), containsAll(['keep', 'c']));
      expect(rig.top(), isNot(contains('a')));
    });
  });

  group('matching', () {
    Future<_Rig> filled() async {
      final rig = _Rig();
      for (final line in [
        'weather gothenburg',
        'weather gothenburg',
        'weather malmö',
        'cal week',
        'we',
      ]) {
        await rig.history.record(line);
        rig.later(const Duration(minutes: 1));
      }
      return rig;
    }

    test(
      'gives the lines that carry on from what is typed, best first',
      () async {
        final rig = await filled();

        expect(
          [for (final e in rig.history.matching('we')) e.line],
          ['weather gothenburg', 'weather malmö'],
        );
      },
    );

    test('ignores case and leading space', () async {
      final rig = await filled();

      expect(
        rig.history.matching('  WEATHER G').single.line,
        'weather gothenburg',
      );
    });

    test('leaves out a line that is exactly what is typed', () async {
      final rig = await filled();

      expect([
        for (final e in rig.history.matching('we')) e.line,
      ], isNot(contains('we')));
    });

    test('is limited', () async {
      final rig = await filled();

      expect(rig.history.matching('w', limit: 1), hasLength(1));
    });

    test('is empty for nothing typed', () async {
      final rig = await filled();

      expect(rig.history.matching(''), isEmpty);
      expect(rig.history.matching('   '), isEmpty);
    });
  });

  group('saving', () {
    test('survives a restart, scores and all', () async {
      final rig = _Rig();
      await rig.history.record('weather');
      await rig.history.record('weather');
      await rig.history.record('cal');

      final again = await rig.restart();

      expect([for (final e in again.top(5)) e.line], ['weather', 'cal']);
      expect(again.scoreNow(again.top(1).single), closeTo(2, 1e-9));
    });

    test('writes on every use', () async {
      final rig = _Rig();

      await rig.history.record('a');
      await rig.history.record('b');

      expect(rig.store.writes, 2);
    });

    test('clear forgets it in memory and in the store', () async {
      final rig = _Rig();
      await rig.history.record('a');

      await rig.history.clear();

      expect(rig.top(), isEmpty);
      expect((await rig.restart()).length, 0);
    });

    test('a store that cannot be read is an empty history', () async {
      final rig = _Rig();
      await rig.history.record('a');
      rig.store.failure = const LocalStoreException('disk on fire');

      final again = await rig.restart();

      expect(again.length, 0);
    });

    test('a store that cannot be written is not an error', () async {
      final rig = _Rig();
      rig.store.failure = const LocalStoreException('disk on fire');

      await rig.history.record('a');
      await rig.history.clear();
    });

    test(
      'while it cannot be written the use is still counted for now',
      () async {
        final rig = _Rig();
        rig.store.failure = const LocalStoreException('disk on fire');

        await rig.history.record('a');

        expect(rig.top(), ['a']);
      },
    );

    test('a damaged save is empty; one bad entry loses only itself', () async {
      final rig = _Rig();
      await rig.store.write(CommandHistory.key, 'not a list');
      expect((await rig.restart()).length, 0);

      await rig.store.write(CommandHistory.key, [
        {'l': 'good', 's': 1.0, 'u': 1000},
        {'l': 'no score'},
        {'l': '', 's': 1.0, 'u': 1},
        'junk',
      ]);

      final again = await rig.restart();

      expect([for (final e in again.top(5)) e.line], ['good']);
    });
  });

  group('HistoryEntry', () {
    test('survives a JSON round trip', () {
      final entry = HistoryEntry(
        line: 'weather',
        score: 2.5,
        updated: DateTime.fromMillisecondsSinceEpoch(1234567),
      );

      final back = HistoryEntry.fromJson(entry.toJson());

      expect(back.line, 'weather');
      expect(back.score, 2.5);
      expect(back.updated, entry.updated);
    });

    test('rejects shapes it cannot read', () {
      for (final bad in [
        null,
        7,
        {'l': 1, 's': 1, 'u': 1},
        {'l': 'x', 's': 'a', 'u': 1},
        {'l': 'x', 's': double.nan, 'u': 1},
        {'l': 'x', 's': double.infinity, 'u': 1},
        {'l': 'x', 's': 1, 'u': 'a'},
      ]) {
        expect(() => HistoryEntry.fromJson(bad), throwsFormatException);
      }
    });
  });
}
