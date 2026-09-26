import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:flutter/material.dart';

/// Keys so tests can find the parts.
const monthPreviousKey = ValueKey('month-previous');
const monthNextKey = ValueKey('month-next');
ValueKey<String> monthDayKey(int day) => ValueKey('month-day-$day');

/// The most dots a day shows; more events than this still show this many.
const monthMaxDots = 3;

/// A month as a calendar card: arrows either side of the title, weekday
/// names, and a cell per day with a dot for each event. Today is a filled
/// cell. Every day and both arrows run a command when tapped.
class MonthView extends StatelessWidget {
  const MonthView({super.key, required this.block, required this.onRun});

  final MonthBlock block;
  final RunCommand onRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final base = theme.textTheme.bodyLarge ?? const TextStyle();
    final dim = base.copyWith(color: fg.withValues(alpha: blockDimAlpha));
    return BlockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Arrow(
                key: monthPreviousKey,
                symbol: '‹',
                label: 'previous month',
                command: block.previousCommand,
                onRun: onRun,
              ),
              Expanded(
                child: Text(
                  block.title,
                  textAlign: TextAlign.center,
                  style: base.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              _Arrow(
                key: monthNextKey,
                symbol: '›',
                label: 'next month',
                command: block.nextCommand,
                onRun: onRun,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final name in block.weekdays)
                Expanded(
                  child: Text(name, textAlign: TextAlign.center, style: dim),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final week in block.weeks)
            Row(
              children: [
                for (final day in week)
                  Expanded(
                    child: day == null
                        ? SizedBox(height: _cellHeight(base))
                        : _DayCell(day: day, onRun: onRun),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Number box, a gap and a row of dots.
double _cellHeight(TextStyle base) => _box(base) + 12;

double _box(TextStyle base) => (base.fontSize ?? 16) * 1.9;

class _Arrow extends StatelessWidget {
  const _Arrow({
    super.key,
    required this.symbol,
    required this.label,
    required this.command,
    required this.onRun,
  });

  final String symbol;
  final String label;
  final String? command;
  final RunCommand onRun;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge;
    final size = (base?.fontSize ?? 16) * 2.4;
    final run = command;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: run == null ? null : () => onRun(run),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              symbol,
              style: base?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.onRun});

  final MonthDay day;
  final RunCommand onRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final bg = theme.colorScheme.surface;
    final base = theme.textTheme.bodyLarge ?? const TextStyle();
    final dots = day.events > monthMaxDots ? monthMaxDots : day.events;
    final events = day.events == 1 ? '1 event' : '${day.events} events';
    return Semantics(
      button: true,
      label:
          '${day.day}${day.today ? ', today' : ''}'
          '${day.events == 0 ? '' : ', $events'}',
      excludeSemantics: true,
      child: InkWell(
        key: monthDayKey(day.day),
        borderRadius: BorderRadius.circular(10),
        onTap: () => onRun(day.command),
        child: SizedBox(
          height: _cellHeight(base),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: _box(base),
                height: _box(base),
                alignment: Alignment.center,
                decoration: day.today
                    ? BoxDecoration(
                        color: fg,
                        borderRadius: BorderRadius.circular(_box(base) / 3),
                      )
                    : null,
                child: Text(
                  '${day.day}',
                  style: base.copyWith(
                    color: day.today ? bg : null,
                    fontWeight: day.today ? FontWeight.bold : null,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < dots; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: fg,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(width: 5, height: 5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
