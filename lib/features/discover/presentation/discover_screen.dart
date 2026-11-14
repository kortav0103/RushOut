import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

const _discoverGenres = [
  'All',
  'Classics',
  'Fiction',
  'Mystery',
  'Romance',
  'Gothic',
  'Philosophy',
  'Science Fiction',
];

/// Tab 1: Discover screen with search, genre filter, Continue Reading, and Lofi trigger.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openLofiSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lofi Sanctuary',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Midnight Rain — ReadZen Studio (Bundled Offline Track)',
              ),
              const SizedBox(height: 16),
              const Text(
                'Background audio controls and Sleep Timer will connect in Milestone 2.',
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(discoverFilterProvider);
    final booksAsync = ref.watch(discoverBooksProvider);
    final continueAsync = ref.watch(continueReadingProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              label: 'Open Lofi Music Player',
              button: true,
              child: InkWell(
                key: const Key('lofi_top_right_button'),
                customBorder: const CircleBorder(),
                onTap: () => _openLofiSheet(context),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.headphones_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('discover_search_field'),
                    controller: _searchController,
                    onChanged: (value) =>
                        ref.read(discoverFilterProvider.notifier).setQuery(value),
                    decoration: InputDecoration(
                      hintText: 'Search English titles or authors...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: filter.query.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(discoverFilterProvider.notifier)
                                    .setQuery('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _discoverGenres.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final genre = _discoverGenres[index];
                        final selected = filter.selectedGenre == genre;
                        return ChoiceChip(
                          label: Text(genre),
                          selected: selected,
                          onSelected: (_) => ref
                              .read(discoverFilterProvider.notifier)
                              .setGenre(genre),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  continueAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (item) {
                      if (item == null) return const SizedBox.shrink();
                      return _ContinueReadingCard(item: item);
                    },
                  ),
                ],
              ),
            ),
          ),
          booksAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: _DiscoverErrorState(
                onRetry: () => ref.invalidate(discoverBooksProvider),
              ),
            ),
            data: (books) {
              if (books.isEmpty) {
                return SliverFillRemaining(
                  child: _DiscoverEmptyState(
                    query: filter.query,
                    onResetFilters: () {
                      _searchController.clear();
                      ref.read(discoverFilterProvider.notifier).clear();
                    },
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _CatalogBookCard(
                    book: books[index],
                    onToggleFavorite: () => ref
                        .read(bookActionsProvider)
                        .toggleFavorite(books[index].id),
                    onTap: () => context.push('/book/${books[index].id}'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.item});

  final ContinueReadingItem item;

  @override
  Widget build(BuildContext context) {
    final percentLabel = (item.progress.progressPercent * 100).round();
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('continue_reading_card'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/reader/${item.book.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.menu_book_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Reading · $percentLabel%',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: item.progress.progressPercent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogBookCard extends StatelessWidget {
  const _CatalogBookCard({
    required this.book,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final BookRow book;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final genres = (jsonDecode(book.genresJson) as List<dynamic>)
        .take(2)
        .map((e) => e.toString())
        .join(' · ');
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 74,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (genres.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        genres,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: book.isFavorite
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
                onPressed: onToggleFavorite,
                icon: Icon(
                  book.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: book.isFavorite ? colorScheme.error : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverEmptyState extends StatelessWidget {
  const _DiscoverEmptyState({
    required this.query,
    required this.onResetFilters,
  });

  final String query;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final message = query.trim().isEmpty
        ? 'No books match the selected genre.'
        : "No books found for '$query'. Try another title or import your own file in Library.";
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onResetFilters,
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverErrorState extends StatelessWidget {
  const _DiscoverErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            const Text('Unable to load the catalog right now.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
