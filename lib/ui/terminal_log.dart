import 'package:android_terminal_launcher/terminal/log_line.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/ascii_banner.dart';
import 'package:android_terminal_launcher/ui/block_view.dart';
import 'package:android_terminal_launcher/ui/spinner_text.dart';
import 'package:android_terminal_launcher/ui/tv_row.dart';
import 'package:flutter/material.dart';

/// Keys on the block markers, so tests can find them.
const blockDividerKey = ValueKey('block-divider');
const outputRuleKey = ValueKey('output-rule');

/// How far `_GridText` may enlarge a grid to fill a screen wider than it
/// needs. Exported so tests can check against it instead of a magic number.
const gridUpscaleLimit = 1.75;

/// Renders the session's log, newest line at the bottom. The list is
/// `reverse`d so it stays pinned to the newest line without a scroll
/// controller to manage.
///
/// A command and what it printed read as one block: a faint divider sits above
/// each echoed input line, and the output under it carries a thin rule down its
/// left edge. A [LogKind.banner] line (shown at startup and again after
/// `clear`) renders as [AsciiBanner] instead, with none of that decoration. A
/// fixed-width grid (Text TV, the plain calendar) and a rich block (the
/// calendar card) skip the rule too and run edge to edge instead, like their
/// own screen rather than indented app output.
class TerminalLog extends StatelessWidget {
  const TerminalLog({super.key, required this.session, this.onFill});

  final TerminalSession session;

  /// Puts a command in the prompt, for the buttons in a card that act on
  /// someone (call, text) or need more typed. Without it they do nothing.
  final void Function(String command)? onFill;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        // A snapshot: the list builds children lazily, later than this build,
        // and must see the log as it was when it was told about it, whatever
        // the session does in between.
        final lines = List<LogLine>.of(session.lines, growable: false);
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
            if (line.kind == LogKind.banner) {
              return AsciiBanner(key: ValueKey(line.id), caption: line.text);
            }
            return _LogLineView(
              key: ValueKey(line.id),
              line: line,
              onRun: session.submit,
              onFill: onFill,
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
    required this.onRun,
    required this.onFill,
    required this.startsBlock,
    required this.inBlock,
  });

  final LogLine line;

  /// Runs a command a rich block asks for (a tapped day, an arrow).
  final void Function(String command) onRun;

  /// See [TerminalLog.onFill].
  final void Function(String command)? onFill;

  /// An input line that follows earlier lines: draw the divider above it.
  final bool startsBlock;

  /// Output or error that belongs to a command: draw the rule beside it.
  final bool inBlock;

  @override
  Widget build(BuildContext context) {
    // A rich block is its own widget, edge to edge like a grid: no left rule.
    final block = line.block;
    if (block != null) {
      return BlockView(
        block: block,
        onRun: onRun,
        onFill: onFill ?? BlockView.ignore,
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final base = theme.textTheme.bodyLarge;
    final style = switch (line.kind) {
      LogKind.input => base?.copyWith(fontWeight: FontWeight.bold),
      // Banners are rendered by `AsciiBanner` before reaching here; the case
      // only keeps the switch exhaustive.
      LogKind.output || LogKind.banner || LogKind.progress => base,
      LogKind.error => base?.copyWith(color: colors.error),
    };
    // An empty Text can collapse to no height, and a blank line is content.
    final shown = line.text.isEmpty ? ' ' : line.text;
    final columns = line.columns;
    final isGrid = columns != null;
    final runs = line.runs;
    final text = line.kind == LogKind.progress
        ? SpinnerText(style: style)
        : columns == null
        ? Text(shown, style: style)
        : runs != null
        ? TvRow(runs: runs, columns: columns, style: style, onRun: onRun)
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
    if (inBlock && !isGrid) {
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

/// One line of a fixed-width grid. It never wraps: the font is scaled so
/// [columns] characters exactly fill the available width — smaller on a
/// narrow screen, larger (up to [gridUpscaleLimit]) on a wide one — by the
/// same amount for every line of the grid, so the layout stays aligned and
/// the page fills the screen the way it would on a TV, instead of sitting at
/// native size with the rest of the screen left blank.
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
        // Measured against the grid width, not this line's own text, so every
        // ordinary line in the grid lands on the same scale. A line that
        // somehow runs longer than the grid measures itself instead, so it
        // shrinks rather than getting clipped.
        final reference = columns > text.length ? columns : text.length;
        final painter = TextPainter(
          text: TextSpan(text: 'M' * reference, style: base),
          textScaler: scaler,
          textDirection: TextDirection.ltr,
        )..layout();
        final needed = painter.width;
        painter.dispose();
        // A hair under, so rounding never pushes the last column onto a new
        // line. Unbounded width (nothing to fill) leaves the font alone.
        final scale = constraints.hasBoundedWidth && needed > 0
            ? (constraints.maxWidth / needed * 0.995).clamp(
                0.0,
                gridUpscaleLimit,
              )
            : 1.0;
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
