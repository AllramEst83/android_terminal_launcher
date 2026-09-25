import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/services/theme_settings.dart';

class FakeThemeSettings implements ThemeSettings {
  FakeThemeSettings({this.current = ThemeChoice.dark, this.saveError});

  @override
  ThemeChoice current;

  /// Thrown by [select] after the theme has changed, like a failed save.
  Object? saveError;

  /// Every choice passed to [select], in call order.
  final List<ThemeChoice> selected = [];

  @override
  Future<void> select(ThemeChoice choice) async {
    selected.add(choice);
    current = choice;
    final error = saveError;
    if (error != null) throw error;
  }
}
