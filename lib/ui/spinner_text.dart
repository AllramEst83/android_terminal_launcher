import 'dart:async';

import 'package:flutter/material.dart';

/// The turning bar of the spinner: `[|]`, `[/]`, `[-]`, `[\]`.
const spinnerFrames = ['[|]', '[/]', '[-]', r'[\]'];

/// How long each frame shows.
const spinnerStep = Duration(milliseconds: 120);

/// A rotating bar in brackets, for a command that is still running. The timer
/// lives only while this is on screen: the session takes the line away when the
/// command finishes. With the system's "remove animations" setting on it stands
/// still (`[|]`) instead of turning.
class SpinnerText extends StatefulWidget {
  const SpinnerText({super.key, this.style});

  final TextStyle? style;

  @override
  State<SpinnerText> createState() => _SpinnerTextState();
}

class _SpinnerTextState extends State<SpinnerText> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(spinnerStep, (_) {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % spinnerFrames.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'working',
      excludeSemantics: true,
      child: Text(spinnerFrames[still ? 0 : _frame], style: widget.style),
    );
  }
}
