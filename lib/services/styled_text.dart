/// The eight colours of teletext. The UI maps them to a fixed palette that does
/// not follow the theme: a teletext page is drawn on its own black screen in
/// every theme, because white and yellow text would vanish on a light one.
enum TvColor { black, red, green, yellow, blue, magenta, cyan, white }

/// A stretch of text in one style. A line of coloured output is a list of runs
/// that together cover it; the plain text of the line is their [text] joined,
/// so anything that only wants text (tests, copying) can ignore the style.
class StyledRun {
  const StyledRun(
    this.text, {
    this.fg = TvColor.white,
    this.bg = TvColor.black,
    this.underline = false,
    this.tall = false,
    this.mosaic,
    this.command,
  });

  final String text;
  final TvColor fg;
  final TvColor bg;
  final bool underline;

  /// Drawn twice as high as it is wide, like a teletext headline. A tall run
  /// takes up two rows of the grid: the row itself and the blank one under it,
  /// which the source has already left out. Every run of a row is tall or none
  /// is.
  final bool tall;

  /// Set when the cells are block graphics, not characters: one pattern per
  /// cell (so as many as [text] has characters, which are blanks), each a
  /// 6-bit mask of which sixths of the cell show [fg] rather than [bg]. Bit
  /// `row * 2 + column` is the sixth in that row (0 top to 2 bottom) and
  /// column (0 left, 1 right).
  final List<int>? mosaic;

  /// A command line a tap on this run runs (a page number that opens that
  /// page), or null when it is not tappable.
  final String? command;

  bool sameStyleAs(StyledRun other) =>
      fg == other.fg &&
      bg == other.bg &&
      underline == other.underline &&
      tall == other.tall &&
      command == other.command &&
      (mosaic == null) == (other.mosaic == null);

  @override
  bool operator ==(Object other) =>
      other is StyledRun &&
      other.text == text &&
      sameStyleAs(other) &&
      _sameMasks(mosaic, other.mosaic);

  @override
  int get hashCode => Object.hash(
    text,
    fg,
    bg,
    underline,
    tall,
    command,
    mosaic == null ? null : Object.hashAll(mosaic!),
  );

  @override
  String toString() =>
      'StyledRun(${text.length} "$text" ${fg.name}/${bg.name}'
      '${underline ? ' underline' : ''}${tall ? ' tall' : ''}'
      '${mosaic == null ? '' : ' mosaic $mosaic'}'
      '${command == null ? '' : ' -> $command'})';
}

bool _sameMasks(List<int>? a, List<int>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The text of a styled line.
String plainText(List<StyledRun> runs) => runs.map((run) => run.text).join();

/// [runs] with neighbours of the same style joined, and empty runs dropped.
List<StyledRun> mergeRuns(Iterable<StyledRun> runs) {
  final merged = <StyledRun>[];
  for (final run in runs) {
    if (run.text.isEmpty) continue;
    if (merged.isNotEmpty && merged.last.sameStyleAs(run)) {
      final last = merged.last;
      merged[merged.length - 1] = StyledRun(
        last.text + run.text,
        fg: run.fg,
        bg: run.bg,
        underline: run.underline,
        tall: run.tall,
        command: run.command,
        mosaic: last.mosaic == null ? null : [...last.mosaic!, ...run.mosaic!],
      );
    } else {
      merged.add(run);
    }
  }
  return merged;
}
