import 'package:android_terminal_launcher/ui/ascii_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: AsciiBanner(caption: 'hi'))),
  );
}

void main() {
  testWidgets('shows the caption and the opening frame', (tester) async {
    await _pump(tester);

    expect(find.text('hi'), findsOneWidget);
    expect(find.textContaining('o.o'), findsOneWidget);
  });

  testWidgets('blinks a couple of times, then stops changing', (
    tester,
  ) async {
    await _pump(tester);

    await tester.pump(const Duration(milliseconds: 450));
    expect(find.textContaining('-.-'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 450));
    expect(find.textContaining('o.o'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 450));
    expect(find.textContaining('-.-'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 450));
    expect(find.textContaining('o.o'), findsOneWidget);

    // The timer must have cancelled itself by now: pumping well past it must
    // neither change the frame again nor leave a pending timer behind (which
    // would fail the test on its own).
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('o.o'), findsOneWidget);
  });
}
