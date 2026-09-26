import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:android_terminal_launcher/ui/block_styles.dart';
import 'package:flutter/material.dart';

/// Keys so tests can find the parts.
ValueKey<String> contactCardKey(String name) => ValueKey('contact-$name');
ValueKey<String> contactCallKey(String number) =>
    ValueKey('contact-call-$number');
ValueKey<String> contactSmsKey(String number) =>
    ValueKey('contact-sms-$number');

/// People and their numbers. Each number has a `call` and an `sms` button that
/// put the command in the prompt rather than doing it: a stray tap must never
/// ring someone or send a text, and the text still has to be typed.
class ContactsView extends StatelessWidget {
  const ContactsView({super.key, required this.block, required this.onFill});

  final ContactsBlock block;
  final FillPrompt onFill;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    return BlockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < block.contacts.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: styles.fg.withValues(alpha: 0.2)),
              const SizedBox(height: 8),
            ],
            _Card(card: block.contacts[i], onFill: onFill),
          ],
          if (block.more > 0) ...[
            const SizedBox(height: 10),
            Text('…and ${block.more} more', style: styles.small),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card, required this.onFill});

  final ContactCard card;
  final FillPrompt onFill;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    return Column(
      key: contactCardKey(card.name),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(card.name, style: styles.bold),
        for (final number in card.numbers)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(number.label, style: styles.small),
                Text(number.number, style: styles.base),
                BlockChip(
                  key: contactCallKey(number.number),
                  label: 'call',
                  small: true,
                  semanticLabel: 'call ${card.name}, ${number.label}',
                  onTap: () => onFill(number.callCommand),
                ),
                BlockChip(
                  key: contactSmsKey(number.number),
                  label: 'sms',
                  small: true,
                  semanticLabel: 'text ${card.name}, ${number.label}',
                  onTap: () => onFill(number.smsCommand),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
