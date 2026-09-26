import 'package:android_terminal_launcher/terminal/log_line.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter/material.dart';

/// Keys on the block markers, so tests can find them.
const blockDividerKey = ValueKey('block-divider');
const outputRuleKey = ValueKey('output-rule');

/// Renders the session's log, newest line at the bottom. The list is
/// `reverse`d so it stays pinned to the newest line without a scroll
/// controller to manage.
///
/// A command and what it printed read as one block: a faint divider sits above
/// each echoed input line, and the output under it carries a thin rule down its
/// left edge. Text before the first command (the banner) stays plain.
class TerminalLog extends StatelessWidget {
  const TerminalLog({super.key, required this.session});

  final TerminalSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final lines = session.lines;
        final firstInput = lines.indexWhere((l) => l.kind == LogKind.input);
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
            final position = lines.length - 1 - index;
            final line = lines[position];
            return _LogLineView(
              key: ValueKey(line.id),
              line: line,
              startsBlock: line.kind == LogKind.input && position > 0,
              inBlock:
                  line.kind != LogKind.input &&
                  firstInput != -1 &&
                  position > firstInput,
            );
          },
        );
      },
    );
  }
}

class _LogLineView extends StatelessWidget {
  const _LogLineView({
    super.key,
    required this.line,
    required this.startsBlock,
    required this.inBlock,
  });

  final LogLine line;

  /// An input line that follows earlier lines: draw the divider above it.
  final bool startsBlock;

  /// Output or error that belongs to a command: draw the rule beside it.
  final bool inBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final base = theme.textTheme.bodyLarge;
    final style = switch (line.kind) {
      LogKind.input => base?.copyWith(fontWeight: FontWeight.bold),
      LogKind.output => base,
      LogKind.error => base?.copyWith(color: colors.error),
    };
    // An empty Text can collapse to no height, and a blank line is content.
    final shown = line.text.isEmpty ? ' ' : line.text;
    final columns = line.columns;
    final text = columns == null
        ? Text(shown, style: style)
        : _GridText(shown, style: style, columns: columns);

    if (startsBlock) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: blockDividerKey,
              height: 1,
              child: ColoredBox(
                color: colors.onSurface.withValues(alpha: 0.18),
              ),
            ),
            const SizedBox(height: 8),
            text,
          ],
        ),
      );
    }
    if (inBlock) {
      final rule = line.kind == LogKind.error ? colors.error : colors.onSurface;
      return Container(
        key: outputRuleKey,
        margin: const EdgeInsets.only(left: 2),
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: rule.withValues(alpha: 0.4), width: 2),
          ),
        ),
        child: text,
      );
    }
    return text;
  }
}

/// One line of a fixed-width grid. It never wraps: when [columns] characters
/// would not fit the available width the font is made smaller, by the same
/// amount for every line of the grid, so the layout stays aligned.
class _GridText extends StatelessWidget {
  const _GridText(this.text, {required this.style, required this.columns});

  final String text;
  final TextStyle? style;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: 'M' * columns, style: base),
          textScaler: scaler,
          textDirection: TextDirection.ltr,
        )..layout();
        final needed = painter.width;
        painter.dispose();
        final fits =
            !constraints.hasBoundedWidth || needed <= constraints.maxWidth;
        // A hair under, so rounding never pushes the last column onto a new line.
        final scale = fits ? 1.0 : constraints.maxWidth / needed * 0.995;
        return Text(
          text,
          style: base.copyWith(fontSize: (base.fontSize ?? 14) * scale),
          textScaler: scaler,
          softWrap: false,
          maxLines: 1,
          overflow: TextOverflow.clip,
        );
      },
    );
  }
}
