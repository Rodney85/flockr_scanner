// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ScansTable extends Scans with TableInfo<$ScansTable, Scan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _epcMeta = const VerificationMeta('epc');
  @override
  late final GeneratedColumn<String> epc = GeneratedColumn<String>(
    'epc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scannedAtMeta = const VerificationMeta(
    'scannedAt',
  );
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
    'scanned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _animalNameMeta = const VerificationMeta(
    'animalName',
  );
  @override
  late final GeneratedColumn<String> animalName = GeneratedColumn<String>(
    'animal_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _foundMeta = const VerificationMeta('found');
  @override
  late final GeneratedColumn<bool> found = GeneratedColumn<bool>(
    'found',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("found" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    epc,
    scannedAt,
    status,
    animalName,
    found,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scans';
  @override
  VerificationContext validateIntegrity(
    Insertable<Scan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('epc')) {
      context.handle(
        _epcMeta,
        epc.isAcceptableOrUnknown(data['epc']!, _epcMeta),
      );
    } else if (isInserting) {
      context.missing(_epcMeta);
    }
    if (data.containsKey('scanned_at')) {
      context.handle(
        _scannedAtMeta,
        scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_scannedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('animal_name')) {
      context.handle(
        _animalNameMeta,
        animalName.isAcceptableOrUnknown(data['animal_name']!, _animalNameMeta),
      );
    }
    if (data.containsKey('found')) {
      context.handle(
        _foundMeta,
        found.isAcceptableOrUnknown(data['found']!, _foundMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Scan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Scan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      epc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epc'],
      )!,
      scannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scanned_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      animalName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}animal_name'],
      ),
      found: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}found'],
      ),
    );
  }

  @override
  $ScansTable createAlias(String alias) {
    return $ScansTable(attachedDatabase, alias);
  }
}

