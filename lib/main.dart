import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/android_app_repository.dart';
import 'package:android_terminal_launcher/services/android_calendar_service.dart';
import 'package:android_terminal_launcher/services/android_clock_service.dart';
import 'package:android_terminal_launcher/services/android_contacts_service.dart';
import 'package:android_terminal_launcher/services/android_location_service.dart';
import 'package:android_terminal_launcher/services/android_permission_service.dart';
import 'package:android_terminal_launcher/services/android_phone_service.dart';
import 'package:android_terminal_launcher/services/android_sms_service.dart';
import 'package:android_terminal_launcher/services/currency_rates.dart';
import 'package:android_terminal_launcher/services/entry_store.dart';
import 'package:android_terminal_launcher/services/flutter_secret_store.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/imap_mail_service.dart';
import 'package:android_terminal_launcher/services/io_http_fetcher.dart';
import 'package:android_terminal_launcher/services/mail_account.dart';
import 'package:android_terminal_launcher/services/shared_preferences_local_store.dart';
import 'package:android_terminal_launcher/services/smhi.dart';
import 'package:android_terminal_launcher/services/text_tv.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/services/view_mode_controller.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/command_history.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/providers/appearance_provider.dart';
import 'package:android_terminal_launcher/terminal/providers/calendar_provider.dart';
import 'package:android_terminal_launcher/terminal/providers/clock_provider.dart';
import 'package:android_terminal_launcher/terminal/providers/history_provider.dart';
import 'package:android_terminal_launcher/terminal/providers/info_provider.dart';
import 'package:android_terminal_launcher/terminal/providers/mail_provider.dart';
import 'package:android_terminal_launcher/terminal/providers/notes_provider.dart';
import 'package:android_terminal_launcher/terminal/providers/phone_provider.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Must match `applicationId` in `android/app/build.gradle`.
const _appId = 'com.codedbykay.android_terminal_launcher';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Everything below lives for the whole process, so nothing is disposed.
  final store = SharedPreferencesLocalStore();
  // One fetcher for everything that goes online (Text TV, weather, rates).
  final fetcher = IoHttpFetcher();
  // One permission service for every feature that needs a runtime permission.
  const permissions = AndroidPermissionService();
  // Loaded before the first frame so the saved theme/size never flash the
  // default.
  final themes = ThemeController(store: store);
  final fontSize = FontSizeController(store: store);
  final view = ViewModeController(store: store);
  // The first frame already shows the chips for an empty prompt.
  final history = CommandHistory(store: store);
  await Future.wait([
    themes.load(),
    fontSize.load(),
    view.load(),
    history.load(),
  ]);

  final session = TerminalSession(
    registry: CommandRegistry.fromProviders([
      ...defaultProviders,
      ToolsProvider(
        currency: CurrencyRates(fetcher: fetcher, store: store),
      ),
      InfoProvider(
        textTv: TextTv(fetcher: fetcher),
        weather: Weather(
          fetcher: fetcher,
          store: store,
          preferred: Smhi(fetcher: fetcher),
        ),
        location: AndroidLocationService(permissions: permissions),
      ),
      CalendarProvider(AndroidCalendarService(permissions: permissions)),
      PhoneProvider(
        contacts: AndroidContactsService(permissions: permissions),
        phone: AndroidPhoneService(permissions: permissions),
        sms: AndroidSmsService(permissions: permissions),
      ),
      MailProvider(
        ImapMailService(accounts: MailAccountStore(FlutterSecretStore())),
      ),
      ClockProvider(const AndroidClockService()),
      HistoryProvider(history),
      AppearanceProvider(themes, fontSize, view),
      NotesProvider(
        notes: EntryStore(store: store, key: 'notes'),
        todos: EntryStore(store: store, key: 'todos'),
      ),
    ]),
    apps: AndroidAppRepository(ownPackage: _appId),
    banner: [Messages.welcome],
    view: view,
    history: history,
  );
  runApp(App(session: session, themes: themes, fontSize: fontSize));
}
