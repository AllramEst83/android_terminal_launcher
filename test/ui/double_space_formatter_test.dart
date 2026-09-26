import 'package:android_terminal_launcher/terminal/suggestion.dart';
import 'package:android_terminal_launcher/ui/double_space_formatter.dart';
import 'package:android_terminal_launcher/ui/prompt_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _at(String text, [int? cursor]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: cursor ?? text.length),
);

void main() {
  const formatter = DoubleSpaceFormatter();

  group('DoubleSpaceFormatter', () {
    test('turns the second space into a full stop and a space', () {
      final result = formatter.formatEditUpdate(
        _at('Test sentence '),
        _at('Test sentence  '),
      );

      expect(result.text, 'Test sentence. ');
      expect(result.selection, const TextSelection.collapsed(offset: 15));
    });

    test('leaves an ordinary keystroke alone', () {
      final result = formatter.formatEditUpdate(_at('Test'), _at('Tests'));

      expect(result.text, 'Tests');
    });

    test('leaves a selection alone', () {
      const selected = TextEditingValue(
        text: 'Test sentence  ',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
      );

      expect(
        formatter.formatEditUpdate(_at('Test sentence '), selected),
        selected,
      );
    });

    test('leaves a word still being composed alone', () {
      const composing = TextEditingValue(
        text: 'Test sentence  ',
        selection: TextSelection.collapsed(offset: 15),
        composing: TextRange(start: 5, end: 13),
      );

      expect(
        formatter.formatEditUpdate(_at('Test sentence '), composing),
        composing,
      );
    });
  });

  group('in the prompt', () {
    Future<TextField> pumpPrompt(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PromptInput(
              onSubmit: (_) async {},
              onSuggest: (_) async => const <Suggestion>[],
            ),
          ),
        ),
      );
      return tester.widget<TextField>(find.byType(TextField));
    }

    String text(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('typing a space twice ends the sentence', (tester) async {
      await pumpPrompt(tester);

      await tester.enterText(find.byType(TextField), 'note add hello ');
      await tester.enterText(find.byType(TextField), 'note add hello  ');

      expect(text(tester), 'note add hello. ');
    });

    testWidgets('a command word followed by two spaces is untouched', (
      tester,
    ) async {
      await pumpPrompt(tester);

      await tester.enterText(find.byType(TextField), 'list ');
      await tester.enterText(find.byType(TextField), 'list  ');

      expect(text(tester), 'list  ');
    });

    testWidgets('the cursor ends after the new space', (tester) async {
      await pumpPrompt(tester);

      await tester.enterText(find.byType(TextField), 'note add hello ');
      await tester.enterText(find.byType(TextField), 'note add hello  ');

      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(controller.selection.baseOffset, controller.text.length);
    });
  });
}
