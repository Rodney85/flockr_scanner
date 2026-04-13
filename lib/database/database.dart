import 'package:drift/drift.dart' hide Column;
import 'connection/shared.dart' as impl;

part 'database.g.dart';

class Scans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get epc => text()();
  DateTimeColumn get scannedAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get animalName => text().nullable()();
  BoolColumn get found => boolean().nullable()();
}

@DriftDatabase(tables: [Scans])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(impl.openConnection());

  @override
  int get schemaVersion => 1;

  Stream<List<Scan>> watchAllScans() {
    return (select(scans)
          ..orderBy([
            (t) => OrderingTerm(expression: t.scannedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Future<List<Scan>> getPendingScans() {
    return (select(scans)..where((t) => t.status.equals('pending'))).get();
  }

  Future<void> updateScan(int id, String newStatus, {bool? found, String? animalName}) {
    return (update(scans)..where((t) => t.id.equals(id))).write(
      ScansCompanion(
        status: Value(newStatus),
        found: found != null ? Value(found) : const Value.absent(),
        animalName: animalName != null ? Value(animalName) : const Value.absent(),
      ),
    );
  }

  Future<void> clearScans() => delete(scans).go();
}
