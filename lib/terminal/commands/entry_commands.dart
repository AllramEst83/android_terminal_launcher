import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/entry.dart';
import 'package:android_terminal_launcher/services/entry_store.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/tools/entry_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';

/// `note` and `todo` are the same numbered list with different words. This
/// file holds both; [_Kind] carries the differences.
Command noteCommand(EntryStore store) => _entryCommand(_Kind.note, store);

Command todoCommand(EntryStore store) => _entryCommand(_Kind.todo, store);

enum _Kind {
  note(
    name: 'note',
    plural: 'notes',
    description: 'Keep numbered notes',
    forms: [
      'add <text>',
      'list',
      'show <id>',
      'edit <id> <text>',
      'rm <id>',
      'find <text>',
    ],
    examples: ['note add "buy milk"', 'note show 1', 'note rm 1'],
  ),
  todo(
    name: 'todo',
    plural: 'todos',
    description: 'Keep a todo list',
    forms: [
      'add <text>',
      'list',
      'done <id>',
      'undo <id>',
      'show <id>',
      'edit <id> <text>',
      'rm <id>',
      'find <text>',
      'clear',
    ],
    examples: ['todo add "call mom"', 'todo done 1', 'todo clear'],
  );

  const _Kind({
    required this.name,
    required this.plural,
    required this.description,
    required this.forms,
    required this.examples,
  });

  final String name;
  final String plural;
  final String description;
  final List<String> forms;
  final List<String> examples;

  bool get isTodo => this == todo;

  /// `add <text>` becomes `add `, `list` stays `list`: what to offer while the
  /// subcommand is being typed.
  List<String> get subcommands => [
    for (final form in forms)
      form.contains(' ') ? '${form.split(' ').first} ' : form,
  ];
}

Command _entryCommand(_Kind kind, EntryStore store) => Command(
  name: kind.name,
  description: kind.description,
  usage:
      '${kind.name} <${kind.forms.map((f) => f.split(' ').first).join('|')}>',
  forms: [for (final form in kind.forms) '${kind.name} $form'],
  examples: kind.examples,
  notes: const ['quote text that has spaces'],
  run: (context) => _run(kind, store, context.args),
  // What is written in a note or a todo is the user's own, not for chips.
  history: HistoryPolicy.name,
  argSuggestions: (partial, apps) => [
    // Only the subcommand word; ids and text are the user's to type.
    if (!partial.contains(' '))
      for (final sub in kind.subcommands)
        if (sub.startsWith(partial.toLowerCase())) sub,
  ],
);

Future<CommandResult> _run(
  _Kind kind,
  EntryStore store,
  List<String> args,
) async {
  final sub = args.isEmpty ? 'list' : args.first.toLowerCase();
  final rest = args.isEmpty ? const <String>[] : args.sublist(1);
  CommandFailure usage() =>
      CommandFailure(Messages.entryUsage(kind.name, kind.forms));

  try {
    switch (sub) {
      case 'list' || 'ls':
        return rest.isEmpty ? await _list(kind, store) : usage();
      case 'add':
        final text = rest.join(' ').trim();
        return text.isEmpty ? usage() : await _add(kind, store, text);
      case 'show':
        return rest.length == 1
            ? await _show(kind, store, rest.first)
            : usage();
      case 'edit':
        final text = rest.skip(1).join(' ').trim();
        return rest.length < 2 || text.isEmpty
            ? usage()
            : await _edit(kind, store, rest.first, text);
      case 'rm' || 'remove' || 'delete' || 'del':
        return rest.length == 1
            ? await _remove(kind, store, rest.first)
            : usage();
      case 'find' || 'search':
        final query = rest.join(' ').trim();
        return query.isEmpty ? usage() : await _find(kind, store, query);
      case 'done' when kind.isTodo:
        return rest.length == 1
            ? await _mark(kind, store, rest.first, done: true)
            : usage();
      case 'undo' when kind.isTodo:
        return rest.length == 1
            ? await _mark(kind, store, rest.first, done: false)
            : usage();
      case 'clear' when kind.isTodo:
        return rest.isEmpty ? await _clear(store) : usage();
      default:
        return usage();
    }
  } on LocalStoreException catch (error) {
    return CommandFailure.single(
      Messages.entryStorageFailed(kind.name, error.message),
    );
  }
}

