import 'package:android_terminal_launcher/services/view_mode.dart';
import 'package:android_terminal_launcher/services/view_mode_settings.dart';

class FakeViewModeSettings implements ViewModeSettings {
  FakeViewModeSettings({this.current = ViewMode.rich, this.saveError});

  @override
  ViewMode current;

  /// Thrown by [select] after the mode has changed, like a failed save.
  Object? saveError;

  /// Every mode passed to [select], in call order.
  final List<ViewMode> selected = [];

  @override
  Future<void> select(ViewMode mode) async {
    selected.add(mode);
    current = mode;
    final error = saveError;
    if (error != null) throw error;
  }
}
