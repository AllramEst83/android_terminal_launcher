import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/shared_preferences_local_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'local_store_contract.dart';

/// A platform whose disk always fails, like a full or locked-down device.
final class _FailingPlatform extends InMemorySharedPreferencesAsync {
  _FailingPlatform() : super.empty();

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) => throw PlatformException(code: 'disk', message: 'disk full');

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) =>
      throw PlatformException(code: 'disk');

  @override
  Future<bool> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) => throw PlatformException(code: 'disk', message: 'disk locked');
}

void main() {
  // The real platform is never touched in tests: an in-memory one stands in.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  localStoreContract(() => SharedPreferencesLocalStore());

  test('values survive a new store instance on the same storage', () async {
    await SharedPreferencesLocalStore().write('k', {'a': 1});

    expect(await SharedPreferencesLocalStore().read('k'), {'a': 1});
  });

  test('unreadable stored data is reported, not returned as garbage', () async {
    await SharedPreferencesAsync().setString('k', '{not json');

    await expectLater(
      SharedPreferencesLocalStore().read('k'),
      throwsA(
        isA<LocalStoreException>().having(
          (e) => e.message,
          'message',
          contains("'k'"),
        ),
      ),
    );
  });

  test(
    'a disk failure while reading or writing becomes a LocalStoreException',
    () async {
      SharedPreferencesAsyncPlatform.instance = _FailingPlatform();
      final store = SharedPreferencesLocalStore();

      await expectLater(store.read('k'), throwsA(isA<LocalStoreException>()));
      await expectLater(
        store.write('k', 1),
        throwsA(
          isA<LocalStoreException>().having(
            (e) => e.message,
            'message',
            contains('disk full'),
          ),
        ),
      );
      await expectLater(
        store.delete('k'),
        throwsA(
          isA<LocalStoreException>().having(
            (e) => e.message,
            'message',
            contains('disk locked'),
          ),
        ),
      );
    },
  );
}
