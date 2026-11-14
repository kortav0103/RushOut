// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, BookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _genresJsonMeta =
      const VerificationMeta('genresJson');
  @override
  late final GeneratedColumn<String> genresJson = GeneratedColumn<String>(
      'genres_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _remoteCoverUrlMeta =
      const VerificationMeta('remoteCoverUrl');
  @override
  late final GeneratedColumn<String> remoteCoverUrl = GeneratedColumn<String>(
      'remote_cover_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _localCoverPathMeta =
      const VerificationMeta('localCoverPath');
  @override
  late final GeneratedColumn<String> localCoverPath = GeneratedColumn<String>(
      'local_cover_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _remoteEpubUrlMeta =
      const VerificationMeta('remoteEpubUrl');
  @override
  late final GeneratedColumn<String> remoteEpubUrl = GeneratedColumn<String>(
      'remote_epub_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _localFilePathMeta =
      const VerificationMeta('localFilePath');
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
      'local_file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceTypeMeta =
      const VerificationMeta('sourceType');
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
      'source_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('discover'));
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
      'format', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('epub'));
  static const VerificationMeta _wordCountMeta =
      const VerificationMeta('wordCount');
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
      'word_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _fileSizeBytesMeta =
      const VerificationMeta('fileSizeBytes');
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
      'file_size_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sha256ChecksumMeta =
      const VerificationMeta('sha256Checksum');
  @override
  late final GeneratedColumn<String> sha256Checksum = GeneratedColumn<String>(
      'sha256_checksum', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isTtsSupportedMeta =
      const VerificationMeta('isTtsSupported');
  @override
  late final GeneratedColumn<bool> isTtsSupported = GeneratedColumn<bool>(
      'is_tts_supported', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_tts_supported" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _isDownloadedMeta =
      const VerificationMeta('isDownloaded');
  @override
  late final GeneratedColumn<bool> isDownloaded = GeneratedColumn<bool>(
      'is_downloaded', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_downloaded" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        author,
        description,
        genresJson,
        remoteCoverUrl,
        localCoverPath,
        remoteEpubUrl,
        localFilePath,
        sourceType,
        format,
        wordCount,
        fileSizeBytes,
        sha256Checksum,
        isTtsSupported,
        isDownloaded,
        isFavorite,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(Insertable<BookRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('genres_json')) {
      context.handle(
          _genresJsonMeta,
          genresJson.isAcceptableOrUnknown(
              data['genres_json']!, _genresJsonMeta));
    }
    if (data.containsKey('remote_cover_url')) {
      context.handle(
          _remoteCoverUrlMeta,
          remoteCoverUrl.isAcceptableOrUnknown(
              data['remote_cover_url']!, _remoteCoverUrlMeta));
    }
    if (data.containsKey('local_cover_path')) {
      context.handle(
          _localCoverPathMeta,
          localCoverPath.isAcceptableOrUnknown(
              data['local_cover_path']!, _localCoverPathMeta));
    }
    if (data.containsKey('remote_epub_url')) {
      context.handle(
          _remoteEpubUrlMeta,
          remoteEpubUrl.isAcceptableOrUnknown(
              data['remote_epub_url']!, _remoteEpubUrlMeta));
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
          _localFilePathMeta,
          localFilePath.isAcceptableOrUnknown(
              data['local_file_path']!, _localFilePathMeta));
    }
    if (data.containsKey('source_type')) {
      context.handle(
          _sourceTypeMeta,
          sourceType.isAcceptableOrUnknown(
              data['source_type']!, _sourceTypeMeta));
    }
    if (data.containsKey('format')) {
      context.handle(_formatMeta,
          format.isAcceptableOrUnknown(data['format']!, _formatMeta));
    }
    if (data.containsKey('word_count')) {
      context.handle(_wordCountMeta,
          wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta));
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
          _fileSizeBytesMeta,
          fileSizeBytes.isAcceptableOrUnknown(
              data['file_size_bytes']!, _fileSizeBytesMeta));
    }
    if (data.containsKey('sha256_checksum')) {
      context.handle(
          _sha256ChecksumMeta,
          sha256Checksum.isAcceptableOrUnknown(
              data['sha256_checksum']!, _sha256ChecksumMeta));
    }
    if (data.containsKey('is_tts_supported')) {
      context.handle(
          _isTtsSupportedMeta,
          isTtsSupported.isAcceptableOrUnknown(
              data['is_tts_supported']!, _isTtsSupportedMeta));
    }
    if (data.containsKey('is_downloaded')) {
      context.handle(
          _isDownloadedMeta,
          isDownloaded.isAcceptableOrUnknown(
              data['is_downloaded']!, _isDownloadedMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      genresJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genres_json'])!,
      remoteCoverUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}remote_cover_url']),
      localCoverPath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_cover_path']),
      remoteEpubUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_epub_url']),
      localFilePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_file_path']),
      sourceType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_type'])!,
      format: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}format'])!,
      wordCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}word_count'])!,
      fileSizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size_bytes'])!,
      sha256Checksum: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sha256_checksum']),
      isTtsSupported: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_tts_supported'])!,
      isDownloaded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_downloaded'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class BookRow extends DataClass implements Insertable<BookRow> {
  final String id;
  final String title;
  final String author;
  final String description;
  final String genresJson;
  final String? remoteCoverUrl;
  final String? localCoverPath;
  final String? remoteEpubUrl;
  final String? localFilePath;
  final String sourceType;
  final String format;
  final int wordCount;
  final int fileSizeBytes;
  final String? sha256Checksum;
  final bool isTtsSupported;
  final bool isDownloaded;
  final bool isFavorite;
  final DateTime createdAt;
  const BookRow(
      {required this.id,
      required this.title,
      required this.author,
      required this.description,
      required this.genresJson,
      this.remoteCoverUrl,
      this.localCoverPath,
      this.remoteEpubUrl,
      this.localFilePath,
      required this.sourceType,
      required this.format,
      required this.wordCount,
      required this.fileSizeBytes,
      this.sha256Checksum,
      required this.isTtsSupported,
      required this.isDownloaded,
      required this.isFavorite,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['description'] = Variable<String>(description);
    map['genres_json'] = Variable<String>(genresJson);
    if (!nullToAbsent || remoteCoverUrl != null) {
      map['remote_cover_url'] = Variable<String>(remoteCoverUrl);
    }
    if (!nullToAbsent || localCoverPath != null) {
      map['local_cover_path'] = Variable<String>(localCoverPath);
    }
    if (!nullToAbsent || remoteEpubUrl != null) {
      map['remote_epub_url'] = Variable<String>(remoteEpubUrl);
    }
    if (!nullToAbsent || localFilePath != null) {
      map['local_file_path'] = Variable<String>(localFilePath);
    }
    map['source_type'] = Variable<String>(sourceType);
    map['format'] = Variable<String>(format);
    map['word_count'] = Variable<int>(wordCount);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    if (!nullToAbsent || sha256Checksum != null) {
      map['sha256_checksum'] = Variable<String>(sha256Checksum);
    }
    map['is_tts_supported'] = Variable<bool>(isTtsSupported);
    map['is_downloaded'] = Variable<bool>(isDownloaded);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      author: Value(author),
      description: Value(description),
      genresJson: Value(genresJson),
      remoteCoverUrl: remoteCoverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteCoverUrl),
      localCoverPath: localCoverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localCoverPath),
      remoteEpubUrl: remoteEpubUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteEpubUrl),
      localFilePath: localFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localFilePath),
      sourceType: Value(sourceType),
      format: Value(format),
      wordCount: Value(wordCount),
      fileSizeBytes: Value(fileSizeBytes),
      sha256Checksum: sha256Checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256Checksum),
      isTtsSupported: Value(isTtsSupported),
      isDownloaded: Value(isDownloaded),
      isFavorite: Value(isFavorite),
      createdAt: Value(createdAt),
    );
  }

  factory BookRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      description: serializer.fromJson<String>(json['description']),
      genresJson: serializer.fromJson<String>(json['genresJson']),
      remoteCoverUrl: serializer.fromJson<String?>(json['remoteCoverUrl']),
      localCoverPath: serializer.fromJson<String?>(json['localCoverPath']),
      remoteEpubUrl: serializer.fromJson<String?>(json['remoteEpubUrl']),
      localFilePath: serializer.fromJson<String?>(json['localFilePath']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      format: serializer.fromJson<String>(json['format']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      sha256Checksum: serializer.fromJson<String?>(json['sha256Checksum']),
      isTtsSupported: serializer.fromJson<bool>(json['isTtsSupported']),
      isDownloaded: serializer.fromJson<bool>(json['isDownloaded']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'description': serializer.toJson<String>(description),
      'genresJson': serializer.toJson<String>(genresJson),
      'remoteCoverUrl': serializer.toJson<String?>(remoteCoverUrl),
      'localCoverPath': serializer.toJson<String?>(localCoverPath),
      'remoteEpubUrl': serializer.toJson<String?>(remoteEpubUrl),
      'localFilePath': serializer.toJson<String?>(localFilePath),
      'sourceType': serializer.toJson<String>(sourceType),
      'format': serializer.toJson<String>(format),
      'wordCount': serializer.toJson<int>(wordCount),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'sha256Checksum': serializer.toJson<String?>(sha256Checksum),
      'isTtsSupported': serializer.toJson<bool>(isTtsSupported),
      'isDownloaded': serializer.toJson<bool>(isDownloaded),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BookRow copyWith(
          {String? id,
          String? title,
          String? author,
          String? description,
          String? genresJson,
          Value<String?> remoteCoverUrl = const Value.absent(),
          Value<String?> localCoverPath = const Value.absent(),
          Value<String?> remoteEpubUrl = const Value.absent(),
          Value<String?> localFilePath = const Value.absent(),
          String? sourceType,
          String? format,
          int? wordCount,
          int? fileSizeBytes,
          Value<String?> sha256Checksum = const Value.absent(),
          bool? isTtsSupported,
          bool? isDownloaded,
          bool? isFavorite,
          DateTime? createdAt}) =>
      BookRow(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        description: description ?? this.description,
        genresJson: genresJson ?? this.genresJson,
        remoteCoverUrl:
            remoteCoverUrl.present ? remoteCoverUrl.value : this.remoteCoverUrl,
        localCoverPath:
            localCoverPath.present ? localCoverPath.value : this.localCoverPath,
        remoteEpubUrl:
            remoteEpubUrl.present ? remoteEpubUrl.value : this.remoteEpubUrl,
        localFilePath:
            localFilePath.present ? localFilePath.value : this.localFilePath,
        sourceType: sourceType ?? this.sourceType,
        format: format ?? this.format,
        wordCount: wordCount ?? this.wordCount,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        sha256Checksum:
            sha256Checksum.present ? sha256Checksum.value : this.sha256Checksum,
        isTtsSupported: isTtsSupported ?? this.isTtsSupported,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt ?? this.createdAt,
      );
  BookRow copyWithCompanion(BooksCompanion data) {
    return BookRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      description:
          data.description.present ? data.description.value : this.description,
      genresJson:
          data.genresJson.present ? data.genresJson.value : this.genresJson,
      remoteCoverUrl: data.remoteCoverUrl.present
          ? data.remoteCoverUrl.value
          : this.remoteCoverUrl,
      localCoverPath: data.localCoverPath.present
          ? data.localCoverPath.value
          : this.localCoverPath,
      remoteEpubUrl: data.remoteEpubUrl.present
          ? data.remoteEpubUrl.value
          : this.remoteEpubUrl,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      sourceType:
          data.sourceType.present ? data.sourceType.value : this.sourceType,
      format: data.format.present ? data.format.value : this.format,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      sha256Checksum: data.sha256Checksum.present
          ? data.sha256Checksum.value
          : this.sha256Checksum,
      isTtsSupported: data.isTtsSupported.present
          ? data.isTtsSupported.value
          : this.isTtsSupported,
      isDownloaded: data.isDownloaded.present
          ? data.isDownloaded.value
          : this.isDownloaded,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('genresJson: $genresJson, ')
          ..write('remoteCoverUrl: $remoteCoverUrl, ')
          ..write('localCoverPath: $localCoverPath, ')
          ..write('remoteEpubUrl: $remoteEpubUrl, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('sourceType: $sourceType, ')
          ..write('format: $format, ')
          ..write('wordCount: $wordCount, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('sha256Checksum: $sha256Checksum, ')
          ..write('isTtsSupported: $isTtsSupported, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      author,
      description,
      genresJson,
      remoteCoverUrl,
      localCoverPath,
      remoteEpubUrl,
      localFilePath,
      sourceType,
      format,
      wordCount,
      fileSizeBytes,
      sha256Checksum,
      isTtsSupported,
      isDownloaded,
      isFavorite,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.description == this.description &&
          other.genresJson == this.genresJson &&
          other.remoteCoverUrl == this.remoteCoverUrl &&
          other.localCoverPath == this.localCoverPath &&
          other.remoteEpubUrl == this.remoteEpubUrl &&
          other.localFilePath == this.localFilePath &&
          other.sourceType == this.sourceType &&
          other.format == this.format &&
          other.wordCount == this.wordCount &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.sha256Checksum == this.sha256Checksum &&
          other.isTtsSupported == this.isTtsSupported &&
          other.isDownloaded == this.isDownloaded &&
          other.isFavorite == this.isFavorite &&
          other.createdAt == this.createdAt);
}

class BooksCompanion extends UpdateCompanion<BookRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> author;
  final Value<String> description;
  final Value<String> genresJson;
  final Value<String?> remoteCoverUrl;
  final Value<String?> localCoverPath;
  final Value<String?> remoteEpubUrl;
  final Value<String?> localFilePath;
  final Value<String> sourceType;
  final Value<String> format;
  final Value<int> wordCount;
  final Value<int> fileSizeBytes;
  final Value<String?> sha256Checksum;
  final Value<bool> isTtsSupported;
  final Value<bool> isDownloaded;
  final Value<bool> isFavorite;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.remoteCoverUrl = const Value.absent(),
    this.localCoverPath = const Value.absent(),
    this.remoteEpubUrl = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.format = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.sha256Checksum = const Value.absent(),
    this.isTtsSupported = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String title,
    required String author,
    this.description = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.remoteCoverUrl = const Value.absent(),
    this.localCoverPath = const Value.absent(),
    this.remoteEpubUrl = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.format = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.sha256Checksum = const Value.absent(),
    this.isTtsSupported = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        author = Value(author);
  static Insertable<BookRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? description,
    Expression<String>? genresJson,
    Expression<String>? remoteCoverUrl,
    Expression<String>? localCoverPath,
    Expression<String>? remoteEpubUrl,
    Expression<String>? localFilePath,
    Expression<String>? sourceType,
    Expression<String>? format,
    Expression<int>? wordCount,
    Expression<int>? fileSizeBytes,
    Expression<String>? sha256Checksum,
    Expression<bool>? isTtsSupported,
    Expression<bool>? isDownloaded,
    Expression<bool>? isFavorite,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (genresJson != null) 'genres_json': genresJson,
      if (remoteCoverUrl != null) 'remote_cover_url': remoteCoverUrl,
      if (localCoverPath != null) 'local_cover_path': localCoverPath,
      if (remoteEpubUrl != null) 'remote_epub_url': remoteEpubUrl,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (sourceType != null) 'source_type': sourceType,
      if (format != null) 'format': format,
      if (wordCount != null) 'word_count': wordCount,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (sha256Checksum != null) 'sha256_checksum': sha256Checksum,
      if (isTtsSupported != null) 'is_tts_supported': isTtsSupported,
      if (isDownloaded != null) 'is_downloaded': isDownloaded,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? author,
      Value<String>? description,
      Value<String>? genresJson,
      Value<String?>? remoteCoverUrl,
      Value<String?>? localCoverPath,
      Value<String?>? remoteEpubUrl,
      Value<String?>? localFilePath,
      Value<String>? sourceType,
      Value<String>? format,
      Value<int>? wordCount,
      Value<int>? fileSizeBytes,
      Value<String?>? sha256Checksum,
      Value<bool>? isTtsSupported,
      Value<bool>? isDownloaded,
      Value<bool>? isFavorite,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      genresJson: genresJson ?? this.genresJson,
      remoteCoverUrl: remoteCoverUrl ?? this.remoteCoverUrl,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      remoteEpubUrl: remoteEpubUrl ?? this.remoteEpubUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      sourceType: sourceType ?? this.sourceType,
      format: format ?? this.format,
      wordCount: wordCount ?? this.wordCount,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      sha256Checksum: sha256Checksum ?? this.sha256Checksum,
      isTtsSupported: isTtsSupported ?? this.isTtsSupported,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (genresJson.present) {
      map['genres_json'] = Variable<String>(genresJson.value);
    }
    if (remoteCoverUrl.present) {
      map['remote_cover_url'] = Variable<String>(remoteCoverUrl.value);
    }
    if (localCoverPath.present) {
      map['local_cover_path'] = Variable<String>(localCoverPath.value);
    }
    if (remoteEpubUrl.present) {
      map['remote_epub_url'] = Variable<String>(remoteEpubUrl.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (sha256Checksum.present) {
      map['sha256_checksum'] = Variable<String>(sha256Checksum.value);
    }
    if (isTtsSupported.present) {
      map['is_tts_supported'] = Variable<bool>(isTtsSupported.value);
    }
    if (isDownloaded.present) {
      map['is_downloaded'] = Variable<bool>(isDownloaded.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('genresJson: $genresJson, ')
          ..write('remoteCoverUrl: $remoteCoverUrl, ')
          ..write('localCoverPath: $localCoverPath, ')
          ..write('remoteEpubUrl: $remoteEpubUrl, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('sourceType: $sourceType, ')
          ..write('format: $format, ')
          ..write('wordCount: $wordCount, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('sha256Checksum: $sha256Checksum, ')
          ..write('isTtsSupported: $isTtsSupported, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressesTable extends ReadingProgresses
    with TableInfo<$ReadingProgressesTable, ReadingProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterIndexMeta =
      const VerificationMeta('chapterIndex');
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
      'chapter_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sentenceIndexMeta =
      const VerificationMeta('sentenceIndex');
  @override
  late final GeneratedColumn<int> sentenceIndex = GeneratedColumn<int>(
      'sentence_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _scrollOffsetMeta =
      const VerificationMeta('scrollOffset');
  @override
  late final GeneratedColumn<double> scrollOffset = GeneratedColumn<double>(
      'scroll_offset', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _progressPercentMeta =
      const VerificationMeta('progressPercent');
  @override
  late final GeneratedColumn<double> progressPercent = GeneratedColumn<double>(
      'progress_percent', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        bookId,
        chapterIndex,
        sentenceIndex,
        scrollOffset,
        progressPercent,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progresses';
  @override
  VerificationContext validateIntegrity(Insertable<ReadingProgressRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
          _chapterIndexMeta,
          chapterIndex.isAcceptableOrUnknown(
              data['chapter_index']!, _chapterIndexMeta));
    }
    if (data.containsKey('sentence_index')) {
      context.handle(
          _sentenceIndexMeta,
          sentenceIndex.isAcceptableOrUnknown(
              data['sentence_index']!, _sentenceIndexMeta));
    }
    if (data.containsKey('scroll_offset')) {
      context.handle(
          _scrollOffsetMeta,
          scrollOffset.isAcceptableOrUnknown(
              data['scroll_offset']!, _scrollOffsetMeta));
    }
    if (data.containsKey('progress_percent')) {
      context.handle(
          _progressPercentMeta,
          progressPercent.isAcceptableOrUnknown(
              data['progress_percent']!, _progressPercentMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  ReadingProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressRow(
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      chapterIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_index'])!,
      sentenceIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sentence_index'])!,
      scrollOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}scroll_offset'])!,
      progressPercent: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}progress_percent'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ReadingProgressesTable createAlias(String alias) {
    return $ReadingProgressesTable(attachedDatabase, alias);
  }
}

class ReadingProgressRow extends DataClass
    implements Insertable<ReadingProgressRow> {
  final String bookId;
  final int chapterIndex;
  final int sentenceIndex;
  final double scrollOffset;
  final double progressPercent;
  final DateTime updatedAt;
  const ReadingProgressRow(
      {required this.bookId,
      required this.chapterIndex,
      required this.sentenceIndex,
      required this.scrollOffset,
      required this.progressPercent,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['sentence_index'] = Variable<int>(sentenceIndex);
    map['scroll_offset'] = Variable<double>(scrollOffset);
    map['progress_percent'] = Variable<double>(progressPercent);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingProgressesCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressesCompanion(
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      sentenceIndex: Value(sentenceIndex),
      scrollOffset: Value(scrollOffset),
      progressPercent: Value(progressPercent),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgressRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressRow(
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      sentenceIndex: serializer.fromJson<int>(json['sentenceIndex']),
      scrollOffset: serializer.fromJson<double>(json['scrollOffset']),
      progressPercent: serializer.fromJson<double>(json['progressPercent']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'sentenceIndex': serializer.toJson<int>(sentenceIndex),
      'scrollOffset': serializer.toJson<double>(scrollOffset),
      'progressPercent': serializer.toJson<double>(progressPercent),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingProgressRow copyWith(
          {String? bookId,
          int? chapterIndex,
          int? sentenceIndex,
          double? scrollOffset,
          double? progressPercent,
          DateTime? updatedAt}) =>
      ReadingProgressRow(
        bookId: bookId ?? this.bookId,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        sentenceIndex: sentenceIndex ?? this.sentenceIndex,
        scrollOffset: scrollOffset ?? this.scrollOffset,
        progressPercent: progressPercent ?? this.progressPercent,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ReadingProgressRow copyWithCompanion(ReadingProgressesCompanion data) {
    return ReadingProgressRow(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      sentenceIndex: data.sentenceIndex.present
          ? data.sentenceIndex.value
          : this.sentenceIndex,
      scrollOffset: data.scrollOffset.present
          ? data.scrollOffset.value
          : this.scrollOffset,
      progressPercent: data.progressPercent.present
          ? data.progressPercent.value
          : this.progressPercent,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressRow(')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('scrollOffset: $scrollOffset, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, chapterIndex, sentenceIndex,
      scrollOffset, progressPercent, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressRow &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.sentenceIndex == this.sentenceIndex &&
          other.scrollOffset == this.scrollOffset &&
          other.progressPercent == this.progressPercent &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressesCompanion extends UpdateCompanion<ReadingProgressRow> {
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<int> sentenceIndex;
  final Value<double> scrollOffset;
  final Value<double> progressPercent;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReadingProgressesCompanion({
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.sentenceIndex = const Value.absent(),
    this.scrollOffset = const Value.absent(),
    this.progressPercent = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressesCompanion.insert({
    required String bookId,
    this.chapterIndex = const Value.absent(),
    this.sentenceIndex = const Value.absent(),
    this.scrollOffset = const Value.absent(),
    this.progressPercent = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId);
  static Insertable<ReadingProgressRow> custom({
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<int>? sentenceIndex,
    Expression<double>? scrollOffset,
    Expression<double>? progressPercent,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (sentenceIndex != null) 'sentence_index': sentenceIndex,
      if (scrollOffset != null) 'scroll_offset': scrollOffset,
      if (progressPercent != null) 'progress_percent': progressPercent,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressesCompanion copyWith(
      {Value<String>? bookId,
      Value<int>? chapterIndex,
      Value<int>? sentenceIndex,
      Value<double>? scrollOffset,
      Value<double>? progressPercent,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ReadingProgressesCompanion(
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      progressPercent: progressPercent ?? this.progressPercent,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (sentenceIndex.present) {
      map['sentence_index'] = Variable<int>(sentenceIndex.value);
    }
    if (scrollOffset.present) {
      map['scroll_offset'] = Variable<double>(scrollOffset.value);
    }
    if (progressPercent.present) {
      map['progress_percent'] = Variable<double>(progressPercent.value);
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
    return (StringBuffer('ReadingProgressesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('scrollOffset: $scrollOffset, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksHighlightsTable extends BookmarksHighlights
    with TableInfo<$BookmarksHighlightsTable, BookmarkHighlightRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksHighlightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterIndexMeta =
      const VerificationMeta('chapterIndex');
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
      'chapter_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sentenceIndexMeta =
      const VerificationMeta('sentenceIndex');
  @override
  late final GeneratedColumn<int> sentenceIndex = GeneratedColumn<int>(
      'sentence_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _charStartMeta =
      const VerificationMeta('charStart');
  @override
  late final GeneratedColumn<int> charStart = GeneratedColumn<int>(
      'char_start', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _charEndMeta =
      const VerificationMeta('charEnd');
  @override
  late final GeneratedColumn<int> charEnd = GeneratedColumn<int>(
      'char_end', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _selectedTextMeta =
      const VerificationMeta('selectedText');
  @override
  late final GeneratedColumn<String> selectedText = GeneratedColumn<String>(
      'selected_text', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _colorHexMeta =
      const VerificationMeta('colorHex');
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
      'color_hex', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#FFE082'));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bookId,
        type,
        chapterIndex,
        sentenceIndex,
        charStart,
        charEnd,
        selectedText,
        colorHex,
        note,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks_highlights';
  @override
  VerificationContext validateIntegrity(
      Insertable<BookmarkHighlightRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
          _chapterIndexMeta,
          chapterIndex.isAcceptableOrUnknown(
              data['chapter_index']!, _chapterIndexMeta));
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('sentence_index')) {
      context.handle(
          _sentenceIndexMeta,
          sentenceIndex.isAcceptableOrUnknown(
              data['sentence_index']!, _sentenceIndexMeta));
    } else if (isInserting) {
      context.missing(_sentenceIndexMeta);
    }
    if (data.containsKey('char_start')) {
      context.handle(_charStartMeta,
          charStart.isAcceptableOrUnknown(data['char_start']!, _charStartMeta));
    }
    if (data.containsKey('char_end')) {
      context.handle(_charEndMeta,
          charEnd.isAcceptableOrUnknown(data['char_end']!, _charEndMeta));
    }
    if (data.containsKey('selected_text')) {
      context.handle(
          _selectedTextMeta,
          selectedText.isAcceptableOrUnknown(
              data['selected_text']!, _selectedTextMeta));
    }
    if (data.containsKey('color_hex')) {
      context.handle(_colorHexMeta,
          colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookmarkHighlightRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkHighlightRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      chapterIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_index'])!,
      sentenceIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sentence_index'])!,
      charStart: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}char_start'])!,
      charEnd: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}char_end'])!,
      selectedText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}selected_text'])!,
      colorHex: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color_hex'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $BookmarksHighlightsTable createAlias(String alias) {
    return $BookmarksHighlightsTable(attachedDatabase, alias);
  }
}

class BookmarkHighlightRow extends DataClass
    implements Insertable<BookmarkHighlightRow> {
  final int id;
  final String bookId;
  final String type;
  final int chapterIndex;
  final int sentenceIndex;
  final int charStart;
  final int charEnd;
  final String selectedText;
  final String colorHex;
  final String note;
  final DateTime createdAt;
  const BookmarkHighlightRow(
      {required this.id,
      required this.bookId,
      required this.type,
      required this.chapterIndex,
      required this.sentenceIndex,
      required this.charStart,
      required this.charEnd,
      required this.selectedText,
      required this.colorHex,
      required this.note,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['type'] = Variable<String>(type);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['sentence_index'] = Variable<int>(sentenceIndex);
    map['char_start'] = Variable<int>(charStart);
    map['char_end'] = Variable<int>(charEnd);
    map['selected_text'] = Variable<String>(selectedText);
    map['color_hex'] = Variable<String>(colorHex);
    map['note'] = Variable<String>(note);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksHighlightsCompanion toCompanion(bool nullToAbsent) {
    return BookmarksHighlightsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      type: Value(type),
      chapterIndex: Value(chapterIndex),
      sentenceIndex: Value(sentenceIndex),
      charStart: Value(charStart),
      charEnd: Value(charEnd),
      selectedText: Value(selectedText),
      colorHex: Value(colorHex),
      note: Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory BookmarkHighlightRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkHighlightRow(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      type: serializer.fromJson<String>(json['type']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      sentenceIndex: serializer.fromJson<int>(json['sentenceIndex']),
      charStart: serializer.fromJson<int>(json['charStart']),
      charEnd: serializer.fromJson<int>(json['charEnd']),
      selectedText: serializer.fromJson<String>(json['selectedText']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      note: serializer.fromJson<String>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'type': serializer.toJson<String>(type),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'sentenceIndex': serializer.toJson<int>(sentenceIndex),
      'charStart': serializer.toJson<int>(charStart),
      'charEnd': serializer.toJson<int>(charEnd),
      'selectedText': serializer.toJson<String>(selectedText),
      'colorHex': serializer.toJson<String>(colorHex),
      'note': serializer.toJson<String>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BookmarkHighlightRow copyWith(
          {int? id,
          String? bookId,
          String? type,
          int? chapterIndex,
          int? sentenceIndex,
          int? charStart,
          int? charEnd,
          String? selectedText,
          String? colorHex,
          String? note,
          DateTime? createdAt}) =>
      BookmarkHighlightRow(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        type: type ?? this.type,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        sentenceIndex: sentenceIndex ?? this.sentenceIndex,
        charStart: charStart ?? this.charStart,
        charEnd: charEnd ?? this.charEnd,
        selectedText: selectedText ?? this.selectedText,
        colorHex: colorHex ?? this.colorHex,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );
  BookmarkHighlightRow copyWithCompanion(BookmarksHighlightsCompanion data) {
    return BookmarkHighlightRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      type: data.type.present ? data.type.value : this.type,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      sentenceIndex: data.sentenceIndex.present
          ? data.sentenceIndex.value
          : this.sentenceIndex,
      charStart: data.charStart.present ? data.charStart.value : this.charStart,
      charEnd: data.charEnd.present ? data.charEnd.value : this.charEnd,
      selectedText: data.selectedText.present
          ? data.selectedText.value
          : this.selectedText,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkHighlightRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('type: $type, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('charStart: $charStart, ')
          ..write('charEnd: $charEnd, ')
          ..write('selectedText: $selectedText, ')
          ..write('colorHex: $colorHex, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, type, chapterIndex, sentenceIndex,
      charStart, charEnd, selectedText, colorHex, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkHighlightRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.type == this.type &&
          other.chapterIndex == this.chapterIndex &&
          other.sentenceIndex == this.sentenceIndex &&
          other.charStart == this.charStart &&
          other.charEnd == this.charEnd &&
          other.selectedText == this.selectedText &&
          other.colorHex == this.colorHex &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class BookmarksHighlightsCompanion
    extends UpdateCompanion<BookmarkHighlightRow> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<String> type;
  final Value<int> chapterIndex;
  final Value<int> sentenceIndex;
  final Value<int> charStart;
  final Value<int> charEnd;
  final Value<String> selectedText;
  final Value<String> colorHex;
  final Value<String> note;
  final Value<DateTime> createdAt;
  const BookmarksHighlightsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.type = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.sentenceIndex = const Value.absent(),
    this.charStart = const Value.absent(),
    this.charEnd = const Value.absent(),
    this.selectedText = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BookmarksHighlightsCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required String type,
    required int chapterIndex,
    required int sentenceIndex,
    this.charStart = const Value.absent(),
    this.charEnd = const Value.absent(),
    this.selectedText = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : bookId = Value(bookId),
        type = Value(type),
        chapterIndex = Value(chapterIndex),
        sentenceIndex = Value(sentenceIndex);
  static Insertable<BookmarkHighlightRow> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<String>? type,
    Expression<int>? chapterIndex,
    Expression<int>? sentenceIndex,
    Expression<int>? charStart,
    Expression<int>? charEnd,
    Expression<String>? selectedText,
    Expression<String>? colorHex,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (type != null) 'type': type,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (sentenceIndex != null) 'sentence_index': sentenceIndex,
      if (charStart != null) 'char_start': charStart,
      if (charEnd != null) 'char_end': charEnd,
      if (selectedText != null) 'selected_text': selectedText,
      if (colorHex != null) 'color_hex': colorHex,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BookmarksHighlightsCompanion copyWith(
      {Value<int>? id,
      Value<String>? bookId,
      Value<String>? type,
      Value<int>? chapterIndex,
      Value<int>? sentenceIndex,
      Value<int>? charStart,
      Value<int>? charEnd,
      Value<String>? selectedText,
      Value<String>? colorHex,
      Value<String>? note,
      Value<DateTime>? createdAt}) {
    return BookmarksHighlightsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      type: type ?? this.type,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      charStart: charStart ?? this.charStart,
      charEnd: charEnd ?? this.charEnd,
      selectedText: selectedText ?? this.selectedText,
      colorHex: colorHex ?? this.colorHex,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (sentenceIndex.present) {
      map['sentence_index'] = Variable<int>(sentenceIndex.value);
    }
    if (charStart.present) {
      map['char_start'] = Variable<int>(charStart.value);
    }
    if (charEnd.present) {
      map['char_end'] = Variable<int>(charEnd.value);
    }
    if (selectedText.present) {
      map['selected_text'] = Variable<String>(selectedText.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksHighlightsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('type: $type, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('charStart: $charStart, ')
          ..write('charEnd: $charEnd, ')
          ..write('selectedText: $selectedText, ')
          ..write('colorHex: $colorHex, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $VoicePacksTable extends VoicePacks
    with TableInfo<$VoicePacksTable, VoicePackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoicePacksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accentMeta = const VerificationMeta('accent');
  @override
  late final GeneratedColumn<String> accent = GeneratedColumn<String>(
      'accent', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
      'gender', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelTypeMeta =
      const VerificationMeta('modelType');
  @override
  late final GeneratedColumn<String> modelType = GeneratedColumn<String>(
      'model_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _speakerIdMeta =
      const VerificationMeta('speakerId');
  @override
  late final GeneratedColumn<int> speakerId = GeneratedColumn<int>(
      'speaker_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sampleRateMeta =
      const VerificationMeta('sampleRate');
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
      'sample_rate', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(24000));
  static const VerificationMeta _remoteUrlMeta =
      const VerificationMeta('remoteUrl');
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
      'remote_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _previewUrlMeta =
      const VerificationMeta('previewUrl');
  @override
  late final GeneratedColumn<String> previewUrl = GeneratedColumn<String>(
      'preview_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sha256ChecksumMeta =
      const VerificationMeta('sha256Checksum');
  @override
  late final GeneratedColumn<String> sha256Checksum = GeneratedColumn<String>(
      'sha256_checksum', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _localDirPathMeta =
      const VerificationMeta('localDirPath');
  @override
  late final GeneratedColumn<String> localDirPath = GeneratedColumn<String>(
      'local_dir_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isDownloadedMeta =
      const VerificationMeta('isDownloaded');
  @override
  late final GeneratedColumn<bool> isDownloaded = GeneratedColumn<bool>(
      'is_downloaded', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_downloaded" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isSelectedMeta =
      const VerificationMeta('isSelected');
  @override
  late final GeneratedColumn<bool> isSelected = GeneratedColumn<bool>(
      'is_selected', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_selected" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        accent,
        gender,
        modelType,
        speakerId,
        sampleRate,
        remoteUrl,
        previewUrl,
        sha256Checksum,
        localDirPath,
        sizeBytes,
        isDownloaded,
        isSelected
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voice_packs';
  @override
  VerificationContext validateIntegrity(Insertable<VoicePackRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('accent')) {
      context.handle(_accentMeta,
          accent.isAcceptableOrUnknown(data['accent']!, _accentMeta));
    } else if (isInserting) {
      context.missing(_accentMeta);
    }
    if (data.containsKey('gender')) {
      context.handle(_genderMeta,
          gender.isAcceptableOrUnknown(data['gender']!, _genderMeta));
    } else if (isInserting) {
      context.missing(_genderMeta);
    }
    if (data.containsKey('model_type')) {
      context.handle(_modelTypeMeta,
          modelType.isAcceptableOrUnknown(data['model_type']!, _modelTypeMeta));
    } else if (isInserting) {
      context.missing(_modelTypeMeta);
    }
    if (data.containsKey('speaker_id')) {
      context.handle(_speakerIdMeta,
          speakerId.isAcceptableOrUnknown(data['speaker_id']!, _speakerIdMeta));
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
          _sampleRateMeta,
          sampleRate.isAcceptableOrUnknown(
              data['sample_rate']!, _sampleRateMeta));
    }
    if (data.containsKey('remote_url')) {
      context.handle(_remoteUrlMeta,
          remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta));
    } else if (isInserting) {
      context.missing(_remoteUrlMeta);
    }
    if (data.containsKey('preview_url')) {
      context.handle(
          _previewUrlMeta,
          previewUrl.isAcceptableOrUnknown(
              data['preview_url']!, _previewUrlMeta));
    }
    if (data.containsKey('sha256_checksum')) {
      context.handle(
          _sha256ChecksumMeta,
          sha256Checksum.isAcceptableOrUnknown(
              data['sha256_checksum']!, _sha256ChecksumMeta));
    }
    if (data.containsKey('local_dir_path')) {
      context.handle(
          _localDirPathMeta,
          localDirPath.isAcceptableOrUnknown(
              data['local_dir_path']!, _localDirPathMeta));
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('is_downloaded')) {
      context.handle(
          _isDownloadedMeta,
          isDownloaded.isAcceptableOrUnknown(
              data['is_downloaded']!, _isDownloadedMeta));
    }
    if (data.containsKey('is_selected')) {
      context.handle(
          _isSelectedMeta,
          isSelected.isAcceptableOrUnknown(
              data['is_selected']!, _isSelectedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VoicePackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoicePackRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      accent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}accent'])!,
      gender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gender'])!,
      modelType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model_type'])!,
      speakerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}speaker_id'])!,
      sampleRate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sample_rate'])!,
      remoteUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_url'])!,
      previewUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}preview_url']),
      sha256Checksum: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sha256_checksum']),
      localDirPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_dir_path']),
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      isDownloaded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_downloaded'])!,
      isSelected: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_selected'])!,
    );
  }

  @override
  $VoicePacksTable createAlias(String alias) {
    return $VoicePacksTable(attachedDatabase, alias);
  }
}

class VoicePackRow extends DataClass implements Insertable<VoicePackRow> {
  final String id;
  final String name;
  final String accent;
  final String gender;
  final String modelType;
  final int speakerId;
  final int sampleRate;
  final String remoteUrl;
  final String? previewUrl;
  final String? sha256Checksum;
  final String? localDirPath;
  final int sizeBytes;
  final bool isDownloaded;
  final bool isSelected;
  const VoicePackRow(
      {required this.id,
      required this.name,
      required this.accent,
      required this.gender,
      required this.modelType,
      required this.speakerId,
      required this.sampleRate,
      required this.remoteUrl,
      this.previewUrl,
      this.sha256Checksum,
      this.localDirPath,
      required this.sizeBytes,
      required this.isDownloaded,
      required this.isSelected});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['accent'] = Variable<String>(accent);
    map['gender'] = Variable<String>(gender);
    map['model_type'] = Variable<String>(modelType);
    map['speaker_id'] = Variable<int>(speakerId);
    map['sample_rate'] = Variable<int>(sampleRate);
    map['remote_url'] = Variable<String>(remoteUrl);
    if (!nullToAbsent || previewUrl != null) {
      map['preview_url'] = Variable<String>(previewUrl);
    }
    if (!nullToAbsent || sha256Checksum != null) {
      map['sha256_checksum'] = Variable<String>(sha256Checksum);
    }
    if (!nullToAbsent || localDirPath != null) {
      map['local_dir_path'] = Variable<String>(localDirPath);
    }
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['is_downloaded'] = Variable<bool>(isDownloaded);
    map['is_selected'] = Variable<bool>(isSelected);
    return map;
  }

  VoicePacksCompanion toCompanion(bool nullToAbsent) {
    return VoicePacksCompanion(
      id: Value(id),
      name: Value(name),
      accent: Value(accent),
      gender: Value(gender),
      modelType: Value(modelType),
      speakerId: Value(speakerId),
      sampleRate: Value(sampleRate),
      remoteUrl: Value(remoteUrl),
      previewUrl: previewUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(previewUrl),
      sha256Checksum: sha256Checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256Checksum),
      localDirPath: localDirPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localDirPath),
      sizeBytes: Value(sizeBytes),
      isDownloaded: Value(isDownloaded),
      isSelected: Value(isSelected),
    );
  }

  factory VoicePackRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoicePackRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      accent: serializer.fromJson<String>(json['accent']),
      gender: serializer.fromJson<String>(json['gender']),
      modelType: serializer.fromJson<String>(json['modelType']),
      speakerId: serializer.fromJson<int>(json['speakerId']),
      sampleRate: serializer.fromJson<int>(json['sampleRate']),
      remoteUrl: serializer.fromJson<String>(json['remoteUrl']),
      previewUrl: serializer.fromJson<String?>(json['previewUrl']),
      sha256Checksum: serializer.fromJson<String?>(json['sha256Checksum']),
      localDirPath: serializer.fromJson<String?>(json['localDirPath']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      isDownloaded: serializer.fromJson<bool>(json['isDownloaded']),
      isSelected: serializer.fromJson<bool>(json['isSelected']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'accent': serializer.toJson<String>(accent),
      'gender': serializer.toJson<String>(gender),
      'modelType': serializer.toJson<String>(modelType),
      'speakerId': serializer.toJson<int>(speakerId),
      'sampleRate': serializer.toJson<int>(sampleRate),
      'remoteUrl': serializer.toJson<String>(remoteUrl),
      'previewUrl': serializer.toJson<String?>(previewUrl),
      'sha256Checksum': serializer.toJson<String?>(sha256Checksum),
      'localDirPath': serializer.toJson<String?>(localDirPath),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'isDownloaded': serializer.toJson<bool>(isDownloaded),
      'isSelected': serializer.toJson<bool>(isSelected),
    };
  }

  VoicePackRow copyWith(
          {String? id,
          String? name,
          String? accent,
          String? gender,
          String? modelType,
          int? speakerId,
          int? sampleRate,
          String? remoteUrl,
          Value<String?> previewUrl = const Value.absent(),
          Value<String?> sha256Checksum = const Value.absent(),
          Value<String?> localDirPath = const Value.absent(),
          int? sizeBytes,
          bool? isDownloaded,
          bool? isSelected}) =>
      VoicePackRow(
        id: id ?? this.id,
        name: name ?? this.name,
        accent: accent ?? this.accent,
        gender: gender ?? this.gender,
        modelType: modelType ?? this.modelType,
        speakerId: speakerId ?? this.speakerId,
        sampleRate: sampleRate ?? this.sampleRate,
        remoteUrl: remoteUrl ?? this.remoteUrl,
        previewUrl: previewUrl.present ? previewUrl.value : this.previewUrl,
        sha256Checksum:
            sha256Checksum.present ? sha256Checksum.value : this.sha256Checksum,
        localDirPath:
            localDirPath.present ? localDirPath.value : this.localDirPath,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        isSelected: isSelected ?? this.isSelected,
      );
  VoicePackRow copyWithCompanion(VoicePacksCompanion data) {
    return VoicePackRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      accent: data.accent.present ? data.accent.value : this.accent,
      gender: data.gender.present ? data.gender.value : this.gender,
      modelType: data.modelType.present ? data.modelType.value : this.modelType,
      speakerId: data.speakerId.present ? data.speakerId.value : this.speakerId,
      sampleRate:
          data.sampleRate.present ? data.sampleRate.value : this.sampleRate,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      previewUrl:
          data.previewUrl.present ? data.previewUrl.value : this.previewUrl,
      sha256Checksum: data.sha256Checksum.present
          ? data.sha256Checksum.value
          : this.sha256Checksum,
      localDirPath: data.localDirPath.present
          ? data.localDirPath.value
          : this.localDirPath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      isDownloaded: data.isDownloaded.present
          ? data.isDownloaded.value
          : this.isDownloaded,
      isSelected:
          data.isSelected.present ? data.isSelected.value : this.isSelected,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoicePackRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('accent: $accent, ')
          ..write('gender: $gender, ')
          ..write('modelType: $modelType, ')
          ..write('speakerId: $speakerId, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('previewUrl: $previewUrl, ')
          ..write('sha256Checksum: $sha256Checksum, ')
          ..write('localDirPath: $localDirPath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('isSelected: $isSelected')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      accent,
      gender,
      modelType,
      speakerId,
      sampleRate,
      remoteUrl,
      previewUrl,
      sha256Checksum,
      localDirPath,
      sizeBytes,
      isDownloaded,
      isSelected);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoicePackRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.accent == this.accent &&
          other.gender == this.gender &&
          other.modelType == this.modelType &&
          other.speakerId == this.speakerId &&
          other.sampleRate == this.sampleRate &&
          other.remoteUrl == this.remoteUrl &&
          other.previewUrl == this.previewUrl &&
          other.sha256Checksum == this.sha256Checksum &&
          other.localDirPath == this.localDirPath &&
          other.sizeBytes == this.sizeBytes &&
          other.isDownloaded == this.isDownloaded &&
          other.isSelected == this.isSelected);
}

class VoicePacksCompanion extends UpdateCompanion<VoicePackRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> accent;
  final Value<String> gender;
  final Value<String> modelType;
  final Value<int> speakerId;
  final Value<int> sampleRate;
  final Value<String> remoteUrl;
  final Value<String?> previewUrl;
  final Value<String?> sha256Checksum;
  final Value<String?> localDirPath;
  final Value<int> sizeBytes;
  final Value<bool> isDownloaded;
  final Value<bool> isSelected;
  final Value<int> rowid;
  const VoicePacksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.accent = const Value.absent(),
    this.gender = const Value.absent(),
    this.modelType = const Value.absent(),
    this.speakerId = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.previewUrl = const Value.absent(),
    this.sha256Checksum = const Value.absent(),
    this.localDirPath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.isSelected = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VoicePacksCompanion.insert({
    required String id,
    required String name,
    required String accent,
    required String gender,
    required String modelType,
    this.speakerId = const Value.absent(),
    this.sampleRate = const Value.absent(),
    required String remoteUrl,
    this.previewUrl = const Value.absent(),
    this.sha256Checksum = const Value.absent(),
    this.localDirPath = const Value.absent(),
    required int sizeBytes,
    this.isDownloaded = const Value.absent(),
    this.isSelected = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        accent = Value(accent),
        gender = Value(gender),
        modelType = Value(modelType),
        remoteUrl = Value(remoteUrl),
        sizeBytes = Value(sizeBytes);
  static Insertable<VoicePackRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? accent,
    Expression<String>? gender,
    Expression<String>? modelType,
    Expression<int>? speakerId,
    Expression<int>? sampleRate,
    Expression<String>? remoteUrl,
    Expression<String>? previewUrl,
    Expression<String>? sha256Checksum,
    Expression<String>? localDirPath,
    Expression<int>? sizeBytes,
    Expression<bool>? isDownloaded,
    Expression<bool>? isSelected,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (accent != null) 'accent': accent,
      if (gender != null) 'gender': gender,
      if (modelType != null) 'model_type': modelType,
      if (speakerId != null) 'speaker_id': speakerId,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (previewUrl != null) 'preview_url': previewUrl,
      if (sha256Checksum != null) 'sha256_checksum': sha256Checksum,
      if (localDirPath != null) 'local_dir_path': localDirPath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (isDownloaded != null) 'is_downloaded': isDownloaded,
      if (isSelected != null) 'is_selected': isSelected,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VoicePacksCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? accent,
      Value<String>? gender,
      Value<String>? modelType,
      Value<int>? speakerId,
      Value<int>? sampleRate,
      Value<String>? remoteUrl,
      Value<String?>? previewUrl,
      Value<String?>? sha256Checksum,
      Value<String?>? localDirPath,
      Value<int>? sizeBytes,
      Value<bool>? isDownloaded,
      Value<bool>? isSelected,
      Value<int>? rowid}) {
    return VoicePacksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      accent: accent ?? this.accent,
      gender: gender ?? this.gender,
      modelType: modelType ?? this.modelType,
      speakerId: speakerId ?? this.speakerId,
      sampleRate: sampleRate ?? this.sampleRate,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      sha256Checksum: sha256Checksum ?? this.sha256Checksum,
      localDirPath: localDirPath ?? this.localDirPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isSelected: isSelected ?? this.isSelected,
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
    if (accent.present) {
      map['accent'] = Variable<String>(accent.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (modelType.present) {
      map['model_type'] = Variable<String>(modelType.value);
    }
    if (speakerId.present) {
      map['speaker_id'] = Variable<int>(speakerId.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (previewUrl.present) {
      map['preview_url'] = Variable<String>(previewUrl.value);
    }
    if (sha256Checksum.present) {
      map['sha256_checksum'] = Variable<String>(sha256Checksum.value);
    }
    if (localDirPath.present) {
      map['local_dir_path'] = Variable<String>(localDirPath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (isDownloaded.present) {
      map['is_downloaded'] = Variable<bool>(isDownloaded.value);
    }
    if (isSelected.present) {
      map['is_selected'] = Variable<bool>(isSelected.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VoicePacksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('accent: $accent, ')
          ..write('gender: $gender, ')
          ..write('modelType: $modelType, ')
          ..write('speakerId: $speakerId, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('previewUrl: $previewUrl, ')
          ..write('sha256Checksum: $sha256Checksum, ')
          ..write('localDirPath: $localDirPath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('isSelected: $isSelected, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LofiTracksTable extends LofiTracks
    with TableInfo<$LofiTracksTable, LofiTrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LofiTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationSecMeta =
      const VerificationMeta('durationSec');
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
      'duration_sec', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _streamUrlMeta =
      const VerificationMeta('streamUrl');
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
      'stream_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sha256ChecksumMeta =
      const VerificationMeta('sha256Checksum');
  @override
  late final GeneratedColumn<String> sha256Checksum = GeneratedColumn<String>(
      'sha256_checksum', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isBundledMeta =
      const VerificationMeta('isBundled');
  @override
  late final GeneratedColumn<bool> isBundled = GeneratedColumn<bool>(
      'is_bundled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_bundled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isCachedMeta =
      const VerificationMeta('isCached');
  @override
  late final GeneratedColumn<bool> isCached = GeneratedColumn<bool>(
      'is_cached', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_cached" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        artist,
        durationSec,
        streamUrl,
        localPath,
        sha256Checksum,
        isBundled,
        isCached
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lofi_tracks';
  @override
  VerificationContext validateIntegrity(Insertable<LofiTrackRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
          _durationSecMeta,
          durationSec.isAcceptableOrUnknown(
              data['duration_sec']!, _durationSecMeta));
    } else if (isInserting) {
      context.missing(_durationSecMeta);
    }
    if (data.containsKey('stream_url')) {
      context.handle(_streamUrlMeta,
          streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta));
    } else if (isInserting) {
      context.missing(_streamUrlMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('sha256_checksum')) {
      context.handle(
          _sha256ChecksumMeta,
          sha256Checksum.isAcceptableOrUnknown(
              data['sha256_checksum']!, _sha256ChecksumMeta));
    }
    if (data.containsKey('is_bundled')) {
      context.handle(_isBundledMeta,
          isBundled.isAcceptableOrUnknown(data['is_bundled']!, _isBundledMeta));
    }
    if (data.containsKey('is_cached')) {
      context.handle(_isCachedMeta,
          isCached.isAcceptableOrUnknown(data['is_cached']!, _isCachedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LofiTrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LofiTrackRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      durationSec: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_sec'])!,
      streamUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stream_url'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      sha256Checksum: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sha256_checksum']),
      isBundled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_bundled'])!,
      isCached: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_cached'])!,
    );
  }

  @override
  $LofiTracksTable createAlias(String alias) {
    return $LofiTracksTable(attachedDatabase, alias);
  }
}

class LofiTrackRow extends DataClass implements Insertable<LofiTrackRow> {
  final String id;
  final String title;
  final String artist;
  final int durationSec;
  final String streamUrl;
  final String? localPath;
  final String? sha256Checksum;
  final bool isBundled;
  final bool isCached;
  const LofiTrackRow(
      {required this.id,
      required this.title,
      required this.artist,
      required this.durationSec,
      required this.streamUrl,
      this.localPath,
      this.sha256Checksum,
      required this.isBundled,
      required this.isCached});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['duration_sec'] = Variable<int>(durationSec);
    map['stream_url'] = Variable<String>(streamUrl);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || sha256Checksum != null) {
      map['sha256_checksum'] = Variable<String>(sha256Checksum);
    }
    map['is_bundled'] = Variable<bool>(isBundled);
    map['is_cached'] = Variable<bool>(isCached);
    return map;
  }

  LofiTracksCompanion toCompanion(bool nullToAbsent) {
    return LofiTracksCompanion(
      id: Value(id),
      title: Value(title),
      artist: Value(artist),
      durationSec: Value(durationSec),
      streamUrl: Value(streamUrl),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      sha256Checksum: sha256Checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256Checksum),
      isBundled: Value(isBundled),
      isCached: Value(isCached),
    );
  }

  factory LofiTrackRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LofiTrackRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      durationSec: serializer.fromJson<int>(json['durationSec']),
      streamUrl: serializer.fromJson<String>(json['streamUrl']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      sha256Checksum: serializer.fromJson<String?>(json['sha256Checksum']),
      isBundled: serializer.fromJson<bool>(json['isBundled']),
      isCached: serializer.fromJson<bool>(json['isCached']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'durationSec': serializer.toJson<int>(durationSec),
      'streamUrl': serializer.toJson<String>(streamUrl),
      'localPath': serializer.toJson<String?>(localPath),
      'sha256Checksum': serializer.toJson<String?>(sha256Checksum),
      'isBundled': serializer.toJson<bool>(isBundled),
      'isCached': serializer.toJson<bool>(isCached),
    };
  }

  LofiTrackRow copyWith(
          {String? id,
          String? title,
          String? artist,
          int? durationSec,
          String? streamUrl,
          Value<String?> localPath = const Value.absent(),
          Value<String?> sha256Checksum = const Value.absent(),
          bool? isBundled,
          bool? isCached}) =>
      LofiTrackRow(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        durationSec: durationSec ?? this.durationSec,
        streamUrl: streamUrl ?? this.streamUrl,
        localPath: localPath.present ? localPath.value : this.localPath,
        sha256Checksum:
            sha256Checksum.present ? sha256Checksum.value : this.sha256Checksum,
        isBundled: isBundled ?? this.isBundled,
        isCached: isCached ?? this.isCached,
      );
  LofiTrackRow copyWithCompanion(LofiTracksCompanion data) {
    return LofiTrackRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      durationSec:
          data.durationSec.present ? data.durationSec.value : this.durationSec,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      sha256Checksum: data.sha256Checksum.present
          ? data.sha256Checksum.value
          : this.sha256Checksum,
      isBundled: data.isBundled.present ? data.isBundled.value : this.isBundled,
      isCached: data.isCached.present ? data.isCached.value : this.isCached,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LofiTrackRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('durationSec: $durationSec, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('localPath: $localPath, ')
          ..write('sha256Checksum: $sha256Checksum, ')
          ..write('isBundled: $isBundled, ')
          ..write('isCached: $isCached')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, artist, durationSec, streamUrl,
      localPath, sha256Checksum, isBundled, isCached);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LofiTrackRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.durationSec == this.durationSec &&
          other.streamUrl == this.streamUrl &&
          other.localPath == this.localPath &&
          other.sha256Checksum == this.sha256Checksum &&
          other.isBundled == this.isBundled &&
          other.isCached == this.isCached);
}

class LofiTracksCompanion extends UpdateCompanion<LofiTrackRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> artist;
  final Value<int> durationSec;
  final Value<String> streamUrl;
  final Value<String?> localPath;
  final Value<String?> sha256Checksum;
  final Value<bool> isBundled;
  final Value<bool> isCached;
  final Value<int> rowid;
  const LofiTracksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.sha256Checksum = const Value.absent(),
    this.isBundled = const Value.absent(),
    this.isCached = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LofiTracksCompanion.insert({
    required String id,
    required String title,
    required String artist,
    required int durationSec,
    required String streamUrl,
    this.localPath = const Value.absent(),
    this.sha256Checksum = const Value.absent(),
    this.isBundled = const Value.absent(),
    this.isCached = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        artist = Value(artist),
        durationSec = Value(durationSec),
        streamUrl = Value(streamUrl);
  static Insertable<LofiTrackRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<int>? durationSec,
    Expression<String>? streamUrl,
    Expression<String>? localPath,
    Expression<String>? sha256Checksum,
    Expression<bool>? isBundled,
    Expression<bool>? isCached,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (durationSec != null) 'duration_sec': durationSec,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (localPath != null) 'local_path': localPath,
      if (sha256Checksum != null) 'sha256_checksum': sha256Checksum,
      if (isBundled != null) 'is_bundled': isBundled,
      if (isCached != null) 'is_cached': isCached,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LofiTracksCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? artist,
      Value<int>? durationSec,
      Value<String>? streamUrl,
      Value<String?>? localPath,
      Value<String?>? sha256Checksum,
      Value<bool>? isBundled,
      Value<bool>? isCached,
      Value<int>? rowid}) {
    return LofiTracksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      durationSec: durationSec ?? this.durationSec,
      streamUrl: streamUrl ?? this.streamUrl,
      localPath: localPath ?? this.localPath,
      sha256Checksum: sha256Checksum ?? this.sha256Checksum,
      isBundled: isBundled ?? this.isBundled,
      isCached: isCached ?? this.isCached,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (sha256Checksum.present) {
      map['sha256_checksum'] = Variable<String>(sha256Checksum.value);
    }
    if (isBundled.present) {
      map['is_bundled'] = Variable<bool>(isBundled.value);
    }
    if (isCached.present) {
      map['is_cached'] = Variable<bool>(isCached.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LofiTracksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('durationSec: $durationSec, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('localPath: $localPath, ')
          ..write('sha256Checksum: $sha256Checksum, ')
          ..write('isBundled: $isBundled, ')
          ..write('isCached: $isCached, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $XiangqiMatchesTable extends XiangqiMatches
    with TableInfo<$XiangqiMatchesTable, XiangqiMatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $XiangqiMatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _difficultyMeta =
      const VerificationMeta('difficulty');
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
      'difficulty', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _playerSideMeta =
      const VerificationMeta('playerSide');
  @override
  late final GeneratedColumn<String> playerSide = GeneratedColumn<String>(
      'player_side', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currentFenMeta =
      const VerificationMeta('currentFen');
  @override
  late final GeneratedColumn<String> currentFen = GeneratedColumn<String>(
      'current_fen', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _moveHistoryMeta =
      const VerificationMeta('moveHistory');
  @override
  late final GeneratedColumn<String> moveHistory = GeneratedColumn<String>(
      'move_history', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _fenHistoryJsonMeta =
      const VerificationMeta('fenHistoryJson');
  @override
  late final GeneratedColumn<String> fenHistoryJson = GeneratedColumn<String>(
      'fen_history_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('ongoing'));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        difficulty,
        playerSide,
        currentFen,
        moveHistory,
        fenHistoryJson,
        status,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'xiangqi_matches';
  @override
  VerificationContext validateIntegrity(Insertable<XiangqiMatchRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('difficulty')) {
      context.handle(
          _difficultyMeta,
          difficulty.isAcceptableOrUnknown(
              data['difficulty']!, _difficultyMeta));
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('player_side')) {
      context.handle(
          _playerSideMeta,
          playerSide.isAcceptableOrUnknown(
              data['player_side']!, _playerSideMeta));
    } else if (isInserting) {
      context.missing(_playerSideMeta);
    }
    if (data.containsKey('current_fen')) {
      context.handle(
          _currentFenMeta,
          currentFen.isAcceptableOrUnknown(
              data['current_fen']!, _currentFenMeta));
    } else if (isInserting) {
      context.missing(_currentFenMeta);
    }
    if (data.containsKey('move_history')) {
      context.handle(
          _moveHistoryMeta,
          moveHistory.isAcceptableOrUnknown(
              data['move_history']!, _moveHistoryMeta));
    }
    if (data.containsKey('fen_history_json')) {
      context.handle(
          _fenHistoryJsonMeta,
          fenHistoryJson.isAcceptableOrUnknown(
              data['fen_history_json']!, _fenHistoryJsonMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  XiangqiMatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return XiangqiMatchRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      difficulty: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}difficulty'])!,
      playerSide: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}player_side'])!,
      currentFen: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}current_fen'])!,
      moveHistory: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}move_history'])!,
      fenHistoryJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}fen_history_json'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $XiangqiMatchesTable createAlias(String alias) {
    return $XiangqiMatchesTable(attachedDatabase, alias);
  }
}

class XiangqiMatchRow extends DataClass implements Insertable<XiangqiMatchRow> {
  final int id;
  final String difficulty;
  final String playerSide;
  final String currentFen;
  final String moveHistory;
  final String fenHistoryJson;
  final String status;
  final DateTime updatedAt;
  const XiangqiMatchRow(
      {required this.id,
      required this.difficulty,
      required this.playerSide,
      required this.currentFen,
      required this.moveHistory,
      required this.fenHistoryJson,
      required this.status,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['difficulty'] = Variable<String>(difficulty);
    map['player_side'] = Variable<String>(playerSide);
    map['current_fen'] = Variable<String>(currentFen);
    map['move_history'] = Variable<String>(moveHistory);
    map['fen_history_json'] = Variable<String>(fenHistoryJson);
    map['status'] = Variable<String>(status);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  XiangqiMatchesCompanion toCompanion(bool nullToAbsent) {
    return XiangqiMatchesCompanion(
      id: Value(id),
      difficulty: Value(difficulty),
      playerSide: Value(playerSide),
      currentFen: Value(currentFen),
      moveHistory: Value(moveHistory),
      fenHistoryJson: Value(fenHistoryJson),
      status: Value(status),
      updatedAt: Value(updatedAt),
    );
  }

  factory XiangqiMatchRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return XiangqiMatchRow(
      id: serializer.fromJson<int>(json['id']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
      playerSide: serializer.fromJson<String>(json['playerSide']),
      currentFen: serializer.fromJson<String>(json['currentFen']),
      moveHistory: serializer.fromJson<String>(json['moveHistory']),
      fenHistoryJson: serializer.fromJson<String>(json['fenHistoryJson']),
      status: serializer.fromJson<String>(json['status']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'difficulty': serializer.toJson<String>(difficulty),
      'playerSide': serializer.toJson<String>(playerSide),
      'currentFen': serializer.toJson<String>(currentFen),
      'moveHistory': serializer.toJson<String>(moveHistory),
      'fenHistoryJson': serializer.toJson<String>(fenHistoryJson),
      'status': serializer.toJson<String>(status),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  XiangqiMatchRow copyWith(
          {int? id,
          String? difficulty,
          String? playerSide,
          String? currentFen,
          String? moveHistory,
          String? fenHistoryJson,
          String? status,
          DateTime? updatedAt}) =>
      XiangqiMatchRow(
        id: id ?? this.id,
        difficulty: difficulty ?? this.difficulty,
        playerSide: playerSide ?? this.playerSide,
        currentFen: currentFen ?? this.currentFen,
        moveHistory: moveHistory ?? this.moveHistory,
        fenHistoryJson: fenHistoryJson ?? this.fenHistoryJson,
        status: status ?? this.status,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  XiangqiMatchRow copyWithCompanion(XiangqiMatchesCompanion data) {
    return XiangqiMatchRow(
      id: data.id.present ? data.id.value : this.id,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      playerSide:
          data.playerSide.present ? data.playerSide.value : this.playerSide,
      currentFen:
          data.currentFen.present ? data.currentFen.value : this.currentFen,
      moveHistory:
          data.moveHistory.present ? data.moveHistory.value : this.moveHistory,
      fenHistoryJson: data.fenHistoryJson.present
          ? data.fenHistoryJson.value
          : this.fenHistoryJson,
      status: data.status.present ? data.status.value : this.status,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('XiangqiMatchRow(')
          ..write('id: $id, ')
          ..write('difficulty: $difficulty, ')
          ..write('playerSide: $playerSide, ')
          ..write('currentFen: $currentFen, ')
          ..write('moveHistory: $moveHistory, ')
          ..write('fenHistoryJson: $fenHistoryJson, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, difficulty, playerSide, currentFen,
      moveHistory, fenHistoryJson, status, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is XiangqiMatchRow &&
          other.id == this.id &&
          other.difficulty == this.difficulty &&
          other.playerSide == this.playerSide &&
          other.currentFen == this.currentFen &&
          other.moveHistory == this.moveHistory &&
          other.fenHistoryJson == this.fenHistoryJson &&
          other.status == this.status &&
          other.updatedAt == this.updatedAt);
}

class XiangqiMatchesCompanion extends UpdateCompanion<XiangqiMatchRow> {
  final Value<int> id;
  final Value<String> difficulty;
  final Value<String> playerSide;
  final Value<String> currentFen;
  final Value<String> moveHistory;
  final Value<String> fenHistoryJson;
  final Value<String> status;
  final Value<DateTime> updatedAt;
  const XiangqiMatchesCompanion({
    this.id = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.playerSide = const Value.absent(),
    this.currentFen = const Value.absent(),
    this.moveHistory = const Value.absent(),
    this.fenHistoryJson = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  XiangqiMatchesCompanion.insert({
    this.id = const Value.absent(),
    required String difficulty,
    required String playerSide,
    required String currentFen,
    this.moveHistory = const Value.absent(),
    this.fenHistoryJson = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : difficulty = Value(difficulty),
        playerSide = Value(playerSide),
        currentFen = Value(currentFen);
  static Insertable<XiangqiMatchRow> custom({
    Expression<int>? id,
    Expression<String>? difficulty,
    Expression<String>? playerSide,
    Expression<String>? currentFen,
    Expression<String>? moveHistory,
    Expression<String>? fenHistoryJson,
    Expression<String>? status,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (difficulty != null) 'difficulty': difficulty,
      if (playerSide != null) 'player_side': playerSide,
      if (currentFen != null) 'current_fen': currentFen,
      if (moveHistory != null) 'move_history': moveHistory,
      if (fenHistoryJson != null) 'fen_history_json': fenHistoryJson,
      if (status != null) 'status': status,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  XiangqiMatchesCompanion copyWith(
      {Value<int>? id,
      Value<String>? difficulty,
      Value<String>? playerSide,
      Value<String>? currentFen,
      Value<String>? moveHistory,
      Value<String>? fenHistoryJson,
      Value<String>? status,
      Value<DateTime>? updatedAt}) {
    return XiangqiMatchesCompanion(
      id: id ?? this.id,
      difficulty: difficulty ?? this.difficulty,
      playerSide: playerSide ?? this.playerSide,
      currentFen: currentFen ?? this.currentFen,
      moveHistory: moveHistory ?? this.moveHistory,
      fenHistoryJson: fenHistoryJson ?? this.fenHistoryJson,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (playerSide.present) {
      map['player_side'] = Variable<String>(playerSide.value);
    }
    if (currentFen.present) {
      map['current_fen'] = Variable<String>(currentFen.value);
    }
    if (moveHistory.present) {
      map['move_history'] = Variable<String>(moveHistory.value);
    }
    if (fenHistoryJson.present) {
      map['fen_history_json'] = Variable<String>(fenHistoryJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('XiangqiMatchesCompanion(')
          ..write('id: $id, ')
          ..write('difficulty: $difficulty, ')
          ..write('playerSide: $playerSide, ')
          ..write('currentFen: $currentFen, ')
          ..write('moveHistory: $moveHistory, ')
          ..write('fenHistoryJson: $fenHistoryJson, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $ReadingProgressesTable readingProgresses =
      $ReadingProgressesTable(this);
  late final $BookmarksHighlightsTable bookmarksHighlights =
      $BookmarksHighlightsTable(this);
  late final $VoicePacksTable voicePacks = $VoicePacksTable(this);
  late final $LofiTracksTable lofiTracks = $LofiTracksTable(this);
  late final $XiangqiMatchesTable xiangqiMatches = $XiangqiMatchesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        books,
        readingProgresses,
        bookmarksHighlights,
        voicePacks,
        lofiTracks,
        xiangqiMatches
      ];
}

typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  required String id,
  required String title,
  required String author,
  Value<String> description,
  Value<String> genresJson,
  Value<String?> remoteCoverUrl,
  Value<String?> localCoverPath,
  Value<String?> remoteEpubUrl,
  Value<String?> localFilePath,
  Value<String> sourceType,
  Value<String> format,
  Value<int> wordCount,
  Value<int> fileSizeBytes,
  Value<String?> sha256Checksum,
  Value<bool> isTtsSupported,
  Value<bool> isDownloaded,
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> author,
  Value<String> description,
  Value<String> genresJson,
  Value<String?> remoteCoverUrl,
  Value<String?> localCoverPath,
  Value<String?> remoteEpubUrl,
  Value<String?> localFilePath,
  Value<String> sourceType,
  Value<String> format,
  Value<int> wordCount,
  Value<int> fileSizeBytes,
  Value<String?> sha256Checksum,
  Value<bool> isTtsSupported,
  Value<bool> isDownloaded,
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get genresJson => $composableBuilder(
      column: $table.genresJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteCoverUrl => $composableBuilder(
      column: $table.remoteCoverUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localCoverPath => $composableBuilder(
      column: $table.localCoverPath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteEpubUrl => $composableBuilder(
      column: $table.remoteEpubUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get wordCount => $composableBuilder(
      column: $table.wordCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sha256Checksum => $composableBuilder(
      column: $table.sha256Checksum,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isTtsSupported => $composableBuilder(
      column: $table.isTtsSupported,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get genresJson => $composableBuilder(
      column: $table.genresJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteCoverUrl => $composableBuilder(
      column: $table.remoteCoverUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localCoverPath => $composableBuilder(
      column: $table.localCoverPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteEpubUrl => $composableBuilder(
      column: $table.remoteEpubUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get wordCount => $composableBuilder(
      column: $table.wordCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sha256Checksum => $composableBuilder(
      column: $table.sha256Checksum,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isTtsSupported => $composableBuilder(
      column: $table.isTtsSupported,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get genresJson => $composableBuilder(
      column: $table.genresJson, builder: (column) => column);

  GeneratedColumn<String> get remoteCoverUrl => $composableBuilder(
      column: $table.remoteCoverUrl, builder: (column) => column);

  GeneratedColumn<String> get localCoverPath => $composableBuilder(
      column: $table.localCoverPath, builder: (column) => column);

  GeneratedColumn<String> get remoteEpubUrl => $composableBuilder(
      column: $table.remoteEpubUrl, builder: (column) => column);

  GeneratedColumn<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => column);

  GeneratedColumn<String> get sha256Checksum => $composableBuilder(
      column: $table.sha256Checksum, builder: (column) => column);

  GeneratedColumn<bool> get isTtsSupported => $composableBuilder(
      column: $table.isTtsSupported, builder: (column) => column);

  GeneratedColumn<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BooksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BooksTable,
    BookRow,
    $$BooksTableFilterComposer,
    $$BooksTableOrderingComposer,
    $$BooksTableAnnotationComposer,
    $$BooksTableCreateCompanionBuilder,
    $$BooksTableUpdateCompanionBuilder,
    (BookRow, BaseReferences<_$AppDatabase, $BooksTable, BookRow>),
    BookRow,
    PrefetchHooks Function()> {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String> genresJson = const Value.absent(),
            Value<String?> remoteCoverUrl = const Value.absent(),
            Value<String?> localCoverPath = const Value.absent(),
            Value<String?> remoteEpubUrl = const Value.absent(),
            Value<String?> localFilePath = const Value.absent(),
            Value<String> sourceType = const Value.absent(),
            Value<String> format = const Value.absent(),
            Value<int> wordCount = const Value.absent(),
            Value<int> fileSizeBytes = const Value.absent(),
            Value<String?> sha256Checksum = const Value.absent(),
            Value<bool> isTtsSupported = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BooksCompanion(
            id: id,
            title: title,
            author: author,
            description: description,
            genresJson: genresJson,
            remoteCoverUrl: remoteCoverUrl,
            localCoverPath: localCoverPath,
            remoteEpubUrl: remoteEpubUrl,
            localFilePath: localFilePath,
            sourceType: sourceType,
            format: format,
            wordCount: wordCount,
            fileSizeBytes: fileSizeBytes,
            sha256Checksum: sha256Checksum,
            isTtsSupported: isTtsSupported,
            isDownloaded: isDownloaded,
            isFavorite: isFavorite,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String author,
            Value<String> description = const Value.absent(),
            Value<String> genresJson = const Value.absent(),
            Value<String?> remoteCoverUrl = const Value.absent(),
            Value<String?> localCoverPath = const Value.absent(),
            Value<String?> remoteEpubUrl = const Value.absent(),
            Value<String?> localFilePath = const Value.absent(),
            Value<String> sourceType = const Value.absent(),
            Value<String> format = const Value.absent(),
            Value<int> wordCount = const Value.absent(),
            Value<int> fileSizeBytes = const Value.absent(),
            Value<String?> sha256Checksum = const Value.absent(),
            Value<bool> isTtsSupported = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BooksCompanion.insert(
            id: id,
            title: title,
            author: author,
            description: description,
            genresJson: genresJson,
            remoteCoverUrl: remoteCoverUrl,
            localCoverPath: localCoverPath,
            remoteEpubUrl: remoteEpubUrl,
            localFilePath: localFilePath,
            sourceType: sourceType,
            format: format,
            wordCount: wordCount,
            fileSizeBytes: fileSizeBytes,
            sha256Checksum: sha256Checksum,
            isTtsSupported: isTtsSupported,
            isDownloaded: isDownloaded,
            isFavorite: isFavorite,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BooksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BooksTable,
    BookRow,
    $$BooksTableFilterComposer,
    $$BooksTableOrderingComposer,
    $$BooksTableAnnotationComposer,
    $$BooksTableCreateCompanionBuilder,
    $$BooksTableUpdateCompanionBuilder,
    (BookRow, BaseReferences<_$AppDatabase, $BooksTable, BookRow>),
    BookRow,
    PrefetchHooks Function()>;
typedef $$ReadingProgressesTableCreateCompanionBuilder
    = ReadingProgressesCompanion Function({
  required String bookId,
  Value<int> chapterIndex,
  Value<int> sentenceIndex,
  Value<double> scrollOffset,
  Value<double> progressPercent,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$ReadingProgressesTableUpdateCompanionBuilder
    = ReadingProgressesCompanion Function({
  Value<String> bookId,
  Value<int> chapterIndex,
  Value<int> sentenceIndex,
  Value<double> scrollOffset,
  Value<double> progressPercent,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ReadingProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sentenceIndex => $composableBuilder(
      column: $table.sentenceIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get scrollOffset => $composableBuilder(
      column: $table.scrollOffset, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get progressPercent => $composableBuilder(
      column: $table.progressPercent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ReadingProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sentenceIndex => $composableBuilder(
      column: $table.sentenceIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get scrollOffset => $composableBuilder(
      column: $table.scrollOffset,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get progressPercent => $composableBuilder(
      column: $table.progressPercent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ReadingProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => column);

  GeneratedColumn<int> get sentenceIndex => $composableBuilder(
      column: $table.sentenceIndex, builder: (column) => column);

  GeneratedColumn<double> get scrollOffset => $composableBuilder(
      column: $table.scrollOffset, builder: (column) => column);

  GeneratedColumn<double> get progressPercent => $composableBuilder(
      column: $table.progressPercent, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReadingProgressesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReadingProgressesTable,
    ReadingProgressRow,
    $$ReadingProgressesTableFilterComposer,
    $$ReadingProgressesTableOrderingComposer,
    $$ReadingProgressesTableAnnotationComposer,
    $$ReadingProgressesTableCreateCompanionBuilder,
    $$ReadingProgressesTableUpdateCompanionBuilder,
    (
      ReadingProgressRow,
      BaseReferences<_$AppDatabase, $ReadingProgressesTable, ReadingProgressRow>
    ),
    ReadingProgressRow,
    PrefetchHooks Function()> {
  $$ReadingProgressesTableTableManager(
      _$AppDatabase db, $ReadingProgressesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> bookId = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<int> sentenceIndex = const Value.absent(),
            Value<double> scrollOffset = const Value.absent(),
            Value<double> progressPercent = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadingProgressesCompanion(
            bookId: bookId,
            chapterIndex: chapterIndex,
            sentenceIndex: sentenceIndex,
            scrollOffset: scrollOffset,
            progressPercent: progressPercent,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String bookId,
            Value<int> chapterIndex = const Value.absent(),
            Value<int> sentenceIndex = const Value.absent(),
            Value<double> scrollOffset = const Value.absent(),
            Value<double> progressPercent = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadingProgressesCompanion.insert(
            bookId: bookId,
            chapterIndex: chapterIndex,
            sentenceIndex: sentenceIndex,
            scrollOffset: scrollOffset,
            progressPercent: progressPercent,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReadingProgressesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReadingProgressesTable,
    ReadingProgressRow,
    $$ReadingProgressesTableFilterComposer,
    $$ReadingProgressesTableOrderingComposer,
    $$ReadingProgressesTableAnnotationComposer,
    $$ReadingProgressesTableCreateCompanionBuilder,
    $$ReadingProgressesTableUpdateCompanionBuilder,
    (
      ReadingProgressRow,
      BaseReferences<_$AppDatabase, $ReadingProgressesTable, ReadingProgressRow>
    ),
    ReadingProgressRow,
    PrefetchHooks Function()>;
typedef $$BookmarksHighlightsTableCreateCompanionBuilder
    = BookmarksHighlightsCompanion Function({
  Value<int> id,
  required String bookId,
  required String type,
  required int chapterIndex,
  required int sentenceIndex,
  Value<int> charStart,
  Value<int> charEnd,
  Value<String> selectedText,
  Value<String> colorHex,
  Value<String> note,
  Value<DateTime> createdAt,
});
typedef $$BookmarksHighlightsTableUpdateCompanionBuilder
    = BookmarksHighlightsCompanion Function({
  Value<int> id,
  Value<String> bookId,
  Value<String> type,
  Value<int> chapterIndex,
  Value<int> sentenceIndex,
  Value<int> charStart,
  Value<int> charEnd,
  Value<String> selectedText,
  Value<String> colorHex,
  Value<String> note,
  Value<DateTime> createdAt,
});

class $$BookmarksHighlightsTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksHighlightsTable> {
  $$BookmarksHighlightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sentenceIndex => $composableBuilder(
      column: $table.sentenceIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get charStart => $composableBuilder(
      column: $table.charStart, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get charEnd => $composableBuilder(
      column: $table.charEnd, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get selectedText => $composableBuilder(
      column: $table.selectedText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colorHex => $composableBuilder(
      column: $table.colorHex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$BookmarksHighlightsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksHighlightsTable> {
  $$BookmarksHighlightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sentenceIndex => $composableBuilder(
      column: $table.sentenceIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get charStart => $composableBuilder(
      column: $table.charStart, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get charEnd => $composableBuilder(
      column: $table.charEnd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get selectedText => $composableBuilder(
      column: $table.selectedText,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colorHex => $composableBuilder(
      column: $table.colorHex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$BookmarksHighlightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksHighlightsTable> {
  $$BookmarksHighlightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => column);

  GeneratedColumn<int> get sentenceIndex => $composableBuilder(
      column: $table.sentenceIndex, builder: (column) => column);

  GeneratedColumn<int> get charStart =>
      $composableBuilder(column: $table.charStart, builder: (column) => column);

  GeneratedColumn<int> get charEnd =>
      $composableBuilder(column: $table.charEnd, builder: (column) => column);

  GeneratedColumn<String> get selectedText => $composableBuilder(
      column: $table.selectedText, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookmarksHighlightsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BookmarksHighlightsTable,
    BookmarkHighlightRow,
    $$BookmarksHighlightsTableFilterComposer,
    $$BookmarksHighlightsTableOrderingComposer,
    $$BookmarksHighlightsTableAnnotationComposer,
    $$BookmarksHighlightsTableCreateCompanionBuilder,
    $$BookmarksHighlightsTableUpdateCompanionBuilder,
    (
      BookmarkHighlightRow,
      BaseReferences<_$AppDatabase, $BookmarksHighlightsTable,
          BookmarkHighlightRow>
    ),
    BookmarkHighlightRow,
    PrefetchHooks Function()> {
  $$BookmarksHighlightsTableTableManager(
      _$AppDatabase db, $BookmarksHighlightsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksHighlightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksHighlightsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksHighlightsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<int> sentenceIndex = const Value.absent(),
            Value<int> charStart = const Value.absent(),
            Value<int> charEnd = const Value.absent(),
            Value<String> selectedText = const Value.absent(),
            Value<String> colorHex = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              BookmarksHighlightsCompanion(
            id: id,
            bookId: bookId,
            type: type,
            chapterIndex: chapterIndex,
            sentenceIndex: sentenceIndex,
            charStart: charStart,
            charEnd: charEnd,
            selectedText: selectedText,
            colorHex: colorHex,
            note: note,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String bookId,
            required String type,
            required int chapterIndex,
            required int sentenceIndex,
            Value<int> charStart = const Value.absent(),
            Value<int> charEnd = const Value.absent(),
            Value<String> selectedText = const Value.absent(),
            Value<String> colorHex = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              BookmarksHighlightsCompanion.insert(
            id: id,
            bookId: bookId,
            type: type,
            chapterIndex: chapterIndex,
            sentenceIndex: sentenceIndex,
            charStart: charStart,
            charEnd: charEnd,
            selectedText: selectedText,
            colorHex: colorHex,
            note: note,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BookmarksHighlightsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BookmarksHighlightsTable,
    BookmarkHighlightRow,
    $$BookmarksHighlightsTableFilterComposer,
    $$BookmarksHighlightsTableOrderingComposer,
    $$BookmarksHighlightsTableAnnotationComposer,
    $$BookmarksHighlightsTableCreateCompanionBuilder,
    $$BookmarksHighlightsTableUpdateCompanionBuilder,
    (
      BookmarkHighlightRow,
      BaseReferences<_$AppDatabase, $BookmarksHighlightsTable,
          BookmarkHighlightRow>
    ),
    BookmarkHighlightRow,
    PrefetchHooks Function()>;
typedef $$VoicePacksTableCreateCompanionBuilder = VoicePacksCompanion Function({
  required String id,
  required String name,
  required String accent,
  required String gender,
  required String modelType,
  Value<int> speakerId,
  Value<int> sampleRate,
  required String remoteUrl,
  Value<String?> previewUrl,
  Value<String?> sha256Checksum,
  Value<String?> localDirPath,
  required int sizeBytes,
  Value<bool> isDownloaded,
  Value<bool> isSelected,
  Value<int> rowid,
});
typedef $$VoicePacksTableUpdateCompanionBuilder = VoicePacksCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> accent,
  Value<String> gender,
  Value<String> modelType,
  Value<int> speakerId,
  Value<int> sampleRate,
  Value<String> remoteUrl,
  Value<String?> previewUrl,
  Value<String?> sha256Checksum,
  Value<String?> localDirPath,
  Value<int> sizeBytes,
  Value<bool> isDownloaded,
  Value<bool> isSelected,
  Value<int> rowid,
});

class $$VoicePacksTableFilterComposer
    extends Composer<_$AppDatabase, $VoicePacksTable> {
  $$VoicePacksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accent => $composableBuilder(
      column: $table.accent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gender => $composableBuilder(
      column: $table.gender, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modelType => $composableBuilder(
      column: $table.modelType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get speakerId => $composableBuilder(
      column: $table.speakerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sampleRate => $composableBuilder(
      column: $table.sampleRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteUrl => $composableBuilder(
      column: $table.remoteUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get previewUrl => $composableBuilder(
      column: $table.previewUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sha256Checksum => $composableBuilder(
      column: $table.sha256Checksum,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localDirPath => $composableBuilder(
      column: $table.localDirPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSelected => $composableBuilder(
      column: $table.isSelected, builder: (column) => ColumnFilters(column));
}

class $$VoicePacksTableOrderingComposer
    extends Composer<_$AppDatabase, $VoicePacksTable> {
  $$VoicePacksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accent => $composableBuilder(
      column: $table.accent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gender => $composableBuilder(
      column: $table.gender, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modelType => $composableBuilder(
      column: $table.modelType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get speakerId => $composableBuilder(
      column: $table.speakerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sampleRate => $composableBuilder(
      column: $table.sampleRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
      column: $table.remoteUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get previewUrl => $composableBuilder(
      column: $table.previewUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sha256Checksum => $composableBuilder(
      column: $table.sha256Checksum,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localDirPath => $composableBuilder(
      column: $table.localDirPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSelected => $composableBuilder(
      column: $table.isSelected, builder: (column) => ColumnOrderings(column));
}

class $$VoicePacksTableAnnotationComposer
    extends Composer<_$AppDatabase, $VoicePacksTable> {
  $$VoicePacksTableAnnotationComposer({
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

  GeneratedColumn<String> get accent =>
      $composableBuilder(column: $table.accent, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<String> get modelType =>
      $composableBuilder(column: $table.modelType, builder: (column) => column);

  GeneratedColumn<int> get speakerId =>
      $composableBuilder(column: $table.speakerId, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
      column: $table.sampleRate, builder: (column) => column);

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<String> get previewUrl => $composableBuilder(
      column: $table.previewUrl, builder: (column) => column);

  GeneratedColumn<String> get sha256Checksum => $composableBuilder(
      column: $table.sha256Checksum, builder: (column) => column);

  GeneratedColumn<String> get localDirPath => $composableBuilder(
      column: $table.localDirPath, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => column);

  GeneratedColumn<bool> get isSelected => $composableBuilder(
      column: $table.isSelected, builder: (column) => column);
}

class $$VoicePacksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VoicePacksTable,
    VoicePackRow,
    $$VoicePacksTableFilterComposer,
    $$VoicePacksTableOrderingComposer,
    $$VoicePacksTableAnnotationComposer,
    $$VoicePacksTableCreateCompanionBuilder,
    $$VoicePacksTableUpdateCompanionBuilder,
    (
      VoicePackRow,
      BaseReferences<_$AppDatabase, $VoicePacksTable, VoicePackRow>
    ),
    VoicePackRow,
    PrefetchHooks Function()> {
  $$VoicePacksTableTableManager(_$AppDatabase db, $VoicePacksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VoicePacksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VoicePacksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VoicePacksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> accent = const Value.absent(),
            Value<String> gender = const Value.absent(),
            Value<String> modelType = const Value.absent(),
            Value<int> speakerId = const Value.absent(),
            Value<int> sampleRate = const Value.absent(),
            Value<String> remoteUrl = const Value.absent(),
            Value<String?> previewUrl = const Value.absent(),
            Value<String?> sha256Checksum = const Value.absent(),
            Value<String?> localDirPath = const Value.absent(),
            Value<int> sizeBytes = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<bool> isSelected = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VoicePacksCompanion(
            id: id,
            name: name,
            accent: accent,
            gender: gender,
            modelType: modelType,
            speakerId: speakerId,
            sampleRate: sampleRate,
            remoteUrl: remoteUrl,
            previewUrl: previewUrl,
            sha256Checksum: sha256Checksum,
            localDirPath: localDirPath,
            sizeBytes: sizeBytes,
            isDownloaded: isDownloaded,
            isSelected: isSelected,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String accent,
            required String gender,
            required String modelType,
            Value<int> speakerId = const Value.absent(),
            Value<int> sampleRate = const Value.absent(),
            required String remoteUrl,
            Value<String?> previewUrl = const Value.absent(),
            Value<String?> sha256Checksum = const Value.absent(),
            Value<String?> localDirPath = const Value.absent(),
            required int sizeBytes,
            Value<bool> isDownloaded = const Value.absent(),
            Value<bool> isSelected = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VoicePacksCompanion.insert(
            id: id,
            name: name,
            accent: accent,
            gender: gender,
            modelType: modelType,
            speakerId: speakerId,
            sampleRate: sampleRate,
            remoteUrl: remoteUrl,
            previewUrl: previewUrl,
            sha256Checksum: sha256Checksum,
            localDirPath: localDirPath,
            sizeBytes: sizeBytes,
            isDownloaded: isDownloaded,
            isSelected: isSelected,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$VoicePacksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $VoicePacksTable,
    VoicePackRow,
    $$VoicePacksTableFilterComposer,
    $$VoicePacksTableOrderingComposer,
    $$VoicePacksTableAnnotationComposer,
    $$VoicePacksTableCreateCompanionBuilder,
    $$VoicePacksTableUpdateCompanionBuilder,
    (
      VoicePackRow,
      BaseReferences<_$AppDatabase, $VoicePacksTable, VoicePackRow>
    ),
    VoicePackRow,
    PrefetchHooks Function()>;
typedef $$LofiTracksTableCreateCompanionBuilder = LofiTracksCompanion Function({
  required String id,
  required String title,
  required String artist,
  required int durationSec,
  required String streamUrl,
  Value<String?> localPath,
  Value<String?> sha256Checksum,
  Value<bool> isBundled,
  Value<bool> isCached,
  Value<int> rowid,
});
typedef $$LofiTracksTableUpdateCompanionBuilder = LofiTracksCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> artist,
  Value<int> durationSec,
  Value<String> streamUrl,
  Value<String?> localPath,
  Value<String?> sha256Checksum,
  Value<bool> isBundled,
  Value<bool> isCached,
  Value<int> rowid,
});

class $$LofiTracksTableFilterComposer
    extends Composer<_$AppDatabase, $LofiTracksTable> {
  $$LofiTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get streamUrl => $composableBuilder(
      column: $table.streamUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sha256Checksum => $composableBuilder(
      column: $table.sha256Checksum,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isBundled => $composableBuilder(
      column: $table.isBundled, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCached => $composableBuilder(
      column: $table.isCached, builder: (column) => ColumnFilters(column));
}

class $$LofiTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $LofiTracksTable> {
  $$LofiTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get streamUrl => $composableBuilder(
      column: $table.streamUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sha256Checksum => $composableBuilder(
      column: $table.sha256Checksum,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isBundled => $composableBuilder(
      column: $table.isBundled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCached => $composableBuilder(
      column: $table.isCached, builder: (column) => ColumnOrderings(column));
}

class $$LofiTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LofiTracksTable> {
  $$LofiTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => column);

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get sha256Checksum => $composableBuilder(
      column: $table.sha256Checksum, builder: (column) => column);

  GeneratedColumn<bool> get isBundled =>
      $composableBuilder(column: $table.isBundled, builder: (column) => column);

  GeneratedColumn<bool> get isCached =>
      $composableBuilder(column: $table.isCached, builder: (column) => column);
}

class $$LofiTracksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LofiTracksTable,
    LofiTrackRow,
    $$LofiTracksTableFilterComposer,
    $$LofiTracksTableOrderingComposer,
    $$LofiTracksTableAnnotationComposer,
    $$LofiTracksTableCreateCompanionBuilder,
    $$LofiTracksTableUpdateCompanionBuilder,
    (
      LofiTrackRow,
      BaseReferences<_$AppDatabase, $LofiTracksTable, LofiTrackRow>
    ),
    LofiTrackRow,
    PrefetchHooks Function()> {
  $$LofiTracksTableTableManager(_$AppDatabase db, $LofiTracksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LofiTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LofiTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LofiTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> artist = const Value.absent(),
            Value<int> durationSec = const Value.absent(),
            Value<String> streamUrl = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<String?> sha256Checksum = const Value.absent(),
            Value<bool> isBundled = const Value.absent(),
            Value<bool> isCached = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LofiTracksCompanion(
            id: id,
            title: title,
            artist: artist,
            durationSec: durationSec,
            streamUrl: streamUrl,
            localPath: localPath,
            sha256Checksum: sha256Checksum,
            isBundled: isBundled,
            isCached: isCached,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String artist,
            required int durationSec,
            required String streamUrl,
            Value<String?> localPath = const Value.absent(),
            Value<String?> sha256Checksum = const Value.absent(),
            Value<bool> isBundled = const Value.absent(),
            Value<bool> isCached = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LofiTracksCompanion.insert(
            id: id,
            title: title,
            artist: artist,
            durationSec: durationSec,
            streamUrl: streamUrl,
            localPath: localPath,
            sha256Checksum: sha256Checksum,
            isBundled: isBundled,
            isCached: isCached,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LofiTracksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LofiTracksTable,
    LofiTrackRow,
    $$LofiTracksTableFilterComposer,
    $$LofiTracksTableOrderingComposer,
    $$LofiTracksTableAnnotationComposer,
    $$LofiTracksTableCreateCompanionBuilder,
    $$LofiTracksTableUpdateCompanionBuilder,
    (
      LofiTrackRow,
      BaseReferences<_$AppDatabase, $LofiTracksTable, LofiTrackRow>
    ),
    LofiTrackRow,
    PrefetchHooks Function()>;
typedef $$XiangqiMatchesTableCreateCompanionBuilder = XiangqiMatchesCompanion
    Function({
  Value<int> id,
  required String difficulty,
  required String playerSide,
  required String currentFen,
  Value<String> moveHistory,
  Value<String> fenHistoryJson,
  Value<String> status,
  Value<DateTime> updatedAt,
});
typedef $$XiangqiMatchesTableUpdateCompanionBuilder = XiangqiMatchesCompanion
    Function({
  Value<int> id,
  Value<String> difficulty,
  Value<String> playerSide,
  Value<String> currentFen,
  Value<String> moveHistory,
  Value<String> fenHistoryJson,
  Value<String> status,
  Value<DateTime> updatedAt,
});

class $$XiangqiMatchesTableFilterComposer
    extends Composer<_$AppDatabase, $XiangqiMatchesTable> {
  $$XiangqiMatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get playerSide => $composableBuilder(
      column: $table.playerSide, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currentFen => $composableBuilder(
      column: $table.currentFen, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get moveHistory => $composableBuilder(
      column: $table.moveHistory, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fenHistoryJson => $composableBuilder(
      column: $table.fenHistoryJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$XiangqiMatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $XiangqiMatchesTable> {
  $$XiangqiMatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get playerSide => $composableBuilder(
      column: $table.playerSide, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currentFen => $composableBuilder(
      column: $table.currentFen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get moveHistory => $composableBuilder(
      column: $table.moveHistory, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fenHistoryJson => $composableBuilder(
      column: $table.fenHistoryJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$XiangqiMatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $XiangqiMatchesTable> {
  $$XiangqiMatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => column);

  GeneratedColumn<String> get playerSide => $composableBuilder(
      column: $table.playerSide, builder: (column) => column);

  GeneratedColumn<String> get currentFen => $composableBuilder(
      column: $table.currentFen, builder: (column) => column);

  GeneratedColumn<String> get moveHistory => $composableBuilder(
      column: $table.moveHistory, builder: (column) => column);

  GeneratedColumn<String> get fenHistoryJson => $composableBuilder(
      column: $table.fenHistoryJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$XiangqiMatchesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $XiangqiMatchesTable,
    XiangqiMatchRow,
    $$XiangqiMatchesTableFilterComposer,
    $$XiangqiMatchesTableOrderingComposer,
    $$XiangqiMatchesTableAnnotationComposer,
    $$XiangqiMatchesTableCreateCompanionBuilder,
    $$XiangqiMatchesTableUpdateCompanionBuilder,
    (
      XiangqiMatchRow,
      BaseReferences<_$AppDatabase, $XiangqiMatchesTable, XiangqiMatchRow>
    ),
    XiangqiMatchRow,
    PrefetchHooks Function()> {
  $$XiangqiMatchesTableTableManager(
      _$AppDatabase db, $XiangqiMatchesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$XiangqiMatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$XiangqiMatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$XiangqiMatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> difficulty = const Value.absent(),
            Value<String> playerSide = const Value.absent(),
            Value<String> currentFen = const Value.absent(),
            Value<String> moveHistory = const Value.absent(),
            Value<String> fenHistoryJson = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              XiangqiMatchesCompanion(
            id: id,
            difficulty: difficulty,
            playerSide: playerSide,
            currentFen: currentFen,
            moveHistory: moveHistory,
            fenHistoryJson: fenHistoryJson,
            status: status,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String difficulty,
            required String playerSide,
            required String currentFen,
            Value<String> moveHistory = const Value.absent(),
            Value<String> fenHistoryJson = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              XiangqiMatchesCompanion.insert(
            id: id,
            difficulty: difficulty,
            playerSide: playerSide,
            currentFen: currentFen,
            moveHistory: moveHistory,
            fenHistoryJson: fenHistoryJson,
            status: status,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$XiangqiMatchesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $XiangqiMatchesTable,
    XiangqiMatchRow,
    $$XiangqiMatchesTableFilterComposer,
    $$XiangqiMatchesTableOrderingComposer,
    $$XiangqiMatchesTableAnnotationComposer,
    $$XiangqiMatchesTableCreateCompanionBuilder,
    $$XiangqiMatchesTableUpdateCompanionBuilder,
    (
      XiangqiMatchRow,
      BaseReferences<_$AppDatabase, $XiangqiMatchesTable, XiangqiMatchRow>
    ),
    XiangqiMatchRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$ReadingProgressesTableTableManager get readingProgresses =>
      $$ReadingProgressesTableTableManager(_db, _db.readingProgresses);
  $$BookmarksHighlightsTableTableManager get bookmarksHighlights =>
      $$BookmarksHighlightsTableTableManager(_db, _db.bookmarksHighlights);
  $$VoicePacksTableTableManager get voicePacks =>
      $$VoicePacksTableTableManager(_db, _db.voicePacks);
  $$LofiTracksTableTableManager get lofiTracks =>
      $$LofiTracksTableTableManager(_db, _db.lofiTracks);
  $$XiangqiMatchesTableTableManager get xiangqiMatches =>
      $$XiangqiMatchesTableTableManager(_db, _db.xiangqiMatches);
}
