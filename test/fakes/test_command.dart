import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';

Command testCommand(
  String name, {
  List<String> aliases = const [],
  String description = 'a test command',
  String? usage,
  ArgSuggester? argSuggestions,
}) {
  return Command(
    name: name,
    aliases: aliases,
    description: description,
    usage: usage ?? name,
    run: (context) async => const CommandOutput(['ok']),
    argSuggestions: argSuggestions,
  );
}
