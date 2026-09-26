import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/font_size_settings.dart';

class FakeFontSizeSettings implements FontSizeSettings {
  FakeFontSizeSettings({this.current = FontSizeChoice.normal, this.saveError});

  @override
  FontSizeChoice current;

  /// Thrown by [select] after the size has changed, like a failed save.
  Object? saveError;

  /// Every choice passed to [select], in call order.
  final List<FontSizeChoice> selected = [];

  @override
  Future<void> select(FontSizeChoice choice) async {
    selected.add(choice);
    current = choice;
    final error = saveError;
    if (error != null) throw error;
  }
}
