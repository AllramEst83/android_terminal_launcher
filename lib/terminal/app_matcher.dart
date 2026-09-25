import 'package:android_terminal_launcher/services/app_info.dart';

/// Every app whose label matches [query], best first: exact, then prefix, then
/// substring (case-insensitive). An empty query returns all apps. Unlike
/// [matchApps] this keeps the weaker tiers, since it feeds a suggestion list
/// rather than deciding what to launch.
List<AppInfo> rankApps(List<AppInfo> apps, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return apps;

  final ranked = <AppInfo>[];
  final tiers = <bool Function(String label)>[
    (label) => label == needle,
    (label) => label.startsWith(needle),
    (label) => label.contains(needle),
  ];
  for (final matches in tiers) {
    for (final app in apps) {
      if (matches(app.label.toLowerCase()) && !ranked.contains(app)) {
        ranked.add(app);
      }
    }
  }
  return ranked;
}

/// Case-insensitive match of [query] against app labels. The best tier that
/// has any hit wins: exact name, then prefix, then substring. Several hits in
/// that tier are returned together so the caller can list them, not guess.
List<AppInfo> matchApps(List<AppInfo> apps, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  final tiers = <bool Function(String label)>[
    (label) => label == needle,
    (label) => label.startsWith(needle),
    (label) => label.contains(needle),
  ];
  for (final matches in tiers) {
    final hits = apps.where((app) => matches(app.label.toLowerCase())).toList();
    if (hits.isNotEmpty) return hits;
  }
  return const [];
}
