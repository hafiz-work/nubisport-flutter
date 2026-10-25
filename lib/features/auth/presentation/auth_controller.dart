import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_repository_impl.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

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
  Future<void> login({required String email, required String password}) async {
    // shortcut: no captcha token - production login needs one (API enforces Turnstile);
    // plug a mobile captcha/attestation provider in here once the backend path is decided.
    final user = await _repo.login(email: email, password: password);
    state = AsyncData(user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);
