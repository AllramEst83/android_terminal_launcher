import 'package:android_terminal_launcher/services/android_app_repository.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/app_repository_exception.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel(AndroidAppRepository.channelName);
const _self = 'com.codedbykay.android_terminal_launcher';

/// Stands in for the Kotlin side; the real platform is never touched in tests.
void _mockChannel(Future<Object?>? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

Map<String, String> _entry(String label, String packageName) => {
  'label': label,
  'packageName': packageName,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _mockChannel((call) => null));

  AndroidAppRepository repository() =>
      AndroidAppRepository(ownPackage: _self, channel: _channel);

  test('maps entries and sorts case-insensitively by label', () async {
    _mockChannel(
      (call) async => [
        _entry('maps', 'pkg.maps'),
        _entry('Zoom', 'pkg.zoom'),
        _entry('Clock', 'pkg.clock'),
      ],
    );

    final apps = await repository().listApps();

    expect(apps, const [
      AppInfo(label: 'Clock', packageName: 'pkg.clock'),
      AppInfo(label: 'maps', packageName: 'pkg.maps'),
      AppInfo(label: 'Zoom', packageName: 'pkg.zoom'),
    ]);
  });

  test('excludes this app from the listing', () async {
    _mockChannel(
      (call) async => [_entry('Terminal', _self), _entry('Clock', 'pkg.clock')],
    );

    final apps = await repository().listApps();

    expect(apps.map((a) => a.packageName), ['pkg.clock']);
  });

  test('skips malformed entries and falls back to the package name', () async {
    _mockChannel(
      (call) async => [
        {'label': 'No package'},
        {'packageName': 'pkg.nolabel'},
        _entry('Clock', 'pkg.clock'),
      ],
    );

    final apps = await repository().listApps();

    expect(apps, const [
      AppInfo(label: 'Clock', packageName: 'pkg.clock'),
      AppInfo(label: 'pkg.nolabel', packageName: 'pkg.nolabel'),
    ]);
  });

  test('caches the list until an explicit refresh', () async {
    var queries = 0;
    _mockChannel((call) async {
      queries++;
      return [_entry('Clock', 'pkg.clock')];
    });
    final repo = repository();

    await repo.listApps();
    await repo.listApps();
    expect(queries, 1);

    await repo.listApps(refresh: true);
    expect(queries, 2);
  });

  test('a platform failure becomes an AppRepositoryException', () async {
    _mockChannel((call) async => throw PlatformException(code: 'LIST_FAILED'));

    expect(repository().listApps(), throwsA(isA<AppRepositoryException>()));
  });

  test('a failed listing is not cached', () async {
    var fail = true;
    _mockChannel((call) async {
      if (fail) throw PlatformException(code: 'LIST_FAILED');
      return [_entry('Clock', 'pkg.clock')];
    });
    final repo = repository();

    await expectLater(repo.listApps(), throwsA(isA<AppRepositoryException>()));
    fail = false;

    expect(await repo.listApps(), hasLength(1));
  });

  test('launch sends the package name and returns the result', () async {
    MethodCall? received;
    _mockChannel((call) async {
      received = call;
      return true;
    });

    final launched = await repository().launch('pkg.clock');

    expect(launched, isTrue);
    expect(received?.method, 'launch');
    expect(received?.arguments, {'packageName': 'pkg.clock'});
  });

  test('launch returns false when the platform says so', () async {
    _mockChannel((call) async => false);

    expect(await repository().launch('pkg.clock'), isFalse);
  });

  test('launch returns false instead of throwing on platform errors', () async {
    _mockChannel((call) async => throw PlatformException(code: 'BOOM'));

    expect(await repository().launch('pkg.clock'), isFalse);
  });

  test('uninstall sends the package name on its own method', () async {
    MethodCall? received;
    _mockChannel((call) async {
      received = call;
      return true;
    });

    final started = await repository().uninstall('pkg.clock');

    expect(started, isTrue);
    expect(received?.method, 'uninstall');
    expect(received?.arguments, {'packageName': 'pkg.clock'});
  });

  test('uninstall returns false when the dialog cannot open', () async {
    _mockChannel((call) async => false);

    expect(await repository().uninstall('pkg.clock'), isFalse);
  });

  test(
    'uninstall returns false instead of throwing on platform errors',
    () async {
      _mockChannel((call) async => throw PlatformException(code: 'BOOM'));

      expect(await repository().uninstall('pkg.clock'), isFalse);
    },
  );

  test('uninstall does not change the cached listing', () async {
    var queries = 0;
    _mockChannel((call) async {
      if (call.method == 'listApps') {
        queries++;
        return [_entry('Clock', 'pkg.clock')];
      }
      return true;
    });
    final repo = repository();
    await repo.listApps();

    await repo.uninstall('pkg.clock');
    await repo.listApps();

    // Only the user's confirmation can remove an app, so it stays listed
    // until an explicit refresh.
    expect(queries, 1);
  });
}
