import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_history.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/history_command.dart';

/// The command history. Built in `main.dart` with the same history the session
/// records into.
class HistoryProvider implements CommandProvider {
  HistoryProvider(this.history);

  final CommandHistory history;

  /// Shares the terminal's own help group, next to `help` and `clear`.
  @override
  String get name => 'system';

  @override
  List<Command> get commands => [historyCommand(history)];
}
