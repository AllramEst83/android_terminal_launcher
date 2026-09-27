import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/services/local_store.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_text.dart';
import 'package:android_terminal_launcher/terminal/tools/event_input.dart';
import 'package:android_terminal_launcher/terminal/tools/last_calendar_events.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';

const _subcommands = ['add', 'edit', 'rm'];
const _lastCalendarKey = 'event_last_calendar';
const _confirmFlag = '--confirm';
const _defaultLength = '1h';

/// `event add`, `event edit <n|#id>`, `event rm <n|#id>`: creates, changes and
/// removes calendar events, one question at a time (title, description,
/// start, end, calendar), reusing whatever `cal day`/`cal week` last showed to
/// name one by number.
Command eventCommand(
  CalendarService calendar,
  LastCalendarEvents lastEvents,
  LocalStore store,
) => Command(
  name: 'event',
  description: 'Add, edit or remove events',
  usage: 'event add|edit|rm',
  forms: ['event add [title]', 'event edit <n|#id>', 'event rm <n|#id>'],
  examples: ['event add', 'event add "Dentist"', 'event rm 2'],
  notes: [
    'a guided form: one question at',
    '  a time; cancel to stop',
    'n|#id: from the last cal day or',
    '  cal week; #id survives a new',
    '  list, n is its position there',
    'rm asks first; --confirm removes',
  ],
  run: (context) =>
      _event(calendar, lastEvents, store, context.args, context.now()),
  argSuggestions: _suggestArgs,
  // The arguments are the user's own words (a title) or an id, not a line
  // worth replaying.
  history: HistoryPolicy.name,
);

List<String> _suggestArgs(String partial, List<AppInfo> apps) {
  final words = partial.split(' ');
  if (words.length != 1) return const [];
  final typed = words.first.toLowerCase();
  return [
    for (final option in _subcommands)
      if (option.startsWith(typed)) option,
  ];
}

Future<CommandResult> _event(
  CalendarService calendar,
  LastCalendarEvents lastEvents,
  LocalStore store,
  List<String> args,
  DateTime now,
) async {
  if (args.isEmpty) return const CommandFailure(Messages.eventUsage);
  final rest = args.sublist(1);
  return switch (args.first.toLowerCase()) {
    'add' => _add(calendar, store, rest, now),
    'edit' when rest.length == 1 => _edit(
      calendar,
      lastEvents,
      store,
      rest.single,
      now,
    ),
    'rm' when rest.isNotEmpty => _remove(calendar, lastEvents, rest),
    _ => const CommandFailure(Messages.eventUsage),
  };
}

// ---- add / edit: the guided form ----

CommandResult _add(
  CalendarService calendar,
  LocalStore store,
  List<String> rest,
  DateTime now,
) {
  final given = rest.isEmpty ? null : rest.join(' ').trim();
  return given == null || given.isEmpty
      ? _askTitle(calendar, store, now)
      : _askDescription(calendar, store, now, title: given);
}

Future<CommandResult> _edit(
  CalendarService calendar,
  LastCalendarEvents lastEvents,
  LocalStore store,
  String target,
  DateTime now,
) async {
  if (lastEvents.isEmpty) return CommandFailure.single(Messages.eventNoList);
  final event = lastEvents.find(target);
  if (event == null) {
    return CommandFailure.single(Messages.eventNotFound(target));
  }
  return _askTitle(calendar, store, now, current: event);
}

CommandAsk _askTitle(
  CalendarService calendar,
  LocalStore store,
  DateTime now, {
  CalendarEvent? current,
  String? error,
}) {
  final prompt =
      error ??
      (current == null
          ? Messages.eventTitlePrompt
          : Messages.eventTitlePromptEdit(current.title));
  return CommandAsk(prompt, (answer) async {
    final trimmed = answer.trim();
    final title = trimmed.isEmpty ? current?.title : trimmed;
    if (title == null || title.isEmpty) {
      return _askTitle(
        calendar,
        store,
        now,
        current: current,
        error: Messages.eventTitleNeeded,
      );
    }
    return _askDescription(
      calendar,
      store,
      now,
      current: current,
      title: title,
    );
  });
}

CommandAsk _askDescription(
  CalendarService calendar,
  LocalStore store,
  DateTime now, {
  CalendarEvent? current,
  required String title,
}) {
  final prompt = current == null
      ? Messages.eventDescriptionPrompt
      : Messages.eventDescriptionPromptEdit(
          current.description?.isEmpty ?? true
              ? '(none)'
              : current.description!,
        );
  return CommandAsk(prompt, (answer) async {
    final trimmed = answer.trim();
    final description = trimmed.isEmpty ? current?.description : trimmed;
    return _askStart(
      calendar,
      store,
      now,
      current: current,
      title: title,
      description: description,
    );
  });
}

