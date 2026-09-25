import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/open_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';

const _firefox = AppInfo(label: 'Firefox', packageName: 'org.mozilla.firefox');
const _chrome = AppInfo(label: 'Chrome', packageName: 'com.android.chrome');
const _chromeBeta = AppInfo(
  label: 'Chrome Beta',
  packageName: 'com.chrome.beta',
);

Future<CommandResult> _open(FakeAppRepository apps, List<String> args) {
  return openCommand.run(
    CommandContext(args: args, apps: apps, commands: const []),
  );
}

void main() {
  test('launches the single matching app', () async {
    final apps = FakeAppRepository(apps: const [_firefox, _chrome]);

    final result = await _open(apps, ['firefox']);

    expect(apps.launched, ['org.mozilla.firefox']);
    expect((result as CommandOutput).lines, [Messages.opening('Firefox')]);
  });

  test('joins multi-word args into one name', () async {
    const app = AppInfo(label: 'Google Maps', packageName: 'maps');
    final apps = FakeAppRepository(apps: const [app]);

    await _open(apps, ['google', 'maps']);

    expect(apps.launched, ['maps']);
  });

  test('open prefers exact match over substring', () async {
    final apps = FakeAppRepository(apps: const [_chromeBeta, _chrome]);

    await _open(apps, ['chrome']);

    expect(apps.launched, ['com.android.chrome']);
  });

  test('lists candidates instead of guessing when several match', () async {
    final apps = FakeAppRepository(apps: const [_chrome, _chromeBeta]);

    final result = await _open(apps, ['chr']);

    expect(apps.launched, isEmpty);
    expect((result as CommandFailure).lines, [
      Messages.ambiguousApp('chr'),
      '  Chrome',
      '  Chrome Beta',
    ]);
  });

  test('reports when no app matches', () async {
    final apps = FakeAppRepository(apps: const [_firefox]);

    final result = await _open(apps, ['zzz']);

    expect(apps.launched, isEmpty);
    expect((result as CommandFailure).lines, [Messages.noAppFound('zzz')]);
  });

  test('prints usage when given no app name', () async {
    final apps = FakeAppRepository(apps: const [_firefox]);

    final result = await _open(apps, const []);

    expect((result as CommandFailure).lines, [Messages.openUsage]);
    expect(apps.launched, isEmpty);
  });

  test('reports a failed launch', () async {
    final apps = FakeAppRepository(
      apps: const [_firefox],
      launchSucceeds: false,
    );

    final result = await _open(apps, ['firefox']);

    expect((result as CommandFailure).lines, [
      Messages.launchFailed('Firefox'),
    ]);
  });
}
