import 'package:android_terminal_launcher/terminal/suggestion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A horizontally scrolling strip of tappable suggestions above the prompt.
/// It listens to [suggestions] itself so typing rebuilds only this strip.
class SuggestionBar extends StatelessWidget {
  const SuggestionBar({
    super.key,
    required this.suggestions,
    required this.onSelected,
  });

  final ValueListenable<List<Suggestion>> suggestions;
  final ValueChanged<Suggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Suggestion>>(
      valueListenable: suggestions,
      builder: (context, items, _) {
        if (items.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: items.length,
            separatorBuilder: (context, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _SuggestionChip(
              key: ValueKey(items[index].completion),
              suggestion: items[index],
              onTap: () => onSelected(items[index]),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  final Suggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(suggestion.label, style: theme.textTheme.bodyMedium),
          ),
        ),
      ),
    );
  }
}
