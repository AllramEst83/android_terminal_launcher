import 'package:android_terminal_launcher/services/mail_service.dart';
import 'package:android_terminal_launcher/terminal/tools/mail_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/mail_hosts.dart';
import 'package:android_terminal_launcher/terminal/tools/mail_text.dart';
import 'package:flutter_test/flutter_test.dart';

// Saturday 26 September 2026, mid-afternoon.
final _now = DateTime(2026, 9, 26, 15, 30);

void main() {
  group('mailWhen', () {
    test('today is the time, with a leading zero', () {
      expect(mailWhen(DateTime(2026, 9, 26, 9, 5), _now), '09:05');
      expect(mailWhen(DateTime(2026, 9, 26, 0, 0), _now), '00:00');
    });

    test('the last six days are the weekday', () {
      expect(mailWhen(DateTime(2026, 9, 25, 23, 59), _now), 'Fri');
      expect(mailWhen(DateTime(2026, 9, 20, 8), _now), 'Sun');
    });

    test('a week ago is the date, since the weekday would be today', () {
      expect(mailWhen(DateTime(2026, 9, 19, 8), _now), '19 Sep');
    });

    test('earlier this year is day and month', () {
      expect(mailWhen(DateTime(2026, 1, 3, 12), _now), '3 Jan');
    });

    test('an earlier year adds the year and drops the day', () {
      expect(mailWhen(DateTime(2025, 12, 31, 12), _now), 'Dec 2025');
    });

    test('no date is empty', () {
      expect(mailWhen(null, _now), isEmpty);
    });

    test('a date in the future (a wrong clock) is still shown', () {
      expect(mailWhen(DateTime(2026, 9, 28, 12), _now), '28 Sep');
    });
  });

  test('clip cuts with an ellipsis and leaves short text alone', () {
    expect(clip('short', 10), 'short');
    expect(clip('exactly10!', 10), 'exactly10!');
    expect(clip('this is far too long', 10), 'this is f…');
    expect(clip('this is far too long', 10), hasLength(10));
  });

  test('groupDigits writes thousands', () {
    expect(groupDigits(7), '7');
    expect(groupDigits(1234), '1,234');
    expect(groupDigits(1234567), '1,234,567');
    expect(groupDigits(100000), '100,000');
  });

  group('the summary', () {
    MailMessages found(int shown, int total, int unread) => MailMessages(
      [
        for (var i = 0; i < shown; i++)
          MailMessage(uid: i, from: 'a', subject: 's'),
      ],
      total: total,
      unread: unread,
    );

    test('says how many of how many when there are more', () {
      expect(mailSummary(found(20, 1234, 7)), 'latest 20 of 1,234, 7 unread');
    });

    test('says just the count when it shows them all', () {
      expect(mailSummary(found(3, 3, 0)), '3 messages');
      expect(mailSummary(found(1, 1, 1)), '1 message, 1 unread');
    });
  });

  group('the plain lines', () {
    test('fit a phone: no line is wider than 36 characters', () {
      final found = MailMessages(
        [
          MailMessage(
            uid: 1,
            from: 'A Sender With A Really Long Display Name Indeed',
            subject: 'A subject that goes on and on and on and on and on',
            date: DateTime(2020, 5, 5),
            unread: true,
          ),
          MailMessage(uid: 2, from: 'b@example.com', subject: ''),
        ],
        total: 2,
        unread: 1,
      );

      final lines = mailLines(found, _now);

      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(36), reason: line);
      }
      expect(lines[1], contains('May 2020'));
      expect(lines[2], endsWith('…'));
      expect(lines.last, contains('(no subject)'));
    });

    test('number the messages past nine without shifting the columns', () {
      final found = MailMessages(
        [
          for (var i = 1; i <= 12; i++)
            MailMessage(uid: i, from: 'Anna', subject: 's', date: _now),
        ],
        total: 12,
        unread: 0,
      );

      final lines = mailLines(found, _now).where((l) => l.contains('Anna'));

      expect(lines.map((l) => l.indexOf('15:30')).toSet(), hasLength(1));
    });
  });

  test('the card row has the same text as the plain lines', () {
    final message = MailMessage(
      uid: 9,
      from: 'Anna',
      subject: '',
      date: DateTime(2026, 9, 25, 10),
      unread: true,
    );

    final block = mailBlock(MailMessages([message], total: 1, unread: 1), _now);

    expect(block.rows.single.subject, '(no subject)');
    expect(block.rows.single.when, 'Fri');
    expect(block.rows.single.uid, 9);
    expect(
      block.rows.single.removeCommand,
      'mail rm #9',
      reason: 'by the server id, which never shifts',
    );
  });

  group('servers', () {
    test('are known for the common providers', () {
      expect(imapServerFor('a@gmail.com'), 'imap.gmail.com');
      expect(imapServerFor('a@icloud.com'), 'imap.mail.me.com');
      expect(imapServerFor('A@Gmail.COM'), 'imap.gmail.com');
    });

    test('are not guessed for others', () {
      expect(imapServerFor('a@example.org'), isNull);
      expect(imapServerFor('a@outlook.com'), isNull);
    });

    test('an address has the shape of one, or is refused', () {
      expect(looksLikeEmail('a@b.co'), isTrue);
      expect(looksLikeEmail('first.last+tag@sub.example.org'), isTrue);
      for (final bad in ['a', 'a@b', 'a@@b.co', '@b.co', 'a@.co', 'a b@c.de']) {
        expect(looksLikeEmail(bad), isFalse, reason: bad);
      }
    });
  });
}
