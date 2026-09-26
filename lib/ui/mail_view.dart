import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:android_terminal_launcher/ui/block_styles.dart';
import 'package:flutter/material.dart';

/// Keys so tests can find the parts.
ValueKey<String> mailRowKey(int uid) => ValueKey('mail-row-$uid');
ValueKey<String> mailUnreadKey(int uid) => ValueKey('mail-unread-$uid');
ValueKey<String> mailRemoveKey(int uid) => ValueKey('mail-remove-$uid');

/// The inbox: a row a message with who sent it and when, what it is about, and
/// a dot and bold type on the ones not read yet. The bin at the end of a row
/// puts `mail rm` for that message in the prompt: it does not remove anything
/// until the user presses Enter.
class MailView extends StatelessWidget {
  const MailView({super.key, required this.block, required this.onFill});

  final MailBlock block;
  final FillPrompt onFill;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    return BlockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Inbox', style: styles.bold),
          Text(block.summary, style: styles.small),
          const SizedBox(height: 4),
          for (final row in block.rows) ...[
            Divider(height: 1, color: styles.fg.withValues(alpha: 0.2)),
            _Row(row: row, onFill: onFill),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.onFill});

  final MailRow row;
  final FillPrompt onFill;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    final dot = styles.size * 0.6;
    final subject = row.unread
        ? styles.base
        : styles.base.copyWith(
            color: styles.fg.withValues(alpha: blockDimAlpha),
          );
    final remove = row.removeCommand;
    return Padding(
      key: mailRowKey(row.uid),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label:
                  '${row.unread ? 'unread, ' : ''}from ${row.sender}'
                  '${row.when.isEmpty ? '' : ', ${row.when}'}, ${row.subject}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The dot's column is always there, so read and unread
                    // rows line up.
                    SizedBox(
                      width: dot + 8,
                      height: styles.size * 1.3,
                      child: row.unread
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: DecoratedBox(
                                key: mailUnreadKey(row.uid),
                                decoration: BoxDecoration(
                                  color: styles.fg,
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox(width: dot, height: dot),
                              ),
                            )
                          : null,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(
                                child: Text(
                                  row.sender,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: row.unread ? styles.bold : styles.base,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(row.when, style: styles.small),
                            ],
                          ),
                          Text(
                            row.subject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: subject,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (remove != null)
            Semantics(
              button: true,
              label: 'Move to trash: ${row.subject}',
              excludeSemantics: true,
              child: InkWell(
                key: mailRemoveKey(row.uid),
                borderRadius: BorderRadius.circular(8),
                onTap: () => onFill(remove),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.delete_outline,
                    size: styles.size * 1.2,
                    color: styles.fg.withValues(alpha: blockDimAlpha),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
