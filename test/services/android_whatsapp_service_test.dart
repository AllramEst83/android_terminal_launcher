import 'package:android_terminal_launcher/services/android_whatsapp_service.dart';
import 'package:android_terminal_launcher/services/whatsapp_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel(AndroidWhatsAppService.channelName);

/// Stands in for the Kotlin side; the real platform is never touched in tests.
void _mockChannel(Future<Object?>? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _mockChannel((call) => null));

  late AndroidWhatsAppService service;
  late List<MethodCall> calls;
  setUp(() {
    service = const AndroidWhatsAppService(
      channel: _channel,
      timeout: Duration(milliseconds: 50),
    );
    calls = [];
  });

  void answer(Object? Function(MethodCall call) reply) {
    _mockChannel((call) async {
      calls.add(call);
      return reply(call);
    });
  }

  test('opens the chat with the number and text', () async {
    answer((call) => true);

    final result = await service.openChat('0701234567', 'hi');

    expect(result, isA<WhatsAppOpened>());
    expect(calls.map((c) => c.method), ['open']);
    expect(calls.single.arguments, {'number': '0701234567', 'text': 'hi'});
  });

  test('a chat that says it did not open is a failure', () async {
    answer((call) => false);

    expect(await service.openChat('0701234567', 'hi'), isA<WhatsAppFailed>());
  });

  test('a platform error is a failure', () async {
    answer((call) => throw PlatformException(code: 'UNAVAILABLE'));

    expect(await service.openChat('0701234567', 'hi'), isA<WhatsAppFailed>());
  });

  test('a reply that never comes is a failure', () async {
    _mockChannel((call) => Future<Object?>.delayed(const Duration(seconds: 5)));

    expect(await service.openChat('0701234567', 'hi'), isA<WhatsAppFailed>());
  });

  test('no handler at all is unsupported, not a crash', () async {
    _mockChannel((call) => throw MissingPluginException());

    expect(await service.openChat('0701234567', 'hi'), isA<WhatsAppFailed>());
  });
}
