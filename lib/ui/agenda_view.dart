import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:android_terminal_launcher/ui/readable_color.dart';
import 'package:flutter/material.dart';

/// Keys so tests can find the parts.
ValueKey<String> agendaDayKey(String label) => ValueKey('agenda-day-$label');
const agendaEntryKey = ValueKey('agenda-entry');
const agendaLegendKey = ValueKey('agenda-legend');

/// Days as an agenda card: a heading per day (tap it to open that day), then
/// each event as a row with a bar in its calendar's colour, its times stacked
/// in a column, and its title and place wrapping under themselves rather than
/// back to the left edge. Events that are over are dimmed and the one under
/// way is lit.
class AgendaView extends StatelessWidget {
  const AgendaView({super.key, required this.block, required this.onRun});

  final AgendaBlock block;
  final RunCommand onRun;

  @override
  Widget build(BuildContext context) {
    // A single day's heading would only run the command that drew it.
    final tappable = block.days.length > 1;
    return BlockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < block.days.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _DaySection(
              day: block.days[i],
              onTap: tappable ? () => onRun(block.days[i].command) : null,
            ),
          ],
          if (block.legend.isNotEmpty) _Legend(block.legend),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day, required this.onTap});

  final AgendaDay day;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final bg = theme.colorScheme.surface;
    final base = theme.textTheme.bodyLarge ?? const TextStyle();
    final dim = base.copyWith(color: fg.withValues(alpha: blockDimAlpha));
    final small = dim.copyWith(fontSize: (base.fontSize ?? 16) * 0.85);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: agendaDayKey(day.label),
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // The label side takes whatever the count leaves, and its
                // label shortens instead of overflowing when a big font meets
                // a narrow phone.
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          day.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: base.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (day.today) ...[
                        const SizedBox(width: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: fg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            child: Text(
                              'today',
                              style: small.copyWith(
                                color: bg,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  day.entries.isEmpty ? 'free' : '${day.entries.length}',
                  style: small,
                ),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: fg.withValues(alpha: 0.2))),
          ),
          child: const SizedBox(height: 4),
        ),
        for (final entry in day.entries) _EntryRow(entry: entry),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final AgendaEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final bg = theme.colorScheme.surface;
    final base = theme.textTheme.bodyLarge ?? const TextStyle();
    final fontSize = base.fontSize ?? 16;
    final small = base.copyWith(fontSize: fontSize * 0.85);
    final dim = small.copyWith(color: fg.withValues(alpha: blockDimAlpha));
    final live = entry.phase == EntryPhase.now;
    final bar = entry.color == null
        ? fg.withValues(alpha: 0.5)
        : readableOn(Color(entry.color!), bg);

    final row = Container(
      key: agendaEntryKey,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: live ? fg.withValues(alpha: 0.14) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: bar,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: fontSize * 3.7,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.start, style: entry.allDay ? dim : small),
                    if (entry.end != null) Text(entry.end!, style: dim),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: live
                          ? base.copyWith(fontWeight: FontWeight.bold)
                          : base,
                    ),
                    if (entry.place != null) Text(entry.place!, style: dim),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return entry.phase == EntryPhase.past
        ? Opacity(opacity: blockPastOpacity, child: row)
        : row;
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.calendars);

  final List<AgendaCalendar> calendars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final bg = theme.colorScheme.surface;
    final base = theme.textTheme.bodyLarge ?? const TextStyle();
    final small = base.copyWith(
      fontSize: (base.fontSize ?? 16) * 0.85,
      color: fg.withValues(alpha: blockDimAlpha),
    );
    return Padding(
      key: agendaLegendKey,
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final calendar in calendars)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: (small.fontSize ?? 14) * 1.1,
                  decoration: BoxDecoration(
                    color: calendar.color == null
                        ? fg.withValues(alpha: 0.5)
                        : readableOn(Color(calendar.color!), bg),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(calendar.name, style: small),
              ],
            ),
        ],
      ),
    );
  }
}
