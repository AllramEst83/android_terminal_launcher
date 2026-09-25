import 'package:android_terminal_launcher/services/theme_choice.dart';

/// What the `theme` command may see and change. The Flutter side listens to a
/// concrete implementation; commands only ever see this.
abstract interface class ThemeSettings {
  ThemeChoice get current;

  /// Switches theme at once, then saves the choice. Throws
  /// `LocalStoreException` if it could not be saved; the theme has still
  /// changed for this run.
  Future<void> select(ThemeChoice choice);
}
