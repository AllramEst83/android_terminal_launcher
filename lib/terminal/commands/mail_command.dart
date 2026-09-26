import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/mail_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/plain_flag.dart';
import 'package:android_terminal_launcher/terminal/tools/mail_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/mail_hosts.dart';
import 'package:android_terminal_launcher/terminal/tools/mail_text.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';

const _subcommands = ['rm', 'setup', 'forget'];

/// How many messages `mail` lists.
const mailCount = 20;

/// The list `mail` last showed. `mail rm` goes by it, so a number means the
/// message that was on screen at that number, however much mail has come in
/// since, and an id can only be one the user has seen.
class _LastList {
  bool shown = false;
  int? validity;
  List<MailMessage> messages = const [];

  /// Ids already moved to Trash from this list.
  final removed = <int>{};

  void show(MailMessages found) {
    shown = true;
    validity = found.validity;
    messages = found.messages;
    removed.clear();
  }
}

/// `mail` lists the newest messages in the inbox; `mail rm <number>` moves one
/// of them to Trash (never deletes it); `mail setup <email>` connects an
/// account (the password is asked for on a hidden line, never typed in the
/// command); `mail forget` removes it again. The only change it ever makes to
/// a mailbox is moving a message to Trash, and only when asked by number or id.
Command mailCommand(MailService mail) {
  final last = _LastList();
  return Command(
    name: 'mail',
    aliases: ['email'],
    description: 'Read your latest email',
    usage: 'mail [rm|setup|forget]',
    forms: [
      'mail',
      'mail rm <number>',
      'mail setup <email> [server]',
      'mail forget',
    ],
    examples: ['mail', 'mail rm 3', 'mail setup you@gmail.com'],
    notes: [
      'the $mailCount newest, numbered',
      'rm: to Trash, not deleted; the',
      '  number is from the last list',
      'needs an app password, not your',
      '  normal one. Gmail: Google account',
      '  > Security > App passwords',
      'asked for on a hidden line, kept',
      '  encrypted on this phone',
      'server is guessed for gmail, icloud,',
      '  yahoo and a few more; else add it',
      '--plain: text only, this once',
    ],
    run: (context) => _mail(mail, last, context.args, context.now()),
    spinner: true,
    argSuggestions: _suggestArgs,
  );
}

List<String> _suggestArgs(String partial, List<AppInfo> apps) {
  final words = partial.split(' ');
  if (words.length != 1) return const [];
  final typed = words.first.toLowerCase();
  return [
    for (final option in _subcommands)
      if (option.startsWith(typed)) option,
  ];
}

Future<CommandResult> _mail(
  MailService mail,
  _LastList last,
  List<String> allArgs,
  DateTime now,
) async {
  final (:args, :plain) = splitPlainFlag(allArgs);
  if (args.isEmpty) return _latest(mail, last, now, plain: plain);
  switch (args.first.toLowerCase()) {
    case 'rm' when args.length == 2:
      return _remove(mail, last, args[1]);
    case 'setup' when args.length == 2 || args.length == 3:
      return _setUp(mail, args[1], args.length == 3 ? args[2] : null);
    case 'forget' when args.length == 1:
      return _forget(mail);
    default:
      return const CommandFailure(Messages.mailUsage);
  }
}

Future<CommandResult> _latest(
  MailService mail,
  _LastList last,
  DateTime now, {
  required bool plain,
}) async {
  final result = await mail.latest(count: mailCount);
  if (result is MailMessages) last.show(result);
  return switch (result) {
    MailMessages(messages: final list) when list.isEmpty => noticeOutput(
      Messages.mailEmpty,
      kind: NoticeKind.info,
    ),
    MailMessages() => CommandOutput(
      mailLines(result, now),
      block: plain ? null : mailBlock(result, now),
    ),
    MailNotSetUp() => const CommandFailure([
      Messages.mailNotSetUp,
      Messages.mailHowToSetUp,
    ]),
    MailUnavailable(:final reason) => CommandFailure.single(
      Messages.mailError(reason),
    ),
  };
}

/// `3` is the third message of the last list; `#48213` is the message with that
/// server id (what the card's button puts in the prompt, so it stays right
/// even if the list has been shown again since).
Future<CommandResult> _remove(
  MailService mail,
  _LastList last,
  String target,
) async {
  if (!last.shown || last.messages.isEmpty) {
    return const CommandFailure([Messages.mailNoList]);
  }
  final MailMessage? message;
  if (target.startsWith('#')) {
    final uid = int.tryParse(target.substring(1));
    if (uid == null || uid < 1) {
      return const CommandFailure(Messages.mailUsage);
    }
    message = last.messages.where((m) => m.uid == uid).firstOrNull;
    if (message == null) {
      return CommandFailure.single(Messages.mailNotInList(uid));
    }
  } else {
    final number = int.tryParse(target);
    if (number == null || number < 1) {
      return const CommandFailure(Messages.mailUsage);
    }
    if (number > last.messages.length) {
      return CommandFailure.single(
        Messages.mailNoSuchNumber(number, last.messages.length),
      );
    }
    message = last.messages[number - 1];
  }
  if (last.removed.contains(message.uid)) {
    return CommandFailure.single(Messages.mailAlreadyMoved);
  }

  final result = await mail.moveToTrash(message.uid, validity: last.validity);
  switch (result) {
    case MailMoved(:final folder):
      last.removed.add(message.uid);
      return noticeOutput(
        Messages.mailMoved(clip(mailSubject(message), 40), folder),
        details: const [Messages.mailMovedTip],
      );
    case MailGone():
      last.removed.add(message.uid);
      return CommandFailure.single(Messages.mailGone);
    case MailMoveNotSetUp():
      return const CommandFailure([
        Messages.mailNotSetUp,
        Messages.mailHowToSetUp,
      ]);
    case MailMoveFailed(:final reason):
      return CommandFailure.single(Messages.mailError(reason));
  }
}

CommandResult _setUp(MailService mail, String email, String? server) {
  if (!looksLikeEmail(email)) {
    return CommandFailure.single(Messages.mailBadAddress(email));
  }
  final host = server ?? imapServerFor(email);
  if (host == null) {
    return CommandFailure([
      Messages.mailNoServer(emailDomain(email)),
      Messages.mailGiveServer,
    ]);
  }
  return CommandAskSecret(Messages.mailPasswordPrompt(email), busy: true, (
    typed,
  ) async {
    // Google shows an app password as four groups of four; none has a space.
    final password = typed.replaceAll(RegExp(r'\s'), '');
    if (password.isEmpty) {
      return CommandFailure.single(Messages.secretCancelled);
    }
    final problem = await mail.setUp(
      email: email,
      host: host,
      password: password,
    );
    if (problem != null) {
      return CommandFailure.single(Messages.mailError(problem));
    }
    return noticeOutput(
      Messages.mailSetUp(email),
      details: const [Messages.mailTry],
    );
  });
}

Future<CommandResult> _forget(MailService mail) async {
  final had = await mail.forget();
  return noticeOutput(
    had ? Messages.mailForgotten : Messages.mailNothingToForget,
    kind: had ? NoticeKind.success : NoticeKind.info,
  );
}
