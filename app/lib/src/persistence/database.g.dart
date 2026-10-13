// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, DownloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<String> gid = GeneratedColumn<String>(
    'gid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalLengthMeta = const VerificationMeta(
    'totalLength',
  );
  @override
  late final GeneratedColumn<int> totalLength = GeneratedColumn<int>(
    'total_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedLengthMeta = const VerificationMeta(
    'completedLength',
  );
  @override
  late final GeneratedColumn<int> completedLength = GeneratedColumn<int>(
    'completed_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadSpeedMeta = const VerificationMeta(
    'downloadSpeed',
  );
  @override
  late final GeneratedColumn<int> downloadSpeed = GeneratedColumn<int>(
    'download_speed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dirMeta = const VerificationMeta('dir');
  @override
  late final GeneratedColumn<String> dir = GeneratedColumn<String>(
    'dir',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gid,
    filename,
    totalLength,
    completedLength,
    status,
    downloadSpeed,
    dir,
    errorCode,
    errorMessage,
    addedAt,
    completedAt,
    sourceUrl,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
        _gidMeta,
        gid.isAcceptableOrUnknown(data['gid']!, _gidMeta),
      );
    } else if (isInserting) {
      context.missing(_gidMeta);
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('total_length')) {
      context.handle(
        _totalLengthMeta,
        totalLength.isAcceptableOrUnknown(
          data['total_length']!,
          _totalLengthMeta,
        ),
      );
    }
    if (data.containsKey('completed_length')) {
      context.handle(
        _completedLengthMeta,
        completedLength.isAcceptableOrUnknown(
          data['completed_length']!,
          _completedLengthMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('download_speed')) {
      context.handle(
        _downloadSpeedMeta,
        downloadSpeed.isAcceptableOrUnknown(
          data['download_speed']!,
          _downloadSpeedMeta,
        ),
      );
    }
    if (data.containsKey('dir')) {
      context.handle(
        _dirMeta,
        dir.isAcceptableOrUnknown(data['dir']!, _dirMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid};
  @override
  DownloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRow(
      gid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gid'],
      )!,
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      totalLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_length'],
      )!,
      completedLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_length'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      downloadSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_speed'],
      )!,
      dir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dir'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }
}

