import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/list_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';

void main() {
  test('prints one app label per line', () async {
    final apps = FakeAppRepository(
      apps: const [
        AppInfo(label: 'Clock', packageName: 'clock'),
        AppInfo(label: 'Maps', packageName: 'maps'),
      ],
    );

    final result = await listCommand.run(
      CommandContext(args: const [], apps: apps, commands: const []),
    );

    expect(result, isA<CommandOutput>());
    expect((result as CommandOutput).lines, ['Clock', 'Maps']);
  });

  test('says so when there are no apps', () async {
    final result = await listCommand.run(
      CommandContext(
        args: const [],
        apps: FakeAppRepository(),
        commands: const [],
      ),
    );

    expect((result as CommandOutput).lines, [Messages.noApps]);
  });
}
