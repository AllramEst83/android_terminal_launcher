import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/suggestion.dart';

/// Turns the text typed so far into completions. While the first word is being
/// typed it offers command names and aliases; after that it asks the command
/// itself (`Command.argSuggestions`), so no command is special-cased here.
class Suggester {
  const Suggester({this.maxSuggestions = 8});

  final int maxSuggestions;

  List<Suggestion> suggest(
    String input, {
    required List<Command> commands,
    required List<AppInfo> apps,
  }) {
    final line = input.trimLeft();
    if (line.isEmpty) return const [];

    final split = line.indexOf(RegExp(r'\s'));
    final found = split == -1
        ? _commandNames(line, commands)
        : _arguments(line, split, commands, apps);
    // A suggestion identical to what is already typed would only be noise.
    return found
        .where((s) => s.completion != line)
        .take(maxSuggestions)
        .toList();
  }

  Iterable<Suggestion> _commandNames(
    String word,
    List<Command> commands,
  ) sync* {
    final needle = word.toLowerCase();
    for (final command in commands) {
      for (final key in [command.name, ...command.aliases]) {
        if (!key.toLowerCase().startsWith(needle)) continue;
        // A usage with more than the bare name means it takes arguments, so
        // leave a space ready for them.
        final takesArgs = command.usage.contains(' ');
        yield Suggestion(label: key, completion: takesArgs ? '$key ' : key);
      }
    }
  }

  Iterable<Suggestion> _arguments(
    String line,
    int split,
    List<Command> commands,
    List<AppInfo> apps,
  ) {
    final word = line.substring(0, split);
    final partial = line.substring(split).trimLeft();
    final suggestArgs = _find(commands, word)?.argSuggestions;
    if (suggestArgs == null) return const [];
    return [
      for (final value in suggestArgs(partial, apps))
        Suggestion(label: value, completion: '$word $value'),
    ];
  }

  Command? _find(List<Command> commands, String word) {
    final needle = word.toLowerCase();
    for (final command in commands) {
      if ([
        command.name,
        ...command.aliases,
      ].any((key) => key.toLowerCase() == needle)) {
        return command;
      }
    }
    return null;
  }
}
