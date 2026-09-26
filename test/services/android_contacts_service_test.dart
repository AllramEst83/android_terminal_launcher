import 'package:android_terminal_launcher/services/android_contacts_service.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_permission_service.dart';

const _channel = MethodChannel(AndroidContactsService.channelName);

/// Stands in for the Kotlin side; the real platform is never touched in tests.
void _mockChannel(Future<Object?>? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

Map<String, String?> _row(String? name, String? number, [String? label]) => {
  'name': name,
  'number': number,
  'label': label,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _mockChannel((call) => null));

  late FakePermissionService permissions;
  late AndroidContactsService service;
  setUp(() {
    permissions = FakePermissionService();
    service = AndroidContactsService(
      permissions: permissions,
      channel: _channel,
      timeout: const Duration(milliseconds: 50),
    );
  });

  Future<List<Contact>> contacts() async =>
      ((await service.all()) as ContactsRead).contacts;

  test('asks for contacts permission, then for everyone', () async {
    final calls = <String>[];
    _mockChannel((call) async {
      calls.add(call.method);
      return <Object?>[];
    });

    await service.all();

    expect(permissions.requested, [AppPermission.contacts]);
    expect(calls, ['all']);
  });

  test('one row per number becomes one contact per person', () async {
    _mockChannel(
      (call) async => [
        _row('Anna', '070-111', 'Mobile'),
        _row('Anna', '08-222', 'Work'),
        _row('Bo', '070-333', 'Mobile'),
      ],
    );

    final found = await contacts();

    expect(found.map((c) => c.name), ['Anna', 'Bo']);
    expect(found.first.numbers.map((n) => (n.number, n.label)), [
      ('070-111', 'mobile'),
      ('08-222', 'work'),
    ]);
  });

  test(
    'the same person from two accounts is one, numbers not repeated',
    () async {
      _mockChannel(
        (call) async => [
          _row('Anna', '070-111 22', 'Mobile'),
          _row('anna', '07011122', 'Mobile'),
          _row('ANNA', '08-222', 'Work'),
        ],
      );

      final found = await contacts();

      expect(found, hasLength(1));
      expect(found.single.name, 'Anna');
      expect(found.single.numbers.map((n) => n.number), [
        '070-111 22',
        '08-222',
      ]);
    },
  );

  test('a number in one form or the other is the same number', () async {
    _mockChannel(
      (call) async => [
        _row('Anna', '+46 70 111 22', 'Mobile'),
        _row('Anna', '+4670 11122', 'Mobile'),
      ],
    );

    expect((await contacts()).single.numbers, hasLength(1));
  });

  test('a contact with no name is shown by its number', () async {
    _mockChannel((call) async => [_row(null, '070-111')]);

    final found = await contacts();

    expect(found.single.name, '070-111');
  });

  test(
    'a missing label is "other"; rows without a number are skipped',
    () async {
      _mockChannel(
        (call) async => [
          _row('Anna', '070-111', ' '),
          _row('Bo', null),
          _row('Cia', ' '),
          {'name': 'Dan', 'number': 5},
        ],
      );

      final found = await contacts();

      expect(found.map((c) => c.name), ['Anna']);
      expect(found.single.numbers.single.label, 'other');
    },
  );

  test('an empty phone book is an empty list, not an error', () async {
    _mockChannel((call) async => <Object?>[]);

    expect(await contacts(), isEmpty);
  });

  test('a refused permission never reaches the platform', () async {
    permissions.answer = PermissionStatus.denied;
    var asked = false;
    _mockChannel((call) async {
      asked = true;
      return null;
    });

    final result = await service.all();

    expect((result as ContactsDenied).permanent, isFalse);
    expect(asked, isFalse);
  });

  test('a permanent refusal is passed on as permanent', () async {
    permissions.answer = PermissionStatus.permanentlyDenied;

    expect(((await service.all()) as ContactsDenied).permanent, isTrue);
  });

  test('permission revoked between the two calls is a denial', () async {
    _mockChannel(
      (call) async => throw PlatformException(code: 'NO_PERMISSION'),
    );

    expect(await service.all(), isA<ContactsDenied>());
  });

  test('any other platform error is unavailable', () async {
    _mockChannel((call) async => throw PlatformException(code: 'QUERY_FAILED'));

    expect(await service.all(), isA<ContactsUnavailable>());
  });

  test('a reply that never comes gives up', () async {
    _mockChannel((call) => Future<Object?>.delayed(const Duration(seconds: 5)));

    expect(await service.all(), isA<ContactsUnavailable>());
  });

  test('no handler at all is unsupported, not a crash', () async {
    _mockChannel((call) => throw MissingPluginException());

    expect(await service.all(), isA<ContactsUnavailable>());
  });
}
