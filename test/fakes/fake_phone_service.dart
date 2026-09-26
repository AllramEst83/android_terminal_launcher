import 'package:android_terminal_launcher/services/phone_service.dart';

/// Answers every call with [result] and records the numbers it was given.
class FakePhoneService implements PhoneService {
  FakePhoneService([this.result = const CallPlaced()]);

  CallResult result;
  final List<String> called = [];

  @override
  Future<CallResult> call(String number) async {
    called.add(number);
    return result;
  }
}
