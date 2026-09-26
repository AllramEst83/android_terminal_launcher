import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/resolve_app.dart';

/// Android never lets an app remove another silently: this opens the system's
/// own confirmation dialog, which is the user's chance to back out.
final uninstallCommand = Command(
  name: 'uninstall',
  description: 'Uninstall an app',
  usage: 'uninstall <app>',
  examples: ['uninstall calculator'],
  notes: ['Android asks you to confirm;', 'run refresh afterwards'],
  run: _uninstall,
  argSuggestions: suggestAppLabels,
);

Future<CommandResult> _uninstall(CommandContext context) async {
  final resolution = await resolveApp(
    context,
    usageMessage: Messages.uninstallUsage,
  );
  switch (resolution) {
    case UnresolvedApp(:final failure):
      return failure;
    case ResolvedApp(:final app):
      final started = await context.apps.uninstall(app.packageName);
      if (!started) {
        return CommandFailure.single(Messages.uninstallFailed(app.label));
      }
      return CommandOutput([Messages.uninstallStarted(app.label)]);
  }
}
