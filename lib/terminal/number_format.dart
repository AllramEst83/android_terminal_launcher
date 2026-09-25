/// Prints [value] the way a person would write it: whole numbers without a
/// `.0`, and everything else rounded to [significant] digits with trailing
/// zeros removed, so `0.1 + 0.2` shows as `0.3` rather than
/// `0.30000000000000004`. Callers reject NaN and infinity before formatting.
String formatNumber(double value, {int significant = 12}) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  final text = value.toStringAsPrecision(significant);
  final exponentAt = text.indexOf('e');
  if (exponentAt == -1) return _trimZeros(text);
  return _trimZeros(text.substring(0, exponentAt)) + text.substring(exponentAt);
}

String _trimZeros(String digits) {
  if (!digits.contains('.')) return digits;
  return digits.replaceFirst(RegExp(r'\.?0+$'), '');
}
