import 'package:android_terminal_launcher/terminal/log_line.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter/material.dart';

/// Renders the session's log, newest line at the bottom. The list is
/// `reverse`d so it stays pinned to the newest line without a scroll
/// controller to manage.
class TerminalLog extends StatelessWidget {
  const TerminalLog({super.key, required this.session});

  final TerminalSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final lines = session.lines;
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: lines.length,
          findChildIndexCallback: (key) {
            // Ids are contiguous, so a key maps straight back to its index.
            if (key is! ValueKey<int> || lines.isEmpty) return null;
            final index = lines.length - 1 - (key.value - lines.first.id);
            return index >= 0 && index < lines.length ? index : null;
          },
          itemBuilder: (context, index) {
            final line = lines[lines.length - 1 - index];
            return _LogLineView(key: ValueKey(line.id), line: line);
          },
        );
      },
    );
  }
}

class _LogLineView extends StatelessWidget {
  const _LogLineView({super.key, required this.line});

  final LogLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge;
    final style = switch (line.kind) {
      LogKind.input => base?.copyWith(fontWeight: FontWeight.bold),
      LogKind.output => base,
      LogKind.error => base?.copyWith(color: theme.colorScheme.error),
    };
    return Text(line.text, style: style);
  }
}