Future<CommandResult> _list(_Kind kind, EntryStore store) async {
  final entries = await store.all();
  if (entries.isEmpty) {
    return noticeOutput(
      Messages.noEntries(kind.plural, kind.name),
      kind: NoticeKind.info,
    );
  }
  return _listing(kind, entries, _count(kind, entries.length));
}

Future<CommandResult> _add(_Kind kind, EntryStore store, String text) async {
  final entry = await store.add(text);
  return noticeOutput(Messages.entryAdded(kind.name, entry.id));
}

Future<CommandResult> _show(_Kind kind, EntryStore store, String rawId) async {
  final id = _parseId(rawId);
  if (id == null) return _badId(rawId);
  final entry = await store.find(id);
  if (entry == null) return _missing(kind, id);

  final meta = [
    '#${entry.id}',
    if (kind.isTodo) entry.done ? 'done' : 'open',
    'created ${_stamp(entry.createdAt)}',
    if (entry.updatedAt != entry.createdAt) 'edited ${_stamp(entry.updatedAt)}',
  ];
  return CommandOutput(
    [entry.text, '  ${meta.join(' · ')}'],
    block: entryDetailBlock(
      kind: kind.name,
      entry: entry,
      created: _stamp(entry.createdAt),
      edited: entry.updatedAt != entry.createdAt
          ? _stamp(entry.updatedAt)
          : null,
    ),
  );
}

Future<CommandResult> _edit(
  _Kind kind,
  EntryStore store,
  String rawId,
  String text,
) async {
  final id = _parseId(rawId);
  if (id == null) return _badId(rawId);
  final updated = await store.update(id, text: text);
  if (updated == null) return _missing(kind, id);
  return noticeOutput(Messages.entryUpdated(kind.name, id));
}

Future<CommandResult> _remove(
  _Kind kind,
  EntryStore store,
  String rawId,
) async {
  final id = _parseId(rawId);
  if (id == null) return _badId(rawId);
  final removed = await store.remove(id);
  if (removed == null) return _missing(kind, id);
  return noticeOutput(Messages.entryRemoved(kind.name, id, removed.text));
}

Future<CommandResult> _find(_Kind kind, EntryStore store, String query) async {
  final needle = query.toLowerCase();
  final matches = [
    for (final entry in await store.all())
      if (entry.text.toLowerCase().contains(needle)) entry,
  ];
  if (matches.isEmpty) {
    return CommandFailure.single(Messages.entryNoMatches(kind.plural, query));
  }
  return _listing(kind, matches, Messages.entryMatches(matches.length, query));
}

Future<CommandResult> _mark(
  _Kind kind,
  EntryStore store,
  String rawId, {
  required bool done,
}) async {
  final id = _parseId(rawId);
  if (id == null) return _badId(rawId);
  final updated = await store.update(id, done: done);
  if (updated == null) return _missing(kind, id);
  return noticeOutput(Messages.todoMarked(id, done: done));
}

Future<CommandResult> _clear(EntryStore store) async {
  final removed = await store.removeWhere((entry) => entry.done);
  return noticeOutput(Messages.todosCleared(removed));
}

/// `3 notes`, `1 todo`.
String _count(_Kind kind, int count) =>
    '$count ${count == 1 ? kind.name : kind.plural}';

/// The rows as text, and as a card with the same [title].
CommandOutput _listing(_Kind kind, List<Entry> entries, String title) =>
    CommandOutput(
      _rows(kind, entries),
      block: entriesBlock(kind: kind.name, title: title, entries: entries),
    );

/// Ids are right-aligned so text lines up; todos get a `[x]` / `[ ]` box.
List<String> _rows(_Kind kind, List<Entry> entries) {
  final width = entries
      .map((e) => '${e.id}'.length)
      .reduce((a, b) => a > b ? a : b);
  return [
    for (final entry in entries)
      '${kind.isTodo ? '[${entry.done ? 'x' : ' '}] ' : ''}'
          '${'${entry.id}'.padLeft(width)}  ${entry.text}',
  ];
}

/// A positive whole number, or null.
int? _parseId(String text) {
  final id = int.tryParse(text);
  return id != null && id > 0 ? id : null;
}

CommandFailure _badId(String text) =>
    CommandFailure.single(Messages.entryBadId(text));

CommandFailure _missing(_Kind kind, int id) =>
    CommandFailure.single(Messages.entryMissing(kind.name, id));

/// `2026-09-25 16:30`, in the device's local time.
String _stamp(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}
