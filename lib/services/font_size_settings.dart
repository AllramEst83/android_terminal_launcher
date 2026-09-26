import 'package:android_terminal_launcher/services/font_size_choice.dart';

/// What the `font` command may see and change. The Flutter side listens to a
/// concrete implementation; commands only ever see this.
abstract interface class FontSizeSettings {
  FontSizeChoice get current;

  /// Switches size at once, then saves the choice. Throws
  /// `LocalStoreException` if it could not be saved; the size has still
  /// changed for this run.
  Future<void> select(FontSizeChoice choice);
}
