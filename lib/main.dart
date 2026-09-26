import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/android_app_repository.dart';
import 'package:android_terminal_launcher/services/currency_rates.dart';
import 'package:android_terminal_launcher/services/entry_store.dart';
import 'package:android_terminal_launcher/services/io_http_fetcher.dart';
import 'package:android_terminal_launcher/services/shared_preferences_local_store.dart';
import 'package:android_terminal_launcher/services/text_tv.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/providers/appearance_provider.dart';
import 'package:android_terminal_launcher/terminal/providers/info_provider.dart';
import 'package:android_terminal_launcher/terminal/providers/notes_provider.dart';
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
  // Loaded before the first frame so the saved theme never flashes the default.
  final themes = ThemeController(store: store);
  await themes.load();

  final session = TerminalSession(
    registry: CommandRegistry.fromProviders([
      ...defaultProviders,
      ToolsProvider(
        currency: CurrencyRates(fetcher: fetcher, store: store),
      ),
      InfoProvider(
        textTv: TextTv(fetcher: fetcher),
        weather: Weather(fetcher: fetcher, store: store),
      ),
      AppearanceProvider(themes),
      NotesProvider(
        notes: EntryStore(store: store, key: 'notes'),
        todos: EntryStore(store: store, key: 'todos'),
      ),
    ]),
    apps: AndroidAppRepository(ownPackage: _appId),
    banner: [Messages.welcome],
  );
  runApp(App(session: session, themes: themes));
}