class Scan extends DataClass implements Insertable<Scan> {
  final int id;
  final String epc;
  final DateTime scannedAt;
  final String status;
  final String? animalName;
  final bool? found;
  const Scan({
    required this.id,
    required this.epc,
    required this.scannedAt,
    required this.status,
    this.animalName,
    this.found,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['epc'] = Variable<String>(epc);
    map['scanned_at'] = Variable<DateTime>(scannedAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || animalName != null) {
      map['animal_name'] = Variable<String>(animalName);
    }
    if (!nullToAbsent || found != null) {
      map['found'] = Variable<bool>(found);
    }
    return map;
  }

  ScansCompanion toCompanion(bool nullToAbsent) {
    return ScansCompanion(
      id: Value(id),
      epc: Value(epc),
      scannedAt: Value(scannedAt),
      status: Value(status),
      animalName: animalName == null && nullToAbsent
          ? const Value.absent()
          : Value(animalName),
      found: found == null && nullToAbsent
          ? const Value.absent()
          : Value(found),
    );
  }

  factory Scan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Scan(
      id: serializer.fromJson<int>(json['id']),
      epc: serializer.fromJson<String>(json['epc']),
      scannedAt: serializer.fromJson<DateTime>(json['scannedAt']),
      status: serializer.fromJson<String>(json['status']),
      animalName: serializer.fromJson<String?>(json['animalName']),
      found: serializer.fromJson<bool?>(json['found']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'epc': serializer.toJson<String>(epc),
      'scannedAt': serializer.toJson<DateTime>(scannedAt),
      'status': serializer.toJson<String>(status),
      'animalName': serializer.toJson<String?>(animalName),
      'found': serializer.toJson<bool?>(found),
    };
  }

  Scan copyWith({
    int? id,
    String? epc,
    DateTime? scannedAt,
    String? status,
    Value<String?> animalName = const Value.absent(),
    Value<bool?> found = const Value.absent(),
  }) => Scan(
    id: id ?? this.id,
    epc: epc ?? this.epc,
    scannedAt: scannedAt ?? this.scannedAt,
    status: status ?? this.status,
    animalName: animalName.present ? animalName.value : this.animalName,
    found: found.present ? found.value : this.found,
  );
  Scan copyWithCompanion(ScansCompanion data) {
    return Scan(
      id: data.id.present ? data.id.value : this.id,
      epc: data.epc.present ? data.epc.value : this.epc,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
      status: data.status.present ? data.status.value : this.status,
      animalName: data.animalName.present
          ? data.animalName.value
          : this.animalName,
      found: data.found.present ? data.found.value : this.found,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Scan(')
          ..write('id: $id, ')
          ..write('epc: $epc, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('status: $status, ')
          ..write('animalName: $animalName, ')
          ..write('found: $found')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, epc, scannedAt, status, animalName, found);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Scan &&
          other.id == this.id &&
          other.epc == this.epc &&
          other.scannedAt == this.scannedAt &&
          other.status == this.status &&
          other.animalName == this.animalName &&
          other.found == this.found);
}

class ScansCompanion extends UpdateCompanion<Scan> {
  final Value<int> id;
  final Value<String> epc;
  final Value<DateTime> scannedAt;
  final Value<String> status;
  final Value<String?> animalName;
  final Value<bool?> found;
  const ScansCompanion({
    this.id = const Value.absent(),
    this.epc = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.animalName = const Value.absent(),
    this.found = const Value.absent(),
  });
  ScansCompanion.insert({
    this.id = const Value.absent(),
    required String epc,
    required DateTime scannedAt,
    this.status = const Value.absent(),
    this.animalName = const Value.absent(),
    this.found = const Value.absent(),
  }) : epc = Value(epc),
       scannedAt = Value(scannedAt);
  static Insertable<Scan> custom({
    Expression<int>? id,
    Expression<String>? epc,
    Expression<DateTime>? scannedAt,
    Expression<String>? status,
    Expression<String>? animalName,
    Expression<bool>? found,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (epc != null) 'epc': epc,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (status != null) 'status': status,
      if (animalName != null) 'animal_name': animalName,
      if (found != null) 'found': found,
    });
  }

  ScansCompanion copyWith({
    Value<int>? id,
    Value<String>? epc,
    Value<DateTime>? scannedAt,
    Value<String>? status,
    Value<String?>? animalName,
    Value<bool?>? found,
  }) {
    return ScansCompanion(
      id: id ?? this.id,
      epc: epc ?? this.epc,
      scannedAt: scannedAt ?? this.scannedAt,
      status: status ?? this.status,
      animalName: animalName ?? this.animalName,
      found: found ?? this.found,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (epc.present) {
      map['epc'] = Variable<String>(epc.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (animalName.present) {
      map['animal_name'] = Variable<String>(animalName.value);
    }
    if (found.present) {
      map['found'] = Variable<bool>(found.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScansCompanion(')
          ..write('id: $id, ')
          ..write('epc: $epc, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('status: $status, ')
          ..write('animalName: $animalName, ')
          ..write('found: $found')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ScansTable scans = $ScansTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [scans];
}

typedef $$ScansTableCreateCompanionBuilder =
    ScansCompanion Function({
      Value<int> id,
      required String epc,
      required DateTime scannedAt,
      Value<String> status,
      Value<String?> animalName,
      Value<bool?> found,
    });
typedef $$ScansTableUpdateCompanionBuilder =
    ScansCompanion Function({
      Value<int> id,
      Value<String> epc,
      Value<DateTime> scannedAt,
      Value<String> status,
      Value<String?> animalName,
      Value<bool?> found,
    });

class $$ScansTableFilterComposer extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epc => $composableBuilder(
    column: $table.epc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get animalName => $composableBuilder(
    column: $table.animalName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get found => $composableBuilder(
    column: $table.found,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScansTableOrderingComposer
    extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epc => $composableBuilder(
    column: $table.epc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get animalName => $composableBuilder(
    column: $table.animalName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get found => $composableBuilder(
    column: $table.found,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScansTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get epc =>
      $composableBuilder(column: $table.epc, builder: (column) => column);

  GeneratedColumn<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get animalName => $composableBuilder(
    column: $table.animalName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get found =>
      $composableBuilder(column: $table.found, builder: (column) => column);
}

class $$ScansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScansTable,
          Scan,
          $$ScansTableFilterComposer,
          $$ScansTableOrderingComposer,
          $$ScansTableAnnotationComposer,
          $$ScansTableCreateCompanionBuilder,
          $$ScansTableUpdateCompanionBuilder,
          (Scan, BaseReferences<_$AppDatabase, $ScansTable, Scan>),
          Scan,
          PrefetchHooks Function()
        > {
  $$ScansTableTableManager(_$AppDatabase db, $ScansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> epc = const Value.absent(),
                Value<DateTime> scannedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> animalName = const Value.absent(),
                Value<bool?> found = const Value.absent(),
              }) => ScansCompanion(
                id: id,
                epc: epc,
                scannedAt: scannedAt,
                status: status,
                animalName: animalName,
                found: found,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String epc,
                required DateTime scannedAt,
                Value<String> status = const Value.absent(),
                Value<String?> animalName = const Value.absent(),
                Value<bool?> found = const Value.absent(),
              }) => ScansCompanion.insert(
                id: id,
                epc: epc,
                scannedAt: scannedAt,
                status: status,
                animalName: animalName,
                found: found,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScansTable,
      Scan,
      $$ScansTableFilterComposer,
      $$ScansTableOrderingComposer,
      $$ScansTableAnnotationComposer,
      $$ScansTableCreateCompanionBuilder,
      $$ScansTableUpdateCompanionBuilder,
      (Scan, BaseReferences<_$AppDatabase, $ScansTable, Scan>),
      Scan,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ScansTableTableManager get scans =>
      $$ScansTableTableManager(_db, _db.scans);
}
