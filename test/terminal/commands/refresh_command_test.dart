import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/app_repository_exception.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/refresh_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';

Future<CommandResult> _refresh(FakeAppRepository apps) {
  return refreshCommand.run(
    CommandContext(args: const [], apps: apps, commands: const []),
  );
}

void main() {
  test('asks the repository for a fresh listing', () async {
    final apps = FakeAppRepository();

    await _refresh(apps);

    expect(apps.refreshCalls, 1);
  });

  test('reports how many apps were found', () async {
    final apps = FakeAppRepository(
      apps: const [
        AppInfo(label: 'Clock', packageName: 'clock'),
        AppInfo(label: 'Maps', packageName: 'maps'),
      ],
    );

    final result = await _refresh(apps);

    expect((result as CommandOutput).lines, [Messages.refreshed(2)]);
  });

  test('uses the singular for one app', () async {
    final apps = FakeAppRepository(
      apps: const [AppInfo(label: 'Clock', packageName: 'clock')],
    );

    final result = await _refresh(apps);

    expect((result as CommandOutput).lines, ['refreshed: 1 app']);
  });

  test('lets a repository failure propagate to the session', () {
    final apps = FakeAppRepository(
      listError: const AppRepositoryException('boom'),
    );

    expect(_refresh(apps), throwsA(isA<AppRepositoryException>()));
  });
}
