import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/app_repository.dart';

class FakeAppRepository implements AppRepository {
  FakeAppRepository({
    this.apps = const [],
    this.launchSucceeds = true,
    this.uninstallSucceeds = true,
    this.listError,
  });

  List<AppInfo> apps;
  bool launchSucceeds;
  bool uninstallSucceeds;
  Object? listError;

  /// Package names passed to [launch], in call order.
  final List<String> launched = [];

  /// Package names passed to [uninstall], in call order.
  final List<String> uninstalled = [];
  int listCalls = 0;

  /// How many of the [listApps] calls asked for a refresh.
  int refreshCalls = 0;

  @override
  Future<List<AppInfo>> listApps({bool refresh = false}) async {
    listCalls++;
    if (refresh) refreshCalls++;
    final error = listError;
    if (error != null) throw error;
    return apps;
  }

  @override
  Future<bool> launch(String packageName) async {
    launched.add(packageName);
    return launchSucceeds;
  }

  @override
  Future<bool> uninstall(String packageName) async {
    uninstalled.add(packageName);
    return uninstallSucceeds;
  }
}
