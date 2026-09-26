import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/cal_command.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_calendar_service.dart';

// Saturday 26 September 2026.
final _now = DateTime(2026, 9, 26, 15, 30);

final _lunch = CalendarEvent(
  id: 1,
  title: 'Lunch',
  start: DateTime(2026, 9, 26, 12),
  end: DateTime(2026, 9, 26, 13),
);

class _Rig {
  final calendar = FakeCalendarService();
  late final Command command = calCommand(calendar);

  Future<CommandResult> run(List<String> args) => command.run(
    CommandContext(
      args: args,
      apps: FakeAppRepository(),
      commands: const [],
      now: () => _now,
    ),
  );

  (DateTime, DateTime) get asked => calendar.asked.single;
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() || CommandAskSecret() => fail('unexpected clear'),
};

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  group('month', () {
    test('no arguments shows this month as a fixed-width grid', () async {
      rig.calendar.result = CalendarEvents([_lunch]);

      final result = await rig.run([]) as CommandOutput;

      expect(result.columns, monthGridColumns);
      expect(result.lines.first.trim(), 'September 2026');
      expect(result.lines.join('\n'), contains('>26*'));
      expect(rig.asked, (DateTime(2026, 9), DateTime(2026, 10)));
    });

    test('an ISO month, and the words for the neighbours', () async {
      await rig.run(['month', '2026-12']);
      expect(rig.calendar.asked.last, (DateTime(2026, 12), DateTime(2027)));

      await rig.run(['month', 'next']);
      expect(rig.calendar.asked.last, (DateTime(2026, 10), DateTime(2026, 11)));

      await rig.run(['2026-01']);
      expect(rig.calendar.asked.last, (DateTime(2026, 1), DateTime(2026, 2)));
    });

    test('a bad month is named and nothing is read', () async {
      final result = await rig.run(['month', '2026-13']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.calBadMonth('2026-13')]);
      expect(rig.calendar.asked, isEmpty);
    });
  });

  group('day', () {
    test('today, tomorrow and yesterday', () async {
      await rig.run(['today']);
      expect(rig.calendar.asked.last, (
        DateTime(2026, 9, 26),
        DateTime(2026, 9, 27),
      ));

      await rig.run(['tomorrow']);
      expect(rig.calendar.asked.last, (
        DateTime(2026, 9, 27),
        DateTime(2026, 9, 28),
      ));

      await rig.run(['day', 'yesterday']);
      expect(rig.calendar.asked.last, (
        DateTime(2026, 9, 25),
        DateTime(2026, 9, 26),
      ));
    });

    test(
      'shows the heading and the events, as plain wrapping output',
      () async {
        rig.calendar.result = CalendarEvents([_lunch]);

        final result = await rig.run(['today']) as CommandOutput;

        expect(result.columns, isNull);
        expect(result.lines, ['Sat 26 Sep 2026', '12:00-13:00 Lunch']);
      },
    );

    test('"day" alone means today; a bare date means that day', () async {
      await rig.run(['day']);
      expect(rig.calendar.asked.last.$1, DateTime(2026, 9, 26));

      await rig.run(['2026-10-03']);
      expect(rig.calendar.asked.last, (
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 4),
      ));
    });

    test('a quiet day says so', () async {
      expect(_lines(await rig.run(['today'])), [
        'Sat 26 Sep 2026',
        'no events',
      ]);
    });

    test('a bad date is named and nothing is read', () async {
      final result = await rig.run(['day', '2026-02-31']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.calBadDate('2026-02-31')]);
      expect(rig.calendar.asked, isEmpty);
    });
  });

  group('week', () {
    test('reads Monday to the next Monday', () async {
      await rig.run(['week']);

      expect(rig.asked, (DateTime(2026, 9, 21), DateTime(2026, 9, 28)));
    });

    test('takes a date inside the week', () async {
      await rig.run(['week', '2026-10-07']);

      expect(rig.asked, (DateTime(2026, 10, 5), DateTime(2026, 10, 12)));
    });

    test('lists seven days with today marked', () async {
      rig.calendar.result = CalendarEvents([_lunch]);

      final lines = _lines(await rig.run(['week']));

      expect(lines.where((line) => line.contains(' 2026')), hasLength(7));
      expect(lines, contains('Sat 26 Sep 2026 (today)'));
      expect(lines, contains('  12:00-13:00 Lunch'));
    });
  });

  group('usage', () {
    test('too many arguments', () async {
      final result = await rig.run(['week', 'today', 'now']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), Messages.calUsage);
    });

    test('a stray word is a usage error, not a guess', () async {
      final result = await rig.run(['banana', 'split']);

      expect(_lines(result), Messages.calUsage);
    });

    test(
      'a lone word that is neither date nor month is named as a month',
      () async {
        final result = await rig.run(['banana']);

        expect(_lines(result), [Messages.calBadMonth('banana')]);
      },
    );

    test('views ignore case', () async {
      await rig.run(['WEEK']);

      expect(rig.asked.$1, DateTime(2026, 9, 21));
    });
  });

  group('failures', () {
    test('a refusal says so', () async {
      rig.calendar.result = const CalendarDenied(permanent: false);

      final result = await rig.run([]);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.permissionDenied(Messages.calendar)]);
    });

    test('a permanent refusal says where to turn it on', () async {
      rig.calendar.result = const CalendarDenied(permanent: true);

      final result = await rig.run(['week']);

      expect(_lines(result), [
        Messages.permissionOff(Messages.calendar),
        ...Messages.permissionHowToGrant,
      ]);
    });

    test('an unreadable calendar gives the reason', () async {
      rig.calendar.result = const CalendarUnavailable(
        'the calendar did not answer',
      );

      final result = await rig.run(['today']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        Messages.calError('the calendar did not answer'),
      ]);
    });

    test('every failure line fits a phone screen', () async {
      for (final failed in <CalendarResult>[
        const CalendarDenied(permanent: false),
        const CalendarDenied(permanent: true),
      ]) {
        rig.calendar.result = failed;
        for (final line in _lines(await rig.run([]))) {
          expect(line.length, lessThanOrEqualTo(36), reason: line);
        }
      }
    });
  });

  group('argument suggestions', () {
    List<String> suggest(String partial) =>
        rig.command.argSuggestions!(partial, const []);

    test('offers the views and day words for the first word', () {
      expect(suggest(''), [
        'day',
        'week',
        'month',
        'today',
        'tomorrow',
        'yesterday',
      ]);
      expect(suggest('we'), ['week']);
      expect(suggest('to'), ['today', 'tomorrow']);
    });

    test(
      'offers a day word after day or week, and a month word after month',
      () {
        expect(suggest('day to'), ['day today', 'day tomorrow']);
        expect(suggest('week '), [
          'week today',
          'week tomorrow',
          'week yesterday',
        ]);
        expect(suggest('month n'), ['month next']);
      },
    );

    test('a typed date is the user\'s to type', () {
      expect(suggest('day 2026'), isEmpty);
      expect(suggest('month 2026-1'), isEmpty);
    });
  });

  test('is also reachable as calendar', () {
    expect(rig.command.aliases, contains('calendar'));
  });
}
