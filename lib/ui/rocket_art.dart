/// Width of every line of every frame, so the whole picture can be centred as
/// one block without the rocket shearing (each line padded to the same width).
const rocketArtWidth = 11;

/// How many rows the rocket climbs during the launch. Tall enough that it
/// clears the screen's top third: it is meant to be seen leaving.
const rocketLift = 10;

const _rocket = [
  r'    ^    ',
  r'   / \   ',
  r'  | O |  ',
  r' /|___|\ ',
  r'  /_|_\  ',
];

/// The exhaust, in three sizes: idling on the pad, and two that alternate
/// while the engines burn.
const _idle = [r'    .    ', r'         '];
const _burnA = [r'   \|/   ', r'    v    '];
const _burnB = [r'   (|)   ', r'    :    '];

const _pad = '===========';
const _flameRows = 2;

/// Rows from the top of the picture to the pad, rocket and exhaust included.
const rocketArtHeight = _rocketRows + _flameRows + 1 + rocketLift;
const _rocketRows = 5;

/// One picture of the rocket [lift] rows above the pad (0 to [rocketLift])
/// with the given [exhaust] lines. Every frame is [rocketArtHeight] lines of
/// [rocketArtWidth] characters, plain ASCII only, so it never falls back off
/// `JetBrainsMono` onto a font whose glyphs have another width.
List<String> _frame(int lift, List<String> exhaust) {
  final blank = ' ' * rocketArtWidth;
  final top = rocketArtHeight - 1 - _flameRows - _rocketRows - lift;
  final art = [..._rocket, ...exhaust];
  return [
    for (var row = 0; row < rocketArtHeight - 1; row++)
      row >= top && row < top + art.length ? ' ${art[row - top]} ' : blank,
    _pad,
  ];
}

/// The launch, frame by frame: ignition on the pad, then the climb, then the
/// rocket settles high in the sky with its engines idling. It ends there on
/// purpose (see `AsciiBanner`).
final List<List<String>> rocketFrames = List.unmodifiable([
  _frame(0, _idle),
  _frame(0, _burnA),
  _frame(0, _burnB),
  // Slow off the pad, then faster: bigger steps as it gathers speed.
  _frame(1, _burnA),
  _frame(2, _burnB),
  _frame(3, _burnA),
  _frame(5, _burnB),
  _frame(7, _burnA),
  _frame(9, _burnB),
  _frame(10, _burnA),
  _frame(10, _idle),
]);
