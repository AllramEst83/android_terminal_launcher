import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';

/// The app list is cached; this re-queries it so newly installed or removed
/// apps show up in `list` and `open`.
final refreshCommand = Command(
  name: 'refresh',
  description: 'Reload the installed app list',
  usage: 'refresh',
  run: (context) async {
    final apps = await context.apps.listApps(refresh: true);
    return CommandOutput([Messages.refreshed(apps.length)]);
  },
);
