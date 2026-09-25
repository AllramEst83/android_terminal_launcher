import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/terminal/app_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

AppInfo app(String label) => AppInfo(label: label, packageName: 'pkg.$label');

void main() {
  test('exact match wins over prefix and substring', () {
    final apps = [app('Maps Go'), app('Maps'), app('Google Maps')];

    expect(matchApps(apps, 'maps'), [app('Maps')]);
  });

  test('prefix match wins over substring', () {
    final apps = [app('Google Maps'), app('Mapsly')];

    expect(matchApps(apps, 'maps'), [app('Mapsly')]);
  });

  test('falls back to substring', () {
    final apps = [app('Google Maps'), app('Clock')];

    expect(matchApps(apps, 'maps'), [app('Google Maps')]);
  });

  test('matching is case-insensitive', () {
    expect(matchApps([app('FireFox')], 'FIREFOX'), [app('FireFox')]);
  });

  test('several hits in the winning tier are all returned', () {
    final apps = [app('Chrome'), app('Chrome Beta'), app('Clock')];

    expect(matchApps(apps, 'chrome'), [app('Chrome')]);
    expect(matchApps(apps, 'chr'), [app('Chrome'), app('Chrome Beta')]);
  });

  test('no hits, or a blank query, return nothing', () {
    expect(matchApps([app('Clock')], 'zzz'), isEmpty);
    expect(matchApps([app('Clock')], '  '), isEmpty);
  });

  group('rankApps', () {
    test('keeps every tier, best first', () {
      final apps = [app('My Chrome'), app('Chrome Beta'), app('Chrome')];

      expect(rankApps(apps, 'chrome'), [
        app('Chrome'),
        app('Chrome Beta'),
        app('My Chrome'),
      ]);
    });

    test('keeps the given order within a tier', () {
      final apps = [app('Camera'), app('Calendar'), app('Calculator')];

      expect(rankApps(apps, 'ca'), apps);
    });

    test('is case-insensitive and ignores surrounding space', () {
      expect(rankApps([app('FireFox')], '  FIRE '), [app('FireFox')]);
    });

    test('a blank query returns every app', () {
      final apps = [app('Clock'), app('Maps')];

      expect(rankApps(apps, ''), apps);
      expect(rankApps(apps, '  '), apps);
    });

    test('no hits return nothing', () {
      expect(rankApps([app('Clock')], 'zzz'), isEmpty);
    });
  });
}
