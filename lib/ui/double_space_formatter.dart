import 'package:android_terminal_launcher/terminal/tools/double_space.dart';
import 'package:flutter/services.dart';

/// Applies [periodOnDoubleSpace] to the prompt: typing a space twice ends the
/// sentence with `. `.
class DoubleSpaceFormatter extends TextInputFormatter {
  const DoubleSpaceFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only a plain keystroke with the cursor in place, not a selection or an
    // IME still composing a word.
    if (!newValue.selection.isCollapsed || newValue.composing.isValid) {
      return newValue;
    }
    final edit = periodOnDoubleSpace(
      oldValue.text,
      newValue.text,
      newValue.selection.baseOffset,
    );
    if (edit == null) return newValue;
    return TextEditingValue(
      text: edit.text,
      selection: TextSelection.collapsed(offset: edit.cursor),
    );
  }
}
