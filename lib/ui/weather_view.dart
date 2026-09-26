import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:android_terminal_launcher/ui/weather_icon.dart';
import 'package:flutter/material.dart';

/// Keys so tests can find the parts.
const weatherNowKey = ValueKey('weather-now');
ValueKey<String> weatherDayKey(String label) => ValueKey('weather-day-$label');
const weatherRainKey = ValueKey('weather-rain');

/// The weather as a card: the place, the sky and the temperature large, a line
/// of wind, humidity and how it feels, then a row per day with its low and high
/// drawn on a bar shared by the whole week, so a warm day and a cold one are
/// seen at a glance.
class WeatherView extends StatelessWidget {
  const WeatherView({super.key, required this.block});

  final WeatherBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final base = theme.textTheme.bodyLarge ?? const TextStyle();
    final fontSize = base.fontSize ?? 16;
    final dim = base.copyWith(color: fg.withValues(alpha: blockDimAlpha));
    final small = dim.copyWith(fontSize: fontSize * 0.85);
    final now = block.now;

    final coldest = block.days.isEmpty
        ? 0
        : block.days.map((d) => d.low).reduce((a, b) => a < b ? a : b);
    final warmest = block.days.isEmpty
        ? 0
        : block.days.map((d) => d.high).reduce((a, b) => a > b ? a : b);

    return BlockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(block.place, style: base.copyWith(fontWeight: FontWeight.bold)),
          if (block.note != null) Text(block.note!, style: small),
          const SizedBox(height: 10),
          Semantics(
            key: weatherNowKey,
            container: true,
            label:
                '${now.description}, ${now.temperature} degrees, '
                'feels like ${now.feelsLike}',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                WeatherIcon(kind: now.kind, size: fontSize * 3.6, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scaled down rather than overflowing when a big font
                      // meets a narrow phone.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${now.temperature}°C',
                          style: base.copyWith(
                            fontSize: fontSize * 2.6,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                      ),
                      Text(now.description, style: base),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 2,
            children: [
              Text('feels ${now.feelsLike}°', style: small),
              Text('wind ${now.windSpeed} m/s ${now.windPoint}', style: small),
              Text('humidity ${now.humidity}%', style: small),
            ],
          ),
          if (block.days.isNotEmpty) ...[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: fg.withValues(alpha: 0.2)),
                ),
              ),
              child: const SizedBox(height: 6),
            ),
            for (final day in block.days)
              _DayRow(day: day, coldest: coldest, warmest: warmest),
          ],
          if (block.source != null) ...[
            const SizedBox(height: 6),
            Text(block.source!, style: small),
          ],
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.coldest,
    required this.warmest,
  });

  final WeatherDay day;
  final int coldest;
  final int warmest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final base = theme.textTheme.bodyLarge ?? const TextStyle();
    final fontSize = base.fontSize ?? 16;
    final small = base.copyWith(
      fontSize: fontSize * 0.85,
      color: fg.withValues(alpha: blockDimAlpha),
    );

    final labelWidth = fontSize * 3.4;
    final iconSize = fontSize * 1.6;
    final degreesWidth = fontSize * 2.5;
    final rainWidth = fontSize * 4.4;
    // What the row needs without the rain; the rain is only shown when the bar
    // still gets a useful length beside it.
    final fixed = labelWidth + iconSize + degreesWidth * 2 + 8 + 16;
    const minimumBar = 48.0;

    return Semantics(
      key: weatherDayKey(day.label),
      container: true,
      excludeSemantics: true,
      label:
          '${day.label}, ${day.description}, ${day.low} to ${day.high} degrees'
          '${day.rain == null ? '' : ', ${day.rain} millimetres of rain'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showRain =
                day.rain != null &&
                constraints.maxWidth - fixed - rainWidth >= minimumBar;
            return Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    day.label,
                    maxLines: 1,
                    style: base.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                WeatherIcon(kind: day.kind, size: iconSize, color: fg),
                const SizedBox(width: 8),
                SizedBox(
                  width: degreesWidth,
                  child: Text(
                    '${day.low}°',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    style: small,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _RangeBar(
                      low: day.low,
                      high: day.high,
                      coldest: coldest,
                      warmest: warmest,
                      color: fg,
                    ),
                  ),
                ),
                SizedBox(
                  width: degreesWidth,
                  child: Text(
                    '${day.high}°',
                    maxLines: 1,
                    style: base.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (showRain)
                  SizedBox(
                    key: weatherRainKey,
                    width: rainWidth,
                    child: Text(
                      '${day.rain}mm',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      style: small,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A day's low to high as a bar along a track that spans the whole week.
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.low,
    required this.high,
    required this.coldest,
    required this.warmest,
    required this.color,
  });

  final int low;
  final int high;
  final int coldest;
  final int warmest;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final span = (warmest - coldest).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // A week of one temperature is a bar filling the track.
        final from = span == 0 ? 0.0 : (low - coldest) / span;
        final to = span == 0 ? 1.0 : (high - coldest) / span;
        // Never thinner than a dot, so a day with low equal to high shows,
        // and moved in from the end if the dot would poke out of the track.
        final dot = width < 6 ? width : 6.0;
        final length = ((to - from) * width).clamp(dot, width);
        final start = (from * width).clamp(0.0, width - length);
        return SizedBox(
          height: 6,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: start,
                width: length,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
