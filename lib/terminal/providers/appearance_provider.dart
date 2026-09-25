import 'package:android_terminal_launcher/services/theme_settings.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/theme_command.dart';

/// How the launcher looks. Built in `main.dart`, since it needs the live
/// [ThemeSettings] the app listens to.
class AppearanceProvider implements CommandProvider {
  AppearanceProvider(this._settings);

  final ThemeSettings _settings;

  @override
  String get name => 'appearance';

  @override
  List<Command> get commands => [themeCommand(_settings)];
}
