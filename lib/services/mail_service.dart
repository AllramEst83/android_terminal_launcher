/// One message in the inbox, as far as a list needs it: no body.
class MailMessage {
  const MailMessage({
    required this.uid,
    required this.from,
    required this.subject,
    this.date,
    this.unread = false,
  });

  /// The server's id for it, which never changes and is never reused, unlike
  /// its position in the inbox. What a later `mail rm` must go by.
  final int uid;

  /// Who sent it: the display name if there is one, else the address. Never
  /// empty.
  final String from;

  /// May be empty; the list shows `(no subject)` then.
  final String subject;

  /// When it was sent, in local time; null if the header was missing or
  /// unreadable.
  final DateTime? date;
  final bool unread;
}

sealed class MailResult {
  const MailResult();
}

/// The newest [messages] first, at most as many as were asked for. [total] is
/// how many the whole inbox holds and [unread] how many of those are unseen.
class MailMessages extends MailResult {
  const MailMessages(
    this.messages, {
    required this.total,
    required this.unread,
    this.validity,
  });

  final List<MailMessage> messages;
  final int total;
  final int unread;

  /// The server's `UIDVALIDITY` for the inbox: the ids in [messages] mean these
  /// messages only while it stays the same. Hand it back to `moveToTrash`.
  final int? validity;
}

/// No account has been set up yet (`mail setup`).
class MailNotSetUp extends MailResult {
  const MailNotSetUp();
}

/// The server could not be reached or refused us; [reason] is short and
/// printable and never contains the password.
class MailUnavailable extends MailResult {
  const MailUnavailable(this.reason);

  final String reason;
}

/// Who the launcher reads mail as. Never the password.
class MailAccountInfo {
  const MailAccountInfo({required this.email, required this.host});

  final String email;
  final String host;
}

sealed class MailMoveResult {
  const MailMoveResult();
}

/// The message is now in [folder] (the server's own name for its Trash).
class MailMoved extends MailMoveResult {
  const MailMoved(this.folder);

  final String folder;
}

/// There is no such message in the inbox any more: moved or deleted elsewhere.
class MailGone extends MailMoveResult {
  const MailGone();
}

class MailMoveNotSetUp extends MailMoveResult {
  const MailMoveNotSetUp();
}

/// Nothing was changed; [reason] is short and printable.
class MailMoveFailed extends MailMoveResult {
  const MailMoveFailed(this.reason);

  final String reason;
}

/// The user's inbox, read over IMAP with an app password kept on the device.
abstract class MailService {
  /// The account that is set up, or null.
  Future<MailAccountInfo?> account();

  /// Logs in with [password] and, only if that works, remembers all three so
  /// later calls need no typing. Returns null on success, else why it failed
  /// (nothing is saved then). Never throws.
  Future<String?> setUp({
    required String email,
    required String host,
    required String password,
  });

  /// Forgets the account and its password, and says whether there was
  /// anything to forget (a damaged saved account counts).
  Future<bool> forget();

  /// The [count] newest messages in the inbox. Never throws.
  Future<MailResult> latest({int count = 20});

  /// Moves the inbox message with [uid] to the server's Trash folder: never
  /// deletes it outright, so it can be got back. If [validity] is given and
  /// the server's differs, the ids have been renumbered since the list was
  /// read, so nothing is touched. Never throws, and changes nothing unless it
  /// returns [MailMoved].
  Future<MailMoveResult> moveToTrash(int uid, {int? validity});
}
