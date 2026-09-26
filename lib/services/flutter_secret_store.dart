import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/secret_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [SecretStore] on `flutter_secure_storage` (the Android Keystore). This is
/// the only file that knows about the package.
class FlutterSecretStore implements SecretStore {
  FlutterSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) =>
      _guard("could not read '$key'", () => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) => _guard(
    "could not save '$key'",
    () => _storage.write(key: key, value: value),
  );

  @override
  Future<void> delete(String key) =>
      _guard("could not delete '$key'", () => _storage.delete(key: key));

  Future<T> _guard<T>(String what, Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error) {
      throw LocalStoreException('$what: ${error.message ?? error.code}');
    }
  }
}
