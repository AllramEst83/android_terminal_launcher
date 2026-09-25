import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/date_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';

Future<String> _date(DateTime now) async {
  final result = await dateCommand.run(
    CommandContext(
      args: const [],
      apps: FakeAppRepository(),
      commands: const [],
      now: () => now,
    ),
  );
  return (result as CommandOutput).lines.single;
}

void main() {
  test('prints weekday, date and time from the injected clock', () async {
    expect(
      await _date(DateTime(2026, 9, 25, 16, 30, 12)),
      'Fri 2026-09-25 16:30:12',
    );
  });

  test('zero-pads month, day and time fields', () async {
    expect(
      await _date(DateTime(2026, 1, 2, 3, 4, 5)),
      'Fri 2026-01-02 03:04:05',
    );
  });

  test('gets the weekday right at both ends of the week', () async {
    expect((await _date(DateTime(2026, 9, 21))).startsWith('Mon '), isTrue);
    expect((await _date(DateTime(2026, 9, 27))).startsWith('Sun '), isTrue);
  });

  test('time is an alias', () {
    expect(dateCommand.aliases, contains('time'));
  });
}
