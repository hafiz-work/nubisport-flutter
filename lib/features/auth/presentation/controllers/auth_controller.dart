import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// App-wide auth state: loading (restoring) -> data(user) signed in / data(null) signed out.
/// The root widget switches screens on it, so there is no route guard to forget.
class AuthController extends AsyncNotifier<AppUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AppUser?> build() async {
    // Refresh token died mid-use (interceptor cleared it): back to login.
    ref.listen(sessionExpiredProvider, (_, _) => state = const AsyncData(null));
    return _repo.restoreSession();
  }

  /// Throws [AuthFailure]; state stays signed out on failure so the form keeps its input.
  Future<void> login({required String email, required String password, String? captchaToken}) async {
    final user = await _repo.login(email: email, password: password, captchaToken: captchaToken);
    state = AsyncData(user);
  }

  /// Creates the account; the user still has to verify their email before signing in,
  /// so the auth state is left untouched. Throws [AuthFailure].
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? captchaToken,
  }) => _repo.register(name: name, email: email, password: password, captchaToken: captchaToken);

  /// Mails a reset link when the address has an account. Throws [AuthFailure].
  Future<void> forgotPassword({required String email, String? captchaToken}) =>
      _repo.forgotPassword(email: email, captchaToken: captchaToken);

  /// PATCH /me through the repository; refreshes the signed-in user on success.
  Future<AppUser> updateProfile({
    required String name,
    required String username,
    required String location,
    required String bio,
    required bool profilePublic,
  }) async {
    final user = await _repo.updateProfile(
      name: name,
      username: username,
      location: location,
      bio: bio,
      profilePublic: profilePublic,
    );
    state = AsyncData(user);
    return user;
  }

  /// The server ends every session on success, so wipe local state too.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _repo.changePassword(currentPassword: currentPassword, newPassword: newPassword);
    await _repo.logout();
    state = const AsyncData(null);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);
