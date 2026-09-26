import 'dart:async';

import 'package:flutter/material.dart';

const _frameA = [r'  /\_/\', r' ( o.o )', r'  > ^ <'];
const _frameB = [r'  /\_/\', r' ( -.- )', r'  > ^ <'];

/// A couple of blinks, then it settles on [_frameA]. Not an endless loop: this
/// sits on a launcher's home screen, which can be on-screen for hours, and a
/// timer ticking (and repainting) forever for that long would only drain the
/// battery for no one to see.
const _sequence = [_frameA, _frameB, _frameA, _frameB, _frameA];
const _frameInterval = Duration(milliseconds: 450);

/// The banner shown on startup and after `clear`: a small ASCII cat that
/// blinks a couple of times and settles, with [caption] (`Messages.welcome`)
/// printed underneath. Plain ASCII only, so it never falls back off
/// `JetBrainsMono` onto a font with different glyph widths.
class AsciiBanner extends StatefulWidget {
  const AsciiBanner({super.key, required this.caption});

  final String caption;

  @override
  State<AsciiBanner> createState() => _AsciiBannerState();
}

class _AsciiBannerState extends State<AsciiBanner> {
  var _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_frameInterval, _advance);
  }

  void _advance(Timer timer) {
    if (_step >= _sequence.length - 1) {
      timer.cancel();
      return;
    }
    setState(() => _step++);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in _sequence[_step]) Text(line, style: style),
        const SizedBox(height: 4),
        Text(widget.caption, style: style),
      ],
    );
  }
}
