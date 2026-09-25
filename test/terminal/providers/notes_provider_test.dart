import 'package:android_terminal_launcher/services/entry_store.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/providers/notes_provider.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/in_memory_local_store.dart';

TerminalSession _session(InMemoryLocalStore store) {
  final session = TerminalSession(
    registry: CommandRegistry.fromProviders([
      ...defaultProviders,
      NotesProvider(
        notes: EntryStore(store: store, key: 'notes'),
        todos: EntryStore(store: store, key: 'todos'),
      ),
    ]),
    apps: FakeAppRepository(),
  );
  addTearDown(session.dispose);
  return session;
}

void main() {
  test('registers note and todo without clashing with the built-ins', () {
    final store = InMemoryLocalStore();

    final registry = CommandRegistry.fromProviders([
      ...defaultProviders,
      NotesProvider(
        notes: EntryStore(store: store, key: 'notes'),
        todos: EntryStore(store: store, key: 'todos'),
      ),
    ]);

    expect(registry.lookup('note'), isNotNull);
    expect(registry.lookup('todo'), isNotNull);
  });

  test('typing a quoted note through the session saves and lists it', () async {
    final session = _session(InMemoryLocalStore());

    await session.submit('note add "buy milk and eggs"');
    await session.submit('note');

    expect(session.lines.map((l) => l.text), [
      r'$ note add "buy milk and eggs"',
      'added note 1',
      r'$ note',
      '1  buy milk and eggs',
    ]);
  });

  test('an unclosed quote never reaches the store', () async {
    final store = InMemoryLocalStore();
    final session = _session(store);

    await session.submit('note add "oops');

    expect(store.writes, 0);
    expect(session.lines.last.text, 'unterminated quote');
  });

  test('notes outlive the session that wrote them', () async {
    final store = InMemoryLocalStore();
    await _session(store).submit('todo add water plants');

    final later = _session(store);
    await later.submit('todo');

    expect(later.lines.last.text, '[ ] 1  water plants');
  });

  test('several commands typed back to back are all kept', () async {
    final session = _session(InMemoryLocalStore());

    // The UI does not await submit, so these overlap.
    await Future.wait([
      for (var i = 1; i <= 10; i++) session.submit('note add item$i'),
    ]);
    await session.submit('note');

    final listed = session.lines
        .map((l) => l.text)
        .where((t) => RegExp(r'^\s*\d+  item').hasMatch(t))
        .toList();
    expect(listed, hasLength(10));
  });
}
