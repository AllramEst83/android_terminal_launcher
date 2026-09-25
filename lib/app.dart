import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/terminal_screen.dart';
import 'package:android_terminal_launcher/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class App extends StatelessWidget {
  const App({super.key, required this.session, required this.themes});

  final TerminalSession session;
  final ThemeController themes;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themes,
      builder: (context, _) {
        final theme = themeFor(themes.current);
        return MaterialApp(
          title: Messages.appTitle,
          debugShowCheckedModeBanner: false,
          theme: theme,
          // A terminal changes colour instantly, it does not fade.
          themeAnimationDuration: Duration.zero,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyleFor(theme),
            child: child!,
          ),
          home: TerminalScreen(session: session),
        );
      },
    );
  }
}
