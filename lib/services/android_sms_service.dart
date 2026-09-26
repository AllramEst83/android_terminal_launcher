import 'dart:async';

import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:android_terminal_launcher/services/sms_service.dart';
import 'package:flutter/services.dart';

/// [SmsService] backed by the Kotlin `SmsChannelHandler`, after asking
/// [PermissionService] for `sms`. The only file that knows about the channel.
class AndroidSmsService implements SmsService {
  const AndroidSmsService({
    required this._permissions,
    this._channel = const MethodChannel(channelName),
    this.timeout = const Duration(seconds: 45),
  });

  static const channelName = 'com.codedbykay.android_terminal_launcher/sms';

  final PermissionService _permissions;
  final MethodChannel _channel;

  /// The Kotlin side stops waiting for the network after 30 s; this only
  /// guards against a reply that never comes at all.
  final Duration timeout;

  @override
  Future<SmsResult> send(String number, String text) async {
    final status = await _permissions.request(AppPermission.sms);
    if (status != PermissionStatus.granted) {
      return SmsDenied(permanent: status == PermissionStatus.permanentlyDenied);
    }
    try {
      final ok = await _channel
          .invokeMethod<bool>('send', {'number': number, 'text': text})
          .timeout(timeout);
      return ok == true ? const SmsSent() : const SmsFailed(_generic);
    } on PlatformException catch (error) {
      return switch (error.code) {
        'NO_PERMISSION' => const SmsDenied(permanent: false),
        'NO_SERVICE' => const SmsFailed('no network service'),
        'RADIO_OFF' => const SmsFailed('flight mode is on'),
        // Some parts may have gone; resending blindly could double them.
        'NOT_CONFIRMED' => const SmsFailed(
          'not confirmed by the network; check before resending',
        ),
        _ => const SmsFailed(_generic),
      };
    } on MissingPluginException {
      return const SmsFailed('texting is not supported here');
    } on TimeoutException {
      return const SmsFailed(
        'not confirmed by the network; check before resending',
      );
    }
  }

  static const _generic = 'the message could not be sent';
}
