import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:android_terminal_launcher/ui/block_styles.dart';
import 'package:flutter/material.dart';

/// Keys so tests can find the parts.
ValueKey<String> entryRowKey(int id) => ValueKey('entry-row-$id');
ValueKey<String> entryBoxKey(int id) => ValueKey('entry-box-$id');
const entryDoneChipKey = ValueKey('entry-done');
const entryEditChipKey = ValueKey('entry-edit');
const entryRemoveChipKey = ValueKey('entry-remove');

/// A list of notes or todos: the number, the text, and for a todo a box that
/// ticks it (tap the row to see the whole entry).
class EntriesView extends StatelessWidget {
  const EntriesView({super.key, required this.block, required this.onRun});

  final EntriesBlock block;
  final RunCommand onRun;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    return BlockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(block.title, style: styles.bold),
          const SizedBox(height: 4),
          for (final row in block.rows) ...[
            Divider(height: 1, color: styles.fg.withValues(alpha: 0.2)),
            _Row(block: block, row: row, onRun: onRun),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.block, required this.row, required this.onRun});

  final EntriesBlock block;
  final EntryRow row;
  final RunCommand onRun;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    final text = row.done
        ? styles.base.copyWith(
            color: styles.fg.withValues(alpha: blockDimAlpha),
            decoration: TextDecoration.lineThrough,
          )
        : styles.base;
    return Semantics(
      container: true,
      label:
          '${block.todo ? (row.done ? 'done, ' : 'open, ') : ''}'
          'number ${row.id}, ${row.text}',
      excludeSemantics: true,
      child: InkWell(
        key: entryRowKey(row.id),
        borderRadius: BorderRadius.circular(6),
        onTap: () => onRun(row.showCommand),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.todo && row.toggleCommand != null) ...[
                InkWell(
                  key: entryBoxKey(row.id),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onRun(row.toggleCommand!),
                  child: Icon(
                    row.done
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank,
                    size: styles.size * 1.3,
                    color: styles.fg,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              SizedBox(
                width: styles.size * 2.4,
                child: Text('#${row.id}', style: styles.small),
              ),
              Expanded(child: Text(row.text, style: text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One note or todo in full, with what can be done to it: tick it (a todo), or
/// edit or remove it, which put the command in the prompt so the new text can
/// be typed or the removal looked at before it happens.
class EntryDetailView extends StatelessWidget {
  const EntryDetailView({
    super.key,
    required this.block,
    required this.onRun,
    required this.onFill,
  });

  final EntryDetailBlock block;
  final RunCommand onRun;
  final FillPrompt onFill;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    final done = block.done;
    return BlockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${block.kind} #${block.id}', style: styles.bold),
              ),
              if (done != null)
                Text(done ? 'done' : 'open', style: styles.small),
            ],
          ),
          const SizedBox(height: 8),
          Text(block.text, style: styles.base),
          const SizedBox(height: 8),
          Text(
            [
              'created ${block.created}',
              if (block.edited != null) 'edited ${block.edited}',
            ].join(' · '),
            style: styles.small,
          ),
          if (block.toggleCommand != null ||
              block.editCommand != null ||
              block.removeCommand != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (block.toggleCommand != null)
                  BlockChip(
                    key: entryDoneChipKey,
                    label: done == true ? 'undo' : 'done',
                    small: true,
                    onTap: () => onRun(block.toggleCommand!),
                  ),
                if (block.editCommand != null)
                  BlockChip(
                    key: entryEditChipKey,
                    label: 'edit',
                    small: true,
                    onTap: () => onFill(block.editCommand!),
                  ),
                if (block.removeCommand != null)
                  BlockChip(
                    key: entryRemoveChipKey,
                    label: 'remove',
                    small: true,
                    onTap: () => onFill(block.removeCommand!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
