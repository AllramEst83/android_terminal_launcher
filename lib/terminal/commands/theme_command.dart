import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/services/theme_settings.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';

/// `theme` lists the themes (the current one starred), `theme <name>` switches.
Command themeCommand(ThemeSettings settings) => Command(
  name: 'theme',
  description: 'Show or change the colour theme',
  usage: 'theme [name]',
  run: (context) => _theme(settings, context.args),
  argSuggestions: (partial, apps) => [
    for (final value in ['list', ...ThemeChoice.values.map((c) => c.name)])
      if (value.startsWith(partial.toLowerCase())) value,
  ],
);

Future<CommandResult> _theme(ThemeSettings settings, List<String> args) async {
  if (args.isEmpty ||
      (args.length == 1 && args.first.toLowerCase() == 'list')) {
    return CommandOutput(_listing(settings.current));
  }
  if (args.length != 1) return const CommandFailure([Messages.themeUsage]);

  final choice = ThemeChoice.parse(args.first);
  if (choice == null) {
    return CommandFailure.single(
      Messages.unknownTheme(
        args.first,
        ThemeChoice.values.map((c) => c.name).toList(),
      ),
    );
  }
  try {
    await settings.select(choice);
  } on LocalStoreException catch (error) {
    // The theme did change, so say so, and say it won't survive a restart.
    return CommandOutput([
      Messages.themeChanged(choice.name),
      Messages.themeNotSaved(error.message),
    ]);
  }
  return CommandOutput([Messages.themeChanged(choice.name)]);
}

List<String> _listing(ThemeChoice current) {
  final width = ThemeChoice.values.map((c) => c.name.length).reduce(_max);
  return [
    Messages.themeHeader,
    for (final choice in ThemeChoice.values)
      '${choice == current ? '*' : ' '} ${choice.name.padRight(width)}  '
          '${choice.description}',
  ];
}

int _max(int a, int b) => a > b ? a : b;
