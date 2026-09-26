sealed class CallResult {
  const CallResult();
}

/// The call is being placed (`CALL_PHONE` was granted).
class CallPlaced extends CallResult {
  const CallPlaced();
}

/// The dialer is open with the number filled in and the user must press call.
/// This is what happens without `CALL_PHONE`, and for numbers Android won't
/// let an app dial directly (emergency numbers), so it is not an error.
class DialerOpened extends CallResult {
  const DialerOpened();
}

/// Not even the dialer could be opened; [reason] is short and printable.
class CallFailed extends CallResult {
  const CallFailed(this.reason);

  final String reason;
}

/// Phone calls. Asks for `CALL_PHONE` itself the first time and falls back to
/// the dialer when it is refused, so calling never dead-ends on permission.
abstract class PhoneService {
  /// [number] is dialable as it stands (digits and a leading `+`). Never
  /// throws; every failure is a [CallFailed].
  Future<CallResult> call(String number);
}
