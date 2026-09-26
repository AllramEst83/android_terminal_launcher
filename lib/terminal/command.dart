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
    this.groups = const [],
    this.now = systemNow,
  });

  final List<String> args;
  final AppRepository apps;
  final List<Command> commands;

  /// [commands] by provider, for `help`. Empty when nothing was grouped.
  final List<CommandGroup> groups;
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
    this.forms = const [],
    this.examples = const [],
    this.notes = const [],
    this.argSuggestions,
    this.spinner = false,
  });

  final String name;
  final List<String> aliases;
  final String description;

  /// One compact line, e.g. `open <app>`. Also tells the suggester whether the
  /// command takes arguments (a space in it), so keep the name first.
  final String usage;
  final CommandRunner run;

  /// Every way to call it, one per line, for `help <command>`. Defaults to
  /// just [usage].
  final List<String> forms;

  /// Complete example lines to try, for `help <command>`.
  final List<String> examples;

  /// Extra lines for `help <command>`, printed as written.
  final List<String> notes;

  List<String> get usageForms => forms.isEmpty ? [usage] : forms;

  /// Null when the command has nothing useful to suggest for its arguments.
  final ArgSuggester? argSuggestions;

  /// Set for a command that waits on the network or a slow service, so the
  /// log shows a spinner while it runs (after a short delay, so a quick answer
  /// never flashes one). Leave it off for anything that answers at once.
  final bool spinner;
}

/// Commands that belong together (one provider's), in the provider's order.
class CommandGroup {
  const CommandGroup(this.name, this.commands);

  final String name;
  final List<Command> commands;
}
