import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_app_repository.dart';

TerminalSession _session() {
  final session = TerminalSession(
    registry: CommandRegistry(defaultCommands),
    apps: FakeAppRepository(),
    banner: [Messages.welcome],
  );
  addTearDown(session.dispose);
  return session;
}

void main() {
  testWidgets('app shows the welcome banner and the prompt', (tester) async {
    await tester.pumpWidget(App(session: _session()));

    expect(find.text(Messages.welcome), findsOneWidget);
    expect(find.text(Messages.prompt), findsOneWidget);
  });

  testWidgets('back is blocked so the launcher never exits', (tester) async {
    await tester.pumpWidget(App(session: _session()));

    expect(
      find.byWidgetPredicate((w) => w is PopScope && !w.canPop),
      findsOneWidget,
    );
  });
}
