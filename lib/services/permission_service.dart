/// What a feature may need Android's permission for. One entry per capability
/// (not per manifest string), so a feature never names an Android permission;
/// `PermissionsChannelHandler.kt` maps each to the real one(s).
enum AppPermission { location, calendar, contacts, phone, sms }

enum PermissionStatus {
  granted,

  /// Refused this time; asking again may show the dialog again.
  denied,

  /// Refused with "don't ask again" (or twice, on Android 11+): the dialog no
  /// longer appears, so the only way back is the app's settings page. Features
  /// use this to tell the user how to grant it instead of asking in vain.
  permanentlyDenied,
}

/// Runtime permissions. Features ask through this rather than talking to the
/// platform, and print [PermissionStatus.permanentlyDenied] as instructions.
abstract class PermissionService {
  /// Returns at once when already granted; otherwise shows Android's dialog and
  /// waits for the answer. Never throws: anything that stops the dialog from
  /// appearing is a [PermissionStatus.denied].
  Future<PermissionStatus> request(AppPermission permission);
}
