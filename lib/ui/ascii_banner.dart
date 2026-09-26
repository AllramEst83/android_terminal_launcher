import 'dart:async';

import 'package:android_terminal_launcher/ui/rocket_art.dart';
import 'package:flutter/material.dart';

const _frameInterval = Duration(milliseconds: 220);

/// The banner shown on startup and after `clear`: a small ASCII rocket that
/// counts through ignition, lifts off and settles high on the screen, with
/// [caption] (`Messages.welcome`) centred underneath. The launch runs once and
/// stops. Not an endless loop: this sits on a launcher's home screen, which can
/// be on-screen for hours, and a timer ticking (and repainting) forever for
/// that long would only drain the battery for no one to see.
///
/// The picture is centred as one block (see [rocketFrames]: all lines are the
/// same width), so the rocket keeps its shape while the block sits in the
/// middle of the screen.
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
    if (_step >= rocketFrames.length - 1) {
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // One Text for the whole picture: lines padded to one width stay
        // aligned, and the block is what gets centred.
        Text(rocketFrames[_step].join('\n'), style: style),
        const SizedBox(height: 8),
        Text(widget.caption, style: style, textAlign: TextAlign.center),
      ],
    );
  }
}