CommandAsk _askStart(
  CalendarService calendar,
  LocalStore store,
  DateTime now, {
  CalendarEvent? current,
  required String title,
  required String? description,
  String? error,
}) {
  final prompt =
      error ??
      (current == null
          ? Messages.eventStartPrompt
          : Messages.eventStartPromptEdit(_when(current.start)));
  return CommandAsk(
    prompt,
    suggestions: (partial) => _startSuggestions(partial),
    (answer) async {
      final trimmed = answer.trim();
      final start = trimmed.isEmpty
          ? current?.start
          : parseEventStart(trimmed, now);
      if (start == null) {
        return _askStart(
          calendar,
          store,
          now,
          current: current,
          title: title,
          description: description,
          error: Messages.eventBadStart(trimmed),
        );
      }
      return _askEnd(
        calendar,
        store,
        now,
        current: current,
        title: title,
        description: description,
        start: start,
      );
    },
  );
}

List<String> _startSuggestions(String partial) {
  const options = ['today', 'tomorrow', '09:00', '12:00', '18:00'];
  final typed = partial.trim().toLowerCase();
  return [
    for (final option in options)
      if (option.startsWith(typed)) option,
  ];
}

CommandAsk _askEnd(
  CalendarService calendar,
  LocalStore store,
  DateTime now, {
  CalendarEvent? current,
  required String title,
  required String? description,
  required DateTime start,
  String? error,
}) {
  final prompt =
      error ??
      (current == null
          ? Messages.eventEndPrompt(_defaultLength)
          : Messages.eventEndPromptEdit(_when(current.end)));
  return CommandAsk(
    prompt,
    suggestions: (partial) => _endSuggestions(partial),
    busy: true,
    (answer) async {
      final trimmed = answer.trim();
      final DateTime? end;
      if (trimmed.isEmpty) {
        end = current?.end ?? parseEventEnd(_defaultLength, start, now);
      } else {
        end = parseEventEnd(trimmed, start, now);
      }
      if (end == null || !end.isAfter(start)) {
        return _askEnd(
          calendar,
          store,
          now,
          current: current,
          title: title,
          description: description,
          start: start,
          error: Messages.eventBadEnd(trimmed),
        );
      }
      return _startCalendarStep(
        calendar,
        store,
        current: current,
        title: title,
        description: description,
        start: start,
        end: end,
      );
    },
  );
}

List<String> _endSuggestions(String partial) {
  const options = ['1h', '30m', '2h', '15m'];
  final typed = partial.trim().toLowerCase();
  return [
    for (final option in options)
      if (option.startsWith(typed)) option,
  ];
}

Future<CommandResult> _startCalendarStep(
  CalendarService calendar,
  LocalStore store, {
  CalendarEvent? current,
  required String title,
  required String? description,
  required DateTime start,
  required DateTime end,
}) async {
  final result = await calendar.writableCalendars();
  return switch (result) {
    CalendarList(:final calendars) => await _askCalendar(
      calendar,
      store,
      calendars,
      current: current,
      title: title,
      description: description,
      start: start,
      end: end,
    ),
    CalendarListDenied(:final permanent) => CommandFailure(
      Messages.permissionFailure(Messages.calendar, permanent: permanent),
    ),
    CalendarListUnavailable(:final reason) => CommandFailure.single(
      Messages.eventError(reason),
    ),
  };
}

Future<CommandResult> _askCalendar(
  CalendarService calendar,
  LocalStore store,
  List<CalendarInfo> calendars, {
  CalendarEvent? current,
  required String title,
  required String? description,
  required DateTime start,
  required DateTime end,
  String? error,
}) async {
  if (calendars.isEmpty) {
    return CommandFailure.single(Messages.eventNoCalendars);
  }
  final fallback = await _defaultCalendar(store, calendars, current);
  final prompt = error ?? Messages.eventCalendarPrompt(fallback.name);
  return CommandAsk(
    prompt,
    suggestions: (partial) =>
        _calendarSuggestions(partial, calendars, fallback),
    busy: true,
    (answer) async {
      final trimmed = answer.trim();
      final chosen = trimmed.isEmpty
          ? fallback
          : _matchCalendar(trimmed, calendars);
      if (chosen == null) {
        return _askCalendar(
          calendar,
          store,
          calendars,
          current: current,
          title: title,
          description: description,
          start: start,
          end: end,
          error: Messages.eventBadCalendar(trimmed),
        );
      }
      return _save(
        calendar,
        store,
        current: current,
        title: title,
        description: description,
        start: start,
        end: end,
        chosen: chosen,
      );
    },
  );
}

List<String> _calendarSuggestions(
  String partial,
  List<CalendarInfo> calendars,
  CalendarInfo fallback,
) {
  final typed = partial.trim().toLowerCase();
  final names = [
    fallback.name,
    for (final info in calendars)
      if (info.name != fallback.name) info.name,
  ];
  return [
    for (final name in names)
      if (name.toLowerCase().startsWith(typed)) name,
  ];
}

