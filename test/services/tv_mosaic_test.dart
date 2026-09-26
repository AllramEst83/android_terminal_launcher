import 'dart:io';

import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/services/tv_mosaic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pictures the site really uses', () {
    // Each of these is a real texttv.nu picture, looked at in a paint program
    // and written down: the bits are the lit sixths, row by row from the top,
    // left before right.
    void expectPicture(
      int hash, {
      required int mask,
      required TvColor fg,
      required TvColor bg,
    }) {
      final picture = tvPictureFor(hash);

      expect(picture, isNotNull, reason: '$hash');
      expect(picture!.mask, mask, reason: '$hash');
      expect(picture.fg, fg, reason: '$hash');
      expect(picture.bg, bg, reason: '$hash');
    }

    test('the lower two thirds lit, white on blue (a logo stroke)', () {
      expectPicture(2413702233, mask: 60, fg: TvColor.white, bg: TvColor.blue);
    });

    test('the right half of the lower two thirds', () {
      expectPicture(693852549, mask: 40, fg: TvColor.white, bg: TvColor.blue);
    });

    test('everything lit but the lower left', () {
      expectPicture(15963642, mask: 47, fg: TvColor.white, bg: TvColor.blue);
    });

    test('a bar across the middle, yellow on black', () {
      expectPicture(
        2218724507,
        mask: 12,
        fg: TvColor.yellow,
        bg: TvColor.black,
      );
    });

    test('a bar along the bottom, yellow on black', () {
      expectPicture(
        1254105466,
        mask: 48,
        fg: TvColor.yellow,
        bg: TvColor.black,
      );
    });

    test('a cell of one colour has no lit part, and that colour twice', () {
      final picture = tvPictureFor(1074033251)!;

      expect(picture.mask, 0);
      expect(picture.fg, TvColor.white);
      expect(picture.bg, TvColor.white);
    });
  });

  test('every picture on the saved pages is known', () {
    final hashes = <int>{};
    for (final file in Directory(
      'test/fixtures',
    ).listSync().whereType<File>()) {
      final text = file.readAsStringSync();
      for (final match in RegExp(
        r'storage/chars/(\d+)\.gif',
      ).allMatches(text)) {
        hashes.add(int.parse(match[1]!));
      }
    }

    expect(hashes, isNotEmpty);
    expect(hashes.where((hash) => tvPictureFor(hash) == null), isEmpty);
  });

  test('an unknown hash is null', () {
    expect(tvPictureFor(1), isNull);
    expect(tvPictureFor(-5), isNull);
    // The pictures the site draws that are not block graphics (page 777's
    // test card, the weather symbols) are not known either.
    for (final hash in [
      692512409,
      221339736,
      2358923843,
      2057975240,
      644889415,
    ]) {
      expect(tvPictureFor(hash), isNull, reason: '$hash');
    }
  });

  test('repeated lookups give the same answer', () {
    expect(tvPictureFor(2413702233), same(tvPictureFor(2413702233)));
  });
}
