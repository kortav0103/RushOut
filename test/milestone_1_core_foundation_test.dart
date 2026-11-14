import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readzen/app.dart';
import 'package:readzen/core/database/app_database.dart';
import 'package:readzen/core/database/database_providers.dart';
import 'package:readzen/core/theme/app_theme.dart';
import 'package:readzen/core/theme/theme_controller.dart';

const _sampleCatalogJson = '''
{
  "updated_at": "2026-11-14T00:00:00Z",
  "books": [
    {
      "id": "seed-sherlock-bohemia",
      "title": "The Adventures of Sherlock Holmes (A Scandal in Bohemia)",
      "author": "Arthur Conan Doyle",
      "description": "Bundled classic detective story.",
      "genres": ["Mystery", "Classics", "Fiction"],
      "remote_cover_url": "https://cdn.readzen.app/v1/covers/seed-sherlock.webp",
      "remote_epub_url": "https://cdn.readzen.app/v1/epubs/seed-sherlock.epub",
      "local_file_path": "assets/seed/sample_classic.txt",
      "source_type": "bundled_seed",
      "format": "txt",
      "word_count": 850,
      "file_size_bytes": 5120,
      "sha256_checksum": "0001",
      "is_downloaded": true
    },
    {
      "id": "se-pride-and-prejudice",
      "title": "Pride and Prejudice",
      "author": "Jane Austen",
      "description": "Classic novel of manners.",
      "genres": ["Romance", "Classics"],
      "remote_cover_url": "https://cdn.readzen.app/v1/covers/se-pride.webp",
      "remote_epub_url": "https://cdn.readzen.app/v1/epubs/se-pride.epub",
      "word_count": 122189,
      "file_size_bytes": 684210,
      "sha256_checksum": "0002"
    },
    {
      "id": "se-frankenstein",
      "title": "Frankenstein",
      "author": "Mary Shelley",
      "description": "Gothic science fiction classic.",
      "genres": ["Science Fiction", "Gothic"],
      "remote_cover_url": "https://cdn.readzen.app/v1/covers/se-frankenstein.webp",
      "remote_epub_url": "https://cdn.readzen.app/v1/epubs/se-frankenstein.epub",
      "word_count": 75040,
      "file_size_bytes": 492100,
      "sha256_checksum": "0003"
    }
  ]
}
''';

const _sampleLofiJson = '''
{
  "tracks": [
    {
      "id": "lofi-rain",
      "title": "Midnight Rain",
      "artist": "ReadZen Studio",
      "duration_sec": 185,
      "stream_url": "https://cdn.readzen.app/v1/lofi/midnight_rain.aac",
      "local_path": "assets/seed/lofi_rain_preview.aac",
      "sha256_checksum": "1111",
      "is_bundled": true,
      "is_cached": true
    },
    {
      "id": "lofi-cafe",
      "title": "Warm Sepia Cafe",
      "artist": "ReadZen Studio",
      "duration_sec": 212,
      "stream_url": "https://cdn.readzen.app/v1/lofi/warm_sepia_cafe.aac",
      "sha256_checksum": "2222",
      "is_bundled": false,
      "is_cached": false
    }
  ]
}
''';

