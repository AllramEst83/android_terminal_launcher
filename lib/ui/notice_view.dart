import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:android_terminal_launcher/ui/block_styles.dart';
import 'package:flutter/material.dart';

/// Keys so tests can find the parts.
const noticeIconKey = ValueKey('notice-icon');

/// A short statement of what happened, with an icon that says how it went: a
/// tick for done, an "i" for information, an exclamation mark (in the theme's
/// error colour, which every theme keeps readable) for something to look at.
class NoticeView extends StatelessWidget {
  const NoticeView({super.key, required this.block});

  final NoticeBlock block;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, colour) = switch (block.kind) {
      NoticeKind.success => (Icons.check_circle_outline, styles.fg),
      NoticeKind.info => (Icons.info_outline, styles.fg),
      NoticeKind.warning => (Icons.error_outline, scheme.error),
    };
    return BlockCard(
      child: Semantics(
        container: true,
        label: [
          switch (block.kind) {
            NoticeKind.success => 'done',
            NoticeKind.info => 'note',
            NoticeKind.warning => 'warning',
          },
          block.message,
          ...block.details,
        ].join(', '),
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon,
                key: noticeIconKey,
                size: styles.size * 1.3,
                color: colour,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(block.message, style: styles.base),
                  for (final detail in block.details)
                    Text(detail, style: styles.small),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
