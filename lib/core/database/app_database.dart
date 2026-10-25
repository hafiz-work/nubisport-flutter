import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// Local store (drift = SQLite, typed queries, real migrations). Only data sources touch it;
/// features see repositories. Everything here belongs to the signed-in account and is wiped on
/// logout or when another account signs in (same rule as the web's lib/device-data.ts).

/// Last /me of the signed-in account - first paint and offline start. One row at most.
class CachedUsers extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get email => text()();
  TextColumn get role => text()();
  /// `{ "nubi": "ahli" }` as JSON - per-app roles from the API.
  TextColumn get appsJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedUsers])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'nubisport'));

  @override
  int get schemaVersion => 1;

  /// Drop every account-owned row (logout, account switch).
  Future<void> clearAccountData() => transaction(() async {
        for (final table in allTables) {
          await delete(table).go();
        }
      });
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
