import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:flutter/material.dart';

/// How far a coloured grid may be enlarged to fill a screen wider than it
/// needs, the same limit plain grids use.
const tvUpscaleLimit = 1.75;

/// Blank cells of the black screen either side of the page, so text in the
/// last column is not pressed against the edge (a real teletext set has this
/// margin as overscan). The site's pages already leave column 0 blank and use
/// columns 1 to 39 (measured over 4600 rows: column 0 holds text on 5% of
/// them, column 1 on 45%, column 39 on 16%), so that blank column is the left
/// margin and only the right needs one. Together they make the visible margins
/// equal. The page's own colour bars run to the page's edges, so the gutters
/// are black either side of them.
const tvGutterLeftCells = 0;
const tvGutterRightCells = 1;
const tvGutterCells = tvGutterLeftCells + tvGutterRightCells;

/// The teletext colours as drawn: a fixed palette, not the theme's, because a
/// teletext page is its own black screen in every theme. Bright but not
/// searing, and every colour is readable on black.
Color tvColorOf(TvColor color) => switch (color) {
  TvColor.black => const Color(0xFF000000),
  TvColor.red => const Color(0xFFFF4040),
  TvColor.green => const Color(0xFF19E619),
  TvColor.yellow => const Color(0xFFFFEB1A),
  TvColor.blue => const Color(0xFF2F4BFF),
  TvColor.magenta => const Color(0xFFFF4DFF),
  TvColor.cyan => const Color(0xFF1FC8E8),
  TvColor.white => const Color(0xFFFFFFFF),
};

/// The command a tap at [column] (a cell number, fractions and all) runs, or
/// null. A link is only a few cells wide, so a tap that lands within a cell of
/// one still counts; a tap on one is preferred over a near miss of another.
String? tvCommandAt(List<StyledRun> runs, double column) {
  String? nearest;
  var nearestDistance = 1.0;
  var start = 0;
  for (final run in runs) {
    final end = start + run.text.runes.length;
    final command = run.command;
    if (command != null) {
      final distance = column < start
          ? start - column
          : (column >= end ? column - end : 0.0);
      if (distance == 0) return command;
      if (distance < nearestDistance) {
        nearest = command;
        nearestDistance = distance;
      }
    }
    start = end;
  }
  return nearest;
}

/// One row of a coloured fixed-width grid (a Text TV page): every character in
/// its own cell, backgrounds running edge to edge, block graphics drawn as
/// their lit sixths, page-number links underlined and tappable ([onRun] runs
/// the link's command). It scales the font so [columns] cells and the gutters
/// exactly fill the width, the same for every row of a grid, and draws on its own black.
///
/// Drawn cell by cell rather than as text so colour bars line up exactly with
/// the characters on them, ligatures never join neighbouring cells, and rows
/// touch without a seam between them.
class TvRow extends StatelessWidget {
  const TvRow({
    super.key,
    required this.runs,
    required this.columns,
    required this.style,
    this.onRun,
  });

  final List<StyledRun> runs;
  final int columns;
  final TextStyle? style;

  /// Runs the command of a tapped link. Links are not tappable without it.
  final RunCommand? onRun;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final label = plainText(runs).trimRight();
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = _fittingFontSize(
          base,
          scaler,
          constraints,
          columns + tvGutterCells,
        );
        final font = base.copyWith(fontSize: fontSize);
        final cell = TextPainter(
          text: TextSpan(text: 'M', style: font),
          textScaler: scaler,
          textDirection: TextDirection.ltr,
        )..layout();
        final cellWidth = cell.width;
        final rowHeight = cell.height;
        cell.dispose();
        // A headline row is two rows tall and its glyphs are stretched to fit.
        final tall = runs.any((run) => run.tall);