class DownloadRow extends DataClass implements Insertable<DownloadRow> {
  final String gid;
  final String filename;
  final int totalLength;
  final int completedLength;
  final String status;
  final int downloadSpeed;
  final String dir;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? addedAt;
  final DateTime? completedAt;
  final String? sourceUrl;
  final DateTime updatedAt;
  const DownloadRow({
    required this.gid,
    required this.filename,
    required this.totalLength,
    required this.completedLength,
    required this.status,
    required this.downloadSpeed,
    required this.dir,
    this.errorCode,
    this.errorMessage,
    this.addedAt,
    this.completedAt,
    this.sourceUrl,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<String>(gid);
    map['filename'] = Variable<String>(filename);
    map['total_length'] = Variable<int>(totalLength);
    map['completed_length'] = Variable<int>(completedLength);
    map['status'] = Variable<String>(status);
    map['download_speed'] = Variable<int>(downloadSpeed);
    map['dir'] = Variable<String>(dir);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<DateTime>(addedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      gid: Value(gid),
      filename: Value(filename),
      totalLength: Value(totalLength),
      completedLength: Value(completedLength),
      status: Value(status),
      downloadSpeed: Value(downloadSpeed),
      dir: Value(dir),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      updatedAt: Value(updatedAt),
    );
  }

  factory DownloadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRow(
      gid: serializer.fromJson<String>(json['gid']),
      filename: serializer.fromJson<String>(json['filename']),
      totalLength: serializer.fromJson<int>(json['totalLength']),
      completedLength: serializer.fromJson<int>(json['completedLength']),
      status: serializer.fromJson<String>(json['status']),
      downloadSpeed: serializer.fromJson<int>(json['downloadSpeed']),
      dir: serializer.fromJson<String>(json['dir']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      addedAt: serializer.fromJson<DateTime?>(json['addedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<String>(gid),
      'filename': serializer.toJson<String>(filename),
      'totalLength': serializer.toJson<int>(totalLength),
      'completedLength': serializer.toJson<int>(completedLength),
      'status': serializer.toJson<String>(status),
      'downloadSpeed': serializer.toJson<int>(downloadSpeed),
      'dir': serializer.toJson<String>(dir),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'addedAt': serializer.toJson<DateTime?>(addedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DownloadRow copyWith({
    String? gid,
    String? filename,
    int? totalLength,
    int? completedLength,
    String? status,
    int? downloadSpeed,
    String? dir,
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    Value<DateTime?> addedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    DateTime? updatedAt,
  }) => DownloadRow(
    gid: gid ?? this.gid,
    filename: filename ?? this.filename,
    totalLength: totalLength ?? this.totalLength,
    completedLength: completedLength ?? this.completedLength,
    status: status ?? this.status,
    downloadSpeed: downloadSpeed ?? this.downloadSpeed,
    dir: dir ?? this.dir,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DownloadRow copyWithCompanion(DownloadsCompanion data) {
    return DownloadRow(
      gid: data.gid.present ? data.gid.value : this.gid,
      filename: data.filename.present ? data.filename.value : this.filename,
      totalLength: data.totalLength.present
          ? data.totalLength.value
          : this.totalLength,
      completedLength: data.completedLength.present
          ? data.completedLength.value
          : this.completedLength,
      status: data.status.present ? data.status.value : this.status,
      downloadSpeed: data.downloadSpeed.present
          ? data.downloadSpeed.value
          : this.downloadSpeed,
      dir: data.dir.present ? data.dir.value : this.dir,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRow(')
          ..write('gid: $gid, ')
          ..write('filename: $filename, ')
          ..write('totalLength: $totalLength, ')
          ..write('completedLength: $completedLength, ')
          ..write('status: $status, ')
          ..write('downloadSpeed: $downloadSpeed, ')
          ..write('dir: $dir, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('addedAt: $addedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    gid,
    filename,
    totalLength,
    completedLength,
    status,
    downloadSpeed,
    dir,
    errorCode,
    errorMessage,
    addedAt,
    completedAt,
    sourceUrl,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRow &&
          other.gid == this.gid &&
          other.filename == this.filename &&
          other.totalLength == this.totalLength &&
          other.completedLength == this.completedLength &&
          other.status == this.status &&
          other.downloadSpeed == this.downloadSpeed &&
          other.dir == this.dir &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.addedAt == this.addedAt &&
          other.completedAt == this.completedAt &&
          other.sourceUrl == this.sourceUrl &&
          other.updatedAt == this.updatedAt);
}

class DownloadsCompanion extends UpdateCompanion<DownloadRow> {
  final Value<String> gid;
  final Value<String> filename;
  final Value<int> totalLength;
  final Value<int> completedLength;
  final Value<String> status;
  final Value<int> downloadSpeed;
  final Value<String> dir;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<DateTime?> addedAt;
  final Value<DateTime?> completedAt;
  final Value<String?> sourceUrl;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.gid = const Value.absent(),
    this.filename = const Value.absent(),
    this.totalLength = const Value.absent(),
    this.completedLength = const Value.absent(),
    this.status = const Value.absent(),
    this.downloadSpeed = const Value.absent(),
    this.dir = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String gid,
    required String filename,
    this.totalLength = const Value.absent(),
    this.completedLength = const Value.absent(),
    required String status,
    this.downloadSpeed = const Value.absent(),
    this.dir = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : gid = Value(gid),
       filename = Value(filename),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<DownloadRow> custom({
    Expression<String>? gid,
    Expression<String>? filename,
    Expression<int>? totalLength,
    Expression<int>? completedLength,
    Expression<String>? status,
    Expression<int>? downloadSpeed,
    Expression<String>? dir,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? completedAt,
    Expression<String>? sourceUrl,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (filename != null) 'filename': filename,
      if (totalLength != null) 'total_length': totalLength,
      if (completedLength != null) 'completed_length': completedLength,
      if (status != null) 'status': status,
      if (downloadSpeed != null) 'download_speed': downloadSpeed,
      if (dir != null) 'dir': dir,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (addedAt != null) 'added_at': addedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith({
    Value<String>? gid,
    Value<String>? filename,
    Value<int>? totalLength,
    Value<int>? completedLength,
    Value<String>? status,
    Value<int>? downloadSpeed,
    Value<String>? dir,
    Value<String?>? errorCode,
    Value<String?>? errorMessage,
    Value<DateTime?>? addedAt,
    Value<DateTime?>? completedAt,
    Value<String?>? sourceUrl,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DownloadsCompanion(
      gid: gid ?? this.gid,
      filename: filename ?? this.filename,
      totalLength: totalLength ?? this.totalLength,
      completedLength: completedLength ?? this.completedLength,
      status: status ?? this.status,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      dir: dir ?? this.dir,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      addedAt: addedAt ?? this.addedAt,
      completedAt: completedAt ?? this.completedAt,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<String>(gid.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (totalLength.present) {
      map['total_length'] = Variable<int>(totalLength.value);
    }
    if (completedLength.present) {
      map['completed_length'] = Variable<int>(completedLength.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (downloadSpeed.present) {
      map['download_speed'] = Variable<int>(downloadSpeed.value);
    }
    if (dir.present) {
      map['dir'] = Variable<String>(dir.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('gid: $gid, ')
          ..write('filename: $filename, ')
          ..write('totalLength: $totalLength, ')
          ..write('completedLength: $completedLength, ')
          ..write('status: $status, ')
          ..write('downloadSpeed: $downloadSpeed, ')
          ..write('dir: $dir, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('addedAt: $addedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadSettingsTable extends DownloadSettings
    with TableInfo<$DownloadSettingsTable, DownloadSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DownloadSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $DownloadSettingsTable createAlias(String alias) {
    return $DownloadSettingsTable(attachedDatabase, alias);
  }
}

class DownloadSettingRow extends DataClass
    implements Insertable<DownloadSettingRow> {
  final String key;
  final String value;
  const DownloadSettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  DownloadSettingsCompanion toCompanion(bool nullToAbsent) {
    return DownloadSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory DownloadSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  DownloadSettingRow copyWith({String? key, String? value}) =>
      DownloadSettingRow(key: key ?? this.key, value: value ?? this.value);
  DownloadSettingRow copyWithCompanion(DownloadSettingsCompanion data) {
    return DownloadSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadSettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class DownloadSettingsCompanion extends UpdateCompanion<DownloadSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const DownloadSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<DownloadSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return DownloadSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultSaveDirMeta = const VerificationMeta(
    'defaultSaveDir',
  );
  @override
  late final GeneratedColumn<String> defaultSaveDir = GeneratedColumn<String>(
    'default_save_dir',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    parentId,
    defaultSaveDir,
    isDefault,
    iconName,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('default_save_dir')) {
      context.handle(
        _defaultSaveDirMeta,
        defaultSaveDir.isAcceptableOrUnknown(
          data['default_save_dir']!,
          _defaultSaveDirMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultSaveDirMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      defaultSaveDir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_save_dir'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String id;
  final String name;
  final String? parentId;
  final String defaultSaveDir;
  final bool isDefault;
  final String? iconName;
  final int sortOrder;
  const CategoryRow({
    required this.id,
    required this.name,
    this.parentId,
    required this.defaultSaveDir,
    required this.isDefault,
    this.iconName,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['default_save_dir'] = Variable<String>(defaultSaveDir);
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || iconName != null) {
      map['icon_name'] = Variable<String>(iconName);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      defaultSaveDir: Value(defaultSaveDir),
      isDefault: Value(isDefault),
      iconName: iconName == null && nullToAbsent
          ? const Value.absent()
          : Value(iconName),
      sortOrder: Value(sortOrder),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      defaultSaveDir: serializer.fromJson<String>(json['defaultSaveDir']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      iconName: serializer.fromJson<String?>(json['iconName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<String?>(parentId),
      'defaultSaveDir': serializer.toJson<String>(defaultSaveDir),
      'isDefault': serializer.toJson<bool>(isDefault),
      'iconName': serializer.toJson<String?>(iconName),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  CategoryRow copyWith({
    String? id,
    String? name,
    Value<String?> parentId = const Value.absent(),
    String? defaultSaveDir,
    bool? isDefault,
    Value<String?> iconName = const Value.absent(),
    int? sortOrder,
  }) => CategoryRow(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
    defaultSaveDir: defaultSaveDir ?? this.defaultSaveDir,
    isDefault: isDefault ?? this.isDefault,
    iconName: iconName.present ? iconName.value : this.iconName,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      defaultSaveDir: data.defaultSaveDir.present
          ? data.defaultSaveDir.value
          : this.defaultSaveDir,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('defaultSaveDir: $defaultSaveDir, ')
          ..write('isDefault: $isDefault, ')
          ..write('iconName: $iconName, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    parentId,
    defaultSaveDir,
    isDefault,
    iconName,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.defaultSaveDir == this.defaultSaveDir &&
          other.isDefault == this.isDefault &&
          other.iconName == this.iconName &&
          other.sortOrder == this.sortOrder);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> parentId;
  final Value<String> defaultSaveDir;
  final Value<bool> isDefault;
  final Value<String?> iconName;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.defaultSaveDir = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.iconName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    this.parentId = const Value.absent(),
    required String defaultSaveDir,
    this.isDefault = const Value.absent(),
    this.iconName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       defaultSaveDir = Value(defaultSaveDir);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? parentId,
    Expression<String>? defaultSaveDir,
    Expression<bool>? isDefault,
    Expression<String>? iconName,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (defaultSaveDir != null) 'default_save_dir': defaultSaveDir,
      if (isDefault != null) 'is_default': isDefault,
      if (iconName != null) 'icon_name': iconName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? parentId,
    Value<String>? defaultSaveDir,
    Value<bool>? isDefault,
    Value<String?>? iconName,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      defaultSaveDir: defaultSaveDir ?? this.defaultSaveDir,
      isDefault: isDefault ?? this.isDefault,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (defaultSaveDir.present) {
      map['default_save_dir'] = Variable<String>(defaultSaveDir.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('defaultSaveDir: $defaultSaveDir, ')
          ..write('isDefault: $isDefault, ')
          ..write('iconName: $iconName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryExtensionsTable extends CategoryExtensions
    with TableInfo<$CategoryExtensionsTable, CategoryExtensionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryExtensionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _extMeta = const VerificationMeta('ext');
  @override
  late final GeneratedColumn<String> ext = GeneratedColumn<String>(
    'ext',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [categoryId, ext];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_extensions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryExtensionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('ext')) {
      context.handle(
        _extMeta,
        ext.isAcceptableOrUnknown(data['ext']!, _extMeta),
      );
    } else if (isInserting) {
      context.missing(_extMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {categoryId, ext};
  @override
  CategoryExtensionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryExtensionRow(
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      ext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ext'],
      )!,
    );
  }

  @override
  $CategoryExtensionsTable createAlias(String alias) {
    return $CategoryExtensionsTable(attachedDatabase, alias);
  }
}

class CategoryExtensionRow extends DataClass
    implements Insertable<CategoryExtensionRow> {
  final String categoryId;
  final String ext;
  const CategoryExtensionRow({required this.categoryId, required this.ext});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category_id'] = Variable<String>(categoryId);
    map['ext'] = Variable<String>(ext);
    return map;
  }

  CategoryExtensionsCompanion toCompanion(bool nullToAbsent) {
    return CategoryExtensionsCompanion(
      categoryId: Value(categoryId),
      ext: Value(ext),
    );
  }

  factory CategoryExtensionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryExtensionRow(
      categoryId: serializer.fromJson<String>(json['categoryId']),
      ext: serializer.fromJson<String>(json['ext']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'categoryId': serializer.toJson<String>(categoryId),
      'ext': serializer.toJson<String>(ext),
    };
  }

  CategoryExtensionRow copyWith({String? categoryId, String? ext}) =>
      CategoryExtensionRow(
        categoryId: categoryId ?? this.categoryId,
        ext: ext ?? this.ext,
      );
  CategoryExtensionRow copyWithCompanion(CategoryExtensionsCompanion data) {
    return CategoryExtensionRow(
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      ext: data.ext.present ? data.ext.value : this.ext,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryExtensionRow(')
          ..write('categoryId: $categoryId, ')
          ..write('ext: $ext')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(categoryId, ext);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryExtensionRow &&
          other.categoryId == this.categoryId &&
          other.ext == this.ext);
}

class CategoryExtensionsCompanion
    extends UpdateCompanion<CategoryExtensionRow> {
  final Value<String> categoryId;
  final Value<String> ext;
  final Value<int> rowid;
  const CategoryExtensionsCompanion({
    this.categoryId = const Value.absent(),
    this.ext = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryExtensionsCompanion.insert({
    required String categoryId,
    required String ext,
    this.rowid = const Value.absent(),
  }) : categoryId = Value(categoryId),
       ext = Value(ext);
  static Insertable<CategoryExtensionRow> custom({
    Expression<String>? categoryId,
    Expression<String>? ext,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (categoryId != null) 'category_id': categoryId,
      if (ext != null) 'ext': ext,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryExtensionsCompanion copyWith({
    Value<String>? categoryId,
    Value<String>? ext,
    Value<int>? rowid,
  }) {
    return CategoryExtensionsCompanion(
      categoryId: categoryId ?? this.categoryId,
      ext: ext ?? this.ext,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (ext.present) {
      map['ext'] = Variable<String>(ext.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryExtensionsCompanion(')
          ..write('categoryId: $categoryId, ')
          ..write('ext: $ext, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategorySitesTable extends CategorySites
    with TableInfo<$CategorySitesTable, CategorySiteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategorySitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _siteMeta = const VerificationMeta('site');
  @override
  late final GeneratedColumn<String> site = GeneratedColumn<String>(
    'site',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [categoryId, site];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_sites';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategorySiteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('site')) {
      context.handle(
        _siteMeta,
        site.isAcceptableOrUnknown(data['site']!, _siteMeta),
      );
    } else if (isInserting) {
      context.missing(_siteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {categoryId, site};
  @override
  CategorySiteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategorySiteRow(
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      site: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}site'],
      )!,
    );
  }

  @override
  $CategorySitesTable createAlias(String alias) {
    return $CategorySitesTable(attachedDatabase, alias);
  }
}

class CategorySiteRow extends DataClass implements Insertable<CategorySiteRow> {
  final String categoryId;
  final String site;
  const CategorySiteRow({required this.categoryId, required this.site});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category_id'] = Variable<String>(categoryId);
    map['site'] = Variable<String>(site);
    return map;
  }

  CategorySitesCompanion toCompanion(bool nullToAbsent) {
    return CategorySitesCompanion(
      categoryId: Value(categoryId),
      site: Value(site),
    );
  }

  factory CategorySiteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategorySiteRow(
      categoryId: serializer.fromJson<String>(json['categoryId']),
      site: serializer.fromJson<String>(json['site']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'categoryId': serializer.toJson<String>(categoryId),
      'site': serializer.toJson<String>(site),
    };
  }

  CategorySiteRow copyWith({String? categoryId, String? site}) =>
      CategorySiteRow(
        categoryId: categoryId ?? this.categoryId,
        site: site ?? this.site,
      );
  CategorySiteRow copyWithCompanion(CategorySitesCompanion data) {
    return CategorySiteRow(
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      site: data.site.present ? data.site.value : this.site,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategorySiteRow(')
          ..write('categoryId: $categoryId, ')
          ..write('site: $site')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(categoryId, site);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategorySiteRow &&
          other.categoryId == this.categoryId &&
          other.site == this.site);
}

class CategorySitesCompanion extends UpdateCompanion<CategorySiteRow> {
  final Value<String> categoryId;
  final Value<String> site;
  final Value<int> rowid;
  const CategorySitesCompanion({
    this.categoryId = const Value.absent(),
    this.site = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategorySitesCompanion.insert({
    required String categoryId,
    required String site,
    this.rowid = const Value.absent(),
  }) : categoryId = Value(categoryId),
       site = Value(site);
  static Insertable<CategorySiteRow> custom({
    Expression<String>? categoryId,
    Expression<String>? site,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (categoryId != null) 'category_id': categoryId,
      if (site != null) 'site': site,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategorySitesCompanion copyWith({
    Value<String>? categoryId,
    Value<String>? site,
    Value<int>? rowid,
  }) {
    return CategorySitesCompanion(
      categoryId: categoryId ?? this.categoryId,
      site: site ?? this.site,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (site.present) {
      map['site'] = Variable<String>(site.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategorySitesCompanion(')
          ..write('categoryId: $categoryId, ')
          ..write('site: $site, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClassificationRulesTable extends ClassificationRules
    with TableInfo<$ClassificationRulesTable, ClassificationRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassificationRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _flavorMeta = const VerificationMeta('flavor');
  @override
  late final GeneratedColumn<String> flavor = GeneratedColumn<String>(
    'flavor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    pattern,
    flavor,
    priority,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'classification_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClassificationRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('flavor')) {
      context.handle(
        _flavorMeta,
        flavor.isAcceptableOrUnknown(data['flavor']!, _flavorMeta),
      );
    } else if (isInserting) {
      context.missing(_flavorMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClassificationRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClassificationRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      )!,
      flavor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flavor'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $ClassificationRulesTable createAlias(String alias) {
    return $ClassificationRulesTable(attachedDatabase, alias);
  }
}

class ClassificationRuleRow extends DataClass
    implements Insertable<ClassificationRuleRow> {
  final String id;
  final String categoryId;
  final String pattern;
  final String flavor;
  final int priority;
  final String source;
  const ClassificationRuleRow({
    required this.id,
    required this.categoryId,
    required this.pattern,
    required this.flavor,
    required this.priority,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['pattern'] = Variable<String>(pattern);
    map['flavor'] = Variable<String>(flavor);
    map['priority'] = Variable<int>(priority);
    map['source'] = Variable<String>(source);
    return map;
  }

  ClassificationRulesCompanion toCompanion(bool nullToAbsent) {
    return ClassificationRulesCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      pattern: Value(pattern),
      flavor: Value(flavor),
      priority: Value(priority),
      source: Value(source),
    );
  }

  factory ClassificationRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClassificationRuleRow(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      pattern: serializer.fromJson<String>(json['pattern']),
      flavor: serializer.fromJson<String>(json['flavor']),
      priority: serializer.fromJson<int>(json['priority']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String>(categoryId),
      'pattern': serializer.toJson<String>(pattern),
      'flavor': serializer.toJson<String>(flavor),
      'priority': serializer.toJson<int>(priority),
      'source': serializer.toJson<String>(source),
    };
  }

  ClassificationRuleRow copyWith({
    String? id,
    String? categoryId,
    String? pattern,
    String? flavor,
    int? priority,
    String? source,
  }) => ClassificationRuleRow(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    pattern: pattern ?? this.pattern,
    flavor: flavor ?? this.flavor,
    priority: priority ?? this.priority,
    source: source ?? this.source,
  );
  ClassificationRuleRow copyWithCompanion(ClassificationRulesCompanion data) {
    return ClassificationRuleRow(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      flavor: data.flavor.present ? data.flavor.value : this.flavor,
      priority: data.priority.present ? data.priority.value : this.priority,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationRuleRow(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('pattern: $pattern, ')
          ..write('flavor: $flavor, ')
          ..write('priority: $priority, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, categoryId, pattern, flavor, priority, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClassificationRuleRow &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.pattern == this.pattern &&
          other.flavor == this.flavor &&
          other.priority == this.priority &&
          other.source == this.source);
}

class ClassificationRulesCompanion
    extends UpdateCompanion<ClassificationRuleRow> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> pattern;
  final Value<String> flavor;
  final Value<int> priority;
  final Value<String> source;
  final Value<int> rowid;
  const ClassificationRulesCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.pattern = const Value.absent(),
    this.flavor = const Value.absent(),
    this.priority = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClassificationRulesCompanion.insert({
    required String id,
    required String categoryId,
    required String pattern,
    required String flavor,
    required int priority,
    required String source,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       categoryId = Value(categoryId),
       pattern = Value(pattern),
       flavor = Value(flavor),
       priority = Value(priority),
       source = Value(source);
  static Insertable<ClassificationRuleRow> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? pattern,
    Expression<String>? flavor,
    Expression<int>? priority,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (pattern != null) 'pattern': pattern,
      if (flavor != null) 'flavor': flavor,
      if (priority != null) 'priority': priority,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClassificationRulesCompanion copyWith({
    Value<String>? id,
    Value<String>? categoryId,
    Value<String>? pattern,
    Value<String>? flavor,
    Value<int>? priority,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return ClassificationRulesCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      pattern: pattern ?? this.pattern,
      flavor: flavor ?? this.flavor,
      priority: priority ?? this.priority,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (flavor.present) {
      map['flavor'] = Variable<String>(flavor.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationRulesCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('pattern: $pattern, ')
          ..write('flavor: $flavor, ')
          ..write('priority: $priority, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ColumnLayoutTable extends ColumnLayout
    with TableInfo<$ColumnLayoutTable, ColumnLayoutRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ColumnLayoutTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _columnIdMeta = const VerificationMeta(
    'columnId',
  );
  @override
  late final GeneratedColumn<String> columnId = GeneratedColumn<String>(
    'column_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visibleMeta = const VerificationMeta(
    'visible',
  );
  @override
  late final GeneratedColumn<bool> visible = GeneratedColumn<bool>(
    'visible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("visible" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [columnId, sortOrder, visible];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'column_layout';
  @override
  VerificationContext validateIntegrity(
    Insertable<ColumnLayoutRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('column_id')) {
      context.handle(
        _columnIdMeta,
        columnId.isAcceptableOrUnknown(data['column_id']!, _columnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_columnIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('visible')) {
      context.handle(
        _visibleMeta,
        visible.isAcceptableOrUnknown(data['visible']!, _visibleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {columnId};
  @override
  ColumnLayoutRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ColumnLayoutRow(
      columnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}column_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      visible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}visible'],
      )!,
    );
  }

  @override
  $ColumnLayoutTable createAlias(String alias) {
    return $ColumnLayoutTable(attachedDatabase, alias);
  }
}

class ColumnLayoutRow extends DataClass implements Insertable<ColumnLayoutRow> {
  final String columnId;
  final int sortOrder;
  final bool visible;
  const ColumnLayoutRow({
    required this.columnId,
    required this.sortOrder,
    required this.visible,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['column_id'] = Variable<String>(columnId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['visible'] = Variable<bool>(visible);
    return map;
  }

  ColumnLayoutCompanion toCompanion(bool nullToAbsent) {
    return ColumnLayoutCompanion(
      columnId: Value(columnId),
      sortOrder: Value(sortOrder),
      visible: Value(visible),
    );
  }

  factory ColumnLayoutRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ColumnLayoutRow(
      columnId: serializer.fromJson<String>(json['columnId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      visible: serializer.fromJson<bool>(json['visible']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'columnId': serializer.toJson<String>(columnId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'visible': serializer.toJson<bool>(visible),
    };
  }

  ColumnLayoutRow copyWith({String? columnId, int? sortOrder, bool? visible}) =>
      ColumnLayoutRow(
        columnId: columnId ?? this.columnId,
        sortOrder: sortOrder ?? this.sortOrder,
        visible: visible ?? this.visible,
      );
  ColumnLayoutRow copyWithCompanion(ColumnLayoutCompanion data) {
    return ColumnLayoutRow(
      columnId: data.columnId.present ? data.columnId.value : this.columnId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      visible: data.visible.present ? data.visible.value : this.visible,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ColumnLayoutRow(')
          ..write('columnId: $columnId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('visible: $visible')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(columnId, sortOrder, visible);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ColumnLayoutRow &&
          other.columnId == this.columnId &&
          other.sortOrder == this.sortOrder &&
          other.visible == this.visible);
}

class ColumnLayoutCompanion extends UpdateCompanion<ColumnLayoutRow> {
  final Value<String> columnId;
  final Value<int> sortOrder;
  final Value<bool> visible;
  final Value<int> rowid;
  const ColumnLayoutCompanion({
    this.columnId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.visible = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ColumnLayoutCompanion.insert({
    required String columnId,
    required int sortOrder,
    this.visible = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : columnId = Value(columnId),
       sortOrder = Value(sortOrder);
  static Insertable<ColumnLayoutRow> custom({
    Expression<String>? columnId,
    Expression<int>? sortOrder,
    Expression<bool>? visible,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (columnId != null) 'column_id': columnId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (visible != null) 'visible': visible,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ColumnLayoutCompanion copyWith({
    Value<String>? columnId,
    Value<int>? sortOrder,
    Value<bool>? visible,
    Value<int>? rowid,
  }) {
    return ColumnLayoutCompanion(
      columnId: columnId ?? this.columnId,
      sortOrder: sortOrder ?? this.sortOrder,
      visible: visible ?? this.visible,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (columnId.present) {
      map['column_id'] = Variable<String>(columnId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (visible.present) {
      map['visible'] = Variable<bool>(visible.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ColumnLayoutCompanion(')
          ..write('columnId: $columnId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('visible: $visible, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BrowserIntegrationSettingsTable extends BrowserIntegrationSettings
    with
        TableInfo<
          $BrowserIntegrationSettingsTable,
          BrowserIntegrationSettingRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrowserIntegrationSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'browser_integration_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<BrowserIntegrationSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  BrowserIntegrationSettingRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BrowserIntegrationSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $BrowserIntegrationSettingsTable createAlias(String alias) {
    return $BrowserIntegrationSettingsTable(attachedDatabase, alias);
  }
}

class BrowserIntegrationSettingRow extends DataClass
    implements Insertable<BrowserIntegrationSettingRow> {
  final String key;
  final String value;
  const BrowserIntegrationSettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  BrowserIntegrationSettingsCompanion toCompanion(bool nullToAbsent) {
    return BrowserIntegrationSettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory BrowserIntegrationSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BrowserIntegrationSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  BrowserIntegrationSettingRow copyWith({String? key, String? value}) =>
      BrowserIntegrationSettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  BrowserIntegrationSettingRow copyWithCompanion(
    BrowserIntegrationSettingsCompanion data,
  ) {
    return BrowserIntegrationSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BrowserIntegrationSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrowserIntegrationSettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class BrowserIntegrationSettingsCompanion
    extends UpdateCompanion<BrowserIntegrationSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const BrowserIntegrationSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BrowserIntegrationSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<BrowserIntegrationSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BrowserIntegrationSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return BrowserIntegrationSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BrowserIntegrationSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $DownloadSettingsTable downloadSettings = $DownloadSettingsTable(
    this,
  );
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $CategoryExtensionsTable categoryExtensions =
      $CategoryExtensionsTable(this);
  late final $CategorySitesTable categorySites = $CategorySitesTable(this);
  late final $ClassificationRulesTable classificationRules =
      $ClassificationRulesTable(this);
  late final $ColumnLayoutTable columnLayout = $ColumnLayoutTable(this);
  late final $BrowserIntegrationSettingsTable browserIntegrationSettings =
      $BrowserIntegrationSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    downloads,
    downloadSettings,
    categories,
    categoryExtensions,
    categorySites,
    classificationRules,
    columnLayout,
    browserIntegrationSettings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('category_extensions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('category_sites', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DownloadsTableCreateCompanionBuilder =
    DownloadsCompanion Function({
      required String gid,
      required String filename,
      Value<int> totalLength,
      Value<int> completedLength,
      required String status,
      Value<int> downloadSpeed,
      Value<String> dir,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<DateTime?> addedAt,
      Value<DateTime?> completedAt,
      Value<String?> sourceUrl,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DownloadsTableUpdateCompanionBuilder =
    DownloadsCompanion Function({
      Value<String> gid,
      Value<String> filename,
      Value<int> totalLength,
      Value<int> completedLength,
      Value<String> status,
      Value<int> downloadSpeed,
      Value<String> dir,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<DateTime?> addedAt,
      Value<DateTime?> completedAt,
      Value<String?> sourceUrl,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalLength => $composableBuilder(
    column: $table.totalLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedLength => $composableBuilder(
    column: $table.completedLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadSpeed => $composableBuilder(
    column: $table.downloadSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dir => $composableBuilder(
    column: $table.dir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalLength => $composableBuilder(
    column: $table.totalLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedLength => $composableBuilder(
    column: $table.completedLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadSpeed => $composableBuilder(
    column: $table.downloadSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dir => $composableBuilder(
    column: $table.dir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get gid =>
      $composableBuilder(column: $table.gid, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<int> get totalLength => $composableBuilder(
    column: $table.totalLength,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedLength => $composableBuilder(
    column: $table.completedLength,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get downloadSpeed => $composableBuilder(
    column: $table.downloadSpeed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dir =>
      $composableBuilder(column: $table.dir, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadsTable,
          DownloadRow,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (
            DownloadRow,
            BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow>,
          ),
          DownloadRow,
          PrefetchHooks Function()
        > {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> gid = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<int> totalLength = const Value.absent(),
                Value<int> completedLength = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> downloadSpeed = const Value.absent(),
                Value<String> dir = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion(
                gid: gid,
                filename: filename,
                totalLength: totalLength,
                completedLength: completedLength,
                status: status,
                downloadSpeed: downloadSpeed,
                dir: dir,
                errorCode: errorCode,
                errorMessage: errorMessage,
                addedAt: addedAt,
                completedAt: completedAt,
                sourceUrl: sourceUrl,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String gid,
                required String filename,
                Value<int> totalLength = const Value.absent(),
                Value<int> completedLength = const Value.absent(),
                required String status,
                Value<int> downloadSpeed = const Value.absent(),
                Value<String> dir = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion.insert(
                gid: gid,
                filename: filename,
                totalLength: totalLength,
                completedLength: completedLength,
                status: status,
                downloadSpeed: downloadSpeed,
                dir: dir,
                errorCode: errorCode,
                errorMessage: errorMessage,
                addedAt: addedAt,
                completedAt: completedAt,
                sourceUrl: sourceUrl,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadsTable,
      DownloadRow,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (
        DownloadRow,
        BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow>,
      ),
      DownloadRow,
      PrefetchHooks Function()
    >;
typedef $$DownloadSettingsTableCreateCompanionBuilder =
    DownloadSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$DownloadSettingsTableUpdateCompanionBuilder =
    DownloadSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$DownloadSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadSettingsTable> {
  $$DownloadSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadSettingsTable> {
  $$DownloadSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadSettingsTable> {
  $$DownloadSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$DownloadSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadSettingsTable,
          DownloadSettingRow,
          $$DownloadSettingsTableFilterComposer,
          $$DownloadSettingsTableOrderingComposer,
          $$DownloadSettingsTableAnnotationComposer,
          $$DownloadSettingsTableCreateCompanionBuilder,
          $$DownloadSettingsTableUpdateCompanionBuilder,
          (
            DownloadSettingRow,
            BaseReferences<
              _$AppDatabase,
              $DownloadSettingsTable,
              DownloadSettingRow
            >,
          ),
          DownloadSettingRow,
          PrefetchHooks Function()
        > {
  $$DownloadSettingsTableTableManager(
    _$AppDatabase db,
    $DownloadSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadSettingsCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => DownloadSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadSettingsTable,
      DownloadSettingRow,
      $$DownloadSettingsTableFilterComposer,
      $$DownloadSettingsTableOrderingComposer,
      $$DownloadSettingsTableAnnotationComposer,
      $$DownloadSettingsTableCreateCompanionBuilder,
      $$DownloadSettingsTableUpdateCompanionBuilder,
      (
        DownloadSettingRow,
        BaseReferences<
          _$AppDatabase,
          $DownloadSettingsTable,
          DownloadSettingRow
        >,
      ),
      DownloadSettingRow,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      required String name,
      Value<String?> parentId,
      required String defaultSaveDir,
      Value<bool> isDefault,
      Value<String?> iconName,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> parentId,
      Value<String> defaultSaveDir,
      Value<bool> isDefault,
      Value<String?> iconName,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $CategoryExtensionsTable,
    List<CategoryExtensionRow>
  >
  _categoryExtensionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.categoryExtensions,
        aliasName: $_aliasNameGenerator(
          db.categories.id,
          db.categoryExtensions.categoryId,
        ),
      );

  $$CategoryExtensionsTableProcessedTableManager get categoryExtensionsRefs {
    final manager = $$CategoryExtensionsTableTableManager(
      $_db,
      $_db.categoryExtensions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _categoryExtensionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CategorySitesTable, List<CategorySiteRow>>
  _categorySitesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.categorySites,
    aliasName: $_aliasNameGenerator(
      db.categories.id,
      db.categorySites.categoryId,
    ),
  );

  $$CategorySitesTableProcessedTableManager get categorySitesRefs {
    final manager = $$CategorySitesTableTableManager(
      $_db,
      $_db.categorySites,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_categorySitesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultSaveDir => $composableBuilder(
    column: $table.defaultSaveDir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> categoryExtensionsRefs(
    Expression<bool> Function($$CategoryExtensionsTableFilterComposer f) f,
  ) {
    final $$CategoryExtensionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryExtensions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryExtensionsTableFilterComposer(
            $db: $db,
            $table: $db.categoryExtensions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> categorySitesRefs(
    Expression<bool> Function($$CategorySitesTableFilterComposer f) f,
  ) {
    final $$CategorySitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categorySites,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategorySitesTableFilterComposer(
            $db: $db,
            $table: $db.categorySites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultSaveDir => $composableBuilder(
    column: $table.defaultSaveDir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get defaultSaveDir => $composableBuilder(
    column: $table.defaultSaveDir,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> categoryExtensionsRefs<T extends Object>(
    Expression<T> Function($$CategoryExtensionsTableAnnotationComposer a) f,
  ) {
    final $$CategoryExtensionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.categoryExtensions,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CategoryExtensionsTableAnnotationComposer(
                $db: $db,
                $table: $db.categoryExtensions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> categorySitesRefs<T extends Object>(
    Expression<T> Function($$CategorySitesTableAnnotationComposer a) f,
  ) {
    final $$CategorySitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categorySites,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategorySitesTableAnnotationComposer(
            $db: $db,
            $table: $db.categorySites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (CategoryRow, $$CategoriesTableReferences),
          CategoryRow,
          PrefetchHooks Function({
            bool categoryExtensionsRefs,
            bool categorySitesRefs,
          })
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> defaultSaveDir = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<String?> iconName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                parentId: parentId,
                defaultSaveDir: defaultSaveDir,
                isDefault: isDefault,
                iconName: iconName,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> parentId = const Value.absent(),
                required String defaultSaveDir,
                Value<bool> isDefault = const Value.absent(),
                Value<String?> iconName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                parentId: parentId,
                defaultSaveDir: defaultSaveDir,
                isDefault: isDefault,
                iconName: iconName,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({categoryExtensionsRefs = false, categorySitesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (categoryExtensionsRefs) db.categoryExtensions,
                    if (categorySitesRefs) db.categorySites,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (categoryExtensionsRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          CategoryExtensionRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._categoryExtensionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).categoryExtensionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (categorySitesRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          CategorySiteRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._categorySitesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).categorySitesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (CategoryRow, $$CategoriesTableReferences),
      CategoryRow,
      PrefetchHooks Function({
        bool categoryExtensionsRefs,
        bool categorySitesRefs,
      })
    >;
typedef $$CategoryExtensionsTableCreateCompanionBuilder =
    CategoryExtensionsCompanion Function({
      required String categoryId,
      required String ext,
      Value<int> rowid,
    });
typedef $$CategoryExtensionsTableUpdateCompanionBuilder =
    CategoryExtensionsCompanion Function({
      Value<String> categoryId,
      Value<String> ext,
      Value<int> rowid,
    });

final class $$CategoryExtensionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CategoryExtensionsTable,
          CategoryExtensionRow
        > {
  $$CategoryExtensionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(
          db.categoryExtensions.categoryId,
          db.categories.id,
        ),
      );

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CategoryExtensionsTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryExtensionsTable> {
  $$CategoryExtensionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryExtensionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryExtensionsTable> {
  $$CategoryExtensionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryExtensionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryExtensionsTable> {
  $$CategoryExtensionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ext =>
      $composableBuilder(column: $table.ext, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryExtensionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryExtensionsTable,
          CategoryExtensionRow,
          $$CategoryExtensionsTableFilterComposer,
          $$CategoryExtensionsTableOrderingComposer,
          $$CategoryExtensionsTableAnnotationComposer,
          $$CategoryExtensionsTableCreateCompanionBuilder,
          $$CategoryExtensionsTableUpdateCompanionBuilder,
          (CategoryExtensionRow, $$CategoryExtensionsTableReferences),
          CategoryExtensionRow,
          PrefetchHooks Function({bool categoryId})
        > {
  $$CategoryExtensionsTableTableManager(
    _$AppDatabase db,
    $CategoryExtensionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryExtensionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryExtensionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryExtensionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> categoryId = const Value.absent(),
                Value<String> ext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryExtensionsCompanion(
                categoryId: categoryId,
                ext: ext,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String categoryId,
                required String ext,
                Value<int> rowid = const Value.absent(),
              }) => CategoryExtensionsCompanion.insert(
                categoryId: categoryId,
                ext: ext,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoryExtensionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable:
                                    $$CategoryExtensionsTableReferences
                                        ._categoryIdTable(db),
                                referencedColumn:
                                    $$CategoryExtensionsTableReferences
                                        ._categoryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CategoryExtensionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryExtensionsTable,
      CategoryExtensionRow,
      $$CategoryExtensionsTableFilterComposer,
      $$CategoryExtensionsTableOrderingComposer,
      $$CategoryExtensionsTableAnnotationComposer,
      $$CategoryExtensionsTableCreateCompanionBuilder,
      $$CategoryExtensionsTableUpdateCompanionBuilder,
      (CategoryExtensionRow, $$CategoryExtensionsTableReferences),
      CategoryExtensionRow,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$CategorySitesTableCreateCompanionBuilder =
    CategorySitesCompanion Function({
      required String categoryId,
      required String site,
      Value<int> rowid,
    });
typedef $$CategorySitesTableUpdateCompanionBuilder =
    CategorySitesCompanion Function({
      Value<String> categoryId,
      Value<String> site,
      Value<int> rowid,
    });

final class $$CategorySitesTableReferences
    extends
        BaseReferences<_$AppDatabase, $CategorySitesTable, CategorySiteRow> {
  $$CategorySitesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.categorySites.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CategorySitesTableFilterComposer
    extends Composer<_$AppDatabase, $CategorySitesTable> {
  $$CategorySitesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get site => $composableBuilder(
    column: $table.site,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategorySitesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategorySitesTable> {
  $$CategorySitesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get site => $composableBuilder(
    column: $table.site,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategorySitesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategorySitesTable> {
  $$CategorySitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get site =>
      $composableBuilder(column: $table.site, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategorySitesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategorySitesTable,
          CategorySiteRow,
          $$CategorySitesTableFilterComposer,
          $$CategorySitesTableOrderingComposer,
          $$CategorySitesTableAnnotationComposer,
          $$CategorySitesTableCreateCompanionBuilder,
          $$CategorySitesTableUpdateCompanionBuilder,
          (CategorySiteRow, $$CategorySitesTableReferences),
          CategorySiteRow,
          PrefetchHooks Function({bool categoryId})
        > {
  $$CategorySitesTableTableManager(_$AppDatabase db, $CategorySitesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategorySitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategorySitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategorySitesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> categoryId = const Value.absent(),
                Value<String> site = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategorySitesCompanion(
                categoryId: categoryId,
                site: site,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String categoryId,
                required String site,
                Value<int> rowid = const Value.absent(),
              }) => CategorySitesCompanion.insert(
                categoryId: categoryId,
                site: site,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategorySitesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable: $$CategorySitesTableReferences
                                    ._categoryIdTable(db),
                                referencedColumn: $$CategorySitesTableReferences
                                    ._categoryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CategorySitesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategorySitesTable,
      CategorySiteRow,
      $$CategorySitesTableFilterComposer,
      $$CategorySitesTableOrderingComposer,
      $$CategorySitesTableAnnotationComposer,
      $$CategorySitesTableCreateCompanionBuilder,
      $$CategorySitesTableUpdateCompanionBuilder,
      (CategorySiteRow, $$CategorySitesTableReferences),
      CategorySiteRow,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$ClassificationRulesTableCreateCompanionBuilder =
    ClassificationRulesCompanion Function({
      required String id,
      required String categoryId,
      required String pattern,
      required String flavor,
      required int priority,
      required String source,
      Value<int> rowid,
    });
typedef $$ClassificationRulesTableUpdateCompanionBuilder =
    ClassificationRulesCompanion Function({
      Value<String> id,
      Value<String> categoryId,
      Value<String> pattern,
      Value<String> flavor,
      Value<int> priority,
      Value<String> source,
      Value<int> rowid,
    });

class $$ClassificationRulesTableFilterComposer
    extends Composer<_$AppDatabase, $ClassificationRulesTable> {
  $$ClassificationRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flavor => $composableBuilder(
    column: $table.flavor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClassificationRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClassificationRulesTable> {
  $$ClassificationRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flavor => $composableBuilder(
    column: $table.flavor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClassificationRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClassificationRulesTable> {
  $$ClassificationRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get flavor =>
      $composableBuilder(column: $table.flavor, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$ClassificationRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClassificationRulesTable,
          ClassificationRuleRow,
          $$ClassificationRulesTableFilterComposer,
          $$ClassificationRulesTableOrderingComposer,
          $$ClassificationRulesTableAnnotationComposer,
          $$ClassificationRulesTableCreateCompanionBuilder,
          $$ClassificationRulesTableUpdateCompanionBuilder,
          (
            ClassificationRuleRow,
            BaseReferences<
              _$AppDatabase,
              $ClassificationRulesTable,
              ClassificationRuleRow
            >,
          ),
          ClassificationRuleRow,
          PrefetchHooks Function()
        > {
  $$ClassificationRulesTableTableManager(
    _$AppDatabase db,
    $ClassificationRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassificationRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClassificationRulesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ClassificationRulesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> pattern = const Value.absent(),
                Value<String> flavor = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClassificationRulesCompanion(
                id: id,
                categoryId: categoryId,
                pattern: pattern,
                flavor: flavor,
                priority: priority,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String categoryId,
                required String pattern,
                required String flavor,
                required int priority,
                required String source,
                Value<int> rowid = const Value.absent(),
              }) => ClassificationRulesCompanion.insert(
                id: id,
                categoryId: categoryId,
                pattern: pattern,
                flavor: flavor,
                priority: priority,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClassificationRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClassificationRulesTable,
      ClassificationRuleRow,
      $$ClassificationRulesTableFilterComposer,
      $$ClassificationRulesTableOrderingComposer,
      $$ClassificationRulesTableAnnotationComposer,
      $$ClassificationRulesTableCreateCompanionBuilder,
      $$ClassificationRulesTableUpdateCompanionBuilder,
      (
        ClassificationRuleRow,
        BaseReferences<
          _$AppDatabase,
          $ClassificationRulesTable,
          ClassificationRuleRow
        >,
      ),
      ClassificationRuleRow,
      PrefetchHooks Function()
    >;
typedef $$ColumnLayoutTableCreateCompanionBuilder =
    ColumnLayoutCompanion Function({
      required String columnId,
      required int sortOrder,
      Value<bool> visible,
      Value<int> rowid,
    });
typedef $$ColumnLayoutTableUpdateCompanionBuilder =
    ColumnLayoutCompanion Function({
      Value<String> columnId,
      Value<int> sortOrder,
      Value<bool> visible,
      Value<int> rowid,
    });

class $$ColumnLayoutTableFilterComposer
    extends Composer<_$AppDatabase, $ColumnLayoutTable> {
  $$ColumnLayoutTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get columnId => $composableBuilder(
    column: $table.columnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get visible => $composableBuilder(
    column: $table.visible,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ColumnLayoutTableOrderingComposer
    extends Composer<_$AppDatabase, $ColumnLayoutTable> {
  $$ColumnLayoutTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get columnId => $composableBuilder(
    column: $table.columnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get visible => $composableBuilder(
    column: $table.visible,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ColumnLayoutTableAnnotationComposer
    extends Composer<_$AppDatabase, $ColumnLayoutTable> {
  $$ColumnLayoutTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get columnId =>
      $composableBuilder(column: $table.columnId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get visible =>
      $composableBuilder(column: $table.visible, builder: (column) => column);
}

class $$ColumnLayoutTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ColumnLayoutTable,
          ColumnLayoutRow,
          $$ColumnLayoutTableFilterComposer,
          $$ColumnLayoutTableOrderingComposer,
          $$ColumnLayoutTableAnnotationComposer,
          $$ColumnLayoutTableCreateCompanionBuilder,
          $$ColumnLayoutTableUpdateCompanionBuilder,
          (
            ColumnLayoutRow,
            BaseReferences<_$AppDatabase, $ColumnLayoutTable, ColumnLayoutRow>,
          ),
          ColumnLayoutRow,
          PrefetchHooks Function()
        > {
  $$ColumnLayoutTableTableManager(_$AppDatabase db, $ColumnLayoutTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ColumnLayoutTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ColumnLayoutTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ColumnLayoutTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> columnId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> visible = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ColumnLayoutCompanion(
                columnId: columnId,
                sortOrder: sortOrder,
                visible: visible,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String columnId,
                required int sortOrder,
                Value<bool> visible = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ColumnLayoutCompanion.insert(
                columnId: columnId,
                sortOrder: sortOrder,
                visible: visible,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ColumnLayoutTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ColumnLayoutTable,
      ColumnLayoutRow,
      $$ColumnLayoutTableFilterComposer,
      $$ColumnLayoutTableOrderingComposer,
      $$ColumnLayoutTableAnnotationComposer,
      $$ColumnLayoutTableCreateCompanionBuilder,
      $$ColumnLayoutTableUpdateCompanionBuilder,
      (
        ColumnLayoutRow,
        BaseReferences<_$AppDatabase, $ColumnLayoutTable, ColumnLayoutRow>,
      ),
      ColumnLayoutRow,
      PrefetchHooks Function()
    >;
typedef $$BrowserIntegrationSettingsTableCreateCompanionBuilder =
    BrowserIntegrationSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$BrowserIntegrationSettingsTableUpdateCompanionBuilder =
    BrowserIntegrationSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$BrowserIntegrationSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $BrowserIntegrationSettingsTable> {
  $$BrowserIntegrationSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BrowserIntegrationSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BrowserIntegrationSettingsTable> {
  $$BrowserIntegrationSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BrowserIntegrationSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrowserIntegrationSettingsTable> {
  $$BrowserIntegrationSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$BrowserIntegrationSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BrowserIntegrationSettingsTable,
          BrowserIntegrationSettingRow,
          $$BrowserIntegrationSettingsTableFilterComposer,
          $$BrowserIntegrationSettingsTableOrderingComposer,
          $$BrowserIntegrationSettingsTableAnnotationComposer,
          $$BrowserIntegrationSettingsTableCreateCompanionBuilder,
          $$BrowserIntegrationSettingsTableUpdateCompanionBuilder,
          (
            BrowserIntegrationSettingRow,
            BaseReferences<
              _$AppDatabase,
              $BrowserIntegrationSettingsTable,
              BrowserIntegrationSettingRow
            >,
          ),
          BrowserIntegrationSettingRow,
          PrefetchHooks Function()
        > {
  $$BrowserIntegrationSettingsTableTableManager(
    _$AppDatabase db,
    $BrowserIntegrationSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrowserIntegrationSettingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$BrowserIntegrationSettingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BrowserIntegrationSettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BrowserIntegrationSettingsCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => BrowserIntegrationSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BrowserIntegrationSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BrowserIntegrationSettingsTable,
      BrowserIntegrationSettingRow,
      $$BrowserIntegrationSettingsTableFilterComposer,
      $$BrowserIntegrationSettingsTableOrderingComposer,
      $$BrowserIntegrationSettingsTableAnnotationComposer,
      $$BrowserIntegrationSettingsTableCreateCompanionBuilder,
      $$BrowserIntegrationSettingsTableUpdateCompanionBuilder,
      (
        BrowserIntegrationSettingRow,
        BaseReferences<
          _$AppDatabase,
          $BrowserIntegrationSettingsTable,
          BrowserIntegrationSettingRow
        >,
      ),
      BrowserIntegrationSettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$DownloadSettingsTableTableManager get downloadSettings =>
      $$DownloadSettingsTableTableManager(_db, _db.downloadSettings);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$CategoryExtensionsTableTableManager get categoryExtensions =>
      $$CategoryExtensionsTableTableManager(_db, _db.categoryExtensions);
  $$CategorySitesTableTableManager get categorySites =>
      $$CategorySitesTableTableManager(_db, _db.categorySites);
  $$ClassificationRulesTableTableManager get classificationRules =>
      $$ClassificationRulesTableTableManager(_db, _db.classificationRules);
  $$ColumnLayoutTableTableManager get columnLayout =>
      $$ColumnLayoutTableTableManager(_db, _db.columnLayout);
  $$BrowserIntegrationSettingsTableTableManager
  get browserIntegrationSettings =>
      $$BrowserIntegrationSettingsTableTableManager(
        _db,
        _db.browserIntegrationSettings,
      );
}

mixin _$DownloadsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DownloadsTable get downloads => attachedDatabase.downloads;
  DownloadsDaoManager get managers => DownloadsDaoManager(this);
}

class DownloadsDaoManager {
  final _$DownloadsDaoMixin _db;
  DownloadsDaoManager(this._db);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db.attachedDatabase, _db.downloads);
}

mixin _$DownloadSettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DownloadSettingsTable get downloadSettings =>
      attachedDatabase.downloadSettings;
  DownloadSettingsDaoManager get managers => DownloadSettingsDaoManager(this);
}

class DownloadSettingsDaoManager {
  final _$DownloadSettingsDaoMixin _db;
  DownloadSettingsDaoManager(this._db);
  $$DownloadSettingsTableTableManager get downloadSettings =>
      $$DownloadSettingsTableTableManager(
        _db.attachedDatabase,
        _db.downloadSettings,
      );
}

mixin _$CategoriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $CategoryExtensionsTable get categoryExtensions =>
      attachedDatabase.categoryExtensions;
  $CategorySitesTable get categorySites => attachedDatabase.categorySites;
  $ClassificationRulesTable get classificationRules =>
      attachedDatabase.classificationRules;
  CategoriesDaoManager get managers => CategoriesDaoManager(this);
}

class CategoriesDaoManager {
  final _$CategoriesDaoMixin _db;
  CategoriesDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$CategoryExtensionsTableTableManager get categoryExtensions =>
      $$CategoryExtensionsTableTableManager(
        _db.attachedDatabase,
        _db.categoryExtensions,
      );
  $$CategorySitesTableTableManager get categorySites =>
      $$CategorySitesTableTableManager(_db.attachedDatabase, _db.categorySites);
  $$ClassificationRulesTableTableManager get classificationRules =>
      $$ClassificationRulesTableTableManager(
        _db.attachedDatabase,
        _db.classificationRules,
      );
}

mixin _$ColumnsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ColumnLayoutTable get columnLayout => attachedDatabase.columnLayout;
  ColumnsDaoManager get managers => ColumnsDaoManager(this);
}

class ColumnsDaoManager {
  final _$ColumnsDaoMixin _db;
  ColumnsDaoManager(this._db);
  $$ColumnLayoutTableTableManager get columnLayout =>
      $$ColumnLayoutTableTableManager(_db.attachedDatabase, _db.columnLayout);
}

mixin _$BrowserIntegrationDaoMixin on DatabaseAccessor<AppDatabase> {
  $BrowserIntegrationSettingsTable get browserIntegrationSettings =>
      attachedDatabase.browserIntegrationSettings;
  BrowserIntegrationDaoManager get managers =>
      BrowserIntegrationDaoManager(this);
}

class BrowserIntegrationDaoManager {
  final _$BrowserIntegrationDaoMixin _db;
  BrowserIntegrationDaoManager(this._db);
  $$BrowserIntegrationSettingsTableTableManager
  get browserIntegrationSettings =>
      $$BrowserIntegrationSettingsTableTableManager(
        _db.attachedDatabase,
        _db.browserIntegrationSettings,
      );
}
