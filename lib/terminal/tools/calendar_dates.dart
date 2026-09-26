import 'package:android_terminal_launcher/terminal/tools/calendar_text.dart';

final _dayPattern = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
final _monthPattern = RegExp(r'^(\d{4})-(\d{1,2})$');

/// A date typed to a calendar command, at midnight, or null when it is not one:
/// `today`, `tomorrow`, `yesterday` or `2026-09-30`. A date that does not exist
/// (`2026-02-31`) is null, not March.
DateTime? parseDay(String text, DateTime now) {
  final word = text.toLowerCase();
  final today = startOfDay(now);
  switch (word) {
    case 'today':
      return today;
    case 'tomorrow':
      return addDays(today, 1);
    case 'yesterday':
      return addDays(today, -1);
  }
  final match = _dayPattern.firstMatch(text);
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  return date.month == month && date.day == day ? date : null;
}

/// The first of a month typed as `2026-10`, or null. `now` is the current
/// month for the words `this` and `next`/`last`.
DateTime? parseMonth(String text, DateTime now) {
  final thisMonth = DateTime(now.year, now.month);
  switch (text.toLowerCase()) {
    case 'this':
      return thisMonth;
    case 'next':
      return DateTime(now.year, now.month + 1);
    case 'last' || 'prev':
      return DateTime(now.year, now.month - 1);
  }
  final match = _monthPattern.firstMatch(text);
  if (match == null) return null;
  final month = int.parse(match[2]!);
  return month >= 1 && month <= 12
      ? DateTime(int.parse(match[1]!), month)
      : null;
}
