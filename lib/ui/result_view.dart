import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:android_terminal_launcher/ui/block_styles.dart';
import 'package:flutter/material.dart';

/// Keys so tests can find the parts.
const resultValueKey = ValueKey('result-value');

/// One answer, large: what was asked in small type above, the result below it,
/// and any notes under that. Scaled down rather than overflowing when a long
/// number meets a narrow phone.
class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.block});

  final ResultBlock block;

  @override
  Widget build(BuildContext context) {
    final styles = BlockStyles.of(context);
    return BlockCard(
      child: Semantics(
        container: true,
        label: '${block.expression} is ${block.value}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(block.expression, style: styles.small),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                block.value,
                key: resultValueKey,
                style: styles.bold.copyWith(
                  fontSize: styles.size * 2.4,
                  height: 1.15,
                ),
              ),
            ),
            for (final detail in block.details) ...[
              const SizedBox(height: 2),
              Text(detail, style: styles.small),
            ],
          ],
        ),
      ),
    );
  }
}
