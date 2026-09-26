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
