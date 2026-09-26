import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/tools/app_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';

final listCommand = Command(
  name: 'list',
  description: 'List installed apps',
  usage: 'list',
  run: (context) async {
    final apps = await context.apps.listApps();
    if (apps.isEmpty) {
      return noticeOutput(Messages.noApps, kind: NoticeKind.info);
    }
    return CommandOutput([
      for (final app in apps) app.label,
    ], block: appsChoices(apps));
  },
);
