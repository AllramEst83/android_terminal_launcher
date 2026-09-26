import 'dart:typed_data';

import 'package:android_terminal_launcher/services/styled_text.dart';

/// What a block-graphics cell of a Text TV page shows: which sixths of it are
/// lit ([mask], see `StyledRun.mosaic`) in [fg] over [bg]. A cell with one
/// colour all over has [mask] 0 and [fg] equal to [bg].
class TvPicture {
  const TvPicture(this.mask, this.fg, this.bg);

  final int mask;
  final TvColor fg;
  final TvColor bg;
}

/// The picture behind the hash in a texttv.nu picture address
/// (`storage/chars/2413702233.gif`), or null if it is not one this knows.
///
/// texttv.nu draws its block graphics (the big logo lettering, the bars) as
/// one small GIF per cell and names each after the CRC-32 of its bytes. Every
/// such GIF is one of a few thousand: a 13 by 16 picture in two colours, split
/// into a 2 by 3 grid of sixths, each lit or not. Rather than download them (or
/// ship a table that goes stale), this builds every one of them the way the
/// site does, hashes it, and looks the hash up. Built on first use, in a
/// millisecond or few, and only ever asked about pictures the page named.
TvPicture? tvPictureFor(int hash) => _pictures[hash];

// Top-level variables are initialised on first use, so this is built lazily.
final Map<int, TvPicture> _pictures = _build();

const _width = 13;
const _height = 16;

// The site's palette is teletext's eight colours with each channel pulled in
// from 0/255 to 4/252 (and 2/254 for green), so it is not pure black or white.
const _rgb = {
  TvColor.black: [4, 2, 4],
  TvColor.red: [252, 2, 4],
  TvColor.green: [4, 254, 4],
  TvColor.yellow: [252, 254, 4],
  TvColor.blue: [4, 2, 252],
  TvColor.magenta: [252, 2, 252],
  TvColor.cyan: [4, 254, 252],
  TvColor.white: [252, 254, 252],
};

Map<int, TvPicture> _build() {
  final pictures = <int, TvPicture>{};
  // A cell of one colour is drawn with that colour and a placeholder black.
  for (final colour in TvColor.values) {
    final gif = _gif([
      _rgb[colour]!,
      [0, 0, 0],
    ], _lzw(List.filled(208, 0)));
    pictures[_crc32(gif)] = TvPicture(0, colour, colour);
  }
  // The pixels, and so the compressed data, depend on the mask alone; only the
  // palette in the header changes with the colours.
  for (var mask = 1; mask < 63; mask++) {
    final data = _lzw(_pixels(mask));
    for (final bg in TvColor.values) {
      for (final fg in TvColor.values) {
        if (fg == bg) continue;
        final gif = _gif([_rgb[bg]!, _rgb[fg]!], data);
        pictures[_crc32(gif)] = TvPicture(mask, fg, bg);
      }
    }
  }
  return pictures;
}

/// The 13 by 16 pixels of [mask]: 1 where lit. Rows split 5, 6, 5 and columns
/// 6, 7, the way the site cuts a cell.
List<int> _pixels(int mask) {
  return [
    for (var y = 0; y < _height; y++)
      for (var x = 0; x < _width; x++)
        (mask >> ((y < 5 ? 0 : (y < 11 ? 1 : 2)) * 2 + (x < 6 ? 0 : 1))) & 1,
  ];
}

/// GIF LZW with a 2-bit alphabet (the two palette entries), as every GIF
/// encoder does it.
Uint8List _lzw(List<int> pixels) {
  const clear = 4;
  const end = 5;
  final codes = <(int, int)>[]; // (code, width in bits)
  final table = <int, int>{}; // prefix code * 4 + pixel -> code
  var width = 3;
  var next = end + 1;
  codes.add((clear, width));
  var current = pixels.first;
  for (final pixel in pixels.skip(1)) {
    final key = current * 4 + pixel;
    final known = table[key];
    if (known != null) {
      current = known;
      continue;
    }
    codes.add((current, width));
    table[key] = next++;
    if (next - 1 == (1 << width) && width < 12) width++;
    current = pixel;
  }
  codes.add((current, width));
  codes.add((end, width));

  final bytes = <int>[];
  var bits = 0;
  var count = 0;
  for (final (code, size) in codes) {
    bits |= code << count;
    count += size;
    while (count >= 8) {
      bytes.add(bits & 0xFF);
      bits >>= 8;
      count -= 8;
    }
  }
  if (count > 0) bytes.add(bits & 0xFF);
  return Uint8List.fromList(bytes);
}

/// The whole GIF file: header, a two-colour palette, one image, [data] cut into
/// blocks of at most 255 bytes.
Uint8List _gif(List<List<int>> palette, Uint8List data) {
  final bytes = <int>[
    ...'GIF87a'.codeUnits,
    _width, 0, _height, 0, // size, little-endian
    0x80, 0, 0, // a 2-colour global palette; background index; aspect
    for (final colour in palette) ...colour,
    0x2C, 0, 0, 0, 0, _width, 0, _height, 0, 0, // the image
    2, // LZW minimum code size
  ];
  for (var i = 0; i < data.length; i += 255) {
    final block = data.sublist(
      i,
      i + 255 > data.length ? data.length : i + 255,
    );
    bytes
      ..add(block.length)
      ..addAll(block);
  }
  bytes.addAll(const [0, 0x3B]);
  return Uint8List.fromList(bytes);
}

final _crcTable = () {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}();

int _crc32(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}
