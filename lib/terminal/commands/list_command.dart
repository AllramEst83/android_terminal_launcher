import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';

final listCommand = Command(
  name: 'list',
  description: 'List installed apps',
  usage: 'list',
  run: (context) async {
    final apps = await context.apps.listApps();
    if (apps.isEmpty) return const CommandOutput([Messages.noApps]);
    return CommandOutput([for (final app in apps) app.label]);
  },
);
