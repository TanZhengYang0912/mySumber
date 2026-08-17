// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $LocalEquipmentNodesTable extends LocalEquipmentNodes
    with TableInfo<$LocalEquipmentNodesTable, LocalEquipmentNode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEquipmentNodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
      'node_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _facilityNameMeta =
      const VerificationMeta('facilityName');
  @override
  late final GeneratedColumn<String> facilityName = GeneratedColumn<String>(
      'facility_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nodeNameMeta =
      const VerificationMeta('nodeName');
  @override
  late final GeneratedColumn<String> nodeName = GeneratedColumn<String>(
      'node_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [nodeId, facilityName, nodeName, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_equipment_nodes';
  @override
  VerificationContext validateIntegrity(Insertable<LocalEquipmentNode> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('node_id')) {
      context.handle(_nodeIdMeta,
          nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta));
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('facility_name')) {
      context.handle(
          _facilityNameMeta,
          facilityName.isAcceptableOrUnknown(
              data['facility_name']!, _facilityNameMeta));
    }
    if (data.containsKey('node_name')) {
      context.handle(_nodeNameMeta,
          nodeName.isAcceptableOrUnknown(data['node_name']!, _nodeNameMeta));
    } else if (isInserting) {
      context.missing(_nodeNameMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {nodeId};
  @override
  LocalEquipmentNode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEquipmentNode(
      nodeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}node_id'])!,
      facilityName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}facility_name']),
      nodeName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}node_name'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
    );
  }

  @override
  $LocalEquipmentNodesTable createAlias(String alias) {
    return $LocalEquipmentNodesTable(attachedDatabase, alias);
  }
}

