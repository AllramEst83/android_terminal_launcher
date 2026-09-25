import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/app_repository.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';

typedef CommandRunner = Future<CommandResult> Function(CommandContext context);

/// The wall clock. A named top-level function so it can be a const default.
DateTime systemNow() => DateTime.now();

/// Everything a command may read. [commands] is here so `help` can be
/// generated from the registry without depending on it. [now] is injectable so
/// time-based commands stay deterministic in tests.
class CommandContext {
  const CommandContext({
    required this.args,
    required this.apps,
    required this.commands,
    this.now = systemNow,
  });

  final List<String> args;
  final AppRepository apps;
  final List<Command> commands;
  final DateTime Function() now;
}

/// Suggests completions for what has been typed after the command word.
/// [partialArgs] is the raw remainder of the line (possibly empty); the result
/// is the values to offer, best first.
typedef ArgSuggester = List<String> Function(
  String partialArgs,
  List<AppInfo> apps,
);

/// A command is data plus a function; `help` is built from these fields.
class Command {
  const Command({
    required this.name,
    required this.description,
    required this.usage,
    required this.run,
    this.aliases = const [],
    this.argSuggestions,
  });

  final String name;
  final List<String> aliases;
  final String description;
  final String usage;
  final CommandRunner run;

  /// Null when the command has nothing useful to suggest for its arguments.
  final ArgSuggester? argSuggestions;
}
