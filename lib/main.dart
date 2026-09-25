import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/android_app_repository.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Must match `applicationId` in `android/app/build.gradle`.
const _appId = 'com.codedbykay.android_terminal_launcher';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Lives for the whole process, so it is never disposed.
  final session = TerminalSession(
    registry: CommandRegistry.fromProviders(defaultProviders),
    apps: AndroidAppRepository(ownPackage: _appId),
    banner: [Messages.welcome],
  );
  runApp(App(session: session));
}
