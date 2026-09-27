import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/event_command.dart';
import 'package:android_terminal_launcher/terminal/tools/last_calendar_events.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_calendar_service.dart';
import '../../fakes/in_memory_local_store.dart';

// Saturday 26 September 2026, 15:30.
final _now = DateTime(2026, 9, 26, 15, 30);

const _family = CalendarInfo(
  id: 1,
  name: 'Family',
  accountName: 'a@x.com',
  primary: false,
);
const _own = CalendarInfo(
  id: 2,
  name: 'a@x.com',
  accountName: 'a@x.com',
  primary: true,
);

class _Rig {
  final calendar = FakeCalendarService()
    ..listResult = const CalendarList([_family, _own]);
  final lastEvents = LastCalendarEvents();
  final store = InMemoryLocalStore();
  late final Command command = eventCommand(calendar, lastEvents, store);

  Future<CommandResult> run(List<String> args) => command.run(
    CommandContext(
      args: args,
      apps: FakeAppRepository(),
      commands: const [],
      now: () => _now,
    ),
  );
}

Future<CommandResult> _answer(CommandResult result, String input) async {
  expect(result, isA<CommandAsk>(), reason: _describe(result));
  return (result as CommandAsk).then(input);
}

String _describe(CommandResult result) => switch (result) {
  CommandOutput(:final lines) ||
  CommandFailure(:final lines) => lines.join('|'),
  _ => '$result',
};

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() ||
  CommandAskSecret() ||
  CommandAsk() => fail('unexpected result: ${_describe(result)}'),
};

