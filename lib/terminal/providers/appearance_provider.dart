import 'package:android_terminal_launcher/services/font_size_settings.dart';
import 'package:android_terminal_launcher/services/theme_settings.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/font_command.dart';
import 'package:android_terminal_launcher/terminal/commands/theme_command.dart';

/// How the launcher looks. Built in `main.dart`, since it needs the live
/// [ThemeSettings] and [FontSizeSettings] the app listens to.
class AppearanceProvider implements CommandProvider {
  AppearanceProvider(this._theme, this._fontSize);

  final ThemeSettings _theme;
  final FontSizeSettings _fontSize;

  @override
  String get name => 'appearance';

  @override
  List<Command> get commands => [themeCommand(_theme), fontCommand(_fontSize)];
}
