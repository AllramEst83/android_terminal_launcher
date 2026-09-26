import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:flutter/services.dart';

/// [PermissionService] backed by the Kotlin `PermissionsChannelHandler`. The
/// only file that knows about the channel.
class AndroidPermissionService implements PermissionService {
  const AndroidPermissionService([
    this._channel = const MethodChannel(channelName),
  ]);

  static const channelName =
      'com.codedbykay.android_terminal_launcher/permissions';

  final MethodChannel _channel;

  @override
  Future<PermissionStatus> request(AppPermission permission) async {
    try {
      final answer = await _channel.invokeMethod<String>('request', {
        'permission': permission.name,
      });
      return switch (answer) {
        'granted' => PermissionStatus.granted,
        'permanentlyDenied' => PermissionStatus.permanentlyDenied,
        _ => PermissionStatus.denied,
      };
    } on PlatformException {
      return PermissionStatus.denied;
    } on MissingPluginException {
      return PermissionStatus.denied;
    }
  }
}
