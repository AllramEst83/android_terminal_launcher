import 'dart:convert';

import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/secret_store.dart';

const _key = 'mailAccount';

/// Where to log in and as whom. One value, so the password can never be kept
/// apart from the address it belongs to (or left behind when it is forgotten).
class MailAccount {
  const MailAccount({
    required this.email,
    required this.host,
    required this.password,
    this.port = 993,
  });

  final String email;
  final String host;
  final int port;
  final String password;
}

/// The one mail account, kept in a [SecretStore] because it holds a password.
class MailAccountStore {
  MailAccountStore(this._secrets);

  final SecretStore _secrets;

  /// The saved account, or null if there is none. Throws
  /// `LocalStoreException` if the store fails or holds something unreadable.
  Future<MailAccount?> load() async {
    final raw = await _secrets.read(_key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return MailAccount(
        email: data['email'] as String,
        host: data['host'] as String,
        port: data['port'] as int,
        password: data['password'] as String,
      );
    } on Object {
      // Not the message from the parser: it may quote the stored text.
      throw const LocalStoreException(
        'the saved mail account is unreadable (try: mail forget)',
      );
    }
  }

  Future<void> save(MailAccount account) => _secrets.write(
    _key,
    jsonEncode({
      'email': account.email,
      'host': account.host,
      'port': account.port,
      'password': account.password,
    }),
  );

  /// Whether anything is saved, readable or not.
  Future<bool> exists() async => await _secrets.read(_key) != null;

  Future<void> clear() => _secrets.delete(_key);
}
