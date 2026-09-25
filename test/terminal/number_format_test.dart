import 'package:android_terminal_launcher/terminal/number_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('whole numbers have no decimal part', () {
    expect(formatNumber(3), '3');
    expect(formatNumber(-42), '-42');
    expect(formatNumber(1000000), '1000000');
  });

  test('negative zero prints as 0', () {
    expect(formatNumber(-0.0), '0');
  });

  test('float noise is rounded away', () {
    expect(formatNumber(0.1 + 0.2), '0.3');
    expect(formatNumber(2.9999999999999996), '3');
  });

  test('other fractions keep their digits without trailing zeros', () {
    expect(formatNumber(2.5), '2.5');
    expect(formatNumber(100.5), '100.5');
    expect(formatNumber(1234.5678), '1234.5678');
    expect(formatNumber(1 / 3), '0.333333333333');
  });

  test('fewer significant digits when asked', () {
    expect(formatNumber(3.10685596119, significant: 8), '3.106856');
    expect(formatNumber(37.7777777778, significant: 8), '37.777778');
  });

  test('very large and very small numbers use an exponent', () {
    expect(formatNumber(1e20), '1e+20');
    expect(formatNumber(1e-7), '1e-7');
    expect(formatNumber(1.5e-9), '1.5e-9');
  });
}
