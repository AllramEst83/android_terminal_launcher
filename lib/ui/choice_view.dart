import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:android_terminal_launcher/ui/block_styles.dart';
import 'package:flutter/material.dart';

/// Keys so tests can find the parts.
ValueKey<String> choiceKey(String label) => ValueKey('choice-$label');
ValueKey<String> choiceGroupKey(String title) =>
    ValueKey('choice-group-$title');

/// Things to pick from, as chips (short names) or rows (with a sentence each).
/// A tap runs the option's command, or puts it in the prompt when it acts on
/// someone or needs more typed (`ChoiceOption.fill`).
class ChoiceView extends StatelessWidget {
  const ChoiceView({
    super.key,
    required this.block,
    required this.onRun,
    required this.onFill,
  });

  final ChoiceBlock block;
  final RunCommand onRun;
  final FillPrompt onFill;

  void _pick(ChoiceOption option) =>
      option.fill ? onFill(option.command) : onRun(option.command);

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    // Radio buttons only mean something when one of the options is the one in
    // use (a theme); a list of things to pick from just has a chevron.
    final hasCurrent = block.groups.any(
      (g) => g.options.any((o) => o.selected),
    );
    return BlockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (block.title != null) Text(block.title!, style: styles.bold),
          for (var i = 0; i < block.groups.length; i++) ...[
            SizedBox(height: i == 0 && block.title == null ? 0 : 10),
            if (block.groups[i].title != null) ...[
              Text(
                block.groups[i].title!,
                key: choiceGroupKey(block.groups[i].title!),
                style: styles.small,
              ),
              const SizedBox(height: 6),
            ],
            switch (block.layout) {
              ChoiceLayout.chips => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in block.groups[i].options)
                    BlockChip(
                      key: choiceKey(option.label),
                      label: option.label,
                      selected: option.selected,
                      onTap: () => _pick(option),
                    ),
                ],
              ),
              ChoiceLayout.rows => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final option in block.groups[i].options)
                    _Row(
                      option: option,
                      showRadio: hasCurrent,
                      onTap: () => _pick(option),
                    ),
                ],
              ),
            },
          ],
          if (block.footer != null) ...[
            const SizedBox(height: 10),
            Text(block.footer!, style: styles.small),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.option,
    required this.showRadio,
    required this.onTap,
  });

  final ChoiceOption option;
  final bool showRadio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    return Semantics(
      button: true,
      selected: option.selected,
      label: [option.label, ?option.description].join(', '),
      excludeSemantics: true,
      child: InkWell(
        key: choiceKey(option.label),
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showRadio) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    option.selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: styles.size * 1.2,
                    color: styles.fg,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label, style: styles.bold),
                    if (option.description != null)
                      Text(option.description!, style: styles.small),
                  ],
                ),
              ),
              if (!showRadio) ...[
                const SizedBox(width: 8),
                Text('›', style: styles.bold),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
