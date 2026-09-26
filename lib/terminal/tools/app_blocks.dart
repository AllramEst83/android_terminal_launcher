import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/alphabet.dart';
import 'package:android_terminal_launcher/terminal/tools/quote.dart';

/// Every app as a chip under its initial. A tap opens it (`open "<name>"`),
/// which is harmless; the list is in the order given (alphabetical already).
ChoiceBlock appsChoices(List<AppInfo> apps) {
  final byInitial = <String, List<AppInfo>>{};
  for (final app in apps) {
    byInitial.putIfAbsent(initialOf(app.label), () => []).add(app);
  }
  final initials = byInitial.keys.toList()..sort(compareInitials);
  return ChoiceBlock(
    title: apps.length == 1 ? '1 app' : '${apps.length} apps',
    groups: [
      for (final initial in initials)
        ChoiceGroup(
          title: initial,
          options: [
            for (final app in byInitial[initial]!)
              ChoiceOption(
                label: app.label,
                command: 'open ${quoteArg(app.label)}',
              ),
          ],
        ),
    ],
  );
}

/// The several apps a name matched, to pick one of. [command] is the command
/// that acts on the pick; with [fill] the tap puts it in the prompt instead of
/// running it (for `uninstall`, which should be looked at first).
ChoiceBlock appPicker(
  String query,
  List<AppInfo> matches, {
  required String command,
  required bool fill,
}) => ChoiceBlock(
  title: Messages.ambiguousApp(query),
  groups: [
    ChoiceGroup(
      options: [
        for (final app in matches)
          ChoiceOption(
            label: app.label,
            fill: fill,
            command: '$command ${quoteArg(app.label)}',
          ),
      ],
    ),
  ],
);
