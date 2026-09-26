import 'package:android_terminal_launcher/services/font_size_settings.dart';
import 'package:android_terminal_launcher/services/theme_settings.dart';
import 'package:android_terminal_launcher/services/view_mode_settings.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/font_command.dart';
import 'package:android_terminal_launcher/terminal/commands/theme_command.dart';
import 'package:android_terminal_launcher/terminal/commands/ui_command.dart';

/// How the launcher looks. Built in `main.dart`, since it needs the live
/// [ThemeSettings], [FontSizeSettings] and [ViewModeSettings] the app and the
/// session read.
class AppearanceProvider implements CommandProvider {
  AppearanceProvider(this._theme, this._fontSize, this._view);

  final ThemeSettings _theme;
  final FontSizeSettings _fontSize;
  final ViewModeSettings _view;

  @override
  String get name => 'appearance';

  @override
  List<Command> get commands => [
    themeCommand(_theme),
    fontCommand(_fontSize),
    uiCommand(_view),
  ];
}
