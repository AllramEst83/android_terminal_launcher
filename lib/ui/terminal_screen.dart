import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/prompt_filler.dart';
import 'package:android_terminal_launcher/ui/prompt_input.dart';
import 'package:android_terminal_launcher/ui/terminal_log.dart';
import 'package:flutter/material.dart';

/// The whole home screen: the log above, the prompt below. It only renders
/// session state and forwards input. It also joins the two: a button in a card
/// in the log can put a command in the prompt.
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key, required this.session});

  final TerminalSession session;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _filler = PromptFiller();

  @override
  Widget build(BuildContext context) {
    // A launcher must never exit on back.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: TerminalLog(
                  session: widget.session,
                  onFill: _filler.fill,
                ),
              ),
              PromptInput(
                onSubmit: widget.session.submit,
                onSuggest: widget.session.suggest,
                filler: _filler,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
