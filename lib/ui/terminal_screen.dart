import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/prompt_input.dart';
import 'package:android_terminal_launcher/ui/terminal_log.dart';
import 'package:flutter/material.dart';

/// The whole home screen: the log above, the prompt below. It only renders
/// session state and forwards input.
class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key, required this.session});

  final TerminalSession session;

  @override
  Widget build(BuildContext context) {
    // A launcher must never exit on back.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: TerminalLog(session: session)),
              PromptInput(onSubmit: session.submit, onSuggest: session.suggest),
            ],
          ),
        ),
      ),
    );
  }
}