class LocalEquipmentNode extends DataClass
    implements Insertable<LocalEquipmentNode> {
  final String nodeId;
  final String? facilityName;
  final String nodeName;
  final String payload;
  const LocalEquipmentNode(
      {required this.nodeId,
      this.facilityName,
      required this.nodeName,
      required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['node_id'] = Variable<String>(nodeId);
    if (!nullToAbsent || facilityName != null) {
      map['facility_name'] = Variable<String>(facilityName);
    }
    map['node_name'] = Variable<String>(nodeName);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  LocalEquipmentNodesCompanion toCompanion(bool nullToAbsent) {
    return LocalEquipmentNodesCompanion(
      nodeId: Value(nodeId),
      facilityName: facilityName == null && nullToAbsent
          ? const Value.absent()
          : Value(facilityName),
      nodeName: Value(nodeName),
      payload: Value(payload),
    );
  }

  factory LocalEquipmentNode.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEquipmentNode(
      nodeId: serializer.fromJson<String>(json['nodeId']),
      facilityName: serializer.fromJson<String?>(json['facilityName']),
      nodeName: serializer.fromJson<String>(json['nodeName']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'nodeId': serializer.toJson<String>(nodeId),
      'facilityName': serializer.toJson<String?>(facilityName),
      'nodeName': serializer.toJson<String>(nodeName),
      'payload': serializer.toJson<String>(payload),
    };
  }

  LocalEquipmentNode copyWith(
          {String? nodeId,
          Value<String?> facilityName = const Value.absent(),
          String? nodeName,
          String? payload}) =>
      LocalEquipmentNode(
        nodeId: nodeId ?? this.nodeId,
        facilityName:
            facilityName.present ? facilityName.value : this.facilityName,
        nodeName: nodeName ?? this.nodeName,
        payload: payload ?? this.payload,
      );
  LocalEquipmentNode copyWithCompanion(LocalEquipmentNodesCompanion data) {
    return LocalEquipmentNode(
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      facilityName: data.facilityName.present
          ? data.facilityName.value
          : this.facilityName,
      nodeName: data.nodeName.present ? data.nodeName.value : this.nodeName,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEquipmentNode(')
          ..write('nodeId: $nodeId, ')
          ..write('facilityName: $facilityName, ')
          ..write('nodeName: $nodeName, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(nodeId, facilityName, nodeName, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEquipmentNode &&
          other.nodeId == this.nodeId &&
          other.facilityName == this.facilityName &&
          other.nodeName == this.nodeName &&
          other.payload == this.payload);
}

class LocalEquipmentNodesCompanion extends UpdateCompanion<LocalEquipmentNode> {
  final Value<String> nodeId;
  final Value<String?> facilityName;
  final Value<String> nodeName;
  final Value<String> payload;
  final Value<int> rowid;
  const LocalEquipmentNodesCompanion({
    this.nodeId = const Value.absent(),
    this.facilityName = const Value.absent(),
    this.nodeName = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEquipmentNodesCompanion.insert({
    required String nodeId,
    this.facilityName = const Value.absent(),
    required String nodeName,
    required String payload,
    this.rowid = const Value.absent(),
  })  : nodeId = Value(nodeId),
        nodeName = Value(nodeName),
        payload = Value(payload);
  static Insertable<LocalEquipmentNode> custom({
    Expression<String>? nodeId,
    Expression<String>? facilityName,
    Expression<String>? nodeName,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (nodeId != null) 'node_id': nodeId,
      if (facilityName != null) 'facility_name': facilityName,
      if (nodeName != null) 'node_name': nodeName,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEquipmentNodesCompanion copyWith(
      {Value<String>? nodeId,
      Value<String?>? facilityName,
      Value<String>? nodeName,
      Value<String>? payload,
      Value<int>? rowid}) {
    return LocalEquipmentNodesCompanion(
      nodeId: nodeId ?? this.nodeId,
      facilityName: facilityName ?? this.facilityName,
      nodeName: nodeName ?? this.nodeName,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (facilityName.present) {
      map['facility_name'] = Variable<String>(facilityName.value);
    }
    if (nodeName.present) {
      map['node_name'] = Variable<String>(nodeName.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEquipmentNodesCompanion(')
          ..write('nodeId: $nodeId, ')
          ..write('facilityName: $facilityName, ')
          ..write('nodeName: $nodeName, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEquipmentUsageLogsTable extends LocalEquipmentUsageLogs
    with TableInfo<$LocalEquipmentUsageLogsTable, LocalEquipmentUsageLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEquipmentUsageLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _logIdMeta = const VerificationMeta('logId');
  @override
  late final GeneratedColumn<String> logId = GeneratedColumn<String>(
      'log_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
      'node_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _loggedAtMeta =
      const VerificationMeta('loggedAt');
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
      'logged_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [logId, nodeId, loggedAt, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_equipment_usage_logs';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalEquipmentUsageLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('log_id')) {
      context.handle(
          _logIdMeta, logId.isAcceptableOrUnknown(data['log_id']!, _logIdMeta));
    } else if (isInserting) {
      context.missing(_logIdMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(_nodeIdMeta,
          nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta));
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('logged_at')) {
      context.handle(_loggedAtMeta,
          loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta));
    } else if (isInserting) {
      context.missing(_loggedAtMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {logId};
  @override
  LocalEquipmentUsageLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEquipmentUsageLog(
      logId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}log_id'])!,
      nodeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}node_id'])!,
      loggedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}logged_at'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
    );
  }

  @override
  $LocalEquipmentUsageLogsTable createAlias(String alias) {
    return $LocalEquipmentUsageLogsTable(attachedDatabase, alias);
  }
}

class LocalEquipmentUsageLog extends DataClass
    implements Insertable<LocalEquipmentUsageLog> {
  final String logId;
  final String nodeId;
  final DateTime loggedAt;
  final String payload;
  const LocalEquipmentUsageLog(
      {required this.logId,
      required this.nodeId,
      required this.loggedAt,
      required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['log_id'] = Variable<String>(logId);
    map['node_id'] = Variable<String>(nodeId);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  LocalEquipmentUsageLogsCompanion toCompanion(bool nullToAbsent) {
    return LocalEquipmentUsageLogsCompanion(
      logId: Value(logId),
      nodeId: Value(nodeId),
      loggedAt: Value(loggedAt),
      payload: Value(payload),
    );
  }

  factory LocalEquipmentUsageLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEquipmentUsageLog(
      logId: serializer.fromJson<String>(json['logId']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'logId': serializer.toJson<String>(logId),
      'nodeId': serializer.toJson<String>(nodeId),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
      'payload': serializer.toJson<String>(payload),
    };
  }

  LocalEquipmentUsageLog copyWith(
          {String? logId,
          String? nodeId,
          DateTime? loggedAt,
          String? payload}) =>
      LocalEquipmentUsageLog(
        logId: logId ?? this.logId,
        nodeId: nodeId ?? this.nodeId,
        loggedAt: loggedAt ?? this.loggedAt,
        payload: payload ?? this.payload,
      );
  LocalEquipmentUsageLog copyWithCompanion(
      LocalEquipmentUsageLogsCompanion data) {
    return LocalEquipmentUsageLog(
      logId: data.logId.present ? data.logId.value : this.logId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEquipmentUsageLog(')
          ..write('logId: $logId, ')
          ..write('nodeId: $nodeId, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(logId, nodeId, loggedAt, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEquipmentUsageLog &&
          other.logId == this.logId &&
          other.nodeId == this.nodeId &&
          other.loggedAt == this.loggedAt &&
          other.payload == this.payload);
}

class LocalEquipmentUsageLogsCompanion
    extends UpdateCompanion<LocalEquipmentUsageLog> {
  final Value<String> logId;
  final Value<String> nodeId;
  final Value<DateTime> loggedAt;
  final Value<String> payload;
  final Value<int> rowid;
  const LocalEquipmentUsageLogsCompanion({
    this.logId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEquipmentUsageLogsCompanion.insert({
    required String logId,
    required String nodeId,
    required DateTime loggedAt,
    required String payload,
    this.rowid = const Value.absent(),
  })  : logId = Value(logId),
        nodeId = Value(nodeId),
        loggedAt = Value(loggedAt),
        payload = Value(payload);
  static Insertable<LocalEquipmentUsageLog> custom({
    Expression<String>? logId,
    Expression<String>? nodeId,
    Expression<DateTime>? loggedAt,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (logId != null) 'log_id': logId,
      if (nodeId != null) 'node_id': nodeId,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEquipmentUsageLogsCompanion copyWith(
      {Value<String>? logId,
      Value<String>? nodeId,
      Value<DateTime>? loggedAt,
      Value<String>? payload,
      Value<int>? rowid}) {
    return LocalEquipmentUsageLogsCompanion(
      logId: logId ?? this.logId,
      nodeId: nodeId ?? this.nodeId,
      loggedAt: loggedAt ?? this.loggedAt,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (logId.present) {
      map['log_id'] = Variable<String>(logId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEquipmentUsageLogsCompanion(')
          ..write('logId: $logId, ')
          ..write('nodeId: $nodeId, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalReadingsTable extends LocalReadings
    with TableInfo<$LocalReadingsTable, LocalReading> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalReadingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
      'remote_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [remoteId, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_readings';
  @override
  VerificationContext validateIntegrity(Insertable<LocalReading> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {remoteId};
  @override
  LocalReading map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalReading(
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remote_id'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
    );
  }

  @override
  $LocalReadingsTable createAlias(String alias) {
    return $LocalReadingsTable(attachedDatabase, alias);
  }
}

class LocalReading extends DataClass implements Insertable<LocalReading> {
  final int remoteId;
  final String payload;
  const LocalReading({required this.remoteId, required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['remote_id'] = Variable<int>(remoteId);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  LocalReadingsCompanion toCompanion(bool nullToAbsent) {
    return LocalReadingsCompanion(
      remoteId: Value(remoteId),
      payload: Value(payload),
    );
  }

  factory LocalReading.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalReading(
      remoteId: serializer.fromJson<int>(json['remoteId']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'remoteId': serializer.toJson<int>(remoteId),
      'payload': serializer.toJson<String>(payload),
    };
  }

  LocalReading copyWith({int? remoteId, String? payload}) => LocalReading(
        remoteId: remoteId ?? this.remoteId,
        payload: payload ?? this.payload,
      );
  LocalReading copyWithCompanion(LocalReadingsCompanion data) {
    return LocalReading(
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalReading(')
          ..write('remoteId: $remoteId, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(remoteId, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalReading &&
          other.remoteId == this.remoteId &&
          other.payload == this.payload);
}

class LocalReadingsCompanion extends UpdateCompanion<LocalReading> {
  final Value<int> remoteId;
  final Value<String> payload;
  const LocalReadingsCompanion({
    this.remoteId = const Value.absent(),
    this.payload = const Value.absent(),
  });
  LocalReadingsCompanion.insert({
    this.remoteId = const Value.absent(),
    required String payload,
  }) : payload = Value(payload);
  static Insertable<LocalReading> custom({
    Expression<int>? remoteId,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (remoteId != null) 'remote_id': remoteId,
      if (payload != null) 'payload': payload,
    });
  }

  LocalReadingsCompanion copyWith(
      {Value<int>? remoteId, Value<String>? payload}) {
    return LocalReadingsCompanion(
      remoteId: remoteId ?? this.remoteId,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalReadingsCompanion(')
          ..write('remoteId: $remoteId, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

class $LocalAlertsTable extends LocalAlerts
    with TableInfo<$LocalAlertsTable, LocalAlert> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAlertsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
      'remote_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _detectedAtMeta =
      const VerificationMeta('detectedAt');
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
      'detected_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [remoteId, status, isDeleted, detectedAt, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_alerts';
  @override
  VerificationContext validateIntegrity(Insertable<LocalAlert> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('detected_at')) {
      context.handle(
          _detectedAtMeta,
          detectedAt.isAcceptableOrUnknown(
              data['detected_at']!, _detectedAtMeta));
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {remoteId};
  @override
  LocalAlert map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAlert(
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remote_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      detectedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}detected_at'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
    );
  }

  @override
  $LocalAlertsTable createAlias(String alias) {
    return $LocalAlertsTable(attachedDatabase, alias);
  }
}

class LocalAlert extends DataClass implements Insertable<LocalAlert> {
  final int remoteId;
  final String status;
  final bool isDeleted;
  final DateTime detectedAt;
  final String payload;
  const LocalAlert(
      {required this.remoteId,
      required this.status,
      required this.isDeleted,
      required this.detectedAt,
      required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['remote_id'] = Variable<int>(remoteId);
    map['status'] = Variable<String>(status);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['detected_at'] = Variable<DateTime>(detectedAt);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  LocalAlertsCompanion toCompanion(bool nullToAbsent) {
    return LocalAlertsCompanion(
      remoteId: Value(remoteId),
      status: Value(status),
      isDeleted: Value(isDeleted),
      detectedAt: Value(detectedAt),
      payload: Value(payload),
    );
  }

  factory LocalAlert.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAlert(
      remoteId: serializer.fromJson<int>(json['remoteId']),
      status: serializer.fromJson<String>(json['status']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'remoteId': serializer.toJson<int>(remoteId),
      'status': serializer.toJson<String>(status),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
      'payload': serializer.toJson<String>(payload),
    };
  }

  LocalAlert copyWith(
          {int? remoteId,
          String? status,
          bool? isDeleted,
          DateTime? detectedAt,
          String? payload}) =>
      LocalAlert(
        remoteId: remoteId ?? this.remoteId,
        status: status ?? this.status,
        isDeleted: isDeleted ?? this.isDeleted,
        detectedAt: detectedAt ?? this.detectedAt,
        payload: payload ?? this.payload,
      );
  LocalAlert copyWithCompanion(LocalAlertsCompanion data) {
    return LocalAlert(
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      status: data.status.present ? data.status.value : this.status,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      detectedAt:
          data.detectedAt.present ? data.detectedAt.value : this.detectedAt,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAlert(')
          ..write('remoteId: $remoteId, ')
          ..write('status: $status, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(remoteId, status, isDeleted, detectedAt, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAlert &&
          other.remoteId == this.remoteId &&
          other.status == this.status &&
          other.isDeleted == this.isDeleted &&
          other.detectedAt == this.detectedAt &&
          other.payload == this.payload);
}

class LocalAlertsCompanion extends UpdateCompanion<LocalAlert> {
  final Value<int> remoteId;
  final Value<String> status;
  final Value<bool> isDeleted;
  final Value<DateTime> detectedAt;
  final Value<String> payload;
  const LocalAlertsCompanion({
    this.remoteId = const Value.absent(),
    this.status = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.payload = const Value.absent(),
  });
  LocalAlertsCompanion.insert({
    this.remoteId = const Value.absent(),
    required String status,
    this.isDeleted = const Value.absent(),
    required DateTime detectedAt,
    required String payload,
  })  : status = Value(status),
        detectedAt = Value(detectedAt),
        payload = Value(payload);
  static Insertable<LocalAlert> custom({
    Expression<int>? remoteId,
    Expression<String>? status,
    Expression<bool>? isDeleted,
    Expression<DateTime>? detectedAt,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (remoteId != null) 'remote_id': remoteId,
      if (status != null) 'status': status,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (payload != null) 'payload': payload,
    });
  }

  LocalAlertsCompanion copyWith(
      {Value<int>? remoteId,
      Value<String>? status,
      Value<bool>? isDeleted,
      Value<DateTime>? detectedAt,
      Value<String>? payload}) {
    return LocalAlertsCompanion(
      remoteId: remoteId ?? this.remoteId,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      detectedAt: detectedAt ?? this.detectedAt,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAlertsCompanion(')
          ..write('remoteId: $remoteId, ')
          ..write('status: $status, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

class $LocalReportsTable extends LocalReports
    with TableInfo<$LocalReportsTable, LocalReport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalReportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
      'remote_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [remoteId, isDeleted, updatedAt, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_reports';
  @override
  VerificationContext validateIntegrity(Insertable<LocalReport> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {remoteId};
  @override
  LocalReport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalReport(
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remote_id'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
    );
  }

  @override
  $LocalReportsTable createAlias(String alias) {
    return $LocalReportsTable(attachedDatabase, alias);
  }
}

class LocalReport extends DataClass implements Insertable<LocalReport> {
  final int remoteId;
  final bool isDeleted;
  final DateTime updatedAt;
  final String payload;
  const LocalReport(
      {required this.remoteId,
      required this.isDeleted,
      required this.updatedAt,
      required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['remote_id'] = Variable<int>(remoteId);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  LocalReportsCompanion toCompanion(bool nullToAbsent) {
    return LocalReportsCompanion(
      remoteId: Value(remoteId),
      isDeleted: Value(isDeleted),
      updatedAt: Value(updatedAt),
      payload: Value(payload),
    );
  }

  factory LocalReport.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalReport(
      remoteId: serializer.fromJson<int>(json['remoteId']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'remoteId': serializer.toJson<int>(remoteId),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'payload': serializer.toJson<String>(payload),
    };
  }

  LocalReport copyWith(
          {int? remoteId,
          bool? isDeleted,
          DateTime? updatedAt,
          String? payload}) =>
      LocalReport(
        remoteId: remoteId ?? this.remoteId,
        isDeleted: isDeleted ?? this.isDeleted,
        updatedAt: updatedAt ?? this.updatedAt,
        payload: payload ?? this.payload,
      );
  LocalReport copyWithCompanion(LocalReportsCompanion data) {
    return LocalReport(
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalReport(')
          ..write('remoteId: $remoteId, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(remoteId, isDeleted, updatedAt, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalReport &&
          other.remoteId == this.remoteId &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt &&
          other.payload == this.payload);
}

class LocalReportsCompanion extends UpdateCompanion<LocalReport> {
  final Value<int> remoteId;
  final Value<bool> isDeleted;
  final Value<DateTime> updatedAt;
  final Value<String> payload;
  const LocalReportsCompanion({
    this.remoteId = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.payload = const Value.absent(),
  });
  LocalReportsCompanion.insert({
    this.remoteId = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required DateTime updatedAt,
    required String payload,
  })  : updatedAt = Value(updatedAt),
        payload = Value(payload);
  static Insertable<LocalReport> custom({
    Expression<int>? remoteId,
    Expression<bool>? isDeleted,
    Expression<DateTime>? updatedAt,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (remoteId != null) 'remote_id': remoteId,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (payload != null) 'payload': payload,
    });
  }

  LocalReportsCompanion copyWith(
      {Value<int>? remoteId,
      Value<bool>? isDeleted,
      Value<DateTime>? updatedAt,
      Value<String>? payload}) {
    return LocalReportsCompanion(
      remoteId: remoteId ?? this.remoteId,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalReportsCompanion(')
          ..write('remoteId: $remoteId, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

class $LocalCustomerUtilityEntriesTable extends LocalCustomerUtilityEntries
    with
        TableInfo<$LocalCustomerUtilityEntriesTable,
            LocalCustomerUtilityEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCustomerUtilityEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
      'remote_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _utilityMeta =
      const VerificationMeta('utility');
  @override
  late final GeneratedColumn<String> utility = GeneratedColumn<String>(
      'utility', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _periodMonthMeta =
      const VerificationMeta('periodMonth');
  @override
  late final GeneratedColumn<DateTime> periodMonth = GeneratedColumn<DateTime>(
      'period_month', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [remoteId, userId, utility, periodMonth, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_customer_utility_entries';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalCustomerUtilityEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('utility')) {
      context.handle(_utilityMeta,
          utility.isAcceptableOrUnknown(data['utility']!, _utilityMeta));
    } else if (isInserting) {
      context.missing(_utilityMeta);
    }
    if (data.containsKey('period_month')) {
      context.handle(
          _periodMonthMeta,
          periodMonth.isAcceptableOrUnknown(
              data['period_month']!, _periodMonthMeta));
    } else if (isInserting) {
      context.missing(_periodMonthMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {remoteId, userId};
  @override
  LocalCustomerUtilityEntry map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCustomerUtilityEntry(
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remote_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      utility: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}utility'])!,
      periodMonth: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}period_month'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
    );
  }

  @override
  $LocalCustomerUtilityEntriesTable createAlias(String alias) {
    return $LocalCustomerUtilityEntriesTable(attachedDatabase, alias);
  }
}

class LocalCustomerUtilityEntry extends DataClass
    implements Insertable<LocalCustomerUtilityEntry> {
  final int remoteId;
  final String userId;
  final String utility;
  final DateTime periodMonth;
  final String payload;
  const LocalCustomerUtilityEntry(
      {required this.remoteId,
      required this.userId,
      required this.utility,
      required this.periodMonth,
      required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['remote_id'] = Variable<int>(remoteId);
    map['user_id'] = Variable<String>(userId);
    map['utility'] = Variable<String>(utility);
    map['period_month'] = Variable<DateTime>(periodMonth);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  LocalCustomerUtilityEntriesCompanion toCompanion(bool nullToAbsent) {
    return LocalCustomerUtilityEntriesCompanion(
      remoteId: Value(remoteId),
      userId: Value(userId),
      utility: Value(utility),
      periodMonth: Value(periodMonth),
      payload: Value(payload),
    );
  }

  factory LocalCustomerUtilityEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCustomerUtilityEntry(
      remoteId: serializer.fromJson<int>(json['remoteId']),
      userId: serializer.fromJson<String>(json['userId']),
      utility: serializer.fromJson<String>(json['utility']),
      periodMonth: serializer.fromJson<DateTime>(json['periodMonth']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'remoteId': serializer.toJson<int>(remoteId),
      'userId': serializer.toJson<String>(userId),
      'utility': serializer.toJson<String>(utility),
      'periodMonth': serializer.toJson<DateTime>(periodMonth),
      'payload': serializer.toJson<String>(payload),
    };
  }

  LocalCustomerUtilityEntry copyWith(
          {int? remoteId,
          String? userId,
          String? utility,
          DateTime? periodMonth,
          String? payload}) =>
      LocalCustomerUtilityEntry(
        remoteId: remoteId ?? this.remoteId,
        userId: userId ?? this.userId,
        utility: utility ?? this.utility,
        periodMonth: periodMonth ?? this.periodMonth,
        payload: payload ?? this.payload,
      );
  LocalCustomerUtilityEntry copyWithCompanion(
      LocalCustomerUtilityEntriesCompanion data) {
    return LocalCustomerUtilityEntry(
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      userId: data.userId.present ? data.userId.value : this.userId,
      utility: data.utility.present ? data.utility.value : this.utility,
      periodMonth:
          data.periodMonth.present ? data.periodMonth.value : this.periodMonth,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCustomerUtilityEntry(')
          ..write('remoteId: $remoteId, ')
          ..write('userId: $userId, ')
          ..write('utility: $utility, ')
          ..write('periodMonth: $periodMonth, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(remoteId, userId, utility, periodMonth, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCustomerUtilityEntry &&
          other.remoteId == this.remoteId &&
          other.userId == this.userId &&
          other.utility == this.utility &&
          other.periodMonth == this.periodMonth &&
          other.payload == this.payload);
}

class LocalCustomerUtilityEntriesCompanion
    extends UpdateCompanion<LocalCustomerUtilityEntry> {
  final Value<int> remoteId;
  final Value<String> userId;
  final Value<String> utility;
  final Value<DateTime> periodMonth;
  final Value<String> payload;
  final Value<int> rowid;
  const LocalCustomerUtilityEntriesCompanion({
    this.remoteId = const Value.absent(),
    this.userId = const Value.absent(),
    this.utility = const Value.absent(),
    this.periodMonth = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCustomerUtilityEntriesCompanion.insert({
    required int remoteId,
    required String userId,
    required String utility,
    required DateTime periodMonth,
    required String payload,
    this.rowid = const Value.absent(),
  })  : remoteId = Value(remoteId),
        userId = Value(userId),
        utility = Value(utility),
        periodMonth = Value(periodMonth),
        payload = Value(payload);
  static Insertable<LocalCustomerUtilityEntry> custom({
    Expression<int>? remoteId,
    Expression<String>? userId,
    Expression<String>? utility,
    Expression<DateTime>? periodMonth,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (remoteId != null) 'remote_id': remoteId,
      if (userId != null) 'user_id': userId,
      if (utility != null) 'utility': utility,
      if (periodMonth != null) 'period_month': periodMonth,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCustomerUtilityEntriesCompanion copyWith(
      {Value<int>? remoteId,
      Value<String>? userId,
      Value<String>? utility,
      Value<DateTime>? periodMonth,
      Value<String>? payload,
      Value<int>? rowid}) {
    return LocalCustomerUtilityEntriesCompanion(
      remoteId: remoteId ?? this.remoteId,
      userId: userId ?? this.userId,
      utility: utility ?? this.utility,
      periodMonth: periodMonth ?? this.periodMonth,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (utility.present) {
      map['utility'] = Variable<String>(utility.value);
    }
    if (periodMonth.present) {
      map['period_month'] = Variable<DateTime>(periodMonth.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCustomerUtilityEntriesCompanion(')
          ..write('remoteId: $remoteId, ')
          ..write('userId: $userId, ')
          ..write('utility: $utility, ')
          ..write('periodMonth: $periodMonth, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSyncMetadataTable extends LocalSyncMetadata
    with TableInfo<$LocalSyncMetadataTable, LocalSyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
      'scope', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [scope, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sync_metadata';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalSyncMetadataData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
          _scopeMeta, scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta));
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope};
  @override
  LocalSyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSyncMetadataData(
      scope: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $LocalSyncMetadataTable createAlias(String alias) {
    return $LocalSyncMetadataTable(attachedDatabase, alias);
  }
}

class LocalSyncMetadataData extends DataClass
    implements Insertable<LocalSyncMetadataData> {
  final String scope;
  final DateTime syncedAt;
  const LocalSyncMetadataData({required this.scope, required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  LocalSyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return LocalSyncMetadataCompanion(
      scope: Value(scope),
      syncedAt: Value(syncedAt),
    );
  }

  factory LocalSyncMetadataData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSyncMetadataData(
      scope: serializer.fromJson<String>(json['scope']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  LocalSyncMetadataData copyWith({String? scope, DateTime? syncedAt}) =>
      LocalSyncMetadataData(
        scope: scope ?? this.scope,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  LocalSyncMetadataData copyWithCompanion(LocalSyncMetadataCompanion data) {
    return LocalSyncMetadataData(
      scope: data.scope.present ? data.scope.value : this.scope,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSyncMetadataData(')
          ..write('scope: $scope, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSyncMetadataData &&
          other.scope == this.scope &&
          other.syncedAt == this.syncedAt);
}

class LocalSyncMetadataCompanion
    extends UpdateCompanion<LocalSyncMetadataData> {
  final Value<String> scope;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const LocalSyncMetadataCompanion({
    this.scope = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSyncMetadataCompanion.insert({
    required String scope,
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  })  : scope = Value(scope),
        syncedAt = Value(syncedAt);
  static Insertable<LocalSyncMetadataData> custom({
    Expression<String>? scope,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSyncMetadataCompanion copyWith(
      {Value<String>? scope, Value<DateTime>? syncedAt, Value<int>? rowid}) {
    return LocalSyncMetadataCompanion(
      scope: scope ?? this.scope,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSyncMetadataCompanion(')
          ..write('scope: $scope, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $LocalEquipmentNodesTable localEquipmentNodes =
      $LocalEquipmentNodesTable(this);
  late final $LocalEquipmentUsageLogsTable localEquipmentUsageLogs =
      $LocalEquipmentUsageLogsTable(this);
  late final $LocalReadingsTable localReadings = $LocalReadingsTable(this);
  late final $LocalAlertsTable localAlerts = $LocalAlertsTable(this);
  late final $LocalReportsTable localReports = $LocalReportsTable(this);
  late final $LocalCustomerUtilityEntriesTable localCustomerUtilityEntries =
      $LocalCustomerUtilityEntriesTable(this);
  late final $LocalSyncMetadataTable localSyncMetadata =
      $LocalSyncMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        localEquipmentNodes,
        localEquipmentUsageLogs,
        localReadings,
        localAlerts,
        localReports,
        localCustomerUtilityEntries,
        localSyncMetadata
      ];
}

typedef $$LocalEquipmentNodesTableCreateCompanionBuilder
    = LocalEquipmentNodesCompanion Function({
  required String nodeId,
  Value<String?> facilityName,
  required String nodeName,
  required String payload,
  Value<int> rowid,
});
typedef $$LocalEquipmentNodesTableUpdateCompanionBuilder
    = LocalEquipmentNodesCompanion Function({
  Value<String> nodeId,
  Value<String?> facilityName,
  Value<String> nodeName,
  Value<String> payload,
  Value<int> rowid,
});

class $$LocalEquipmentNodesTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalEquipmentNodesTable> {
  $$LocalEquipmentNodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get facilityName => $composableBuilder(
      column: $table.facilityName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nodeName => $composableBuilder(
      column: $table.nodeName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));
}

class $$LocalEquipmentNodesTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalEquipmentNodesTable> {
  $$LocalEquipmentNodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get facilityName => $composableBuilder(
      column: $table.facilityName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nodeName => $composableBuilder(
      column: $table.nodeName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));
}

class $$LocalEquipmentNodesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalEquipmentNodesTable> {
  $$LocalEquipmentNodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get facilityName => $composableBuilder(
      column: $table.facilityName, builder: (column) => column);

  GeneratedColumn<String> get nodeName =>
      $composableBuilder(column: $table.nodeName, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$LocalEquipmentNodesTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $LocalEquipmentNodesTable,
    LocalEquipmentNode,
    $$LocalEquipmentNodesTableFilterComposer,
    $$LocalEquipmentNodesTableOrderingComposer,
    $$LocalEquipmentNodesTableAnnotationComposer,
    $$LocalEquipmentNodesTableCreateCompanionBuilder,
    $$LocalEquipmentNodesTableUpdateCompanionBuilder,
    (
      LocalEquipmentNode,
      BaseReferences<_$LocalDatabase, $LocalEquipmentNodesTable,
          LocalEquipmentNode>
    ),
    LocalEquipmentNode,
    PrefetchHooks Function()> {
  $$LocalEquipmentNodesTableTableManager(
      _$LocalDatabase db, $LocalEquipmentNodesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEquipmentNodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEquipmentNodesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEquipmentNodesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> nodeId = const Value.absent(),
            Value<String?> facilityName = const Value.absent(),
            Value<String> nodeName = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalEquipmentNodesCompanion(
            nodeId: nodeId,
            facilityName: facilityName,
            nodeName: nodeName,
            payload: payload,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String nodeId,
            Value<String?> facilityName = const Value.absent(),
            required String nodeName,
            required String payload,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalEquipmentNodesCompanion.insert(
            nodeId: nodeId,
            facilityName: facilityName,
            nodeName: nodeName,
            payload: payload,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalEquipmentNodesTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $LocalEquipmentNodesTable,
    LocalEquipmentNode,
    $$LocalEquipmentNodesTableFilterComposer,
    $$LocalEquipmentNodesTableOrderingComposer,
    $$LocalEquipmentNodesTableAnnotationComposer,
    $$LocalEquipmentNodesTableCreateCompanionBuilder,
    $$LocalEquipmentNodesTableUpdateCompanionBuilder,
    (
      LocalEquipmentNode,
      BaseReferences<_$LocalDatabase, $LocalEquipmentNodesTable,
          LocalEquipmentNode>
    ),
    LocalEquipmentNode,
    PrefetchHooks Function()>;
typedef $$LocalEquipmentUsageLogsTableCreateCompanionBuilder
    = LocalEquipmentUsageLogsCompanion Function({
  required String logId,
  required String nodeId,
  required DateTime loggedAt,
  required String payload,
  Value<int> rowid,
});
typedef $$LocalEquipmentUsageLogsTableUpdateCompanionBuilder
    = LocalEquipmentUsageLogsCompanion Function({
  Value<String> logId,
  Value<String> nodeId,
  Value<DateTime> loggedAt,
  Value<String> payload,
  Value<int> rowid,
});

class $$LocalEquipmentUsageLogsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalEquipmentUsageLogsTable> {
  $$LocalEquipmentUsageLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get logId => $composableBuilder(
      column: $table.logId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
      column: $table.loggedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));
}

class $$LocalEquipmentUsageLogsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalEquipmentUsageLogsTable> {
  $$LocalEquipmentUsageLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get logId => $composableBuilder(
      column: $table.logId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
      column: $table.loggedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));
}

class $$LocalEquipmentUsageLogsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalEquipmentUsageLogsTable> {
  $$LocalEquipmentUsageLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get logId =>
      $composableBuilder(column: $table.logId, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$LocalEquipmentUsageLogsTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $LocalEquipmentUsageLogsTable,
    LocalEquipmentUsageLog,
    $$LocalEquipmentUsageLogsTableFilterComposer,
    $$LocalEquipmentUsageLogsTableOrderingComposer,
    $$LocalEquipmentUsageLogsTableAnnotationComposer,
    $$LocalEquipmentUsageLogsTableCreateCompanionBuilder,
    $$LocalEquipmentUsageLogsTableUpdateCompanionBuilder,
    (
      LocalEquipmentUsageLog,
      BaseReferences<_$LocalDatabase, $LocalEquipmentUsageLogsTable,
          LocalEquipmentUsageLog>
    ),
    LocalEquipmentUsageLog,
    PrefetchHooks Function()> {
  $$LocalEquipmentUsageLogsTableTableManager(
      _$LocalDatabase db, $LocalEquipmentUsageLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEquipmentUsageLogsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEquipmentUsageLogsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEquipmentUsageLogsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> logId = const Value.absent(),
            Value<String> nodeId = const Value.absent(),
            Value<DateTime> loggedAt = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalEquipmentUsageLogsCompanion(
            logId: logId,
            nodeId: nodeId,
            loggedAt: loggedAt,
            payload: payload,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String logId,
            required String nodeId,
            required DateTime loggedAt,
            required String payload,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalEquipmentUsageLogsCompanion.insert(
            logId: logId,
            nodeId: nodeId,
            loggedAt: loggedAt,
            payload: payload,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalEquipmentUsageLogsTableProcessedTableManager
    = ProcessedTableManager<
        _$LocalDatabase,
        $LocalEquipmentUsageLogsTable,
        LocalEquipmentUsageLog,
        $$LocalEquipmentUsageLogsTableFilterComposer,
        $$LocalEquipmentUsageLogsTableOrderingComposer,
        $$LocalEquipmentUsageLogsTableAnnotationComposer,
        $$LocalEquipmentUsageLogsTableCreateCompanionBuilder,
        $$LocalEquipmentUsageLogsTableUpdateCompanionBuilder,
        (
          LocalEquipmentUsageLog,
          BaseReferences<_$LocalDatabase, $LocalEquipmentUsageLogsTable,
              LocalEquipmentUsageLog>
        ),
        LocalEquipmentUsageLog,
        PrefetchHooks Function()>;
typedef $$LocalReadingsTableCreateCompanionBuilder = LocalReadingsCompanion
    Function({
  Value<int> remoteId,
  required String payload,
});
typedef $$LocalReadingsTableUpdateCompanionBuilder = LocalReadingsCompanion
    Function({
  Value<int> remoteId,
  Value<String> payload,
});

class $$LocalReadingsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalReadingsTable> {
  $$LocalReadingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));
}

class $$LocalReadingsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalReadingsTable> {
  $$LocalReadingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));
}

class $$LocalReadingsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalReadingsTable> {
  $$LocalReadingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$LocalReadingsTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $LocalReadingsTable,
    LocalReading,
    $$LocalReadingsTableFilterComposer,
    $$LocalReadingsTableOrderingComposer,
    $$LocalReadingsTableAnnotationComposer,
    $$LocalReadingsTableCreateCompanionBuilder,
    $$LocalReadingsTableUpdateCompanionBuilder,
    (
      LocalReading,
      BaseReferences<_$LocalDatabase, $LocalReadingsTable, LocalReading>
    ),
    LocalReading,
    PrefetchHooks Function()> {
  $$LocalReadingsTableTableManager(
      _$LocalDatabase db, $LocalReadingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalReadingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalReadingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalReadingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> remoteId = const Value.absent(),
            Value<String> payload = const Value.absent(),
          }) =>
              LocalReadingsCompanion(
            remoteId: remoteId,
            payload: payload,
          ),
          createCompanionCallback: ({
            Value<int> remoteId = const Value.absent(),
            required String payload,
          }) =>
              LocalReadingsCompanion.insert(
            remoteId: remoteId,
            payload: payload,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalReadingsTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $LocalReadingsTable,
    LocalReading,
    $$LocalReadingsTableFilterComposer,
    $$LocalReadingsTableOrderingComposer,
    $$LocalReadingsTableAnnotationComposer,
    $$LocalReadingsTableCreateCompanionBuilder,
    $$LocalReadingsTableUpdateCompanionBuilder,
    (
      LocalReading,
      BaseReferences<_$LocalDatabase, $LocalReadingsTable, LocalReading>
    ),
    LocalReading,
    PrefetchHooks Function()>;
typedef $$LocalAlertsTableCreateCompanionBuilder = LocalAlertsCompanion
    Function({
  Value<int> remoteId,
  required String status,
  Value<bool> isDeleted,
  required DateTime detectedAt,
  required String payload,
});
typedef $$LocalAlertsTableUpdateCompanionBuilder = LocalAlertsCompanion
    Function({
  Value<int> remoteId,
  Value<String> status,
  Value<bool> isDeleted,
  Value<DateTime> detectedAt,
  Value<String> payload,
});

class $$LocalAlertsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalAlertsTable> {
  $$LocalAlertsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));
}

class $$LocalAlertsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalAlertsTable> {
  $$LocalAlertsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));
}

class $$LocalAlertsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalAlertsTable> {
  $$LocalAlertsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$LocalAlertsTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $LocalAlertsTable,
    LocalAlert,
    $$LocalAlertsTableFilterComposer,
    $$LocalAlertsTableOrderingComposer,
    $$LocalAlertsTableAnnotationComposer,
    $$LocalAlertsTableCreateCompanionBuilder,
    $$LocalAlertsTableUpdateCompanionBuilder,
    (
      LocalAlert,
      BaseReferences<_$LocalDatabase, $LocalAlertsTable, LocalAlert>
    ),
    LocalAlert,
    PrefetchHooks Function()> {
  $$LocalAlertsTableTableManager(_$LocalDatabase db, $LocalAlertsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAlertsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAlertsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAlertsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> remoteId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<DateTime> detectedAt = const Value.absent(),
            Value<String> payload = const Value.absent(),
          }) =>
              LocalAlertsCompanion(
            remoteId: remoteId,
            status: status,
            isDeleted: isDeleted,
            detectedAt: detectedAt,
            payload: payload,
          ),
          createCompanionCallback: ({
            Value<int> remoteId = const Value.absent(),
            required String status,
            Value<bool> isDeleted = const Value.absent(),
            required DateTime detectedAt,
            required String payload,
          }) =>
              LocalAlertsCompanion.insert(
            remoteId: remoteId,
            status: status,
            isDeleted: isDeleted,
            detectedAt: detectedAt,
            payload: payload,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalAlertsTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $LocalAlertsTable,
    LocalAlert,
    $$LocalAlertsTableFilterComposer,
    $$LocalAlertsTableOrderingComposer,
    $$LocalAlertsTableAnnotationComposer,
    $$LocalAlertsTableCreateCompanionBuilder,
    $$LocalAlertsTableUpdateCompanionBuilder,
    (
      LocalAlert,
      BaseReferences<_$LocalDatabase, $LocalAlertsTable, LocalAlert>
    ),
    LocalAlert,
    PrefetchHooks Function()>;
typedef $$LocalReportsTableCreateCompanionBuilder = LocalReportsCompanion
    Function({
  Value<int> remoteId,
  Value<bool> isDeleted,
  required DateTime updatedAt,
  required String payload,
});
typedef $$LocalReportsTableUpdateCompanionBuilder = LocalReportsCompanion
    Function({
  Value<int> remoteId,
  Value<bool> isDeleted,
  Value<DateTime> updatedAt,
  Value<String> payload,
});

class $$LocalReportsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalReportsTable> {
  $$LocalReportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));
}

class $$LocalReportsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalReportsTable> {
  $$LocalReportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));
}

class $$LocalReportsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalReportsTable> {
  $$LocalReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$LocalReportsTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $LocalReportsTable,
    LocalReport,
    $$LocalReportsTableFilterComposer,
    $$LocalReportsTableOrderingComposer,
    $$LocalReportsTableAnnotationComposer,
    $$LocalReportsTableCreateCompanionBuilder,
    $$LocalReportsTableUpdateCompanionBuilder,
    (
      LocalReport,
      BaseReferences<_$LocalDatabase, $LocalReportsTable, LocalReport>
    ),
    LocalReport,
    PrefetchHooks Function()> {
  $$LocalReportsTableTableManager(_$LocalDatabase db, $LocalReportsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> remoteId = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String> payload = const Value.absent(),
          }) =>
              LocalReportsCompanion(
            remoteId: remoteId,
            isDeleted: isDeleted,
            updatedAt: updatedAt,
            payload: payload,
          ),
          createCompanionCallback: ({
            Value<int> remoteId = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            required DateTime updatedAt,
            required String payload,
          }) =>
              LocalReportsCompanion.insert(
            remoteId: remoteId,
            isDeleted: isDeleted,
            updatedAt: updatedAt,
            payload: payload,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalReportsTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $LocalReportsTable,
    LocalReport,
    $$LocalReportsTableFilterComposer,
    $$LocalReportsTableOrderingComposer,
    $$LocalReportsTableAnnotationComposer,
    $$LocalReportsTableCreateCompanionBuilder,
    $$LocalReportsTableUpdateCompanionBuilder,
    (
      LocalReport,
      BaseReferences<_$LocalDatabase, $LocalReportsTable, LocalReport>
    ),
    LocalReport,
    PrefetchHooks Function()>;
typedef $$LocalCustomerUtilityEntriesTableCreateCompanionBuilder
    = LocalCustomerUtilityEntriesCompanion Function({
  required int remoteId,
  required String userId,
  required String utility,
  required DateTime periodMonth,
  required String payload,
  Value<int> rowid,
});
typedef $$LocalCustomerUtilityEntriesTableUpdateCompanionBuilder
    = LocalCustomerUtilityEntriesCompanion Function({
  Value<int> remoteId,
  Value<String> userId,
  Value<String> utility,
  Value<DateTime> periodMonth,
  Value<String> payload,
  Value<int> rowid,
});

class $$LocalCustomerUtilityEntriesTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalCustomerUtilityEntriesTable> {
  $$LocalCustomerUtilityEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get utility => $composableBuilder(
      column: $table.utility, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get periodMonth => $composableBuilder(
      column: $table.periodMonth, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));
}

class $$LocalCustomerUtilityEntriesTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalCustomerUtilityEntriesTable> {
  $$LocalCustomerUtilityEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get utility => $composableBuilder(
      column: $table.utility, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get periodMonth => $composableBuilder(
      column: $table.periodMonth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));
}

class $$LocalCustomerUtilityEntriesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalCustomerUtilityEntriesTable> {
  $$LocalCustomerUtilityEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get utility =>
      $composableBuilder(column: $table.utility, builder: (column) => column);

  GeneratedColumn<DateTime> get periodMonth => $composableBuilder(
      column: $table.periodMonth, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$LocalCustomerUtilityEntriesTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $LocalCustomerUtilityEntriesTable,
    LocalCustomerUtilityEntry,
    $$LocalCustomerUtilityEntriesTableFilterComposer,
    $$LocalCustomerUtilityEntriesTableOrderingComposer,
    $$LocalCustomerUtilityEntriesTableAnnotationComposer,
    $$LocalCustomerUtilityEntriesTableCreateCompanionBuilder,
    $$LocalCustomerUtilityEntriesTableUpdateCompanionBuilder,
    (
      LocalCustomerUtilityEntry,
      BaseReferences<_$LocalDatabase, $LocalCustomerUtilityEntriesTable,
          LocalCustomerUtilityEntry>
    ),
    LocalCustomerUtilityEntry,
    PrefetchHooks Function()> {
  $$LocalCustomerUtilityEntriesTableTableManager(
      _$LocalDatabase db, $LocalCustomerUtilityEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCustomerUtilityEntriesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCustomerUtilityEntriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCustomerUtilityEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> remoteId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> utility = const Value.absent(),
            Value<DateTime> periodMonth = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCustomerUtilityEntriesCompanion(
            remoteId: remoteId,
            userId: userId,
            utility: utility,
            periodMonth: periodMonth,
            payload: payload,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int remoteId,
            required String userId,
            required String utility,
            required DateTime periodMonth,
            required String payload,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCustomerUtilityEntriesCompanion.insert(
            remoteId: remoteId,
            userId: userId,
            utility: utility,
            periodMonth: periodMonth,
            payload: payload,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalCustomerUtilityEntriesTableProcessedTableManager
    = ProcessedTableManager<
        _$LocalDatabase,
        $LocalCustomerUtilityEntriesTable,
        LocalCustomerUtilityEntry,
        $$LocalCustomerUtilityEntriesTableFilterComposer,
        $$LocalCustomerUtilityEntriesTableOrderingComposer,
        $$LocalCustomerUtilityEntriesTableAnnotationComposer,
        $$LocalCustomerUtilityEntriesTableCreateCompanionBuilder,
        $$LocalCustomerUtilityEntriesTableUpdateCompanionBuilder,
        (
          LocalCustomerUtilityEntry,
          BaseReferences<_$LocalDatabase, $LocalCustomerUtilityEntriesTable,
              LocalCustomerUtilityEntry>
        ),
        LocalCustomerUtilityEntry,
        PrefetchHooks Function()>;
typedef $$LocalSyncMetadataTableCreateCompanionBuilder
    = LocalSyncMetadataCompanion Function({
  required String scope,
  required DateTime syncedAt,
  Value<int> rowid,
});
typedef $$LocalSyncMetadataTableUpdateCompanionBuilder
    = LocalSyncMetadataCompanion Function({
  Value<String> scope,
  Value<DateTime> syncedAt,
  Value<int> rowid,
});

class $$LocalSyncMetadataTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalSyncMetadataTable> {
  $$LocalSyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalSyncMetadataTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalSyncMetadataTable> {
  $$LocalSyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalSyncMetadataTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalSyncMetadataTable> {
  $$LocalSyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$LocalSyncMetadataTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $LocalSyncMetadataTable,
    LocalSyncMetadataData,
    $$LocalSyncMetadataTableFilterComposer,
    $$LocalSyncMetadataTableOrderingComposer,
    $$LocalSyncMetadataTableAnnotationComposer,
    $$LocalSyncMetadataTableCreateCompanionBuilder,
    $$LocalSyncMetadataTableUpdateCompanionBuilder,
    (
      LocalSyncMetadataData,
      BaseReferences<_$LocalDatabase, $LocalSyncMetadataTable,
          LocalSyncMetadataData>
    ),
    LocalSyncMetadataData,
    PrefetchHooks Function()> {
  $$LocalSyncMetadataTableTableManager(
      _$LocalDatabase db, $LocalSyncMetadataTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSyncMetadataTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> scope = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSyncMetadataCompanion(
            scope: scope,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String scope,
            required DateTime syncedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSyncMetadataCompanion.insert(
            scope: scope,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSyncMetadataTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $LocalSyncMetadataTable,
    LocalSyncMetadataData,
    $$LocalSyncMetadataTableFilterComposer,
    $$LocalSyncMetadataTableOrderingComposer,
    $$LocalSyncMetadataTableAnnotationComposer,
    $$LocalSyncMetadataTableCreateCompanionBuilder,
    $$LocalSyncMetadataTableUpdateCompanionBuilder,
    (
      LocalSyncMetadataData,
      BaseReferences<_$LocalDatabase, $LocalSyncMetadataTable,
          LocalSyncMetadataData>
    ),
    LocalSyncMetadataData,
    PrefetchHooks Function()>;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$LocalEquipmentNodesTableTableManager get localEquipmentNodes =>
      $$LocalEquipmentNodesTableTableManager(_db, _db.localEquipmentNodes);
  $$LocalEquipmentUsageLogsTableTableManager get localEquipmentUsageLogs =>
      $$LocalEquipmentUsageLogsTableTableManager(
          _db, _db.localEquipmentUsageLogs);
  $$LocalReadingsTableTableManager get localReadings =>
      $$LocalReadingsTableTableManager(_db, _db.localReadings);
  $$LocalAlertsTableTableManager get localAlerts =>
      $$LocalAlertsTableTableManager(_db, _db.localAlerts);
  $$LocalReportsTableTableManager get localReports =>
      $$LocalReportsTableTableManager(_db, _db.localReports);
  $$LocalCustomerUtilityEntriesTableTableManager
      get localCustomerUtilityEntries =>
          $$LocalCustomerUtilityEntriesTableTableManager(
              _db, _db.localCustomerUtilityEntries);
  $$LocalSyncMetadataTableTableManager get localSyncMetadata =>
      $$LocalSyncMetadataTableTableManager(_db, _db.localSyncMetadata);
}
