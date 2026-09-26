/// IMAP servers of the common providers, by the domain after the `@`. Only
/// ones that still accept an app password: Outlook.com and Hotmail are left
/// out on purpose, since Microsoft no longer allows that for personal
/// accounts.
const _servers = {
  'gmail.com': 'imap.gmail.com',
  'googlemail.com': 'imap.gmail.com',
  'icloud.com': 'imap.mail.me.com',
  'me.com': 'imap.mail.me.com',
  'mac.com': 'imap.mail.me.com',
  'yahoo.com': 'imap.mail.yahoo.com',
  'ymail.com': 'imap.mail.yahoo.com',
  'aol.com': 'imap.aol.com',
  'fastmail.com': 'imap.fastmail.com',
  'zoho.com': 'imap.zoho.com',
  'gmx.com': 'imap.gmx.com',
  'gmx.net': 'imap.gmx.net',
};

/// Whether [text] has the shape of an address: something, an `@`, a domain
/// with a dot in it, and no spaces. It does not try to be the whole of RFC 5322.
bool looksLikeEmail(String text) =>
    RegExp(r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$').hasMatch(text);

/// The domain of [email], lower-cased. Call only for one that
/// [looksLikeEmail].
String emailDomain(String email) =>
    email.substring(email.lastIndexOf('@') + 1).toLowerCase();

/// The IMAP server for [email]'s domain, or null if it is not a known one.
String? imapServerFor(String email) => _servers[emailDomain(email)];
