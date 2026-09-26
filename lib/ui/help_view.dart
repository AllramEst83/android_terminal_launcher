import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:android_terminal_launcher/ui/block_styles.dart';
import 'package:flutter/material.dart';

/// Keys so tests can find the parts.
ValueKey<String> helpChipKey(String name) => ValueKey('help-chip-$name');
ValueKey<String> helpGroupKey(String name) => ValueKey('help-group-$name');
ValueKey<String> helpRowKey(String name) => ValueKey('help-row-$name');
const helpUsageKey = ValueKey('help-usage');
const helpExamplesKey = ValueKey('help-examples');

/// `help`: each group with its commands as chips. A chip opens that command's
/// help, a group's name opens the group's.
class HelpOverviewView extends StatelessWidget {
  const HelpOverviewView({super.key, required this.block, required this.onRun});

  final HelpOverviewBlock block;
  final RunCommand onRun;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    return BlockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('commands', style: styles.bold),
          for (final group in block.groups) ...[
            const SizedBox(height: 12),
            _GroupLabel(group: group, onRun: onRun),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final command in group.commands)
                  BlockChip(
                    key: helpChipKey(command.name),
                    label: command.name,
                    semanticLabel: 'help for ${command.name}',
                    onTap: () => onRun(command.command),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(block.hint, style: styles.small),
        ],
      ),
    );
  }
}

/// `help <group>`: its commands, each with what it does.
class HelpGroupView extends StatelessWidget {
  const HelpGroupView({super.key, required this.block, required this.onRun});

  final HelpGroupBlock block;
  final RunCommand onRun;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    final commands = block.group.commands;
    return BlockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(block.group.name, style: styles.bold),
          for (var i = 0; i < commands.length; i++) ...[
            const SizedBox(height: 4),
            Divider(height: 1, color: styles.fg.withValues(alpha: 0.2)),
            InkWell(
              key: helpRowKey(commands[i].name),
              borderRadius: BorderRadius.circular(6),
              onTap: () => onRun(commands[i].command),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: commands[i].name,
                                  style: styles.bold,
                                ),
                                if (commands[i].aliases.isNotEmpty)
                                  TextSpan(
                                    text: '  ${commands[i].aliases.join(', ')}',
                                    style: styles.small,
                                  ),
                              ],
                            ),
                          ),
                          Text(commands[i].description, style: styles.small),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('›', style: styles.bold),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `help <command>`: what it is, how to call it, examples to try, and notes.
class HelpDetailView extends StatelessWidget {
  const HelpDetailView({super.key, required this.block, required this.onRun});

  final HelpDetailBlock block;
  final RunCommand onRun;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    final group = block.group;
    return BlockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            block.name,
            style: styles.bold.copyWith(fontSize: styles.size * 1.3),
          ),
          if (group != null)
            _GroupLabel(group: group, onRun: onRun, prefix: 'in '),
          const SizedBox(height: 6),
          Text(block.description, style: styles.base),
          const SizedBox(height: 12),
          Text('usage', style: styles.small),
          const SizedBox(height: 4),
          _CodeBox(key: helpUsageKey, lines: block.usage),
          if (block.examples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('examples', style: styles.small),
            const SizedBox(height: 4),
            _CodeBox(key: helpExamplesKey, lines: block.examples),
          ],
          if (block.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final note in block.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(note, style: styles.small),
              ),
          ],
          if (block.aliases.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('also: ${block.aliases.join(', ')}', style: styles.small),
          ],
        ],
      ),
    );
  }
}

/// A group's name, tappable, for its own help.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({
    required this.group,
    required this.onRun,
    this.prefix = '',
  });

  final HelpGroup group;
  final RunCommand onRun;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        key: helpGroupKey(group.name),
        borderRadius: BorderRadius.circular(6),
        onTap: () => onRun(group.command),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text('$prefix${group.name} ›', style: styles.small),
        ),
      ),
    );
  }
}

/// Lines of something to type, in a tinted box. Not tappable: an example can
/// do things (send a text, place a call), so it is only ever run by typing it.
class _CodeBox extends StatelessWidget {
  const _CodeBox({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: styles.fg.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final line in lines) Text(line, style: styles.base)],
        ),
      ),
    );
  }
}
