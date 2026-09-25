import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/terminal_screen.dart';
import 'package:android_terminal_launcher/ui/theme.dart';
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key, required this.session});

  final TerminalSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Messages.appTitle,
      debugShowCheckedModeBanner: false,
      theme: terminalTheme,
      home: TerminalScreen(session: session),
    );
  }
}
