import 'package:drift/drift.dart';

/// Books table storing catalog metadata, local uploads, and bundled seed entries.
@DataClassName('BookRow')
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get genresJson => text().withDefault(const Constant('[]'))();
  TextColumn get remoteCoverUrl => text().nullable()();
  TextColumn get localCoverPath => text().nullable()();
  TextColumn get remoteEpubUrl => text().nullable()();
  TextColumn get localFilePath => text().nullable()();
  TextColumn get sourceType => text().withDefault(const Constant('discover'))();
  TextColumn get format => text().withDefault(const Constant('epub'))();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  IntColumn get fileSizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get sha256Checksum => text().nullable()();
  BoolColumn get isTtsSupported => boolean().withDefault(const Constant(true))();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reading progress table tracking chapter/page, sentence, and scroll position.
@DataClassName('ReadingProgressRow')
class ReadingProgresses extends Table {
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterIndex => integer().withDefault(const Constant(0))();
  IntColumn get sentenceIndex => integer().withDefault(const Constant(0))();
  RealColumn get scrollOffset => real().withDefault(const Constant(0.0))();
  RealColumn get progressPercent => real().withDefault(const Constant(0.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {bookId};
}

/// Bookmarks and text highlights table with sentence & character offset precision.
@DataClassName('BookmarkHighlightRow')
class BookmarksHighlights extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()(); // 'bookmark' | 'highlight'
  IntColumn get chapterIndex => integer()();
  IntColumn get sentenceIndex => integer()();
  IntColumn get charStart => integer().withDefault(const Constant(0))();
  IntColumn get charEnd => integer().withDefault(const Constant(0))();
  TextColumn get selectedText => text().withDefault(const Constant(''))();
  TextColumn get colorHex => text().withDefault(const Constant('#FFE082'))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// AI TTS Voice Packs table for Kokoro-82M and Piper models.
@DataClassName('VoicePackRow')
class VoicePacks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get accent => text()(); // 'US' | 'UK'
  TextColumn get gender => text()(); // 'Male' | 'Female'
  TextColumn get modelType => text()(); // 'kokoro' | 'piper'
  IntColumn get speakerId => integer().withDefault(const Constant(0))();
  IntColumn get sampleRate => integer().withDefault(const Constant(24000))();
  TextColumn get remoteUrl => text()();
  TextColumn get previewUrl => text().nullable()();
  TextColumn get sha256Checksum => text().nullable()();
  TextColumn get localDirPath => text().nullable()();
  IntColumn get sizeBytes => integer()();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  BoolColumn get isSelected => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lofi background music tracks table.
@DataClassName('LofiTrackRow')
class LofiTracks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  IntColumn get durationSec => integer()();
  TextColumn get streamUrl => text()();
  TextColumn get localPath => text().nullable()();
  TextColumn get sha256Checksum => text().nullable()();
  BoolColumn get isBundled => boolean().withDefault(const Constant(false))();
  BoolColumn get isCached => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Xiangqi match state and FEN history table.
@DataClassName('XiangqiMatchRow')
class XiangqiMatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get difficulty => text()(); // 'easy' | 'medium' | 'hard'
  TextColumn get playerSide => text()(); // 'red' | 'black'
  TextColumn get currentFen => text()();
  TextColumn get moveHistory => text().withDefault(const Constant(''))();
  TextColumn get fenHistoryJson => text().withDefault(const Constant('[]'))();
  TextColumn get status => text().withDefault(const Constant('ongoing'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
