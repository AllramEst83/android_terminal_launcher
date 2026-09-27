import 'dart:async';

import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:flutter/services.dart';

/// [CalendarService] backed by the Kotlin `CalendarChannelHandler`, after
/// asking [PermissionService] for `calendar`. The only file that knows about
/// the channel.
class AndroidCalendarService implements CalendarService {
  const AndroidCalendarService({
    required this._permissions,
    this._channel = const MethodChannel(channelName),
    this.timeout = const Duration(seconds: 15),
  });

  static const channelName =
      'com.codedbykay.android_terminal_launcher/calendar';

  final PermissionService _permissions;
  final MethodChannel _channel;

  /// Only guards against a reply that never comes.
  final Duration timeout;

  @override
  Future<CalendarResult> events({
    required DateTime from,
    required DateTime to,
  }) async {
    final status = await _permissions.request(AppPermission.calendar);
    if (status != PermissionStatus.granted) {
      return CalendarDenied(
        permanent: status == PermissionStatus.permanentlyDenied,
      );
    }
    try {
      // All-day events are stored as UTC midnights, so near the edge of the
      // range one can sit up to a day outside it in UTC terms. Ask for a day
      // either side and filter properly once the times are local.
      final raw = await _channel
          .invokeListMethod<Map<Object?, Object?>>('events', {
            'begin': from
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
            'end': to.add(const Duration(days: 1)).millisecondsSinceEpoch,
          })
          .timeout(timeout);
      final events = <CalendarEvent>[
        for (final entry in raw ?? const <Map<Object?, Object?>>[])
          ?_parse(entry),
      ].where((event) => _overlaps(event, from, to)).toList()..sort(_byStart);
      return CalendarEvents(List.unmodifiable(events));
    } on PlatformException catch (error) {
      return switch (error.code) {
        'NO_PERMISSION' => const CalendarDenied(permanent: false),
        _ => const CalendarUnavailable('could not read the calendar'),
      };
    } on MissingPluginException {
      return const CalendarUnavailable('calendar is not supported here');
    } on TimeoutException {
      return const CalendarUnavailable('the calendar did not answer');
    }
  }

  @override
  Future<CalendarListResult> writableCalendars() async {
    final status = await _permissions.request(AppPermission.calendar);
    if (status != PermissionStatus.granted) {
      return CalendarListDenied(
        permanent: status == PermissionStatus.permanentlyDenied,
      );
    }
    try {
      final raw = await _channel
          .invokeListMethod<Map<Object?, Object?>>('calendars')
          .timeout(timeout);
      final calendars = <CalendarInfo>[
        for (final entry in raw ?? const <Map<Object?, Object?>>[])
          ?_parseCalendar(entry),
      ];
      return CalendarList(List.unmodifiable(calendars));
    } on PlatformException catch (error) {
      return switch (error.code) {
        'NO_PERMISSION' => const CalendarListDenied(permanent: false),
        _ => const CalendarListUnavailable('could not read the calendars'),
      };
    } on MissingPluginException {
      return const CalendarListUnavailable('calendar is not supported here');
    } on TimeoutException {
      return const CalendarListUnavailable('the calendar did not answer');
    }
  }

  @override
  Future<CalendarWriteResult> createEvent(NewCalendarEvent event) =>
      _write('insertEvent', event);

  @override
  Future<CalendarWriteResult> updateEvent(int id, NewCalendarEvent event) =>
      _write('updateEvent', event, id: id);

