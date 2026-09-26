import 'dart:math' as math;

import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:flutter/material.dart';

/// A line drawing of the sky in one colour: a sun, a cloud, rain and so on.
/// Drawn in code so it follows the theme and needs no asset.
class WeatherIcon extends StatelessWidget {
  const WeatherIcon({
    super.key,
    required this.kind,
    required this.size,
    required this.color,
  });

  final WeatherKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: WeatherIconPainter(kind, color)),
      ),
    );
  }
}

/// Paints [kind] into a square, in unit coordinates so it scales cleanly.
class WeatherIconPainter extends CustomPainter {
  const WeatherIconPainter(this.kind, this.color);

  final WeatherKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s / 13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = color;

    Offset at(double x, double y) => Offset(x * s, y * s);

    void rays(Offset centre, double from, double to) {
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final dx = math.cos(angle);
        final dy = math.sin(angle);
        canvas.drawLine(
          centre + Offset(dx, dy) * (from * s),
          centre + Offset(dx, dy) * (to * s),
          line,
        );
      }
    }

    void sun(Offset centre, double radius, double rayFrom, double rayTo) {
      canvas.drawCircle(centre, radius * s, line);
      rays(centre, rayFrom, rayTo);
    }

    switch (kind) {
      case WeatherKind.clear:
        sun(at(0.5, 0.5), 0.2, 0.32, 0.44);
      case WeatherKind.partlyCloudy:
        final cloud = _cloud(s, scale: 0.85, dx: -0.05, dy: 0.1);
        // Keep the sun's lines off the cloud in front of it.
        canvas.save();
        canvas.clipPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRect(Offset.zero & size),
            cloud,
          ),
        );
        sun(at(0.68, 0.32), 0.13, 0.21, 0.3);
        canvas.restore();
        canvas.drawPath(cloud, line);
      case WeatherKind.cloudy:
        canvas.drawPath(_cloud(s), line);
      case WeatherKind.fog:
        canvas.drawPath(_cloud(s, scale: 0.8, dy: -0.14), line);
        canvas.drawLine(at(0.16, 0.72), at(0.84, 0.72), line);
        canvas.drawLine(at(0.28, 0.85), at(0.72, 0.85), line);
      case WeatherKind.drizzle:
        canvas.drawPath(_cloud(s, scale: 0.8, dy: -0.12), line);
        for (final x in const [0.34, 0.5, 0.66]) {
          canvas.drawLine(at(x, 0.72), at(x - 0.03, 0.78), line);
        }
      case WeatherKind.rain:
        canvas.drawPath(_cloud(s, scale: 0.8, dy: -0.12), line);
        for (final x in const [0.32, 0.5, 0.68]) {
          canvas.drawLine(at(x, 0.7), at(x - 0.06, 0.86), line);
        }
      case WeatherKind.snow:
        canvas.drawPath(_cloud(s, scale: 0.8, dy: -0.12), line);
        for (final (x, y) in const [(0.34, 0.76), (0.5, 0.88), (0.66, 0.76)]) {
          canvas.drawCircle(at(x, y), s / 22, dot);
        }
      case WeatherKind.thunder:
        canvas.drawPath(_cloud(s, scale: 0.8, dy: -0.12), line);
        canvas.drawPath(
          Path()
            ..moveTo(0.56 * s, 0.64 * s)
            ..lineTo(0.42 * s, 0.82 * s)
            ..lineTo(0.55 * s, 0.82 * s)
            ..lineTo(0.46 * s, 0.97 * s),
          line,
        );
    }
  }

  @override
  bool shouldRepaint(WeatherIconPainter old) =>
      old.kind != kind || old.color != color;
}

/// A cloud outline in a [s] square: a flat base and two bumps, as one shape so
/// only its outer edge is drawn. [scale] shrinks it about the middle of the
/// square; [dx] and [dy] move it (as fractions of the square).
Path _cloud(double s, {double scale = 1, double dx = 0, double dy = 0}) {
  double x(double v) => (0.5 + (v - 0.5) * scale + dx) * s;
  double y(double v) => (0.5 + (v - 0.5) * scale + dy) * s;
  double r(double v) => v * scale * s;
  final base = Path()
    ..addRRect(
      RRect.fromLTRBR(
        x(0.12),
        y(0.5),
        x(0.88),
        y(0.74),
        Radius.circular(r(0.12)),
      ),
    );
  final left = Path()
    ..addOval(
      Rect.fromCircle(center: Offset(x(0.36), y(0.5)), radius: r(0.17)),
    );
  final right = Path()
    ..addOval(
      Rect.fromCircle(center: Offset(x(0.6), y(0.42)), radius: r(0.21)),
    );
  return Path.combine(
    PathOperation.union,
    Path.combine(PathOperation.union, base, left),
    right,
  );
}
