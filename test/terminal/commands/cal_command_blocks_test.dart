import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/cal_command.dart';
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
  color: 0xFF336699,
);

Future<CommandOutput> _run(List<String> args) async {
  final calendar = FakeCalendarService(CalendarEvents([_lunch]));
  final result = await calCommand(calendar).run(
    CommandContext(
      args: args,
      apps: FakeAppRepository(),
      commands: const [],
      now: () => _now,
    ),
  );
  return result as CommandOutput;
}

void main() {
  test('the month comes with a month block beside its text grid', () async {
    final result = await _run([]);

    final block = result.block as MonthBlock;
    expect(block.title, 'September 2026');
    expect(result.lines.first.trim(), 'September 2026');
    expect(result.columns, isNotNull);
  });

  test('the week is an agenda of seven days from Monday', () async {
    final block = (await _run(['week'])).block as AgendaBlock;

    expect(block.days, hasLength(7));
    expect(block.days.first.label, 'Mon 21 Sep');
    expect(block.days.last.label, 'Sun 27 Sep');
    expect(block.days[5].today, isTrue);
    expect(block.days[5].entries.single.title, 'Lunch');
    expect(block.days[5].entries.single.color, 0xFF336699);
  });

  test('a day is an agenda of one day, also by bare date and word', () async {
    for (final args in [
      ['day'],
      ['today'],
      ['2026-09-26'],
    ]) {
      final block = (await _run(args)).block as AgendaBlock;

      expect(block.days.single.label, 'Sat 26 Sep', reason: '$args');
      expect(block.days.single.entries.single.phase, EntryPhase.past);
    }
  });

  test('--plain gives the text only, wherever it is put', () async {
    for (final args in [
      ['--plain'],
      ['week', '--plain'],
      ['--plain', 'tomorrow'],
      ['day', '2026-09-26', '--plain'],
    ]) {
      final result = await _run(args);

      expect(result.block, isNull, reason: '$args');
      expect(result.lines, isNotEmpty, reason: '$args');
    }
  });

  test('--plain leaves the request itself alone', () async {
    final plain = await _run(['week', '--plain']);
    final rich = await _run(['week']);

    expect(plain.lines, rich.lines);
  });

  test('the text form is the same with and without a block', () async {
    final plain = await _run(['--plain']);
    final rich = await _run([]);

    expect(plain.lines, rich.lines);
    expect(plain.columns, rich.columns);
  });
}