  Future<CalendarWriteResult> _write(
    String method,
    NewCalendarEvent event, {
    int? id,
  }) async {
    final status = await _permissions.request(AppPermission.calendarWrite);
    if (status != PermissionStatus.granted) {
      return CalendarWriteDenied(
        permanent: status == PermissionStatus.permanentlyDenied,
      );
    }
    try {
      final result = await _channel
          .invokeMethod<int>(method, {
            'id': ?id,
            'calendarId': event.calendarId,
            'title': event.title,
            'description': event.description,
            'begin': event.start.millisecondsSinceEpoch,
            'end': event.end.millisecondsSinceEpoch,
          })
          .timeout(timeout);
      if (result == null) {
        return const CalendarWriteFailed('could not save the event');
      }
      return CalendarEventSaved(result);
    } on PlatformException catch (error) {
      return switch (error.code) {
        'NO_PERMISSION' => const CalendarWriteDenied(permanent: false),
        'NOT_FOUND' => const CalendarWriteFailed('that event is gone'),
        _ => const CalendarWriteFailed('could not save the event'),
      };
    } on MissingPluginException {
      return const CalendarWriteFailed('calendar is not supported here');
    } on TimeoutException {
      return const CalendarWriteFailed('the calendar did not answer');
    }
  }

  @override
  Future<CalendarDeleteResult> deleteEvent(int id) async {
    final status = await _permissions.request(AppPermission.calendarWrite);
    if (status != PermissionStatus.granted) {
      return CalendarDeleteDenied(
        permanent: status == PermissionStatus.permanentlyDenied,
      );
    }
    try {
      final removed = await _channel
          .invokeMethod<bool>('deleteEvent', {'id': id})
          .timeout(timeout);
      return removed == true
          ? const CalendarEventDeleted()
          : const CalendarEventAlreadyGone();
    } on PlatformException catch (error) {
      return switch (error.code) {
        'NO_PERMISSION' => const CalendarDeleteDenied(permanent: false),
        _ => const CalendarDeleteFailed('could not delete the event'),
      };
    } on MissingPluginException {
      return const CalendarDeleteFailed('calendar is not supported here');
    } on TimeoutException {
      return const CalendarDeleteFailed('the calendar did not answer');
    }
  }

  static CalendarInfo? _parseCalendar(Map<Object?, Object?> entry) {
    final id = entry['id'];
    final name = entry['name'];
    final accountName = entry['accountName'];
    if (id is! int || name is! String || accountName is! String) return null;
    return CalendarInfo(
      id: id,
      name: name.trim().isEmpty ? accountName : name.trim(),
      accountName: accountName,
      primary: entry['primary'] == true,
    );
  }

  CalendarEvent? _parse(Map<Object?, Object?> entry) {
    final id = entry['id'];
    final begin = entry['begin'];
    final end = entry['end'];
    if (id is! int || begin is! int || end is! int) return null;
    final allDay = entry['allDay'] == true;
    final start = _local(begin, allDay);
    var stop = _local(end, allDay);
    // A broken range would never show; make it the shortest sensible one.
    if (stop.isBefore(start)) {
      stop = allDay ? DateTime(start.year, start.month, start.day + 1) : start;
    }
    final title = entry['title'];
    return CalendarEvent(
      id: id,
      title: title is String ? title.trim() : '',
      start: start,
      end: stop,
      allDay: allDay,
      location: _text(entry['location']),
      calendar: _text(entry['calendar']),
      color: _color(entry['color']),
      description: _text(entry['description']),
    );
  }

  /// A timed event is an instant; an all-day one is a *date*, stored as UTC
  /// midnight, whose calendar day must not shift with the time zone.
  static DateTime _local(int millis, bool allDay) {
    if (!allDay) return DateTime.fromMillisecondsSinceEpoch(millis);
    final utc = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    return DateTime(utc.year, utc.month, utc.day);
  }

  static bool _overlaps(CalendarEvent event, DateTime from, DateTime to) =>
      event.start.isBefore(to) &&
      (event.end.isAfter(from) ||
          // An event with no length is a moment: it is in range if it is in it.
          (event.end == event.start && !event.start.isBefore(from)));

  static int _byStart(CalendarEvent a, CalendarEvent b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  /// Android colours are signed 32-bit ints, so may arrive negative. Keep the
  /// RGB and make it opaque: the value is then the same 0xFFRRGGBB whichever
  /// way it came, and a calendar colour is never a transparency.
  static int? _color(Object? value) =>
      value is int ? (value & 0xFFFFFF) | 0xFF000000 : null;

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}
