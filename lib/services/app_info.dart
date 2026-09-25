/// A launchable app as the terminal sees it.
class AppInfo {
  const AppInfo({required this.label, required this.packageName});

  final String label;
  final String packageName;

  @override
  bool operator ==(Object other) =>
      other is AppInfo &&
      other.label == label &&
      other.packageName == packageName;

  @override
  int get hashCode => Object.hash(label, packageName);

  @override
  String toString() => 'AppInfo($label, $packageName)';
}
