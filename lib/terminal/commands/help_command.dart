import 'dart:math' as math;

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';

/// Generated from the registry, so it can never drift from what exists.
final helpCommand = Command(
  name: 'help',
  description: 'Show available commands',
  usage: 'help',
  run: (context) async {
    final commands = context.commands;
    final width = commands.map((c) => c.usage.length).fold(0, math.max);
    return CommandOutput([
      Messages.helpHeader,
      for (final command in commands)
        '  ${command.usage.padRight(width)}  ${_describe(command)}',
    ]);
  },
);

String _describe(Command command) {
  if (command.aliases.isEmpty) return command.description;
  return '${command.description} (aliases: ${command.aliases.join(', ')})';
}
