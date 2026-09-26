import 'package:android_terminal_launcher/services/currency_rates.dart';
import 'package:android_terminal_launcher/services/text_tv.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/commands/cal_command.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/commands/convert_command.dart';
import 'package:android_terminal_launcher/terminal/commands/mail_command.dart';
import 'package:android_terminal_launcher/terminal/commands/texttv_command.dart';
import 'package:android_terminal_launcher/terminal/commands/weather_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_calendar_service.dart';
import '../fakes/fake_http_fetcher.dart';
import '../fakes/fake_location_service.dart';
import '../fakes/fake_mail_service.dart';
import '../fakes/in_memory_local_store.dart';

void main() {
  final fetcher = FakeHttpFetcher();
  final store = InMemoryLocalStore();

  test('the commands that go online show a spinner', () {
    final slow = <Command>[
      weatherCommand(
        Weather(fetcher: fetcher, store: store),
        FakeLocationService(),
      ),
      textTvCommand(TextTv(fetcher: fetcher)),
      mailCommand(FakeMailService()),
    ];

    for (final command in slow) {
      expect(command.spinner, isTrue, reason: command.name);
    }
  });

  test('the ones that answer at once do not', () {
    final quick = <Command>[
      ...defaultCommands,
      calCommand(FakeCalendarService()),
      convertCommand(CurrencyRates(fetcher: fetcher, store: store)),
    ];

    for (final command in quick) {
      expect(command.spinner, isFalse, reason: command.name);
    }
  });
}
