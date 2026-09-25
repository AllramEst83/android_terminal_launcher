import 'package:android_terminal_launcher/services/app_info.dart';

/// The only way the terminal reaches installed apps. Implementations list
/// launchable apps only, exclude this app, and sort by label.
abstract interface class AppRepository {
  /// Cached after the first call; [refresh] forces a new platform query.
  /// Throws `AppRepositoryException` if the platform query fails.
  Future<List<AppInfo>> listApps({bool refresh = false});

  /// Returns `false` when the app has no launch intent or starting it fails.
  Future<bool> launch(String packageName);

  /// Opens Android's uninstall confirmation for [packageName]. `true` only
  /// means the dialog was shown; the user may still cancel, so callers must not
  /// assume the app is gone. `false` when it could not be started.
  Future<bool> uninstall(String packageName);
}
