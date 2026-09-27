import 'dart:async';

import 'package:android_terminal_launcher/services/whatsapp_service.dart';
import 'package:flutter/services.dart';

/// [WhatsAppService] backed by the Kotlin `WhatsAppChannelHandler`. The only
/// file that knows about the channel.
class AndroidWhatsAppService implements WhatsAppService {
  const AndroidWhatsAppService({
    this._channel = const MethodChannel(channelName),
    this.timeout = const Duration(seconds: 10),
  });

  static const channelName =
      'com.codedbykay.android_terminal_launcher/whatsapp';

  final MethodChannel _channel;

  /// Only guards against a reply that never comes.
  final Duration timeout;

  @override
  Future<WhatsAppResult> openChat(String number, String text) async {
    try {
      final ok =
          await _channel
              .invokeMethod<bool>('open', {'number': number, 'text': text})
              .timeout(timeout) ??
          false;
      return ok ? const WhatsAppOpened() : _failed;
    } on PlatformException {
      return _failed;
    } on MissingPluginException {
      return const WhatsAppFailed('WhatsApp hand-off is not supported here');
    } on TimeoutException {
      return _failed;
    }
  }

  static const _failed = WhatsAppFailed('could not open WhatsApp');
}
