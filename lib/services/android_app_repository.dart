import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/app_repository.dart';
import 'package:android_terminal_launcher/services/app_repository_exception.dart';
import 'package:flutter/services.dart';

/// [AppRepository] backed by the Kotlin `AppsChannelHandler`. This is the only
/// file that knows about the channel; swapping it must touch nothing else.
class AndroidAppRepository implements AppRepository {
  AndroidAppRepository({
    required this.ownPackage,
    this._channel = const MethodChannel(channelName),
  });

  static const channelName = 'com.codedbykay.android_terminal_launcher/apps';

  /// Excluded from the listing. The manifest's `LAUNCHER` filter makes this
  /// app show up in its own query, and `open` must not relaunch the terminal.
  final String ownPackage;
  final MethodChannel _channel;
  List<AppInfo>? _cache;

  @override
  Future<List<AppInfo>> listApps({bool refresh = false}) async {
    final cached = _cache;
    if (!refresh && cached != null) return cached;

    final List<Map<Object?, Object?>>? raw;
    try {
      raw = await _channel.invokeListMethod<Map<Object?, Object?>>('listApps');
    } on PlatformException catch (error) {
      throw AppRepositoryException(
        'could not list apps: ${error.message ?? error.code}',
      );
    } on MissingPluginException {
      throw const AppRepositoryException('could not list apps: unsupported');
    }

    final apps = <AppInfo>[
      for (final entry in raw ?? const <Map<Object?, Object?>>[])
        ?_parse(entry),
    ]..sort(_byLabel);
    return _cache = List.unmodifiable(apps);
  }

  @override
  Future<bool> launch(String packageName) => _invokeBool('launch', packageName);

  @override
  Future<bool> uninstall(String packageName) =>
      _invokeBool('uninstall', packageName);

  /// Expected failures (no launch intent, dialog refused) are a `false`, not
  /// an exception, so a command can print them.
  Future<bool> _invokeBool(String method, String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>(method, {
        'packageName': packageName,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  AppInfo? _parse(Map<Object?, Object?> entry) {
    final packageName = entry['packageName'];
    if (packageName is! String || packageName == ownPackage) return null;
    final label = entry['label'];
    return AppInfo(
      label: label is String && label.isNotEmpty ? label : packageName,
      packageName: packageName,
    );
  }

  static int _byLabel(AppInfo a, AppInfo b) {
    final byLabel = a.label.toLowerCase().compareTo(b.label.toLowerCase());
    return byLabel != 0 ? byLabel : a.packageName.compareTo(b.packageName);
  }
}
