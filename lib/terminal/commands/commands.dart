import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/clear_command.dart';
import 'package:android_terminal_launcher/terminal/commands/date_command.dart';
import 'package:android_terminal_launcher/terminal/commands/help_command.dart';
import 'package:android_terminal_launcher/terminal/commands/list_command.dart';
import 'package:android_terminal_launcher/terminal/commands/open_command.dart';
import 'package:android_terminal_launcher/terminal/commands/refresh_command.dart';
import 'package:android_terminal_launcher/terminal/commands/uninstall_command.dart';

/// The terminal itself: help, clear and the clock. Needs no service of its own.
class SystemProvider implements CommandProvider {
  const SystemProvider();

  @override
  String get name => 'system';

  @override
  List<Command> get commands => [helpCommand, clearCommand, dateCommand];
}

/// Installed apps. These commands reach the app list through
/// `CommandContext.apps`, since suggestions need the same list.
class AppsProvider implements CommandProvider {
  const AppsProvider();

  @override
  String get name => 'apps';

  @override
  List<Command> get commands => [
    listCommand,
    openCommand,
    refreshCommand,
    uninstallCommand,
  ];
}

/// Registered at startup in `main.dart`. A new feature is a provider (its
/// commands in their own files) plus a line here.
const List<CommandProvider> defaultProviders = [
  SystemProvider(),
  AppsProvider(),
];

/// Every command from [defaultProviders], flattened.
final List<Command> defaultCommands = [
  for (final provider in defaultProviders) ...provider.commands,
];
