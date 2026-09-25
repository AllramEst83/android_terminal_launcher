import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/entry_store.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/entry_commands.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/in_memory_local_store.dart';

final _created = DateTime.utc(2026, 9, 25, 10, 5);

/// Both commands over one fake store, so tests can also break the store.
class _Rig {
  _Rig() : store = InMemoryLocalStore() {
    now = _created;
    notes = EntryStore(store: store, key: 'notes', now: () => now);
    todos = EntryStore(store: store, key: 'todos', now: () => now);
    note = noteCommand(notes);
    todo = todoCommand(todos);
  }

  final InMemoryLocalStore store;
  late DateTime now;
  late final EntryStore notes;
  late final EntryStore todos;
  late final Command note;
  late final Command todo;

  Future<CommandResult> _run(Command command, List<String> args) {
    return command.run(
      CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
    );
  }

  Future<CommandResult> runNote(List<String> args) => _run(note, args);
  Future<CommandResult> runTodo(List<String> args) => _run(todo, args);
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() => fail('unexpected clear'),
};

/// What the command prints for a local time, computed the way a phone would.
String _stamp(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

void main() {
  group('note', () {
    late _Rig rig;
    setUp(() => rig = _Rig());

    test('an empty list says how to start', () async {
      final result = await rig.runNote([]);

      expect(_lines(result), [Messages.noEntries('notes', 'note')]);
      expect(result, isA<CommandOutput>());
    });

    test('add saves the text and reports its id', () async {
      final result = await rig.runNote(['add', 'buy', 'milk']);

      expect(_lines(result), [Messages.entryAdded('note', 1)]);
      expect((await rig.notes.all()).single.text, 'buy milk');
    });

    test('add keeps a quoted text exactly, spaces and all', () async {
      await rig.runNote(['add', 'two  spaces  kept']);

      expect((await rig.notes.all()).single.text, 'two  spaces  kept');
    });

    test('list shows every note with its id', () async {
      await rig.runNote(['add', 'first']);
      await rig.runNote(['add', 'second']);

      expect(_lines(await rig.runNote(['list'])), ['1  first', '2  second']);
      expect(_lines(await rig.runNote([])), ['1  first', '2  second']);
      expect(_lines(await rig.runNote(['ls'])), ['1  first', '2  second']);
    });

    test('ids are right-aligned once they reach two digits', () async {
      for (var i = 1; i <= 10; i++) {
        await rig.runNote(['add', 'n$i']);
      }

      final lines = _lines(await rig.runNote(['list']));

      expect(lines.first, ' 1  n1');
      expect(lines.last, '10  n10');
    });

    test('subcommands are case-insensitive', () async {
      await rig.runNote(['ADD', 'hello']);

      expect(_lines(await rig.runNote(['LIST'])), ['1  hello']);
    });

    test('show prints the text and when it was created', () async {
      await rig.runNote(['add', 'remember this']);

      final lines = _lines(await rig.runNote(['show', '1']));

      expect(lines.first, 'remember this');
      expect(lines.last, '  #1 · created ${_stamp(_created)}');
    });

    test('show mentions an edit', () async {
      await rig.runNote(['add', 'draft']);
      rig.now = _created.add(const Duration(days: 1));
      await rig.runNote(['edit', '1', 'final']);

      final lines = _lines(await rig.runNote(['show', '1']));

      expect(lines.first, 'final');
      expect(lines.last, contains('edited ${_stamp(rig.now)}'));
    });

    test('edit replaces the text', () async {
      await rig.runNote(['add', 'old']);

      final result = await rig.runNote(['edit', '1', 'new', 'text']);

      expect(_lines(result), [Messages.entryUpdated('note', 1)]);
      expect((await rig.notes.find(1))?.text, 'new text');
    });

    test('rm removes the note and says what it was', () async {
      await rig.runNote(['add', 'gone soon']);
      await rig.runNote(['add', 'stays']);

      final result = await rig.runNote(['rm', '1']);

      expect(_lines(result), [Messages.entryRemoved('note', 1, 'gone soon')]);
      expect(_lines(await rig.runNote(['list'])), ['2  stays']);
    });

    test('rm has aliases', () async {
      for (final alias in ['remove', 'delete', 'del']) {
        await rig.runNote(['add', 'x']);
        final id = (await rig.notes.all()).last.id;

        final result = await rig.runNote([alias, '$id']);

        expect(result, isA<CommandOutput>(), reason: alias);
      }
      expect(await rig.notes.all(), isEmpty);
    });

    test('find matches text case-insensitively', () async {
      await rig.runNote(['add', 'Buy MILK']);
      await rig.runNote(['add', 'call mom']);

      expect(_lines(await rig.runNote(['find', 'milk'])), ['1  Buy MILK']);
      expect(_lines(await rig.runNote(['search', 'CALL'])), ['2  call mom']);
    });

    test('find with no match is a failure', () async {
      await rig.runNote(['add', 'something']);

      final result = await rig.runNote(['find', 'zzz']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.entryNoMatches('notes', 'zzz')]);
    });

    test('an id that is not a positive number is named', () async {
      for (final bad in ['x', '0', '-1', '1.5']) {
        final result = await rig.runNote(['show', bad]);

        expect(result, isA<CommandFailure>(), reason: bad);
        expect(_lines(result), [Messages.entryBadId(bad)], reason: bad);
      }
    });

    test(
      'an id that does not exist is reported for show, edit and rm',
      () async {
        for (final args in [
          ['show', '9'],
          ['edit', '9', 'text'],
          ['rm', '9'],
        ]) {
          final result = await rig.runNote(args);

          expect(result, isA<CommandFailure>(), reason: '$args');
          expect(_lines(result), [Messages.entryMissing('note', 9)]);
        }
      },
    );

    test('wrong arguments print the usage', () async {
      final usage = Messages.entryUsage('note', [
        'add <text>',
        'list',
        'show <id>',
        'edit <id> <text>',
        'rm <id>',
        'find <text>',
      ]);
      for (final args in [
        ['add'],
        ['add', '   '],
        ['show'],
        ['show', '1', '2'],
        ['edit', '1'],
        ['rm'],
        ['find'],
        ['list', 'extra'],
        ['bogus'],
      ]) {
        final result = await rig.runNote(args);

        expect(result, isA<CommandFailure>(), reason: '$args');
        expect(_lines(result), usage, reason: '$args');
      }
    });

    test('todo-only subcommands are not available on note', () async {
      for (final sub in ['done', 'undo', 'clear']) {
        expect(await rig.runNote([sub, '1']), isA<CommandFailure>());
      }
    });

    test('a storage failure is reported with the command name', () async {
      rig.store.failure = const LocalStoreException('disk full');

      final result = await rig.runNote(['add', 'x']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        Messages.entryStorageFailed('note', 'disk full'),
      ]);
    });

    test('unreadable stored notes are reported and left alone', () async {
      await rig.store.write('notes', 'garbage');
      final writes = rig.store.writes;

      final result = await rig.runNote(['add', 'x']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result).single, contains("'notes' holds unexpected data"));
      expect(rig.store.writes, writes);
    });
  });

  group('todo', () {
    late _Rig rig;
    setUp(() => rig = _Rig());

    test('an empty list says how to start', () async {
      expect(_lines(await rig.runTodo([])), [
        Messages.noEntries('todos', 'todo'),
      ]);
    });

    test('list shows a box for each todo', () async {
      await rig.runTodo(['add', 'wash car']);
      await rig.runTodo(['add', 'call mom']);
      await rig.runTodo(['done', '2']);

      expect(_lines(await rig.runTodo(['list'])), [
        '[ ] 1  wash car',
        '[x] 2  call mom',
      ]);
    });

    test('done and undo tick a todo on and off', () async {
      await rig.runTodo(['add', 'task']);

      expect(_lines(await rig.runTodo(['done', '1'])), [
        Messages.todoMarked(1, done: true),
      ]);
      expect((await rig.todos.find(1))?.done, isTrue);

      expect(_lines(await rig.runTodo(['undo', '1'])), [
        Messages.todoMarked(1, done: false),
      ]);
      expect((await rig.todos.find(1))?.done, isFalse);
    });

    test('done twice is harmless', () async {
      await rig.runTodo(['add', 'task']);
      await rig.runTodo(['done', '1']);

      final result = await rig.runTodo(['done', '1']);

      expect(result, isA<CommandOutput>());
      expect((await rig.todos.find(1))?.done, isTrue);
    });

    test('done on a missing id is reported', () async {
      final result = await rig.runTodo(['done', '4']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.entryMissing('todo', 4)]);
    });

    test('clear removes finished todos only and counts them', () async {
      await rig.runTodo(['add', 'a']);
      await rig.runTodo(['add', 'b']);
      await rig.runTodo(['add', 'c']);
      await rig.runTodo(['done', '1']);
      await rig.runTodo(['done', '3']);

      expect(_lines(await rig.runTodo(['clear'])), [Messages.todosCleared(2)]);
      expect(_lines(await rig.runTodo(['list'])), ['[ ] 2  b']);
    });

    test('clear with nothing finished says so', () async {
      await rig.runTodo(['add', 'a']);

      expect(_lines(await rig.runTodo(['clear'])), [Messages.todosCleared(0)]);
      expect(await rig.todos.all(), hasLength(1));
    });

    test('show says whether it is open or done, without counting the tick as an edit', () async {
      await rig.runTodo(['add', 'task']);
      expect(_lines(await rig.runTodo(['show', '1'])).last, contains('open'));

      rig.now = _created.add(const Duration(days: 2));
      await rig.runTodo(['done', '1']);
      final meta = _lines(await rig.runTodo(['show', '1'])).last;

      expect(meta, contains('done'));
      expect(meta, isNot(contains('edited')));
    });

    test('editing keeps the todo ticked', () async {
      await rig.runTodo(['add', 'task']);
      await rig.runTodo(['done', '1']);

      await rig.runTodo(['edit', '1', 'renamed']);

      final entry = await rig.todos.find(1);
      expect(entry?.text, 'renamed');
      expect(entry?.done, isTrue);
    });

    test('rm and find work like they do for notes', () async {
      await rig.runTodo(['add', 'Water plants']);
      await rig.runTodo(['add', 'pay rent']);

      expect(_lines(await rig.runTodo(['find', 'PLANTS'])), [
        '[ ] 1  Water plants',
      ]);
      expect(_lines(await rig.runTodo(['rm', '2'])), [
        Messages.entryRemoved('todo', 2, 'pay rent'),
      ]);
    });

    test('notes and todos are numbered separately', () async {
      await rig.runNote(['add', 'a note']);
      await rig.runTodo(['add', 'a todo']);

      expect((await rig.notes.all()).single.id, 1);
      expect((await rig.todos.all()).single.id, 1);
      expect(_lines(await rig.runTodo(['list'])), ['[ ] 1  a todo']);
    });

    test(
      'wrong arguments print a usage that includes the todo forms',
      () async {
        final result = await rig.runTodo(['done']);

        expect(result, isA<CommandFailure>());
        expect(_lines(result).join('\n'), contains('todo done <id>'));
        expect(_lines(result).join('\n'), contains('todo clear'));
      },
    );
  });

  group('as commands', () {
    final rig = _Rig();

    test('usage lines name every subcommand, for help', () {
      expect(rig.note.usage, 'note <add|list|show|edit|rm|find>');
      expect(
        rig.todo.usage,
        'todo <add|list|done|undo|show|edit|rm|find|clear>',
      );
    });

    test('names and aliases do not collide', () {
      expect(rig.note.name, 'note');
      expect(rig.todo.name, 'todo');
    });

    test('suggests subcommands, with a space where text or an id follows', () {
      final suggest = rig.note.argSuggestions!;

      expect(suggest('', const []), [
        'add ',
        'list',
        'show ',
        'edit ',
        'rm ',
        'find ',
      ]);
      expect(suggest('s', const []), ['show ']);
      expect(suggest('L', const []), ['list']);
    });

    test('offers nothing once past the subcommand', () {
      expect(rig.note.argSuggestions!('add buy', const []), isEmpty);
      expect(rig.todo.argSuggestions!('done ', const []), isEmpty);
    });

    test('todo suggests its extra subcommands', () {
      final all = rig.todo.argSuggestions!('', const []);

      expect(all, containsAll(['done ', 'undo ', 'clear']));
    });
  });
}
