sealed class SmsResult {
  const SmsResult();
}

/// The network accepted every part of the message.
class SmsSent extends SmsResult {
  const SmsSent();
}

/// The user said no. [permanent] means Android will no longer ask, so the
/// caller should say where the setting is instead of asking again.
class SmsDenied extends SmsResult {
  const SmsDenied({required this.permanent});

  final bool permanent;
}

/// Nothing was sent, or it is not known whether anything was; [reason] is
/// short and printable.
class SmsFailed extends SmsResult {
  const SmsFailed(this.reason);

  final String reason;
}

/// Ordinary text messages (SMS). Asks for `SEND_SMS` itself the first time.
/// Unlike a call there is no dialer to fall back on, so a refusal is final.
abstract class SmsService {
  /// [number] is dialable as it stands (digits and a leading `+`). Long texts
  /// are split into parts by the platform. Never throws; every failure is an
  /// [SmsDenied] or [SmsFailed].
  Future<SmsResult> send(String number, String text);
}