        return Semantics(
          label: label,
          excludeSemantics: true,
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
            heightFactor: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onRun == null
                  ? null
                  : (details) {
                      final command = tvCommandAt(
                        runs,
                        details.localPosition.dx / cellWidth -
                            tvGutterLeftCells,
                      );
                      if (command != null) onRun!(command);
                    },
              child: SizedBox(
                width: cellWidth * (columns + tvGutterCells),
                height: rowHeight * (tall ? 2 : 1),
                child: CustomPaint(
                  painter: _TvRowPainter(
                    runs: runs,
                    font: font,
                    scaler: scaler,
                    cellWidth: cellWidth,
                    tall: tall,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The font size at which [columns] characters fill the available width,
/// measured against the whole grid rather than one row so every row of a grid
/// lands on the same size. Left alone when the width is unbounded.
double _fittingFontSize(
  TextStyle base,
  TextScaler scaler,
  BoxConstraints constraints,
  int columns,
) {
  final size = base.fontSize ?? 14;
  if (!constraints.hasBoundedWidth) return size;
  final probe = TextPainter(
    text: TextSpan(text: 'M' * columns, style: base),
    textScaler: scaler,
    textDirection: TextDirection.ltr,
  )..layout();
  final needed = probe.width;
  probe.dispose();
  if (needed <= 0) return size;
  // A hair under, so rounding never pushes the last column past the edge.
  final scale = (constraints.maxWidth / needed * 0.995).clamp(
    0.0,
    tvUpscaleLimit,
  );
  return size * scale;
}

class _TvRowPainter extends CustomPainter {
  _TvRowPainter({
    required this.runs,
    required this.font,
    required this.scaler,
    required this.cellWidth,
    required this.tall,
  });

  final List<StyledRun> runs;
  final TextStyle font;
  final TextScaler scaler;
  final double cellWidth;
  final bool tall;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (tall) {
      // Draw the row at normal height and stretch the picture: backgrounds,
      // glyphs and underline together, as a teletext headline is.
      canvas.scale(1, 2);
      size = Size(size.width, size.height / 2);
    }
    // The screen itself is black, gutters included, edge to edge.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = tvColorOf(TvColor.black),
    );
    canvas.translate(tvGutterLeftCells * cellWidth, 0);
    _paintRow(canvas, size);
    canvas.restore();
  }

  void _paintRow(Canvas canvas, Size size) {
    var column = 0;
    for (final run in runs) {
      final cells = run.text.runes.length;
      final left = column * cellWidth;

      // Slightly oversize the background so neighbouring bars and rows
      // overlap rather than leave a hairline of the screen behind between them.
      canvas.drawRect(
        Rect.fromLTWH(left, 0, cells * cellWidth, size.height).inflate(0.5),
        Paint()..color = tvColorOf(run.bg),
      );

      final color = tvColorOf(run.fg);
      final mosaic = run.mosaic;
      var index = 0;
      for (final rune in run.text.runes) {
        if (mosaic != null) {
          _paintMosaic(
            canvas,
            size,
            mosaic[index],
            color,
            (column + index) * cellWidth,
          );
        } else if (rune != 0x20) {
          _paintCell(
            canvas,
            size,
            String.fromCharCode(rune),
            color,
            (column + index) * cellWidth,
          );
        }
        index++;
      }

      if (run.underline) {
        final visible = run.text.trimRight().runes.length;
        final thickness = (font.fontSize ?? 14) / 14;
        canvas.drawRect(
          Rect.fromLTWH(
            left,
            size.height - thickness * 2,
            visible * cellWidth,
            thickness,
          ),
          Paint()..color = color,
        );
      }
      column += cells;
    }
  }

  /// The lit sixths of a block-graphics cell: two columns by three rows, in the
  /// proportions of the site's own pictures (rows 5, 6 and 5 sixteenths of the
  /// height, columns 6 and 7 thirteenths of the width). Each is drawn a hair
  /// large, so lit cells that touch, and rows that touch, leave no seam.
  void _paintMosaic(
    Canvas canvas,
    Size size,
    int mask,
    Color color,
    double left,
  ) {
    final columns = [left, left + cellWidth * 6 / 13, left + cellWidth];
    final rows = [
      0.0,
      size.height * 5 / 16,
      size.height * 11 / 16,
      size.height,
    ];
    final paint = Paint()..color = color;
    for (var bit = 0; bit < 6; bit++) {
      if ((mask >> bit) & 1 == 0) continue;
      final row = bit ~/ 2;
      final column = bit % 2;
      canvas.drawRect(
        Rect.fromLTRB(
          columns[column],
          rows[row],
          columns[column + 1],
          rows[row + 1],
        ).inflate(0.5),
        paint,
      );
    }
  }

  void _paintCell(
    Canvas canvas,
    Size size,
    String character,
    Color color,
    double left,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: character,
        style: font.copyWith(color: color),
      ),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        left + (cellWidth - painter.width) / 2,
        (size.height - painter.height) / 2,
      ),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(_TvRowPainter old) =>
      !identical(old.runs, runs) ||
      old.font != font ||
      old.cellWidth != cellWidth ||
      old.tall != tall ||
      old.scaler != scaler;
}
