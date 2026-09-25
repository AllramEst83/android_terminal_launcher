import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/clear_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';

void main() {
  test('asks the session to clear the log', () async {
    final result = await clearCommand.run(
      CommandContext(
        args: const [],
        apps: FakeAppRepository(),
        commands: const [],
      ),
    );

    expect(result, isA<CommandClear>());
  });
}
