import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../domain/app_user.dart';

/// Cached copy of the signed-in user (offline start, first paint).
abstract interface class UserLocalDataSource {
  Future<AppUser?> read();
  Future<void> save(AppUser user);

  /// Wipes every account-owned row, not only the user.
  Future<void> clearAccountData();
}

class DriftUserLocalDataSource implements UserLocalDataSource {
  DriftUserLocalDataSource(this._db);
  final AppDatabase _db;

  @override
  Future<AppUser?> read() async {
    final row = await _db.select(_db.cachedUsers).getSingleOrNull();
    if (row == null) return null;
    final apps = (jsonDecode(row.appsJson) as Map<String, dynamic>).map((k, v) => MapEntry(k, '$v'));
    return AppUser(id: row.id, name: row.name, email: row.email, role: row.role, apps: apps);
  }

  @override
  Future<void> save(AppUser user) => _db.transaction(() async {
    // One row: a different account replaces it (and its data goes - see clearAccountData).
    await _db.delete(_db.cachedUsers).go();
    await _db
        .into(_db.cachedUsers)
        .insert(
          CachedUsersCompanion.insert(
            id: Value(user.id),
            name: user.name,
            email: user.email,
            role: user.role,
            appsJson: Value(jsonEncode(user.apps)),
            updatedAt: DateTime.now(),
          ),
        );
  });

  @override
  Future<void> clearAccountData() => _db.clearAccountData();
}
