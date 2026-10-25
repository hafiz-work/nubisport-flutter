import 'app_user.dart';

/// Auth contract the UI depends on. The implementation (data/auth_repository_impl.dart) can
/// change transport or storage without touching a screen.
abstract interface class AuthRepository {
  /// Signed-in user from stored tokens: fresh /me when online, the cached copy when offline,
  /// null when there is no session (or it expired).
  Future<AppUser?> restoreSession();

  /// Throws [AuthFailure] on any failure.
  Future<AppUser> login({
    required String email,
    required String password,
    String? captchaToken,
  });

  /// Ends the session on the server (best effort) and wipes everything local.
  Future<void> logout();
}

/// Why login failed - the UI turns this into a message.
enum AuthFailureReason {
  invalidCredentials,
  emailUnverified,
  banned,
  captcha,
  rateLimited,
  network,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.reason);
  final AuthFailureReason reason;

  @override
  String toString() => 'AuthFailure($reason)';
}
