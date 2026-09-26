import 'dart:async';

import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:flutter/services.dart';

/// [ContactsService] backed by the Kotlin `ContactsChannelHandler`, after
/// asking [PermissionService] for `contacts`. The only file that knows about
/// the channel.
class AndroidContactsService implements ContactsService {
  const AndroidContactsService({
    required this._permissions,
    this._channel = const MethodChannel(channelName),
    this.timeout = const Duration(seconds: 15),
  });

  static const channelName =
      'com.codedbykay.android_terminal_launcher/contacts';

  final PermissionService _permissions;
  final MethodChannel _channel;

  /// Only guards against a reply that never comes.
  final Duration timeout;

  @override
  Future<ContactsResult> all() async {
    final status = await _permissions.request(AppPermission.contacts);
    if (status != PermissionStatus.granted) {
      return ContactsDenied(
        permanent: status == PermissionStatus.permanentlyDenied,
      );
    }
    try {
      final raw = await _channel
          .invokeListMethod<Map<Object?, Object?>>('all')
          .timeout(timeout);
      return ContactsRead(_group(raw ?? const []));
    } on PlatformException catch (error) {
      return switch (error.code) {
        'NO_PERMISSION' => const ContactsDenied(permanent: false),
        _ => const ContactsUnavailable('could not read the contacts'),
      };
    } on MissingPluginException {
      return const ContactsUnavailable('contacts are not supported here');
    } on TimeoutException {
      return const ContactsUnavailable('the contacts did not answer');
    }
  }

  /// One row per number in, one [Contact] per name out, in the order the names
  /// first appear (the platform sorts them).
  static List<Contact> _group(List<Map<Object?, Object?>> rows) {
    final byName = <String, List<PhoneNumber>>{};
    final names = <String, String>{};
    for (final row in rows) {
      final number = _text(row['number']);
      if (number == null) continue;
      // A contact with no name is shown by its number.
      final name = _text(row['name']) ?? number;
      final key = name.toLowerCase();
      names.putIfAbsent(key, () => name);
      final numbers = byName.putIfAbsent(key, () => []);
      final digits = _digits(number);
      if (numbers.any((existing) => _digits(existing.number) == digits)) {
        continue;
      }
      numbers.add(
        PhoneNumber(number, _text(row['label'])?.toLowerCase() ?? 'other'),
      );
    }
    return List.unmodifiable([
      for (final entry in byName.entries)
        Contact(
          name: names[entry.key]!,
          numbers: List.unmodifiable(entry.value),
        ),
    ]);
  }

  /// The same number written two ways (`070-123 45 67`, `0701234567`) is one.
  static String _digits(String number) =>
      number.replaceAll(RegExp(r'[^\d+]'), '');

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}
