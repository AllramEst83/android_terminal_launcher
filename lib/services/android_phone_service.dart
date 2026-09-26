import 'dart:async';

import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:android_terminal_launcher/services/phone_service.dart';
import 'package:flutter/services.dart';

/// [PhoneService] backed by the Kotlin `PhoneChannelHandler`. The only file
/// that knows about the channel.
class AndroidPhoneService implements PhoneService {
  const AndroidPhoneService({
    required this._permissions,
    this._channel = const MethodChannel(channelName),
    this.timeout = const Duration(seconds: 10),
  });

  static const channelName = 'com.codedbykay.android_terminal_launcher/phone';

  final PermissionService _permissions;
  final MethodChannel _channel;

  /// Only guards against a reply that never comes.
  final Duration timeout;

  @override
  Future<CallResult> call(String number) async {
    final status = await _permissions.request(AppPermission.phone);
    if (status == PermissionStatus.granted) {
      try {
        if (await _invoke('call', number)) return const CallPlaced();
      } on PlatformException catch (error) {
        // Refused at the last moment, or a number apps may not call directly
        // (emergency): the dialer is still fine. Anything else is a failure.
        if (error.code != 'NO_PERMISSION') return _failed;
      } on MissingPluginException {
        return const CallFailed('calling is not supported here');
      } on TimeoutException {
        return _failed;
      }
    }
    try {
      return await _invoke('dial', number) ? const DialerOpened() : _failed;
    } on PlatformException {
      return _failed;
    } on MissingPluginException {
      return const CallFailed('calling is not supported here');
    } on TimeoutException {
      return _failed;
    }
  }

  Future<bool> _invoke(String method, String number) async =>
      await _channel
          .invokeMethod<bool>(method, {'number': number})
          .timeout(timeout) ??
      false;

  static const _failed = CallFailed('could not open the dialer');
}
