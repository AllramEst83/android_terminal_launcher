import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/terminal/app_matcher.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/tools/app_blocks.dart';

/// Outcome of turning a command's arguments into exactly one installed app.
sealed class AppResolution {
  const AppResolution();
}

final class ResolvedApp extends AppResolution {
  const ResolvedApp(this.app);

  final AppInfo app;
}

/// Nothing usable was typed, or it matched no app or several: [failure] is
/// what to print. Several matches are listed, never guessed between.
final class UnresolvedApp extends AppResolution {
  const UnresolvedApp(this.failure);

  final CommandFailure failure;
}

/// Shared by every command that acts on one app (`open`, `uninstall`), so they
/// all match names the same way. Args are joined with spaces so
/// `open google chrome` works before quoting exists.
///
/// Several matches are also offered as a picker in the rich view: a tap on one
/// runs `<pickCommand> "<name>"`, or with [fillPick] puts it in the prompt to be
/// looked at first (for `uninstall`).
Future<AppResolution> resolveApp(
  CommandContext context, {
  required String usageMessage,
  required String pickCommand,
  bool fillPick = false,
}) async {
  final query = context.args.join(' ');
  if (query.isEmpty) return UnresolvedApp(CommandFailure([usageMessage]));

  final matches = matchApps(await context.apps.listApps(), query);
  if (matches.isEmpty) {
    return UnresolvedApp(CommandFailure.single(Messages.noAppFound(query)));
  }
  if (matches.length > 1) {
    return UnresolvedApp(
      CommandFailure(
        [
          Messages.ambiguousApp(query),
          for (final app in matches) '  ${app.label}',
        ],
        block: appPicker(query, matches, command: pickCommand, fill: fillPick),
      ),
    );
  }
  return ResolvedApp(matches.single);
}

/// Argument suggestions for app-taking commands: best matches first.
List<String> suggestAppLabels(String partialArgs, List<AppInfo> apps) {
  // Labels can repeat across packages; offering one is enough.
  return {for (final app in rankApps(apps, partialArgs)) app.label}.toList();
}
