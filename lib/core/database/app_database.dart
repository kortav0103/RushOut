import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Combined view model for the Discover Continue Reading card.
class ContinueReadingItem {
  const ContinueReadingItem({
    required this.book,
    required this.progress,
  });

  final BookRow book;
  final ReadingProgressRow progress;
}

/// Central Drift SQLite database implementing the ReadZen v1.1 ERD.
@DriftDatabase(
  tables: [
    Books,
    ReadingProgresses,
    BookmarksHighlights,
    VoicePacks,
    LofiTracks,
    XiangqiMatches,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Creates an isolated database instance for unit and widget testing.
  factory AppDatabase.forTesting(QueryExecutor executor) => AppDatabase(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Seeds bundled catalog, Lofi, and Voice Pack JSON payloads if tables are empty.
  Future<void> seedFromJson({
    required String catalogJson,
    required String lofiJson,
    required String voicesJson,
  }) async {
    await transaction(() async {
      final existingBookCount = await (select(books)..limit(1)).get();
      if (existingBookCount.isEmpty) {
        final decoded = jsonDecode(catalogJson) as Map<String, dynamic>;
        final bookList = (decoded['books'] as List<dynamic>? ?? const []);
        for (final raw in bookList) {
          final item = raw as Map<String, dynamic>;
          final genres = item['genres'] as List<dynamic>? ?? const [];
          await into(books).insertOnConflictUpdate(
            BooksCompanion.insert(
              id: item['id'] as String,
              title: item['title'] as String,
              author: item['author'] as String,
              description: Value(item['description'] as String? ?? ''),
              genresJson: Value(jsonEncode(genres)),
              remoteCoverUrl: Value(item['remote_cover_url'] as String?),
              remoteEpubUrl: Value(item['remote_epub_url'] as String?),
              localFilePath: Value(item['local_file_path'] as String?),
              sourceType: Value(item['source_type'] as String? ?? 'discover'),
              format: Value(item['format'] as String? ?? 'epub'),
              wordCount: Value((item['word_count'] as num?)?.toInt() ?? 0),
              fileSizeBytes: Value((item['file_size_bytes'] as num?)?.toInt() ?? 0),
              sha256Checksum: Value(item['sha256_checksum'] as String?),
              isTtsSupported: Value(item['is_tts_supported'] as bool? ?? true),
              isDownloaded: Value(item['is_downloaded'] as bool? ?? false),
              isFavorite: Value(item['is_favorite'] as bool? ?? false),
            ),
          );
        }
      }

      final existingLofiCount = await (select(lofiTracks)..limit(1)).get();
      if (existingLofiCount.isEmpty) {
        final decoded = jsonDecode(lofiJson) as Map<String, dynamic>;
        final trackList = (decoded['tracks'] as List<dynamic>? ?? const []);
        for (final raw in trackList) {
          final item = raw as Map<String, dynamic>;
          await into(lofiTracks).insertOnConflictUpdate(
            LofiTracksCompanion.insert(
              id: item['id'] as String,
              title: item['title'] as String,
              artist: item['artist'] as String? ?? 'ReadZen Studio',
              durationSec: (item['duration_sec'] as num?)?.toInt() ?? 180,
              streamUrl: item['stream_url'] as String,
              localPath: Value(item['local_path'] as String?),
              sha256Checksum: Value(item['sha256_checksum'] as String?),
              isBundled: Value(item['is_bundled'] as bool? ?? false),
              isCached: Value(item['is_cached'] as bool? ?? false),
            ),
          );
        }
      }

      final existingVoiceCount = await (select(voicePacks)..limit(1)).get();
      if (existingVoiceCount.isEmpty) {
        final decoded = jsonDecode(voicesJson) as Map<String, dynamic>;
        final voiceList = (decoded['voices'] as List<dynamic>? ?? const []);
        for (final raw in voiceList) {
          final item = raw as Map<String, dynamic>;
          await into(voicePacks).insertOnConflictUpdate(
            VoicePacksCompanion.insert(
              id: item['id'] as String,
              name: item['name'] as String,
              accent: item['accent'] as String? ?? 'US',
              gender: item['gender'] as String? ?? 'Female',
              modelType: item['model_type'] as String? ?? 'kokoro',
              speakerId: Value((item['speaker_id'] as num?)?.toInt() ?? 0),
              sampleRate: Value((item['sample_rate'] as num?)?.toInt() ?? 24000),
              remoteUrl: item['remote_url'] as String,
              previewUrl: Value(item['preview_url'] as String?),
              sha256Checksum: Value(item['sha256_checksum'] as String?),
              sizeBytes: (item['size_bytes'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
    });
  }

  /// Loads and seeds initial offline data from Flutter's bundled assets.
  Future<void> seedFromAssetBundle([AssetBundle? bundle]) async {
    final targetBundle = bundle ?? rootBundle;
    final catalogJson = await targetBundle.loadString('assets/seed/catalog_seed.json');
    final lofiJson = await targetBundle.loadString('assets/seed/lofi_seed.json');
    final voicesJson = await targetBundle.loadString('assets/seed/voices_seed.json');
    await seedFromJson(
      catalogJson: catalogJson,
      lofiJson: lofiJson,
      voicesJson: voicesJson,
    );
  }

  /// Searches Discover and Bundled Seed books locally by title, author, and genre.
  Future<List<BookRow>> searchDiscoverBooks({
    String query = '',
    String? genre,
  }) async {
    final rows = await (select(books)
          ..where((t) => t.sourceType.isIn(['discover', 'bundled_seed']))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .get();
    return _filterBooks(rows, query: query, genre: genre);
  }

  /// Watches Discover and Bundled Seed books reactively with optional search/genre filter.
  Stream<List<BookRow>> watchDiscoverBooks({
    String query = '',
    String? genre,
  }) {
    final stmt = select(books)
      ..where((t) => t.sourceType.isIn(['discover', 'bundled_seed']))
      ..orderBy([(t) => OrderingTerm.asc(t.title)]);
    return stmt.watch().map((rows) => _filterBooks(rows, query: query, genre: genre));
  }

  List<BookRow> _filterBooks(
    List<BookRow> rows, {
    required String query,
    String? genre,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedGenre = genre?.trim().toLowerCase();
    return rows.where((book) {
      final matchesQuery = normalizedQuery.isEmpty ||
          book.title.toLowerCase().contains(normalizedQuery) ||
          book.author.toLowerCase().contains(normalizedQuery);
      if (!matchesQuery) return false;
      if (normalizedGenre == null ||
          normalizedGenre.isEmpty ||
          normalizedGenre == 'all') {
        return true;
      }
      final genres = (jsonDecode(book.genresJson) as List<dynamic>)
          .map((e) => e.toString().toLowerCase());
      return genres.contains(normalizedGenre);
    }).toList();
  }

  /// Watches books downloaded from Discover/Seed for offline reading.
  Stream<List<BookRow>> watchDownloadedBooks() {
    return (select(books)
          ..where(
            (t) =>
                t.isDownloaded.equals(true) &
                t.sourceType.equals('local_upload').not(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Watches user-favorited books across Discover and Library.
  Stream<List<BookRow>> watchFavoriteBooks() {
    return (select(books)
          ..where((t) => t.isFavorite.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch();
  }

  /// Watches locally imported user files (.epub, .pdf, .txt).
  Stream<List<BookRow>> watchUploadedBooks() {
    return (select(books)
          ..where((t) => t.sourceType.equals('local_upload'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Watches a single book record by ID.
  Stream<BookRow?> watchBookById(String bookId) {
    return (select(books)..where((t) => t.id.equals(bookId)))
        .watchSingleOrNull();
  }

  /// Watches the single most recently read, available book for the Continue Reading card.
  Stream<ContinueReadingItem?> watchContinueReading() {
    final query = select(readingProgresses).join([
      innerJoin(books, books.id.equalsExp(readingProgresses.bookId)),
    ])
      ..where(
        books.isDownloaded.equals(true) |
            books.sourceType.equals('local_upload'),
      )
      ..orderBy([OrderingTerm.desc(readingProgresses.updatedAt)])
      ..limit(1);

    return query.watchSingleOrNull().map((row) {
      if (row == null) return null;
      return ContinueReadingItem(
        book: row.readTable(books),
        progress: row.readTable(readingProgresses),
      );
    });
  }

  /// Toggles favorite status on a book and returns the updated state.
  Future<bool> toggleFavorite(String bookId) async {
    return transaction(() async {
      final current = await (select(books)..where((t) => t.id.equals(bookId)))
          .getSingleOrNull();
      if (current == null) return false;
      final nextState = !current.isFavorite;
      await (update(books)..where((t) => t.id.equals(bookId))).write(
        BooksCompanion(isFavorite: Value(nextState)),
      );
      return nextState;
    });
  }

  /// Marks a catalog/seed book as downloaded with its local file path.
  Future<void> markBookDownloaded({
    required String bookId,
    required String localFilePath,
  }) async {
    await (update(books)..where((t) => t.id.equals(bookId))).write(
      BooksCompanion(
        isDownloaded: const Value(true),
        localFilePath: Value(localFilePath),
      ),
    );
  }

  /// Inserts a locally imported book into the My Uploads section.
  Future<void> insertLocalBook({
    required String id,
    required String title,
    required String author,
    required String localFilePath,
    required String format,
    int wordCount = 0,
    int fileSizeBytes = 0,
    bool isTtsSupported = true,
  }) async {
    await into(books).insertOnConflictUpdate(
      BooksCompanion.insert(
        id: id,
        title: title,
        author: author,
        localFilePath: Value(localFilePath),
        sourceType: const Value('local_upload'),
        format: Value(format),
        wordCount: Value(wordCount),
        fileSizeBytes: Value(fileSizeBytes),
        isTtsSupported: Value(isTtsSupported),
        isDownloaded: const Value(true),
      ),
    );
  }

  /// Creates or updates reading progress for a book.
  Future<void> upsertReadingProgress({
    required String bookId,
    required int chapterIndex,
    required int sentenceIndex,
    required double scrollOffset,
    required double progressPercent,
    DateTime? updatedAt,
  }) async {
    await into(readingProgresses).insertOnConflictUpdate(
      ReadingProgressesCompanion.insert(
        bookId: bookId,
        chapterIndex: Value(chapterIndex),
        sentenceIndex: Value(sentenceIndex),
        scrollOffset: Value(scrollOffset),
        progressPercent: Value(progressPercent.clamp(0.0, 1.0)),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  /// Removes downloaded/uploaded book content and reading progress safely.
  Future<void> deleteBookContent(String bookId) async {
    await transaction(() async {
      final book = await (select(books)..where((t) => t.id.equals(bookId)))
          .getSingleOrNull();
      if (book == null) return;

      await (delete(readingProgresses)..where((t) => t.bookId.equals(bookId)))
          .go();

      if (book.sourceType == 'local_upload') {
        await (delete(books)..where((t) => t.id.equals(bookId))).go();
      } else {
        await (update(books)..where((t) => t.id.equals(bookId))).write(
          const BooksCompanion(
            isDownloaded: Value(false),
            localFilePath: Value(null),
          ),
        );
      }
    });
  }

  Future<List<LofiTrackRow>> getAllLofiTracks() => select(lofiTracks).get();
  Stream<List<LofiTrackRow>> watchAllLofiTracks() => select(lofiTracks).watch();

  Future<List<VoicePackRow>> getAllVoicePacks() => select(voicePacks).get();
  Stream<List<VoicePackRow>> watchAllVoicePacks() => select(voicePacks).watch();
}
