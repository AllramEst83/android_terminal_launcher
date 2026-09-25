import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/commands/clear_command.dart';
import 'package:android_terminal_launcher/terminal/commands/date_command.dart';
import 'package:android_terminal_launcher/terminal/commands/help_command.dart';
import 'package:android_terminal_launcher/terminal/commands/list_command.dart';
import 'package:android_terminal_launcher/terminal/commands/open_command.dart';
import 'package:android_terminal_launcher/terminal/commands/refresh_command.dart';
import 'package:android_terminal_launcher/terminal/commands/uninstall_command.dart';

/// Registered at startup in `main.dart`. A new command is one file plus a line
/// here.
final List<Command> defaultCommands = [
  listCommand,
  openCommand,
  helpCommand,
  clearCommand,
  refreshCommand,
  dateCommand,
  uninstallCommand,
];
