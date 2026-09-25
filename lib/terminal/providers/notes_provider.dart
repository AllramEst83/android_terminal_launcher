import 'package:android_terminal_launcher/services/entry_store.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/entry_commands.dart';

/// Notes and todos. Each has its own store (its own storage key), so `note`
/// and `todo` numbering never mix. Built in `main.dart` with the real stores.
class NotesProvider implements CommandProvider {
  NotesProvider({required this._notes, required this._todos});

  final EntryStore _notes;
  final EntryStore _todos;

  @override
  String get name => 'notes';

  @override
  List<Command> get commands => [noteCommand(_notes), todoCommand(_todos)];
}
