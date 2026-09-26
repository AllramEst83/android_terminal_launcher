import 'package:android_terminal_launcher/services/secret_store.dart';

class InMemorySecretStore implements SecretStore {
  InMemorySecretStore({this.failure});

  /// Thrown by every call while set.
  Object? failure;

  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async {
    _throwIfFailing();
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _throwIfFailing();
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _throwIfFailing();
    data.remove(key);
  }

  void _throwIfFailing() {
    final error = failure;
    if (error != null) throw error;
  }
}
