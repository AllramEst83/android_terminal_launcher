import 'package:android_terminal_launcher/services/permission_service.dart';

/// Answers every request with [answer] and records what was asked for.
class FakePermissionService implements PermissionService {
  FakePermissionService([this.answer = PermissionStatus.granted]);

  PermissionStatus answer;
  final List<AppPermission> requested = [];

  @override
  Future<PermissionStatus> request(AppPermission permission) async {
    requested.add(permission);
    return answer;
  }
}