const _sampleVoicesJson = '''
{
  "voices": [
    {
      "id": "kokoro-af-heart",
      "name": "Heart (US Female)",
      "accent": "US",
      "gender": "Female",
      "model_type": "kokoro",
      "speaker_id": 0,
      "sample_rate": 24000,
      "size_bytes": 125829120,
      "remote_url": "https://cdn.readzen.app/v1/voices/kokoro.tar.bz2",
      "preview_url": "https://cdn.readzen.app/v1/voices/previews/heart.wav",
      "sha256_checksum": "aaaa"
    },
    {
      "id": "piper-en-gb-alba",
      "name": "Alba (UK Female)",
      "accent": "UK",
      "gender": "Female",
      "model_type": "piper",
      "speaker_id": 0,
      "sample_rate": 22050,
      "size_bytes": 62914560,
      "remote_url": "https://cdn.readzen.app/v1/voices/alba.tar.bz2",
      "preview_url": "https://cdn.readzen.app/v1/voices/previews/alba.wav",
      "sha256_checksum": "cccc"
    }
  ]
}
''';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 1 — Drift SQLite v1.1 & Offline Seed (AC-1.1..AC-1.5, AC-4.1, AC-4.4, NFR-04)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.seedFromJson(
        catalogJson: _sampleCatalogJson,
        lofiJson: _sampleLofiJson,
        voicesJson: _sampleVoicesJson,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('AC-1.1 & NFR-04: Cold-start seed populates books, lofi tracks, and voice packs idempotently', () async {
      final initialBooks = await db.searchDiscoverBooks();
      final lofiTracks = await db.getAllLofiTracks();
      final voicePacks = await db.getAllVoicePacks();

      expect(initialBooks.length, 3);
      expect(lofiTracks.length, 2);
      expect(voicePacks.length, 2);
      expect(
        initialBooks.firstWhere((b) => b.id == 'seed-sherlock-bohemia').isDownloaded,
        isTrue,
      );

      // Re-seeding must be idempotent and not duplicate rows.
      await db.seedFromJson(
        catalogJson: _sampleCatalogJson,
        lofiJson: _sampleLofiJson,
        voicesJson: _sampleVoicesJson,
      );
      expect((await db.searchDiscoverBooks()).length, 3);
      expect((await db.getAllLofiTracks()).length, 2);
      expect((await db.getAllVoicePacks()).length, 2);
    });

    test('AC-1.2: Discover search filters by title, author, and genre in < 300ms', () async {
      final sw = Stopwatch()..start();
      final byTitle = await db.searchDiscoverBooks(query: 'Sherlock');
      final byAuthor = await db.searchDiscoverBooks(query: 'Austen');
      final byGenre = await db.searchDiscoverBooks(genre: 'Gothic');
      final combined = await db.searchDiscoverBooks(
        query: 'Mary',
        genre: 'Science Fiction',
      );
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(300));
      expect(byTitle.map((b) => b.id), ['seed-sherlock-bohemia']);
      expect(byAuthor.map((b) => b.id), ['se-pride-and-prejudice']);
      expect(byGenre.map((b) => b.id), ['se-frankenstein']);
      expect(combined.map((b) => b.id), ['se-frankenstein']);
    });

    test('AC-1.3: Toggling Favorite immediately updates watchFavoriteBooks stream offline', () async {
      expect(await db.watchFavoriteBooks().first, isEmpty);

      await db.toggleFavorite('se-pride-and-prejudice');
      final afterFav = await db.watchFavoriteBooks().first;
      expect(afterFav.map((b) => b.id), ['se-pride-and-prejudice']);

      await db.toggleFavorite('se-pride-and-prejudice');
      expect(await db.watchFavoriteBooks().first, isEmpty);
    });

    test('AC-1.5 & AC-4.4: Continue Reading tracks most recent book and reactively updates on delete', () async {
      expect(await db.watchContinueReading().first, isNull);

      // Simulate downloading Pride and Prejudice so both books are readable.
      await db.markBookDownloaded(
        bookId: 'se-pride-and-prejudice',
        localFilePath: '/docs/se-pride-and-prejudice.epub',
      );

      final t1 = DateTime(2026, 11, 14, 10, 0);
      final t2 = DateTime(2026, 11, 14, 10, 30);

      await db.upsertReadingProgress(
        bookId: 'seed-sherlock-bohemia',
        chapterIndex: 0,
        sentenceIndex: 4,
        scrollOffset: 120.0,
        progressPercent: 0.25,
        updatedAt: t1,
      );

      await db.upsertReadingProgress(
        bookId: 'se-pride-and-prejudice',
        chapterIndex: 2,
        sentenceIndex: 10,
        scrollOffset: 340.0,
        progressPercent: 0.45,
        updatedAt: t2,
      );

      final latest = await db.watchContinueReading().first;
      expect(latest, isNotNull);
      expect(latest!.book.id, 'se-pride-and-prejudice');
      expect(latest.progress.chapterIndex, 2);
      expect(latest.progress.sentenceIndex, 10);
      expect(latest.progress.progressPercent, closeTo(0.45, 0.001));

      // Deleting the active book removes it from Downloaded & Continue Reading, falling back to Sherlock.
      await db.deleteBookContent('se-pride-and-prejudice');
      final nextLatest = await db.watchContinueReading().first;
      expect(nextLatest, isNotNull);
      expect(nextLatest!.book.id, 'seed-sherlock-bohemia');

      await db.deleteBookContent('seed-sherlock-bohemia');
      expect(await db.watchContinueReading().first, isNull);
    });

    test('AC-4.1: Library segregates Downloaded, Favorites, and My Uploads streams cleanly', () async {
      await db.markBookDownloaded(
        bookId: 'se-frankenstein',
        localFilePath: '/docs/se-frankenstein.epub',
      );
      await db.toggleFavorite('se-pride-and-prejudice');
      await db.insertLocalBook(
        id: 'local-notes-1',
        title: 'Clean Architecture Notes',
        author: 'Local Author',
        localFilePath: '/docs/notes.txt',
        format: 'txt',
        wordCount: 500,
        fileSizeBytes: 2048,
      );

      final downloaded = await db.watchDownloadedBooks().first;
      final favorites = await db.watchFavoriteBooks().first;
      final uploads = await db.watchUploadedBooks().first;

      expect(
        downloaded.map((b) => b.id).toSet(),
        {'seed-sherlock-bohemia', 'se-frankenstein'},
      );
      expect(favorites.map((b) => b.id), ['se-pride-and-prejudice']);
      expect(uploads.map((b) => b.id), ['local-notes-1']);
    });
  });

  group('Milestone 1 — Themes & WCAG AA Contrast (AC-8.1)', () {
    test('AC-8.1: ThemeController switches all 3 themes, persists in SharedPreferences, and passes WCAG AA (>= 4.5:1)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(themeControllerProvider), AppThemeMode.paperLight);

      await container.read(themeControllerProvider.notifier).setTheme(AppThemeMode.warmSepia);
      expect(container.read(themeControllerProvider), AppThemeMode.warmSepia);

      await container.read(themeControllerProvider.notifier).setTheme(AppThemeMode.midnightDark);
      expect(container.read(themeControllerProvider), AppThemeMode.midnightDark);

      // Re-create container with same SharedPreferences to verify persistence across restarts.
      final restoredContainer = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(restoredContainer.dispose);
      expect(restoredContainer.read(themeControllerProvider), AppThemeMode.midnightDark);

      // Verify WCAG AA contrast >= 4.5:1 on primary text/background for all 3 themes.
      for (final mode in AppThemeMode.values) {
        final themeData = AppTheme.fromMode(mode);
        final scheme = themeData.colorScheme;
        final ratio = AppTheme.contrastRatio(scheme.onSurface, scheme.surface);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'Theme ${mode.name} failed WCAG AA contrast: $ratio',
        );
      }
    });
  });

  group('Milestone 1 — 4-Tab StatefulShellRoute & App Shell (AC-3.1, AC-4.1, AC-8.1)', () {
    testWidgets('Renders 4 bottom tabs, top-right Lofi button, and preserves tab switching', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.seedFromJson(
        catalogJson: _sampleCatalogJson,
        lofiJson: _sampleLofiJson,
        voicesJson: _sampleVoicesJson,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const ReadZenApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 4 bottom navigation tabs exist.
      expect(find.text('Discover'), findsWidgets);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Game'), findsOneWidget);
      expect(find.text('Setting'), findsOneWidget);

      // Verify top-right circular Lofi button exists on Discover tab (AC-3.1).
      expect(find.byKey(const Key('lofi_top_right_button')), findsOneWidget);

      // Verify catalog books from offline seed are visible on Discover tab (AC-1.1).
      expect(find.text('Pride and Prejudice'), findsOneWidget);

      // Navigate to Tab 2 (Library) and verify 3 sub-tabs (AC-4.1).
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      expect(find.text('Downloaded'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('My Uploads'), findsOneWidget);

      // Navigate to Tab 3 (Game) and verify Xiangqi difficulty choices.
      await tester.tap(find.text('Game'));
      await tester.pumpAndSettle();
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);

      // Navigate to Tab 4 (Setting) and switch theme to Warm Sepia (AC-8.1).
      await tester.tap(find.text('Setting'));
      await tester.pumpAndSettle();
      expect(find.text('Paper Light'), findsOneWidget);
      expect(find.text('Warm Sepia'), findsOneWidget);
      expect(find.text('Midnight Dark'), findsOneWidget);

      await tester.tap(find.text('Warm Sepia'));
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(
        materialApp.theme?.scaffoldBackgroundColor,
        AppTheme.fromMode(AppThemeMode.warmSepia).scaffoldBackgroundColor,
      );

      // Verify state preservation when switching back to Discover.
      await tester.tap(find.text('Discover').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lofi_top_right_button')), findsOneWidget);

      // Verify catalog_seed.json schema validity check helper.
      final parsedSeed = jsonDecode(_sampleCatalogJson) as Map<String, dynamic>;
      expect(parsedSeed['books'], isA<List<dynamic>>());

      // Unmount widget tree and flush Drift's zero-duration StreamQueryStore cleanup timer.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
      await db.close();
    });
  });
}
