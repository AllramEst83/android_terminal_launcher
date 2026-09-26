import 'package:android_terminal_launcher/services/android_calendar_service.dart';
import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_permission_service.dart';

const _channel = MethodChannel(AndroidCalendarService.channelName);

/// Stands in for the Kotlin side; the real platform is never touched in tests.
void _mockChannel(Future<Object?>? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

int _ms(DateTime time) => time.millisecondsSinceEpoch;

Map<String, Object?> _timed(
  int id,
  String title,
  DateTime start,
  DateTime end,
) => {
  'id': id,
  'title': title,
  'begin': _ms(start),
  'end': _ms(end),
  'allDay': false,
};

/// The provider stores an all-day event as UTC midnights, end exclusive.
Map<String, Object?> _allDay(
  int id,
  String title,
  int year,
  int month,
  int day, {
  int days = 1,
}) => {
  'id': id,
  'title': title,
  'begin': _ms(DateTime.utc(year, month, day)),
  'end': _ms(DateTime.utc(year, month, day + days)),
  'allDay': true,
};

final _from = DateTime(2026, 9, 26);
final _to = DateTime(2026, 9, 27);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _mockChannel((call) => null));

  late FakePermissionService permissions;
  late AndroidCalendarService service;
  setUp(() {
    permissions = FakePermissionService();
    service = AndroidCalendarService(
      permissions: permissions,
      channel: _channel,
      timeout: const Duration(milliseconds: 50),
    );
  });

  Future<List<CalendarEvent>> events() async =>
      ((await service.events(from: _from, to: _to)) as CalendarEvents).events;

  test(
    'asks for calendar permission, then for events a day either side',
    () async {
      MethodCall? seen;
      _mockChannel((call) async {
        seen = call;
        return <Object?>[];
      });

      await service.events(from: _from, to: _to);

      expect(permissions.requested, [AppPermission.calendar]);
      expect(seen?.method, 'events');
      expect(seen?.arguments, {
        'begin': _ms(DateTime(2026, 9, 25)),
        'end': _ms(DateTime(2026, 9, 28)),
      });
    },
  );

  test('maps a timed event to local times', () async {
    _mockChannel(
      (call) async => [
        {
          ..._timed(
            7,
            ' Lunch ',
            DateTime(2026, 9, 26, 12),
            DateTime(2026, 9, 26, 13),
          ),
          'location': 'Cafe',
          'calendar': 'Personal',
        },
      ],
    );

    final found = await events();

    expect(found, hasLength(1));
    expect(found.single.id, 7);
    expect(found.single.title, 'Lunch');
    expect(found.single.start, DateTime(2026, 9, 26, 12));
    expect(found.single.end, DateTime(2026, 9, 26, 13));
    expect(found.single.allDay, isFalse);
    expect(found.single.location, 'Cafe');
    expect(found.single.calendar, 'Personal');
  });

  group('colour', () {
    Future<int?> colourOf(Object? sent) async {
      _mockChannel(
        (call) async => [
          {
            ..._timed(
              1,
              'A',
              DateTime(2026, 9, 26, 12),
              DateTime(2026, 9, 26, 13),
            ),
            'color': sent,
          },
        ],
      );
      return (await events()).single.color;
    }

    test('is passed on as opaque ARGB', () async {
      expect(await colourOf(0xFF336699), 0xFF336699);
    });

    test('a negative Android int is the same colour', () async {
      // 0xFF336699 as a signed 32-bit value, as Kotlin sends it.
      expect(await colourOf(0xFF336699 - 0x100000000), 0xFF336699);
    });

    test('is made opaque whatever alpha it came with', () async {
      expect(await colourOf(0x00336699), 0xFF336699);
    });

    test('is null when there is none, or it is not a number', () async {
      expect(await colourOf(null), isNull);
      expect(await colourOf('red'), isNull);
    });
  });

  test('an all-day event is a date, whatever the time zone', () async {
    _mockChannel((call) async => [_allDay(3, 'Holiday', 2026, 9, 26)]);

    final found = await events();

    expect(found.single.allDay, isTrue);
    expect(found.single.start, DateTime(2026, 9, 26));
    expect(found.single.end, DateTime(2026, 9, 27));
  });

  test('an all-day event on the day before is not on this one', () async {
    _mockChannel((call) async => [_allDay(3, 'Yesterday', 2026, 9, 25)]);

    expect(await events(), isEmpty);
  });

  test('an all-day event on the day after is not on this one', () async {
    _mockChannel((call) async => [_allDay(3, 'Tomorrow', 2026, 9, 27)]);

    expect(await events(), isEmpty);
  });

  test(
    'a multi-day all-day event that reaches into the range is kept',
    () async {
      _mockChannel((call) async => [_allDay(3, 'Trip', 2026, 9, 24, days: 3)]);

      expect((await events()).single.title, 'Trip');
    },
  );

  test(
    'a timed event outside the range is dropped, one crossing in is kept',
    () async {
      _mockChannel(
        (call) async => [
          _timed(
            1,
            'before',
            DateTime(2026, 9, 25, 10),
            DateTime(2026, 9, 25, 11),
          ),
          _timed(
            2,
            'crossing',
            DateTime(2026, 9, 25, 23),
            DateTime(2026, 9, 26, 1),
          ),
          _timed(
            3,
            'after',
            DateTime(2026, 9, 27, 0, 30),
            DateTime(2026, 9, 27, 1),
          ),
        ],
      );

      expect((await events()).map((e) => e.title), ['crossing']);
    },
  );

  test('an event with no length is kept when it is in the range', () async {
    final at = DateTime(2026, 9, 26, 8);
    _mockChannel((call) async => [_timed(1, 'ping', at, at)]);

    expect((await events()).single.start, at);
  });

  test('all-day events sort first, then by start, then by title', () async {
    _mockChannel(
      (call) async => [
        _timed(1, 'b', DateTime(2026, 9, 26, 9), DateTime(2026, 9, 26, 10)),
        _timed(2, 'A', DateTime(2026, 9, 26, 9), DateTime(2026, 9, 26, 10)),
        _timed(3, 'early', DateTime(2026, 9, 26, 7), DateTime(2026, 9, 26, 8)),
        _allDay(4, 'holiday', 2026, 9, 26),
      ],
    );

    expect((await events()).map((e) => e.title), [
      'holiday',
      'early',
      'A',
      'b',
    ]);
  });

  test('skips malformed entries and tolerates missing text', () async {
    _mockChannel(
      (call) async => [
        {'title': 'no id'},
        {'id': 1, 'begin': 'soon', 'end': 2},
        {
          'id': 5,
          'begin': _ms(DateTime(2026, 9, 26, 9)),
          'end': _ms(DateTime(2026, 9, 26, 10)),
          'title': null,
          'location': ' ',
        },
      ],
    );

    final found = await events();

    expect(found, hasLength(1));
    expect(found.single.title, '');
    expect(found.single.location, isNull);
  });

  test('a broken range (end before start) is made harmless', () async {
    _mockChannel(
      (call) async => [
        _timed(1, 'odd', DateTime(2026, 9, 26, 10), DateTime(2026, 9, 26, 9)),
      ],
    );

    final found = await events();

    expect(found.single.end, found.single.start);
  });

  test('a refused permission never reaches the platform', () async {
    permissions.answer = PermissionStatus.denied;
    var asked = false;
    _mockChannel((call) async {
      asked = true;
      return null;
    });

    final result = await service.events(from: _from, to: _to);

    expect((result as CalendarDenied).permanent, isFalse);
    expect(asked, isFalse);
  });

  test('a permanent refusal is passed on as permanent', () async {
    permissions.answer = PermissionStatus.permanentlyDenied;

    final result = await service.events(from: _from, to: _to);

    expect((result as CalendarDenied).permanent, isTrue);
  });

  test('permission revoked between the two calls is a denial', () async {
    _mockChannel(
      (call) async => throw PlatformException(code: 'NO_PERMISSION'),
    );

    expect(await service.events(from: _from, to: _to), isA<CalendarDenied>());
  });

  test('any other platform error is unavailable', () async {
    _mockChannel((call) async => throw PlatformException(code: 'QUERY_FAILED'));

    expect(
      await service.events(from: _from, to: _to),
      isA<CalendarUnavailable>(),
    );
  });

  test('a reply that never comes gives up', () async {
    _mockChannel((call) => Future<Object?>.delayed(const Duration(seconds: 5)));

    expect(
      await service.events(from: _from, to: _to),
      isA<CalendarUnavailable>(),
    );
  });

  test('no handler at all is unsupported, not a crash', () async {
    _mockChannel((call) => throw MissingPluginException());

    expect(
      await service.events(from: _from, to: _to),
      isA<CalendarUnavailable>(),
    );
  });
}
