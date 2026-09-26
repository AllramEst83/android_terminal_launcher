import 'package:android_terminal_launcher/services/local_store.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/view_mode.dart';
import 'package:android_terminal_launcher/services/view_mode_settings.dart';

/// The current [ViewMode], kept in a [LocalStore]. Nothing listens to it: the
/// session reads it as each command finishes.
class ViewModeController implements ViewModeSettings {
  ViewModeController({required this._store});

  static const storeKey = 'viewMode';

  final LocalStore _store;
  ViewMode _current = ViewMode.rich;

  @override
  ViewMode get current => _current;

  /// Applies the saved mode. A missing, unknown or unreadable value keeps the
  /// default: a display preference is never worth failing startup over.
  Future<void> load() async {
    final Object? saved;
    try {
      saved = await _store.read(storeKey);
    } on LocalStoreException {
      return;
    }
    final mode = saved is String ? ViewMode.parse(saved) : null;
    if (mode != null) _current = mode;
  }

  @override
  Future<void> select(ViewMode mode) async {
    _current = mode;
    await _store.write(storeKey, mode.name);
  }
}
