import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/font_size_settings.dart';
import 'package:android_terminal_launcher/services/local_store.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:flutter/foundation.dart';

/// The current font size, kept in a [LocalStore]. The app rebuilds when it
/// changes; commands change it through [FontSizeSettings].
class FontSizeController extends ChangeNotifier implements FontSizeSettings {
  FontSizeController({required this._store});

  static const storeKey = 'fontSize';

  final LocalStore _store;
  FontSizeChoice _current = FontSizeChoice.normal;
  bool _disposed = false;

  @override
  FontSizeChoice get current => _current;

  /// Applies the saved choice. A missing, unknown or unreadable value keeps
  /// the default: a font size is never worth failing startup over.
  Future<void> load() async {
    final Object? saved;
    try {
      saved = await _store.read(storeKey);
    } on LocalStoreException {
      return;
    }
    final choice = saved is String ? FontSizeChoice.parse(saved) : null;
    if (choice != null) _apply(choice);
  }

  @override
  Future<void> select(FontSizeChoice choice) async {
    _apply(choice);
    await _store.write(storeKey, choice.name);
  }

  void _apply(FontSizeChoice choice) {
    if (choice == _current || _disposed) return;
    _current = choice;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
