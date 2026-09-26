import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/resolve_app.dart';

final openCommand = Command(
  name: 'open',
  description: 'Launch an app by name',
  usage: 'open <app>',
  examples: ['open firefox', 'open "google chrome"'],
  notes: ['matches exact, then start,', 'then any part; ties are listed'],
  run: _open,
  argSuggestions: suggestAppLabels,
);

Future<CommandResult> _open(CommandContext context) async {
  final resolution = await resolveApp(
    context,
    usageMessage: Messages.openUsage,
  );
  switch (resolution) {
    case UnresolvedApp(:final failure):
      return failure;
    case ResolvedApp(:final app):
      final launched = await context.apps.launch(app.packageName);
      if (!launched) {
        return CommandFailure.single(Messages.launchFailed(app.label));
      }
      return CommandOutput([Messages.opening(app.label)]);
  }
}
