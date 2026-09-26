import 'dart:async';
import 'dart:io';

import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/mail_account.dart';
import 'package:android_terminal_launcher/services/mail_service.dart';
import 'package:enough_mail/enough_mail.dart'
    show
        ImapClient,
        ImapException,
        MessageFlags,
        MessageSequence,
        MimeMessage,
        StatusFlags,
        StoreAction;

/// [MailService] on `enough_mail`'s IMAP client. This is the only file that
/// knows about the package. Listing only reads (a message is fetched by its
/// envelope, so no body is downloaded). The one change it can make is moving a
/// message to Trash, which never deletes anything outright.
class ImapMailService implements MailService {
  ImapMailService({
    required this._accounts,
    this.secure = true,
    this.timeout = const Duration(seconds: 20),
  });

  final MailAccountStore _accounts;

  /// TLS to the server. Only a test against a local server turns it off.
  final bool secure;

  /// For connecting and for each answer after that.
  final Duration timeout;

  @override
  Future<MailAccountInfo?> account() async {
    try {
      final saved = await _accounts.load();
      if (saved == null) return null;
      return MailAccountInfo(email: saved.email, host: saved.host);
    } on LocalStoreException {
      return null;
    }
  }

  @override
  Future<String?> setUp({
    required String email,
    required String host,
    required String password,
  }) async {
    final target = splitHostPort(host);
    final account = MailAccount(
      email: email,
      host: target.host,
      port: target.port,
      password: password,
    );
    final outcome = await _session<Object?>(account, (client) async => null);
    switch (outcome) {
      case _Failed(:final reason):
        return reason;
      case _Done():
        break;
    }
    try {
      await _accounts.save(account);
    } on LocalStoreException catch (error) {
      return error.message;
    }
    return null;
  }

  @override
  Future<bool> forget() async {
    final had = await _accounts.exists();
    await _accounts.clear();
    return had;
  }

  @override
  Future<MailResult> latest({int count = 20}) async {
    final MailAccount? saved;
    try {
      saved = await _accounts.load();
    } on LocalStoreException catch (error) {
      return MailUnavailable(error.message);
    }
    if (saved == null) return const MailNotSetUp();

    final outcome = await _session<MailMessages>(saved, (client) async {
      final inbox = await client.selectInbox();
      final total = inbox.messagesExists;
      if (total == 0) {
        return const MailMessages([], total: 0, unread: 0);
      }
      final status = await client.statusMailbox(inbox, [StatusFlags.unseen]);
      // The newest `count` by position. (The library's own "recent" call asks
      // for one more than it is told.)
      final first = total > count ? total - count + 1 : 1;
      final fetched = await client.fetchMessages(
        MessageSequence.fromRange(first, total),
        '(UID FLAGS ENVELOPE)',
        responseTimeout: timeout,
      );
      final messages = [
        for (final message in fetched.messages) ?mailMessageFrom(message),
      ]..sort((a, b) => b.uid.compareTo(a.uid));
      return MailMessages(
        messages,
        total: total,
        unread: status.messagesUnseen,
        validity: inbox.uidValidity,
      );
    });
    return switch (outcome) {
      _Done(:final value) => value,
      _Failed(:final reason) => MailUnavailable(reason),
    };
  }

  @override
  Future<MailMoveResult> moveToTrash(int uid, {int? validity}) async {
    final MailAccount? saved;
    try {
      saved = await _accounts.load();
    } on LocalStoreException catch (error) {
      return MailMoveFailed(error.message);
    }
    if (saved == null) return const MailMoveNotSetUp();
    final host = saved.host;

    final outcome = await _session<MailMoveResult>(saved, (client) async {
      final inbox = await client.selectInbox();
      if (validity != null && inbox.uidValidity != validity) {
        return const MailMoveFailed(
          'the server renumbered the inbox; run mail again',
        );
      }
      final sequence = MessageSequence.fromId(uid, isUid: true);
      final present = await client.uidFetchMessages(sequence, '(UID)');
      if (present.messages.isEmpty) return const MailGone();

      final boxes = await client.listMailboxes(recursive: true);
      final trash = boxes.where((box) => box.isTrash).firstOrNull;
      if (trash == null) {
        // Never fall back to deleting: without a Trash there is nowhere safe.
        return MailMoveFailed('no Trash folder on $host; nothing was changed');
      }
      if (client.serverInfo.supportsMove) {
        await client.uidMove(sequence, targetMailbox: trash);
      } else if (client.serverInfo.supportsUidPlus) {
        // Copy first: if a later step fails the message is still in the inbox.
        // Only this uid is expunged, never others already marked deleted.
        await client.uidCopy(sequence, targetMailbox: trash);
        await client.uidStore(
          sequence,
          [MessageFlags.deleted],
          action: StoreAction.add,
          silent: true,
        );
        await client.uidExpunge(sequence);
      } else {
        return MailMoveFailed(
          "$host can't move a message safely; nothing was changed",
        );
      }
      return MailMoved(trash.name);
    });
    return switch (outcome) {
      _Done(:final value) => value,
      _Failed(:final reason) => MailMoveFailed(reason),
    };
  }

