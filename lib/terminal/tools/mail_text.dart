import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/mail_service.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_text.dart';

/// Widths that keep a message on two lines of about 36 characters.
const _whenWidth = 8;
const _senderWidth = 18;
const _subjectWidth = 28;
const _subjectIndent = '       ';

/// [text] cut to [max] characters with a `…` where it was cut.
String clip(String text, int max) =>
    text.length <= max ? text : '${text.substring(0, max - 1)}…';

/// `1,234`.
String groupDigits(int value) =>
    value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

/// When a message was sent, as short as it can be and still be clear: the time
/// today, the weekday within the last week, else the day, with the year only
/// when it is not this one. Empty if [date] is null.
String mailWhen(DateTime? date, DateTime now) {
  if (date == null) return '';
  final today = startOfDay(now);
  final day = startOfDay(date);
  if (day == today) {
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
  // A message from the future (a wrong clock) is shown as a plain date.
  if (day.isBefore(today) && !day.isBefore(addDays(today, -6))) {
    return shortWeekday(day);
  }
  final label = '${day.day} ${shortMonth(day)}';
  return day.year == today.year ? label : '${shortMonth(day)} ${day.year}';
}

/// The subject to show: `(no subject)` for an empty one.
String mailSubject(MailMessage message) =>
    message.subject.isEmpty ? Messages.mailNoSubject : message.subject;

/// `latest 20 of 1,234, 7 unread`.
String mailSummary(MailMessages found) => Messages.mailSummary(
  found.messages.length,
  found.total,
  groupDigits(found.total),
  found.unread,
);

/// The plain form: a summary, then two lines a message.
///
/// ```
/// 1 * 14:05  Anna Berg
///        Lunch tomorrow?
/// ```
/// `*` marks an unread one.
List<String> mailLines(MailMessages found, DateTime now) => [
  mailSummary(found),
  for (var i = 0; i < found.messages.length; i++) ...[
    _first(i + 1, found.messages[i], now),
    '$_subjectIndent${clip(mailSubject(found.messages[i]), _subjectWidth)}',
  ],
];

String _first(int number, MailMessage message, DateTime now) =>
    '${number.toString().padLeft(2)} ${message.unread ? '*' : ' '} '
    '${mailWhen(message.date, now).padRight(_whenWidth)} '
    '${clip(message.from, _senderWidth)}';
