import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:flutter/material.dart';

/// The theme's colours and the text styles the rich views share: the text
/// colour, the base style, a bold and a small dim one.
class BlockStyles {
  const BlockStyles(this.fg, this.base, this.size);

  factory BlockStyles.of(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge ?? const TextStyle();
    return BlockStyles(theme.colorScheme.onSurface, base, base.fontSize ?? 16);
  }

  final Color fg;
  final TextStyle base;
  final double size;

  TextStyle get bold => base.copyWith(fontWeight: FontWeight.bold);
  TextStyle get small => base.copyWith(
    fontSize: size * 0.85,
    color: fg.withValues(alpha: blockDimAlpha),
  );
}

/// A name or word as a button-like outline. [selected] fills it, for the one
/// in use.
class BlockChip extends StatelessWidget {
  const BlockChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.semanticLabel,
    this.small = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// What a screen reader says; the label when null.
  final String? semanticLabel;

  /// Smaller type and padding, for actions beside a line of text.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    final background = Theme.of(context).colorScheme.surface;
    final text = small
        ? styles.base.copyWith(fontSize: styles.size * 0.85)
        : styles.base;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? styles.fg : null,
            border: Border.all(
              color: styles.fg.withValues(alpha: selected ? 1 : 0.5),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: small ? 8 : 10,
              vertical: small ? 4 : 6,
            ),
            child: Text(
              label,
              style: selected
                  ? text.copyWith(
                      color: background,
                      fontWeight: FontWeight.bold,
                    )
                  : text,
            ),
          ),
        ),
      ),
    );
  }
}
