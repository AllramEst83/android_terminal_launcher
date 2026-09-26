import 'package:android_terminal_launcher/services/entry.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/quote.dart';

/// [entries] as a list card. [kind] is `note` or `todo`; a todo's rows have a
/// box that ticks it. [title] says what the list is (`3 notes`).
EntriesBlock entriesBlock({
  required String kind,
  required String title,
  required List<Entry> entries,
}) => EntriesBlock(
  title: title,
  todo: kind == 'todo',
  rows: [
    for (final entry in entries)
      EntryRow(
        id: entry.id,
        text: entry.text,
        done: entry.done,
        showCommand: '$kind show ${entry.id}',
        toggleCommand: kind == 'todo'
            ? '$kind ${entry.done ? 'undo' : 'done'} ${entry.id}'
            : null,
      ),
  ],
);

/// One [entry] in full. Ticking a todo runs (it is undone by ticking again);
/// editing fills the prompt with the current text to change, and removing fills
/// it with the command, since neither should happen by a stray tap.
EntryDetailBlock entryDetailBlock({
  required String kind,
  required Entry entry,
  required String created,
  String? edited,
}) => EntryDetailBlock(
  kind: kind,
  id: entry.id,
  text: entry.text,
  created: created,
  edited: edited,
  done: kind == 'todo' ? entry.done : null,
  toggleCommand: kind == 'todo'
      ? '$kind ${entry.done ? 'undo' : 'done'} ${entry.id}'
      : null,
  editCommand: '$kind edit ${entry.id} ${quoteArg(entry.text)}',
  removeCommand: '$kind rm ${entry.id}',
);
