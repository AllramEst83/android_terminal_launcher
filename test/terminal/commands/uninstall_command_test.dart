import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/uninstall_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';

const _firefox = AppInfo(label: 'Firefox', packageName: 'org.mozilla.firefox');
const _chrome = AppInfo(label: 'Chrome', packageName: 'com.android.chrome');
const _chromeBeta = AppInfo(
  label: 'Chrome Beta',
  packageName: 'com.chrome.beta',
);

Future<CommandResult> _uninstall(FakeAppRepository apps, List<String> args) {
  return uninstallCommand.run(
    CommandContext(args: args, apps: apps, commands: const []),
  );
}

void main() {
  test('asks Android to uninstall the single matching app', () async {
    final apps = FakeAppRepository(apps: const [_firefox, _chrome]);

    final result = await _uninstall(apps, ['firefox']);

    expect(apps.uninstalled, ['org.mozilla.firefox']);
    expect((result as CommandOutput).lines, [
      Messages.uninstallStarted('Firefox'),
    ]);
  });

  test('never launches the app it is removing', () async {
    final apps = FakeAppRepository(apps: const [_firefox]);

    await _uninstall(apps, ['firefox']);

    expect(apps.launched, isEmpty);
  });

  test('joins multi-word args into one name', () async {
    const app = AppInfo(label: 'Google Maps', packageName: 'maps');
    final apps = FakeAppRepository(apps: const [app]);

    await _uninstall(apps, ['google', 'maps']);

    expect(apps.uninstalled, ['maps']);
  });

  test('prefers an exact match over a longer name', () async {
    final apps = FakeAppRepository(apps: const [_chromeBeta, _chrome]);

    await _uninstall(apps, ['chrome']);

    expect(apps.uninstalled, ['com.android.chrome']);
  });

  test('lists candidates and removes nothing when several match', () async {
    final apps = FakeAppRepository(apps: const [_chrome, _chromeBeta]);

    final result = await _uninstall(apps, ['chr']);

    expect(apps.uninstalled, isEmpty);
    expect((result as CommandFailure).lines, [
      Messages.ambiguousApp('chr'),
      '  Chrome',
      '  Chrome Beta',
    ]);
  });

  test('reports when no app matches and removes nothing', () async {
    final apps = FakeAppRepository(apps: const [_firefox]);

    final result = await _uninstall(apps, ['zzz']);

    expect(apps.uninstalled, isEmpty);
    expect((result as CommandFailure).lines, [Messages.noAppFound('zzz')]);
  });

  test('prints its own usage when given no app name', () async {
    final apps = FakeAppRepository(apps: const [_firefox]);

    final result = await _uninstall(apps, const []);

    expect((result as CommandFailure).lines, [Messages.uninstallUsage]);
    expect(apps.uninstalled, isEmpty);
  });

  test('reports when the uninstall dialog cannot be started', () async {
    final apps = FakeAppRepository(
      apps: const [_firefox],
      uninstallSucceeds: false,
    );

    final result = await _uninstall(apps, ['firefox']);

    expect((result as CommandFailure).lines, [
      Messages.uninstallFailed('Firefox'),
    ]);
  });

  test('suggests app names for its argument', () {
    final suggest = uninstallCommand.argSuggestions!;

    expect(suggest('fire', const [_firefox, _chrome]), ['Firefox']);
  });
}
