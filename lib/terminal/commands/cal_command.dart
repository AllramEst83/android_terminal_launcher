import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/plain_flag.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_dates.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_text.dart';

const _views = ['day', 'week', 'month'];
const _dayWords = ['today', 'tomorrow', 'yesterday'];

/// `cal` for this month, `cal week`, `cal tomorrow`, `cal 2026-10`,
/// `cal day 2026-09-30`: the phone's calendar, read-only.
Command calCommand(CalendarService calendar) => Command(
  name: 'cal',
  aliases: ['calendar'],
  description: 'Show your calendar',
  usage: 'cal [day|week|month]',
  forms: [
    'cal',
    'cal month [2026-10]',
    'cal week [date]',
    'cal day [date]',
    'cal today|tomorrow',
    'cal <date>',
  ],
  examples: ['cal', 'cal week', 'cal tomorrow', 'cal 2026-10-03'],
  notes: [
    'date: today, tomorrow, yesterday',
    '  or 2026-09-30',
    'month: this, next, last or 2026-10',
    '--plain: text only, this once',
    '> today, * a day with events',
  ],
  run: (context) => _cal(calendar, context.args, context.now()),
  argSuggestions: _suggestArgs,
);

List<String> _suggestArgs(String partial, List<AppInfo> apps) {
  final words = partial.split(' ');
  final typed = words.last.toLowerCase();
  if (words.length == 1) {
    return [
      for (final option in [..._views, ..._dayWords])
        if (option.startsWith(typed)) option,
    ];
  }
  if (words.length == 2) {
    final options = switch (words.first.toLowerCase()) {
      'month' => const ['this', 'next', 'last'],
      'day' || 'week' => _dayWords,
      _ => const <String>[],
    };
    return [
      for (final option in options)
        if (option.startsWith(typed)) '${words.first} $option',
    ];
  }
  return const [];
}

Future<CommandResult> _cal(
  CalendarService calendar,
  List<String> allArgs,
  DateTime now,
) async {
  final (:args, :plain) = splitPlainFlag(allArgs);
  final today = startOfDay(now);
  final first = args.isEmpty ? 'month' : args.first.toLowerCase();
  final rest = args.isEmpty ? const <String>[] : args.sublist(1);
  if (rest.length > 1) return const CommandFailure(Messages.calUsage);

  // A view is chosen by its word, or a bare date/month stands for its view.
  final String view;
  final String? argument;
  if (_views.contains(first)) {
    view = first;
    argument = rest.isEmpty ? null : rest.first;
  } else if (rest.isEmpty && args.isNotEmpty) {
    argument = args.first;
    view = parseDay(argument, now) != null ? 'day' : 'month';
  } else {
    view = 'month';
    argument = null;
    if (args.isNotEmpty) return const CommandFailure(Messages.calUsage);
  }

  if (view == 'month') {
    final month = argument == null
        ? DateTime(now.year, now.month)
        : parseMonth(argument, now);
    if (month == null) {
      return CommandFailure.single(Messages.calBadMonth(argument!));
    }
    final result = await calendar.events(
      from: month,
      to: DateTime(month.year, month.month + 1),
    );
    return _show(
      result,
      (events) => CommandOutput(
        monthGrid(events, month, today),
        columns: monthGridColumns,
        block: plain ? null : monthBlock(events, month, today),
      ),
    );
  }

  final day = argument == null ? today : parseDay(argument, now);
  if (day == null) return CommandFailure.single(Messages.calBadDate(argument!));
  if (view == 'week') {
    final monday = startOfWeek(day);
    final result = await calendar.events(from: monday, to: addDays(monday, 7));
    return _show(
      result,
      (events) => CommandOutput(
        weekView(events, day, today),
        block: plain
            ? null
            : agendaBlock(events, [
                for (var i = 0; i < 7; i++) addDays(monday, i),
              ], now),
      ),
    );
  }
  final result = await calendar.events(from: day, to: addDays(day, 1));
  return _show(
    result,
    (events) => CommandOutput(
      dayView(events, day),
      block: plain ? null : agendaBlock(events, [day], now),
    ),
  );
}

CommandResult _show(
  CalendarResult result,
  CommandOutput Function(List<CalendarEvent> events) render,
) => switch (result) {
  CalendarEvents(:final events) => render(events),
  CalendarDenied(:final permanent) => CommandFailure(
    Messages.permissionFailure(Messages.calendar, permanent: permanent),
  ),
  CalendarUnavailable(:final reason) => CommandFailure.single(
    Messages.calError(reason),
  ),
};
