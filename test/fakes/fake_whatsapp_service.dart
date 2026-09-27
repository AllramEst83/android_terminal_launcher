import 'package:android_terminal_launcher/services/whatsapp_service.dart';

/// Answers every open with [result] and records what it was given.
class FakeWhatsAppService implements WhatsAppService {
  FakeWhatsAppService([this.result = const WhatsAppOpened()]);

  WhatsAppResult result;

  /// Every `(number, text)` opened, in order.
  final List<(String, String)> opened = [];

  @override
  Future<WhatsAppResult> openChat(String number, String text) async {
    opened.add((number, text));
    return result;
  }
}
