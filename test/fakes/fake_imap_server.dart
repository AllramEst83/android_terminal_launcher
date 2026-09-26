import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A message the [FakeImapServer] holds. [subject] is written as it would be on
/// the wire (so a test can use an encoded word); [name] null means the sender
/// has no display name.
class FakeImapMessage {
  const FakeImapMessage({
    required this.uid,
    required this.subject,
    required this.date,
    required this.address,
    this.name,
    this.seen = false,
  });

  final int uid;
  final String subject;
  final String date;
  final String address;
  final String? name;
  final bool seen;
}

/// A small IMAP server on a local port, just enough for `ImapMailService` to
/// log in, open the inbox, fetch envelopes and move a message to Trash. It
/// answers like a real one (untagged data, then a tagged status) so the real
/// client library is what the test exercises, and it records every command it
/// was sent.
class FakeImapServer {
  FakeImapServer({
    required this.user,
    required this.password,
    List<FakeImapMessage> messages = const [],
  }) : inbox = List.of(messages);

  final String user;
  final String password;

  /// The inbox as it is now: a move takes a message out of it.
  final List<FakeImapMessage> inbox;

  /// What has been moved to the Trash folder, in order.
  final List<FakeImapMessage> trash = [];

  /// Every command line received, tag removed, with the password blanked.
  final List<String> received = [];

  /// How many clients have connected.
  int connections = 0;

  /// Set to make the next SELECT fail with a server error.
  bool failSelect = false;

  /// What the server says it can do. Real ones differ: Gmail has `MOVE`, an
  /// older server may only have `UIDPLUS`.
  String capabilities = 'IMAP4rev1 MOVE UIDPLUS';

  /// Whether a folder flagged `\Trash` exists.
  bool hasTrash = true;

  /// The name of the Trash folder, as `LIST` reports it.
  String trashName = '[Gmail]/Trash';

  /// The inbox's `UIDVALIDITY`.
  int uidValidity = 1;

  /// Uids marked `\Deleted` by a `STORE`, until an `EXPUNGE` removes them.
  final Set<int> _deleted = {};

  late final ServerSocket _server;
  final List<Socket> _sockets = [];

  int get port => _server.port;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_serve);
  }

  Future<void> stop() async {
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _server.close();
  }

  void _serve(Socket socket) {
    connections++;
    _sockets.add(socket);
    socket.write('* OK IMAP4rev1 ready\r\n');
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _handle(socket, line));
  }

  void _handle(Socket socket, String line) {
    final space = line.indexOf(' ');
    if (space < 0) return;
    final tag = line.substring(0, space);
    final rest = line.substring(space + 1);
    final words = rest.split(' ');
    final word = words.first.toUpperCase();
    received.add(word == 'LOGIN' ? 'LOGIN' : rest);

    switch (word) {
      case 'CAPABILITY':
        socket.write('* CAPABILITY $capabilities\r\n$tag OK done\r\n');
      case 'LOGIN':
        final ok = rest.contains('"$user"') && rest.contains('"$password"');
        socket.write(
          ok
              ? '$tag OK [CAPABILITY $capabilities] logged in\r\n'
              : '$tag NO [AUTHENTICATIONFAILED] Invalid credentials\r\n',
        );
      case 'LIST':
        socket.write(
          '* LIST (\\HasNoChildren) "/" "INBOX"\r\n'
          '${hasTrash ? '* LIST (\\HasNoChildren \\Trash) "/" "$trashName"\r\n' : ''}'
          '$tag OK LIST completed\r\n',
        );
      case 'SELECT':
        if (failSelect) {
          socket.write('$tag NO [SERVERBUG] inbox is on fire\r\n');
          return;
        }
        socket.write(
          '* ${inbox.length} EXISTS\r\n'
          '* 0 RECENT\r\n'
          '* OK [UIDVALIDITY $uidValidity] ok\r\n'
          '* FLAGS (\\Seen \\Answered \\Deleted)\r\n'
          '$tag OK [READ-WRITE] SELECT completed\r\n',
        );
      case 'STATUS':
        final unseen = inbox.where((m) => !m.seen).length;
        socket.write(
          '* STATUS "INBOX" (UNSEEN $unseen)\r\n$tag OK STATUS completed\r\n',
        );
      case 'FETCH':
        final range = words[1].split(':');
        final from = int.parse(range.first);
        final to = range.last == '*' ? inbox.length : int.parse(range.last);
        final out = StringBuffer();
        for (var seq = from; seq <= to && seq <= inbox.length; seq++) {
          out.write(_fetchLine(seq, inbox[seq - 1]));
        }
        socket.write('$out$tag OK FETCH completed\r\n');
      case 'UID':
        _handleUid(socket, tag, words);
      case 'LOGOUT':
        socket.write('* BYE bye\r\n$tag OK LOGOUT completed\r\n');
        unawaited(socket.close());
      default:
        socket.write('$tag BAD unknown command\r\n');
    }
  }

  /// `UID FETCH|MOVE|COPY|STORE|EXPUNGE <uid> ...`.
  void _handleUid(Socket socket, String tag, List<String> words) {
    final uid = int.tryParse(words[2]);
    final index = inbox.indexWhere((m) => m.uid == uid);
    switch (words[1].toUpperCase()) {
      case 'FETCH':
        socket.write(
          index < 0
              ? '$tag OK UID FETCH completed\r\n'
              : '* ${index + 1} FETCH (UID $uid)\r\n'
                    '$tag OK UID FETCH completed\r\n',
        );
      case 'MOVE':
        if (index < 0) {
          socket.write('$tag OK UID MOVE completed\r\n');
          return;
        }
        trash.add(inbox.removeAt(index));
        socket.write(
          '* OK [COPYUID $uidValidity $uid ${trash.length}] moved\r\n'
          '* ${index + 1} EXPUNGE\r\n'
          '$tag OK UID MOVE completed\r\n',
        );
      case 'COPY':
        if (index >= 0) trash.add(inbox[index]);
        socket.write('$tag OK UID COPY completed\r\n');
      case 'STORE':
        if (uid != null && index >= 0) _deleted.add(uid);
        socket.write('$tag OK UID STORE completed\r\n');
      case 'EXPUNGE':
        // Only what was asked for, as a real UIDPLUS server does.
        if (index >= 0 && _deleted.remove(uid)) {
          inbox.removeAt(index);
          socket.write('* ${index + 1} EXPUNGE\r\n');
        }
        socket.write('$tag OK UID EXPUNGE completed\r\n');
      default:
        socket.write('$tag BAD unknown command\r\n');
    }
  }

  String _fetchLine(int seq, FakeImapMessage m) {
    final at = m.address.split('@');
    final person =
        '(${m.name == null ? 'NIL' : '"${m.name}"'} NIL "${at[0]}" "${at[1]}")';
    return '* $seq FETCH (UID ${m.uid} '
        'FLAGS (${m.seen ? r'\Seen' : ''}) '
        'ENVELOPE ("${m.date}" ${m.subject} ($person) ($person) ($person) '
        'NIL NIL NIL NIL "<${m.uid}@example.com>"))\r\n';
  }
}
