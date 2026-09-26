import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';

/// A statement of what happened, as output: the [message] and any [details] as
/// plain lines, and as a [NoticeBlock] with an icon for the rich view.
CommandOutput noticeOutput(
  String message, {
  NoticeKind kind = NoticeKind.success,
  List<String> details = const [],
}) => CommandOutput([
  message,
  ...details,
], block: NoticeBlock(kind: kind, message: message, details: details));
