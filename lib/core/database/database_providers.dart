import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Root Drift database provider overridden during app startup or test setup.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider must be overridden at startup');
});

/// Holds the active Discover search text and selected genre filter.
class DiscoverFilterState {
  const DiscoverFilterState({
    this.query = '',
    this.selectedGenre = 'All',
  });

  final String query;
  final String selectedGenre;

  DiscoverFilterState copyWith({
    String? query,
    String? selectedGenre,
  }) {
    return DiscoverFilterState(
      query: query ?? this.query,
      selectedGenre: selectedGenre ?? this.selectedGenre,
    );
  }
}

class DiscoverFilterNotifier extends Notifier<DiscoverFilterState> {
  @override
  DiscoverFilterState build() => const DiscoverFilterState();

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setGenre(String genre) {
    state = state.copyWith(selectedGenre: genre);
  }

  void clear() {
    state = const DiscoverFilterState();
  }
}

final discoverFilterProvider =
    NotifierProvider<DiscoverFilterNotifier, DiscoverFilterState>(
  DiscoverFilterNotifier.new,
);

/// Watches filtered Discover books reactively from Drift.
final discoverBooksProvider = StreamProvider<List<BookRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final filter = ref.watch(discoverFilterProvider);
  return db.watchDiscoverBooks(
    query: filter.query,
    genre: filter.selectedGenre == 'All' ? null : filter.selectedGenre,
  );
});

/// Watches the most recently read book for the Continue Reading card.
final continueReadingProvider = StreamProvider<ContinueReadingItem?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchContinueReading();
});

/// Watches Library sub-tab lists.
final downloadedBooksProvider = StreamProvider<List<BookRow>>((ref) {
  return ref.watch(appDatabaseProvider).watchDownloadedBooks();
});

final favoriteBooksProvider = StreamProvider<List<BookRow>>((ref) {
  return ref.watch(appDatabaseProvider).watchFavoriteBooks();
});

final uploadedBooksProvider = StreamProvider<List<BookRow>>((ref) {
  return ref.watch(appDatabaseProvider).watchUploadedBooks();
});

final bookByIdProvider = StreamProvider.family<BookRow?, String>((ref, bookId) {
  return ref.watch(appDatabaseProvider).watchBookById(bookId);
});

/// Repository actions exposed to UI controllers so UI never accesses DAOs directly.
class BookActionsController {
  BookActionsController(this._db);

  final AppDatabase _db;

  Future<bool> toggleFavorite(String bookId) => _db.toggleFavorite(bookId);

  Future<void> deleteBookContent(String bookId) =>
      _db.deleteBookContent(bookId);
}

final bookActionsProvider = Provider<BookActionsController>((ref) {
  return BookActionsController(ref.watch(appDatabaseProvider));
});
