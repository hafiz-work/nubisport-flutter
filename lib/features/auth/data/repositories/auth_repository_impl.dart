import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../data_sources/auth_remote_data_source.dart';
import 'mock_auth_repository.dart';
import '../data_sources/user_local_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.remote, required this.local, required this.tokens});

  final AuthRemoteDataSource remote;
  final UserLocalDataSource local;
  final TokenStorage tokens;

  @override
  Future<AppUser?> restoreSession() async {
    if (await tokens.read() == null) return null;
    try {
      final user = await remote.me();
      await local.save(user);
      return user;
    } on DioException catch (e) {
      // Offline or server down: keep the session, start from the cached copy.
      if (e.response == null) return local.read();
      // 401 after a failed refresh (the interceptor already cleared tokens): signed out.
      if (e.response?.statusCode == 401) {
        await _wipeLocal();
        return null;
      }
      return local.read();
    }
  }

  @override
  Future<AppUser> login({required String email, required String password, String? captchaToken}) async {
    final result = await remote.login(email: email, password: password, captchaToken: captchaToken);
    // Another account's data must never carry over (same rule as the web's device-data.ts).
    final cached = await local.read();
    if (cached != null && cached.id != result.user.id) {
      await local.clearAccountData();
    }
    await tokens.write(result.tokens);
    // /me has the per-app roles the login answer leaves out; fall back to the login answer.
    final user = await remote.me().catchError((_) => result.user);
    await local.save(user);
    return user;
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? captchaToken,
  }) => remote.register(name: name, email: email, password: password, captchaToken: captchaToken);

  @override
  Future<void> forgotPassword({required String email}) => remote.forgotPassword(email: email);

  @override
  Future<AppUser> updateProfile({
    required String name,
    required String username,
    required String location,
    required String bio,
    required bool profilePublic,
  }) async {
    final user = await remote.updateProfile(
      name: name,
      username: username,
      location: location,
      bio: bio,
      profilePublic: profilePublic,
    );
    await local.save(user);
    return user;
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      remote.changePassword(currentPassword: currentPassword, newPassword: newPassword);

  @override
  Future<void> logout() async {
    try {
      await remote.logout(); // ends the session row server-side
    } catch (_) {
      // Offline: the server session expires on its own (7 days); local wipe still happens.
    }
    await _wipeLocal();
  }

  Future<void> _wipeLocal() async {
    await tokens.clear();
    await local.clearAccountData();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(appConfigProvider).isMock) return MockAuthRepository();
  return AuthRepositoryImpl(
    remote: DioAuthRemoteDataSource(ref.watch(dioProvider)),
    local: DriftUserLocalDataSource(ref.watch(appDatabaseProvider)),
    tokens: ref.watch(tokenStorageProvider),
  );
});