CalendarEvent _event({
  int id = 9,
  String title = 'Standup',
  String? description,
  String? calendarName = 'Family',
}) => CalendarEvent(
  id: id,
  title: title,
  description: description,
  start: DateTime(2026, 9, 26, 9),
  end: DateTime(2026, 9, 26, 9, 30),
  calendar: calendarName,
);

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  group('add', () {
    Future<CommandResult> walk({
      String title = 'Dentist',
      String description = '',
      String start = '18:00',
      String end = '',
      String calendarAnswer = '',
    }) async {
      var result = await rig.run(const ['add']);
      result = await _answer(result, title);
      result = await _answer(result, description);
      result = await _answer(result, start);
      result = await _answer(result, end);
      return _answer(result, calendarAnswer);
    }

    test(
      'asks title, description, start, end, then calendar in order',
      () async {
        var result = await rig.run(const ['add']);
        expect((result as CommandAsk).prompt, Messages.eventTitlePrompt);

        result = await _answer(result, 'Dentist');
        expect((result as CommandAsk).prompt, Messages.eventDescriptionPrompt);

        result = await _answer(result, 'Yearly checkup');
        expect((result as CommandAsk).prompt, Messages.eventStartPrompt);

        result = await _answer(result, '18:00');
        expect((result as CommandAsk).prompt, Messages.eventEndPrompt('1h'));

        result = await _answer(result, '');
        expect(
          (result as CommandAsk).prompt,
          Messages.eventCalendarPrompt('a@x.com'),
        );
      },
    );

    test('an empty title re-asks instead of moving on', () async {
      var result = await rig.run(const ['add']);
      result = await _answer(result, '   ');

      expect((result as CommandAsk).prompt, Messages.eventTitleNeeded);
      expect(rig.calendar.created, isEmpty);
    });

    test(
      'a title given as an argument skips straight to description',
      () async {
        final result = await rig.run(const ['add', 'Dentist']);

        expect((result as CommandAsk).prompt, Messages.eventDescriptionPrompt);
      },
    );

    test('an empty description is none', () async {
      await walk(description: '');

      expect(rig.calendar.created.single.description, isNull);
    });

    test('a bad start re-asks', () async {
      var result = await rig.run(const ['add']);
      result = await _answer(result, 'Dentist');
      result = await _answer(result, '');
      result = await _answer(result, 'whenever');

      expect((result as CommandAsk).prompt, Messages.eventBadStart('whenever'));
    });

    test('an empty end defaults to an hour after the start', () async {
      await walk(start: '18:00', end: '');

      final saved = rig.calendar.created.single;
      expect(saved.start, DateTime(2026, 9, 26, 18));
      expect(saved.end, DateTime(2026, 9, 26, 19));
    });

    test('a bad end re-asks', () async {
      var result = await rig.run(const ['add']);
      result = await _answer(result, 'Dentist');
      result = await _answer(result, '');
      result = await _answer(result, '18:00');
      result = await _answer(result, 'whenever');

      expect((result as CommandAsk).prompt, Messages.eventBadEnd('whenever'));
    });

    test('an empty calendar answer uses the default', () async {
      await walk(calendarAnswer: '');

      expect(rig.calendar.created.single.calendarId, _own.id);
    });

    test('a calendar named by its account also matches', () async {
      await walk(calendarAnswer: 'Family');

      expect(rig.calendar.created.single.calendarId, _family.id);
    });

    test('an unmatched calendar name re-asks', () async {
      var result = await rig.run(const ['add']);
      result = await _answer(result, 'Dentist');
      result = await _answer(result, '');
      result = await _answer(result, '18:00');
      result = await _answer(result, '');
      result = await _answer(result, 'Nonsense');

      expect(
        (result as CommandAsk).prompt,
        Messages.eventBadCalendar('Nonsense'),
      );
    });

    test('saves the event with everything gathered', () async {
      final result = await walk(
        title: 'Dentist',
        description: 'Yearly checkup',
        start: '18:00',
        end: '30m',
        calendarAnswer: 'Family',
      );

      final saved = rig.calendar.created.single;
      expect(saved.title, 'Dentist');
      expect(saved.description, 'Yearly checkup');
      expect(saved.start, DateTime(2026, 9, 26, 18));
      expect(saved.end, DateTime(2026, 9, 26, 18, 30));
      expect(saved.calendarId, _family.id);
      final notice = (result as CommandOutput).block! as NoticeBlock;
      expect(notice.kind, NoticeKind.success);
      expect(notice.message, contains('Dentist'));
    });

    test('remembers the calendar chosen, as the default next time', () async {
      await walk(calendarAnswer: 'Family');

      // A fresh command over the same store: the default survives it.
      final again = eventCommand(rig.calendar, rig.lastEvents, rig.store);
      Future<CommandResult> run(List<String> args) => again.run(
        CommandContext(
          args: args,
          apps: FakeAppRepository(),
          commands: const [],
          now: () => _now,
        ),
      );
      var result = await run(const ['add']);
      result = await _answer(result, 'Dentist');
      result = await _answer(result, '');
      result = await _answer(result, '18:00');
      result = await _answer(result, '');

      expect(
        (result as CommandAsk).prompt,
        Messages.eventCalendarPrompt('Family'),
      );
    });

    test('cancel at any step abandons it without saving', () async {
      var result = await rig.run(const ['add']);
      result = await _answer(result, 'cancel');

      expect(rig.calendar.created, isEmpty);
    });

    test('no calendar to add to is a plain failure', () async {
      rig.calendar.listResult = const CalendarList([]);
      var result = await rig.run(const ['add']);
      result = await _answer(result, 'Dentist');
      result = await _answer(result, '');
      result = await _answer(result, '18:00');
      result = await _answer(result, '');

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.eventNoCalendars]);
    });

    test('a refused calendar-list permission fails cleanly', () async {
      rig.calendar.listResult = const CalendarListDenied(permanent: false);
      var result = await rig.run(const ['add']);
      result = await _answer(result, 'Dentist');
      result = await _answer(result, '');
      result = await _answer(result, '18:00');
      result = await _answer(result, '');

      expect(result, isA<CommandFailure>());
    });

    test('a write failure is reported, not thrown', () async {
      rig.calendar.writeResult = const CalendarWriteFailed('provider error');

      final result = await walk();

      expect(_lines(result), [Messages.eventError('provider error')]);
    });
  });

  group('edit', () {
    test('with nothing shown yet, says so', () async {
      final result = await rig.run(const ['edit', '1']);
      expect(_lines(result), [Messages.eventNoList]);
    });

    test('an unknown number or id fails', () async {
      rig.lastEvents.show([_event()]);

      expect(_lines(await rig.run(const ['edit', '5'])), [
        Messages.eventNotFound('5'),
      ]);
      expect(_lines(await rig.run(const ['edit', '#404'])), [
        Messages.eventNotFound('#404'),
      ]);
    });

    test('every step defaults to the current value', () async {
      rig.lastEvents.show([_event(description: 'Daily sync')]);

      var result = await rig.run(const ['edit', '1']);
      expect((result as CommandAsk).prompt, contains('Standup'));

      result = await _answer(result, '');
      expect((result as CommandAsk).prompt, contains('Daily sync'));

      result = await _answer(result, ''); // start
      result = await _answer(result, ''); // end
      result = await _answer(result, ''); // -> calendar step
      expect((result as CommandAsk).prompt, contains('Family'));

      await _answer(result, '');

      final saved = rig.calendar.updated.single;
      expect(saved.$1, 9);
      expect(saved.$2.title, 'Standup');
      expect(saved.$2.description, 'Daily sync');
      expect(saved.$2.calendarId, _family.id);
    });

    test('changing just the title keeps everything else', () async {
      rig.lastEvents.show([_event()]);
      var result = await rig.run(const ['edit', '1']);

      result = await _answer(result, 'Renamed');
      result = await _answer(result, '');
      result = await _answer(result, '');
      result = await _answer(result, '');
      await _answer(result, '');

      final saved = rig.calendar.updated.single.$2;
      expect(saved.title, 'Renamed');
      expect(saved.calendarId, _family.id);
    });

    test('reached by #id too', () async {
      rig.lastEvents.show([_event(id: 77)]);

      final result = await rig.run(const ['edit', '#77']);

      expect(result, isA<CommandAsk>());
    });
  });

  group('rm', () {
    test('with nothing shown yet, says so', () async {
      expect(_lines(await rig.run(const ['rm', '1'])), [Messages.eventNoList]);
    });

    test('without --confirm, offers to fill the confirming command', () async {
      rig.lastEvents.show([_event(id: 9, title: 'Standup')]);

      final result = await rig.run(const ['rm', '1']);

      expect(result, isA<CommandFailure>());
      final block = (result as CommandFailure).block! as ChoiceBlock;
      final option = block.groups.single.options.single;
      expect(option.fill, isTrue);
      expect(option.command, 'event rm #9 --confirm');
      expect(rig.calendar.deleted, isEmpty);
    });

    test('--confirm deletes it', () async {
      rig.lastEvents.show([_event(id: 9, title: 'Standup')]);

      final result = await rig.run(const ['rm', '1', '--confirm']);

      expect(rig.calendar.deleted, [9]);
      final notice = (result as CommandOutput).block! as NoticeBlock;
      expect(notice.kind, NoticeKind.success);
    });

    test('one already gone is not treated as a failure', () async {
      rig.lastEvents.show([_event(id: 9)]);
      rig.calendar.deleteResult = const CalendarEventAlreadyGone();

      final result = await rig.run(const ['rm', '#9', '--confirm']);

      expect(result, isA<CommandOutput>());
      expect(_lines(result), [Messages.eventGone]);
    });

    test('an unknown target fails', () async {
      rig.lastEvents.show([_event()]);

      expect(_lines(await rig.run(const ['rm', '5'])), [
        Messages.eventNotFound('5'),
      ]);
    });
  });

  test('anything else shows the usage', () async {
    expect(_lines(await rig.run(const [])), Messages.eventUsage);
    expect(_lines(await rig.run(const ['delete', '1'])), Messages.eventUsage);
  });

  group('suggestions', () {
    test('offers the subcommands by prefix', () {
      final suggest = rig.command.argSuggestions!;

      expect(suggest('', const []), ['add', 'edit', 'rm']);
      expect(suggest('e', const []), ['edit']);
      expect(suggest('x', const []), isEmpty);
    });

    test('offers nothing after the subcommand', () {
      expect(rig.command.argSuggestions!('add Dentist', const []), isEmpty);
    });
  });

  test('every help line fits a phone screen', () {
    final lines = [
      rig.command.usage,
      rig.command.description,
      ...rig.command.usageForms,
      ...rig.command.examples,
      ...rig.command.notes,
    ];
    for (final line in lines) {
      expect(line.length, lessThanOrEqualTo(36), reason: line);
    }
  });

  test('is remembered by name only, not the whole line', () {
    expect(rig.command.history, HistoryPolicy.name);
  });
}