CalendarInfo? _matchCalendar(String answer, List<CalendarInfo> calendars) {
  final typed = answer.toLowerCase();
  return calendars
      .where(
        (info) =>
            info.name.toLowerCase() == typed ||
            info.accountName.toLowerCase() == typed,
      )
      .firstOrNull;
}

/// Editing keeps the event's own calendar by name when it still exists among
/// the writable ones; otherwise (and always for adding) the last one used,
/// else the account's own primary calendar — never a hardcoded address.
Future<CalendarInfo> _defaultCalendar(
  LocalStore store,
  List<CalendarInfo> calendars,
  CalendarEvent? current,
) async {
  final currentName = current?.calendar;
  if (currentName != null) {
    final match = calendars
        .where((info) => info.name == currentName)
        .firstOrNull;
    if (match != null) return match;
  }
  final lastId = await _lastCalendarId(store);
  if (lastId != null) {
    final match = calendars.where((info) => info.id == lastId).firstOrNull;
    if (match != null) return match;
  }
  return calendars.where((info) => info.primary).firstOrNull ?? calendars.first;
}

Future<int?> _lastCalendarId(LocalStore store) async {
  try {
    final raw = await store.read(_lastCalendarKey);
    return raw is int ? raw : null;
  } on Object {
    return null;
  }
}

Future<void> _rememberCalendar(LocalStore store, int id) async {
  try {
    await store.write(_lastCalendarKey, id);
  } on Object {
    // A convenience default, not a promise: losing it is never an error.
  }
}

Future<CommandResult> _save(
  CalendarService calendar,
  LocalStore store, {
  CalendarEvent? current,
  required String title,
  required String? description,
  required DateTime start,
  required DateTime end,
  required CalendarInfo chosen,
}) async {
  await _rememberCalendar(store, chosen.id);
  final event = NewCalendarEvent(
    calendarId: chosen.id,
    title: title,
    description: description,
    start: start,
    end: end,
  );
  final result = current == null
      ? await calendar.createEvent(event)
      : await calendar.updateEvent(current.id, event);
  return switch (result) {
    CalendarEventSaved() => noticeOutput(
      current == null
          ? Messages.eventAdded(title)
          : Messages.eventUpdated(title),
    ),
    CalendarWriteDenied(:final permanent) => CommandFailure(
      Messages.permissionFailure(Messages.calendar, permanent: permanent),
    ),
    CalendarWriteFailed(:final reason) => CommandFailure.single(
      Messages.eventError(reason),
    ),
  };
}

String _when(DateTime time) => '${dayHeading(time)} ${_hhmm(time)}';

String _hhmm(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

// ---- rm: resolve, ask to confirm, then act ----

Future<CommandResult> _remove(
  CalendarService calendar,
  LastCalendarEvents lastEvents,
  List<String> args,
) async {
  final confirm = args.contains(_confirmFlag);
  final target = args.where((arg) => arg != _confirmFlag).toList();
  if (target.length != 1) return const CommandFailure(Messages.eventUsage);
  if (lastEvents.isEmpty) return CommandFailure.single(Messages.eventNoList);
  final event = lastEvents.find(target.single);
  if (event == null) {
    return CommandFailure.single(Messages.eventNotFound(target.single));
  }
  if (!confirm) return _confirmRemove(event);

  final result = await calendar.deleteEvent(event.id);
  return switch (result) {
    CalendarEventDeleted() => noticeOutput(
      '${Messages.eventDeleted}: ${event.title.isEmpty ? '(no title)' : event.title}',
    ),
    CalendarEventAlreadyGone() => noticeOutput(
      Messages.eventGone,
      kind: NoticeKind.info,
    ),
    CalendarDeleteDenied(:final permanent) => CommandFailure(
      Messages.permissionFailure(Messages.calendar, permanent: permanent),
    ),
    CalendarDeleteFailed(:final reason) => CommandFailure.single(
      Messages.eventError(reason),
    ),
  };
}

CommandResult _confirmRemove(CalendarEvent event) {
  final title = event.title.isEmpty ? '(no title)' : event.title;
  final summary = '$title — ${_when(event.start)}';
  final confirmCommand = 'event rm #${event.id} $_confirmFlag';
  return CommandFailure(
    ['Delete this event?', '  $summary'],
    block: ChoiceBlock(
      title: 'Delete this event?',
      layout: ChoiceLayout.rows,
      groups: [
        ChoiceGroup(
          options: [
            ChoiceOption(
              label: Messages.eventDeleteConfirm,
              description: summary,
              fill: true,
              command: confirmCommand,
            ),
          ],
        ),
      ],
    ),
  );
}
