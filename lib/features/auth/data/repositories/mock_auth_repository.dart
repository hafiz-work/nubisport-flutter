import '../../../../core/mock/mock_accounts.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// In-memory stand-in for the real API, used when `IS_MOCK=true` (see .env.dev).
///
/// Accounts come from [MockAccounts], so activity data can reference the same
/// ids/names. All use password `Password123!`.
/// - `ahli@nubi.test`       -> member (role user, apps.nubi = ahli)
/// - `admin@nubi.test`      -> admin
/// - `banned@nubi.test`     -> rejected: banned
/// - `unverified@nubi.test` -> rejected: email not verified
///
/// Accounts created with register() can log in afterwards; everything resets
/// when the app process restarts. Nothing here talks to the network.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 500)});

  /// Stand-in for network time; tests pass [Duration.zero].
  final Duration latency;

  final Map<String, AppUser> _accounts = {
    for (final account in MockAccounts.all)
      account.email: AppUser(
        id: account.id,
        name: account.name,
        email: account.email,
        role: account.role,
        apps: account.appRoles,
        username: account.email.split('@').first,
      ),
  };
  final Map<String, String> _passwords = {for (final account in MockAccounts.all) account.email: account.password};
  int _nextId = MockAccounts.all.length + 1;
  AppUser? _session;

  @override
  Future<AppUser?> restoreSession() async {
    await _wait();
    return _session;
  }

  @override
  Future<AppUser> login({required String email, required String password, String? captchaToken}) async {
    await _wait();
    final key = email.trim().toLowerCase();
    if (key == 'banned@nubi.test') {
      throw const AuthFailure(AuthFailureReason.banned);
    }
    if (key == 'unverified@nubi.test') {
      throw const AuthFailure(AuthFailureReason.emailUnverified);
    }
    final user = _accounts[key];
    if (user == null || _passwords[key] != password) {
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    return _session = user;
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    await _wait();
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw const AuthFailure(AuthFailureReason.emailTaken);
    }
    _accounts[key] = AppUser(id: _nextId++, name: name.trim(), email: key, role: 'user', apps: const {'nubi': 'ahli'});
    _passwords[key] = password;
  }

  @override
  Future<void> forgotPassword({required String email, String? captchaToken}) => _wait();

  @override
  Future<AppUser> updateProfile({
    required String name,
    required String username,
    required String location,
    required String bio,
    required bool profilePublic,
  }) async {
    await _wait();
    final current = _session;
    if (current == null) throw const AuthFailure(AuthFailureReason.unknown);
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 100) {
      throw const AuthFailure(AuthFailureReason.invalidName);
    }
    final handle = username.trim().toLowerCase();
    if (profilePublic && handle.isEmpty) {
      throw const AuthFailure(AuthFailureReason.usernameRequired);
    }
    if (handle.isNotEmpty && !RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(handle)) {
      throw const AuthFailure(AuthFailureReason.invalidUsername);
    }
    final taken = _accounts.values.any((user) => user.id != current.id && user.username == handle);
    if (handle.isNotEmpty && taken) throw const AuthFailure(AuthFailureReason.usernameTaken);

    final updated = current.copyWith(
      name: cleanName,
      username: handle,
      bio: bio.trim(),
      location: location.trim(),
      profilePublic: profilePublic,
    );
    _accounts[current.email] = updated;
    _session = updated;
    return updated;
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _wait();
    final current = _session;
    if (current == null) throw const AuthFailure(AuthFailureReason.unknown);
    if (_passwords[current.email] != currentPassword) {
      throw const AuthFailure(AuthFailureReason.wrongPassword);
    }
    if (newPassword.length < 12 || newPassword.length > 200) {
      throw const AuthFailure(AuthFailureReason.weakPassword);
    }
    _passwords[current.email] = newPassword;
  }

  @override
  Future<void> logout() async {
    await _wait();
    _session = null;
  }

  Future<void> _wait() => Future<void>.delayed(latency);
}
