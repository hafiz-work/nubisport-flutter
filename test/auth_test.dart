import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/database/app_database.dart';
import 'package:nubisport_flutter/core/network/session_cookies.dart';
import 'package:nubisport_flutter/core/storage/token_storage.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/auth/data/auth_remote_data_source.dart';
import 'package:nubisport_flutter/features/auth/data/auth_repository_impl.dart';
import 'package:nubisport_flutter/features/auth/data/user_local_data_source.dart';
import 'package:nubisport_flutter/features/auth/domain/app_user.dart';
import 'package:nubisport_flutter/features/auth/domain/auth_repository.dart';
import 'package:nubisport_flutter/features/auth/presentation/login_page.dart';

class MemoryTokenStorage implements TokenStorage {
  AuthTokens? value;
  @override
  Future<AuthTokens?> read() async => value;
  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
  @override
  Future<void> clear() async => value = null;
}

class FakeRemote implements AuthRemoteDataSource {
  AppUser user = const AppUser(id: 1, name: 'Ali', email: 'ali@x', role: 'user', apps: {'nubi': 'ahli'});
  DioException? meError;
  bool logoutFails = false;
  int logoutCalls = 0;

  @override
  Future<({AuthTokens tokens, AppUser user})> login({required String email, required String password, String? captchaToken}) async {
    if (password != 'right') throw const AuthFailure(AuthFailureReason.invalidCredentials);
    return (tokens: AuthTokens(accessToken: 'a${user.id}', refreshToken: 'r${user.id}'), user: user);
  }

  @override
  Future<AppUser> me() async {
    if (meError != null) throw meError!;
    return user;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (logoutFails) throw DioException(requestOptions: RequestOptions());
  }
}

DioException offline() => DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
DioException status(int code, [Object? data]) => DioException(
      requestOptions: RequestOptions(),
      response: Response(requestOptions: RequestOptions(), statusCode: code, data: data),
    );

void main() {
  group('tokensFromSetCookie', () {
    test('reads both tokens, ignores attributes and other cookies', () {
      final headers = Headers.fromMap({
        'set-cookie': [
          'access_token=jwt.abc; Max-Age=900; Path=/; HttpOnly; Secure; SameSite=Lax',
          'refresh_token=rt_xyz; Max-Age=604800; Path=/; HttpOnly',
          'session_active=1; Max-Age=604800; Path=/',
        ],
      });
      final t = tokensFromSetCookie(headers)!;
      expect(t.accessToken, 'jwt.abc');
      expect(t.refreshToken, 'rt_xyz');
    });

    test('null when one is missing or deleted', () {
      expect(tokensFromSetCookie(Headers.fromMap({'set-cookie': ['access_token=x; Path=/']})), isNull);
      expect(
        tokensFromSetCookie(Headers.fromMap({'set-cookie': ['access_token=; Max-Age=0', 'refresh_token=; Max-Age=0']})),
        isNull,
      );
    });
  });

  group('loginFailureReason (same as the web login)', () {
    test('maps API answers', () {
      expect(loginFailureReason(status(401)), AuthFailureReason.invalidCredentials);
      expect(loginFailureReason(status(403, {'code': 'email_unverified'})), AuthFailureReason.emailUnverified);
      expect(loginFailureReason(status(403, {'code': 'account_banned'})), AuthFailureReason.banned);
      expect(loginFailureReason(status(400, {'error': 'Captcha verification failed.'})), AuthFailureReason.captcha);
      expect(loginFailureReason(status(429)), AuthFailureReason.rateLimited);
      expect(loginFailureReason(offline()), AuthFailureReason.network);
    });
  });

  group('AuthRepositoryImpl', () {
    late AppDatabase db;
    late MemoryTokenStorage tokens;
    late FakeRemote remote;
    late DriftUserLocalDataSource local;
    late AuthRepositoryImpl repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      tokens = MemoryTokenStorage();
      remote = FakeRemote();
      local = DriftUserLocalDataSource(db);
      repo = AuthRepositoryImpl(remote: remote, local: local, tokens: tokens);
    });
    tearDown(() => db.close());

    test('login stores tokens and caches the user (drift round trip)', () async {
      final user = await repo.login(email: 'ali@x', password: 'right');
      expect(user.isMember, isTrue);
      expect(tokens.value?.refreshToken, 'r1');
      final cached = await local.read();
      expect(cached?.id, 1);
      expect(cached?.apps, {'nubi': 'ahli'});
    });

    test('wrong password: nothing stored', () async {
      await expectLater(repo.login(email: 'ali@x', password: 'wrong'), throwsA(isA<AuthFailure>()));
      expect(tokens.value, isNull);
      expect(await local.read(), isNull);
    });

    test("another account signing in never sees the previous account's data", () async {
      await repo.login(email: 'ali@x', password: 'right');
      remote.user = const AppUser(id: 2, name: 'Siti', email: 'siti@x', role: 'user');
      await repo.login(email: 'siti@x', password: 'right');
      expect((await local.read())?.id, 2);
      expect(await db.select(db.cachedUsers).get(), hasLength(1));
    });

    test('logout wipes tokens and local data, even offline', () async {
      await repo.login(email: 'ali@x', password: 'right');
      remote.logoutFails = true;
      await repo.logout();
      expect(remote.logoutCalls, 1);
      expect(tokens.value, isNull);
      expect(await local.read(), isNull);
    });

    test('restore: no tokens = signed out; offline = cached user; 401 = wiped', () async {
      expect(await repo.restoreSession(), isNull);

      await repo.login(email: 'ali@x', password: 'right');
      remote.meError = offline();
      expect((await repo.restoreSession())?.id, 1);

      remote.meError = status(401);
      expect(await repo.restoreSession(), isNull);
      expect(tokens.value, isNull);
      expect(await local.read(), isNull);
    });
  });

  testWidgets('login page shows the web wording on a wrong password', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = AuthRepositoryImpl(remote: FakeRemote(), local: DriftUserLocalDataSource(db), tokens: MemoryTokenStorage());
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: AppTheme.light, home: const LoginPage()),
    ));

    await tester.enterText(find.byType(TextFormField).at(0), 'ali@x');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Log masuk'));
    await tester.pumpAndSettle();
    expect(find.text('E-mel atau kata laluan salah.'), findsOneWidget);
  });
}
