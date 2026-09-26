import 'package:android_terminal_launcher/services/view_mode.dart';

/// What the `ui` command may see and change, and what the session reads to
/// decide whether output keeps its rich form. Only new output is affected:
/// what is already in the log stays as it was drawn.
abstract interface class ViewModeSettings {
  ViewMode get current;

  /// Switches mode at once, then saves the choice. Throws
  /// `LocalStoreException` if it could not be saved; the mode has still
  /// changed for this run.
  Future<void> select(ViewMode mode);
}