  /// Connects, logs in, runs [body] and always hangs up. Every way it can go
  /// wrong is a [_Failed] with a sentence for the user; none contains the
  /// password.
  Future<_Outcome<T>> _session<T>(
    MailAccount account,
    Future<T> Function(ImapClient client) body,
  ) async {
    final client = ImapClient(defaultResponseTimeout: timeout);
    var loggedIn = false;
    try {
      await client.connectToServer(
        account.host,
        account.port,
        isSecure: secure,
        timeout: timeout,
      );
      try {
        await client.login(account.email, account.password);
      } on ImapException {
        return _Failed(
          '${account.host} refused the login '
          '(check the address and the app password)',
        );
      }
      loggedIn = true;
      return _Done(await body(client));
    } on SocketException {
      return _Failed("can't reach ${account.host} (no connection?)");
    } on HandshakeException {
      return _Failed('could not make a secure connection to ${account.host}');
    } on TimeoutException {
      return _Failed('${account.host} did not answer in time');
    } on ImapException catch (error) {
      return _Failed(
        '${account.host}: ${_scrub(error.message, account.password)}',
      );
    } on Object catch (error) {
      return _Failed(
        '${account.host}: ${_scrub(error.toString(), account.password)}',
      );
    } finally {
      await _hangUp(client, loggedIn: loggedIn);
    }
  }

  Future<void> _hangUp(ImapClient client, {required bool loggedIn}) async {
    try {
      if (loggedIn && client.isConnected) {
        await client.logout().timeout(const Duration(seconds: 3));
      }
    } on Object {
      // Leaving is best effort; the socket is closed below either way.
    }
    try {
      await client.disconnect();
    } on Object {
      // Nothing left to clean up.
    }
  }
}

/// The first line of [text] with the [secret] blanked, so an error from the
/// server or the library can never put the password on the screen.
String _scrub(String? text, String secret) {
  final line = (text ?? 'something went wrong').split('\n').first.trim();
  return secret.isEmpty ? line : line.replaceAll(secret, '***');
}

sealed class _Outcome<T> {
  const _Outcome();
}

class _Done<T> extends _Outcome<T> {
  const _Done(this.value);

  final T value;
}

class _Failed<T> extends _Outcome<T> {
  const _Failed(this.reason);

  final String reason;
}

/// [text] as a host and port: `imap.example.com` is port 993, and
/// `imap.example.com:143` names its own. A colon followed by anything but a
/// number is left in the host.
({String host, int port}) splitHostPort(String text) {
  final colon = text.lastIndexOf(':');
  final port = colon < 0 ? null : int.tryParse(text.substring(colon + 1));
  if (port == null) return (host: text, port: 993);
  return (host: text.substring(0, colon), port: port);
}

/// [message] as a list entry, or null if the server gave no UID for it (then
/// it could never be told apart later). Kept apart from the network so it can
/// be tested on its own.
MailMessage? mailMessageFrom(MimeMessage message) {
  final uid = message.uid;
  if (uid == null) return null;
  final sender = message.from?.firstOrNull;
  final name = sender?.personalName?.trim() ?? '';
  final address = sender?.email.trim() ?? '';
  final subject = message.envelope?.subject ?? message.decodeSubject() ?? '';
  final sent = message.envelope?.date ?? message.decodeDate();
  return MailMessage(
    uid: uid,
    from: name.isNotEmpty ? name : (address.isNotEmpty ? address : '?'),
    subject: subject.trim(),
    date: sent?.toLocal(),
    unread: !message.isSeen,
  );
}
