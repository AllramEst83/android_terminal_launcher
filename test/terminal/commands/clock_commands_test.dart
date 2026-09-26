import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/clock_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/clock_commands.dart';
import 'package:android_terminal_launcher/terminal/providers/clock_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_clock_service.dart';

// Saturday 26 September 2026, 15:30.
final _now = DateTime(2026, 9, 26, 15, 30);

class _Rig {
  final clock = FakeClockService();
  late final timer = timerCommand(clock);
  late final alarm = alarmCommand(clock);

  Future<CommandResult> runTimer(List<String> args) =>
      timer.run(_context(args));
  Future<CommandResult> runAlarm(List<String> args) =>
      alarm.run(_context(args));

  CommandContext _context(List<String> args) => CommandContext(
    args: args,
    apps: FakeAppRepository(),
    commands: const [],
    now: () => _now,
  );
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() || CommandAskSecret() => fail('unexpected result'),
};

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  group('timer', () {
    test('starts one and says for how long and when it ends', () async {
      final result = await rig.runTimer(['10m']);

      expect(rig.clock.timers, [(const Duration(minutes: 10), null)]);
      expect(_lines(result), ['timer set: 10 min', 'ends 15:40']);
      final notice = (result as CommandOutput).block! as NoticeBlock;
      expect(notice.kind, NoticeKind.success);
    });

    test('a label is everything after the length', () async {
      final result = await rig.runTimer(['1h30m', 'pasta', 'is', 'ready']);

      expect(rig.clock.timers.single.$1, const Duration(minutes: 90));
      expect(rig.clock.timers.single.$2, 'pasta is ready');
      expect(_lines(result), [
        'timer set: 1 h 30 min',
        'ends 17:00',
        'label: pasta is ready',
      ]);
    });

    test('a quoted label with spaces arrives as one word', () async {
      await rig.runTimer(['5m', 'green tea']);

      expect(rig.clock.timers.single.$2, 'green tea');
    });

    test(
      'a smaller unit after a larger one is the rest of the length',
      () async {
        await rig.runTimer(['1h', '30m', 'tea']);

        expect(rig.clock.timers.single.$1, const Duration(minutes: 90));
        expect(rig.clock.timers.single.$2, 'tea');
      },
    );

    test('three parts, each smaller than the last', () async {
      await rig.runTimer(['1h', '30m', '15s']);

      expect(
        rig.clock.timers.single.$1,
        const Duration(hours: 1, minutes: 30, seconds: 15),
      );
      expect(rig.clock.timers.single.$2, isNull);
    });

    test('a same or larger unit after one is a label, not more time', () async {
      await rig.runTimer(['10m', '5m']);

      expect(rig.clock.timers.single.$1, const Duration(minutes: 10));
      expect(rig.clock.timers.single.$2, '5m');
    });

    test('a bare number after a length is a label', () async {
      await rig.runTimer(['1h', '30']);

      expect(rig.clock.timers.single.$1, const Duration(hours: 1));
      expect(rig.clock.timers.single.$2, '30');
    });

    test('a bare number is minutes', () async {
      await rig.runTimer(['25']);

      expect(rig.clock.timers.single.$1, const Duration(minutes: 25));
    });

    test('says the day when it ends on another', () async {
      final result = await rig.runTimer(['10h']);

      expect(_lines(result)[1], 'ends Sun 01:30');
    });

    test('a length that is not one shows the way', () async {
      final result = await rig.runTimer(['soon']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        "'soon' is not a length of time",
        ...Messages.timerHelp,
      ]);
      expect(rig.clock.timers, isEmpty);
    });

    test('zero is too short', () async {
      expect(_lines(await rig.runTimer(['0m'])), [Messages.timerTooShort]);
      expect(_lines(await rig.runTimer(['0'])), [Messages.timerTooShort]);
      expect(rig.clock.timers, isEmpty);
    });

    test('more than a day is too long, exactly a day is fine', () async {
      expect(_lines(await rig.runTimer(['25h'])), [Messages.timerTooLong]);
      expect(rig.clock.timers, isEmpty);

      await rig.runTimer(['24h']);
      expect(rig.clock.timers.single.$1, const Duration(hours: 24));
    });

    test('with none opens the timers in the clock app', () async {
      final result = await rig.runTimer([]);

      expect(rig.clock.timersShown, 1);
      expect(rig.clock.timers, isEmpty);
      final notice = (result as CommandOutput).block! as NoticeBlock;
      expect(notice.kind, NoticeKind.info);
      expect(notice.message, Messages.timersOpened);
    });

    test('a clock app that cannot be reached is one error line', () async {
      rig.clock.result = const ClockUnavailable('no clock app found');

      final result = await rig.runTimer(['10m']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), ['timer: no clock app found']);
    });

    test('opening the list can fail too', () async {
      rig.clock.result = const ClockUnavailable('no clock app found');

      expect(_lines(await rig.runTimer([])), ['timer: no clock app found']);
    });

    test('suggests common lengths as the first word', () {
      final suggest = rig.timer.argSuggestions!;

      expect(suggest('', const []), ['5m', '10m', '25m', '1h']);
      expect(suggest('1', const []), ['10m', '1h']);
      expect(suggest('10m ', const []), isEmpty);
      expect(suggest('x', const []), isEmpty);
    });
  });

  group('alarm', () {
    test('sets one for the next time the clock reads that', () async {
      final result = await rig.runAlarm(['07:30']);

      final alarm = rig.clock.alarms.single;
      expect((alarm.hour, alarm.minute, alarm.label), (7, 30, null));
      expect(alarm.weekdays, isEmpty);
      expect(_lines(result), ['alarm set: 07:30, tomorrow']);
      final notice = (result as CommandOutput).block! as NoticeBlock;
      expect(notice.kind, NoticeKind.success);
    });

    test('a time later today is today', () async {
      final result = await rig.runAlarm(['18:00']);

      expect(_lines(result), ['alarm set: 18:00, today']);
    });

    test('takes the other ways to write a time', () async {
      await rig.runAlarm(['7am']);
      await rig.runAlarm(['7:30', 'pm']);
      await rig.runAlarm(['0645']);

      expect(
        [for (final a in rig.clock.alarms) (a.hour, a.minute)],
        [(7, 0), (19, 30), (6, 45)],
      );
    });

    test('a label is the rest', () async {
      final result = await rig.runAlarm(['07:00', 'go', 'to', 'the', 'gym']);

      expect(rig.clock.alarms.single.label, 'go to the gym');
      expect(_lines(result), [
        'alarm set: 07:00, tomorrow',
        'label: go to the gym',
      ]);
    });

    test('days come before the label and make it repeat', () async {
      final result = await rig.runAlarm(['06:45', 'mon', 'tue', 'wed', 'gym']);

      expect(rig.clock.alarms.single.weekdays, [1, 2, 3]);
      expect(rig.clock.alarms.single.label, 'gym');
      expect(_lines(result).first, 'alarm set: 06:45, Mon-Wed');
    });

    test('weekdays, weekend and daily are one word each', () async {
      await rig.runAlarm(['06:45', 'weekdays']);
      await rig.runAlarm(['09:00', 'weekend']);
      final daily = await rig.runAlarm(['08:00', 'daily']);

      expect(rig.clock.alarms[0].weekdays, [1, 2, 3, 4, 5]);
      expect(rig.clock.alarms[1].weekdays, [6, 7]);
      expect(rig.clock.alarms[2].weekdays, [1, 2, 3, 4, 5, 6, 7]);
      expect(_lines(daily).first, 'alarm set: 08:00, daily');
    });

    test('days are sorted and not repeated', () async {
      await rig.runAlarm(['06:45', 'fri', 'mon', 'fri']);

      expect(rig.clock.alarms.single.weekdays, [1, 5]);
    });

    test('a day word after the label began is part of the label', () async {
      await rig.runAlarm(['06:45', 'gym', 'mon']);

      expect(rig.clock.alarms.single.weekdays, isEmpty);
      expect(rig.clock.alarms.single.label, 'gym mon');
    });

    test('a time that is not one shows the way', () async {
      final result = await rig.runAlarm(['25:00']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        "'25:00' is not a time of day",
        ...Messages.alarmHelp,
      ]);
      expect(rig.clock.alarms, isEmpty);
    });

    test('with none opens the alarms in the clock app', () async {
      final result = await rig.runAlarm([]);

      expect(rig.clock.alarmsShown, 1);
      expect(rig.clock.alarms, isEmpty);
      expect(_lines(result), [Messages.alarmsOpened]);
    });

    test('a clock app that cannot be reached is one error line', () async {
      rig.clock.result = const ClockUnavailable('not allowed to set alarms');

      final result = await rig.runAlarm(['07:00']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), ['alarm: not allowed to set alarms']);
    });
  });

  test('every help line fits a phone screen', () {
    for (final command in [rig.timer, rig.alarm]) {
      final lines = [
        command.usage,
        command.description,
        ...command.usageForms,
        ...command.examples,
        ...command.notes,
      ];
      for (final line in lines) {
        expect(
          line.length,
          lessThanOrEqualTo(36),
          reason: '${command.name}: $line',
        );
      }
    }
  });

  test('both are in the tools help group, and remembered as typed', () {
    final provider = ClockProvider(rig.clock);

    expect(provider.name, 'tools');
    expect([for (final c in provider.commands) c.name], ['timer', 'alarm']);
    for (final command in provider.commands) {
      expect(command.history, HistoryPolicy.line);
      expect(command.spinner, isFalse);
    }
  });
}
