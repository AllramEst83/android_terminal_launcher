import 'package:flutter/material.dart';

/// Runs a command line as if it had been typed. Blocks use it for taps.
typedef RunCommand = void Function(String command);

/// Puts a command line in the prompt without running it, so it can be looked
/// at, edited and sent with Enter (as tapping a suggestion does). Blocks use it
/// for anything that acts on someone or needs more typed.
typedef FillPrompt = void Function(String command);

/// How strongly secondary text (weekday names, end times, places) shows against
/// the background. High enough to keep WCAG AA contrast on every theme,
/// including the light pastel one; a test holds it there.
const blockDimAlpha = 0.8;

/// How strongly something that is over (a finished event) shows. Deliberately
/// faint, but a title must stay readable (contrast 3 on every theme).
const blockPastOpacity = 0.65;

/// The frame every block sits in: a thin rounded outline in the text colour,
/// faint enough to stay a background to the content.
class BlockCard extends StatelessWidget {
  const BlockCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.05),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

/// A title with an arrow either side, for stepping back and forward through
/// time (a month, a week). Every block that can do this shows it the same
/// way; an arrow with no command does nothing when tapped.
class BlockNavHeader extends StatelessWidget {
  const BlockNavHeader({
    super.key,
    required this.title,
    required this.onRun,
    required this.previousKey,
    required this.nextKey,
    required this.previousLabel,
    required this.nextLabel,
    this.previousCommand,
    this.nextCommand,
  });

  final String title;
  final String? previousCommand;
  final String? nextCommand;
  final RunCommand onRun;
  final Key previousKey;
  final Key nextKey;
  final String previousLabel;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    return Row(
      children: [
        _NavArrow(
          key: previousKey,
          symbol: '‹',
          label: previousLabel,
          command: previousCommand,
          onRun: onRun,
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: base.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _NavArrow(
          key: nextKey,
          symbol: '›',
          label: nextLabel,
          command: nextCommand,
          onRun: onRun,
        ),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    super.key,
    required this.symbol,
    required this.label,
    required this.command,
    required this.onRun,
  });

  final String symbol;
  final String label;
  final String? command;
  final RunCommand onRun;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge;
    final size = (base?.fontSize ?? 16) * 2.4;
    final run = command;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: run == null ? null : () => onRun(run),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              symbol,
              style: base?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
