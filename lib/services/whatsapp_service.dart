sealed class WhatsAppResult {
  const WhatsAppResult();
}

/// WhatsApp (or a browser, if it is not installed) opened with the chat
/// ready, text prefilled or empty; the user still has to type or tap send
/// there.
class WhatsAppOpened extends WhatsAppResult {
  const WhatsAppOpened();
}

/// Nothing opened; [reason] is short and printable.
class WhatsAppFailed extends WhatsAppResult {
  const WhatsAppFailed(this.reason);

  final String reason;
}

/// Hands a chat off to WhatsApp via its public `wa.me` link. There is no API
/// to send silently, and none is wanted: the message is only ever opened,
/// never sent, so no permission is needed.
abstract class WhatsAppService {
  /// [number] is dialable as it stands (digits and a leading `+`). [text] may
  /// be empty, which opens the chat with nothing prefilled. Never throws;
  /// every failure is a [WhatsAppFailed].
  Future<WhatsAppResult> openChat(String number, String text);
}
