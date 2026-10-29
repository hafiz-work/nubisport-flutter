import '../models/app_user.dart';

/// Auth contract the UI depends on. The implementation (data/auth_repository_impl.dart) can
/// change transport or storage without touching a screen.
abstract interface class AuthRepository {
  /// Signed-in user from stored tokens: fresh /me when online, the cached copy when offline,
  /// null when there is no session (or it expired).
  Future<AppUser?> restoreSession();

  /// Throws [AuthFailure] on any failure.
  Future<AppUser> login({required String email, required String password, String? captchaToken});

  /// Creates an account. The server never says whether the email was taken; it sends a
  /// verification link and the user signs in after verifying. Throws [AuthFailure].
  Future<void> register({required String name, required String email, required String password, String? captchaToken});

  /// Sends a reset link when the email has an account. The server never reveals whether
  /// it exists. Throws [AuthFailure] on transport/validation failures.
  Future<void> forgotPassword({required String email, String? captchaToken});

  /// Updates the signed-in account (PATCH /me) and returns the fresh user.
  Future<AppUser> updateProfile({
    required String name,
    required String username,
    required String location,
    required String bio,
    required bool profilePublic,
  });

  /// Changes the password (PUT /me/password). The server ends every session, so the
  /// caller must sign out locally afterwards. Throws [AuthFailure].
  Future<void> changePassword({required String currentPassword, required String newPassword});

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
  invalidName,
  invalidEmail,
  weakPassword,
  emailTaken,
  usernameTaken,
  usernameRequired,
  invalidUsername,
  wrongPassword,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.reason);
  final AuthFailureReason reason;

  @override
  String toString() => 'AuthFailure($reason)';
}
