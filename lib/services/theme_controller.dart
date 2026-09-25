import 'package:android_terminal_launcher/services/local_store.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/services/theme_settings.dart';
import 'package:flutter/foundation.dart';

/// The current theme, kept in a [LocalStore]. The app rebuilds when it
/// changes; commands change it through [ThemeSettings].
class ThemeController extends ChangeNotifier implements ThemeSettings {
  ThemeController({required this._store});

  static const storeKey = 'theme';

  final LocalStore _store;
  ThemeChoice _current = ThemeChoice.dark;
  bool _disposed = false;

  @override
  ThemeChoice get current => _current;

  /// Applies the saved choice. A missing, unknown or unreadable value keeps
  /// the default: a theme is never worth failing startup over.
  Future<void> load() async {
    final Object? saved;
    try {
      saved = await _store.read(storeKey);
    } on LocalStoreException {
      return;
    }
    final choice = saved is String ? ThemeChoice.parse(saved) : null;
    if (choice != null) _apply(choice);
  }

  @override
  Future<void> select(ThemeChoice choice) async {
    _apply(choice);
    await _store.write(storeKey, choice.name);
  }

  void _apply(ThemeChoice choice) {
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
