import 'package:android_terminal_launcher/services/sms_service.dart';

/// Answers every send with [result] and records what it was given.
class FakeSmsService implements SmsService {
  FakeSmsService([this.result = const SmsSent()]);

  SmsResult result;

  /// Every `(number, text)` sent, in order.
  final List<(String, String)> sent = [];

  @override
  Future<SmsResult> send(String number, String text) async {
    sent.add((number, text));
    return result;
  }
}
