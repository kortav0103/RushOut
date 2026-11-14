import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

/// Tab 2: Personal Library segmented into Downloaded, Favorites, and My Uploads.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Downloaded'),
              Tab(text: 'Favorites'),
              Tab(text: 'My Uploads'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LibraryBookList(
              booksAsync: ref.watch(downloadedBooksProvider),
              emptyMessage:
                  'No downloaded books yet. Explore Discover to download classics.',
              emptyActionLabel: 'Explore Discover',
              onEmptyAction: () => context.go('/discover'),
              onRetry: () => ref.invalidate(downloadedBooksProvider),
              onTapBook: (book) => context.push('/reader/${book.id}'),
              onDeleteBook: (book) =>
                  ref.read(bookActionsProvider).deleteBookContent(book.id),
            ),
            _LibraryBookList(
              booksAsync: ref.watch(favoriteBooksProvider),
              emptyMessage: 'Tap the heart icon on any book to save it here.',
              onRetry: () => ref.invalidate(favoriteBooksProvider),
              onTapBook: (book) {
                if (book.isDownloaded || book.sourceType == 'local_upload') {
                  context.push('/reader/${book.id}');
                } else {
                  context.push('/book/${book.id}');
                }
              },
            ),
            _LibraryBookList(
              booksAsync: ref.watch(uploadedBooksProvider),
              emptyMessage:
                  'Import your own .epub, .pdf, or .txt files to read and listen.',
              emptyActionLabel: 'Import Now',
              onEmptyAction: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Local file importer activates in Milestone 3.',
                    ),
                  ),
                );
              },
              onRetry: () => ref.invalidate(uploadedBooksProvider),
              onTapBook: (book) => context.push('/reader/${book.id}'),
              onDeleteBook: (book) =>
                  ref.read(bookActionsProvider).deleteBookContent(book.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryBookList extends StatelessWidget {
  const _LibraryBookList({
    required this.booksAsync,
    required this.emptyMessage,
    required this.onRetry,
    required this.onTapBook,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.onDeleteBook,
  });

  final AsyncValue<List<BookRow>> booksAsync;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final VoidCallback onRetry;
  final void Function(BookRow book) onTapBook;
  final Future<void> Function(BookRow book)? onDeleteBook;

  @override
  Widget build(BuildContext context) {
    return booksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load your library.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
      data: (books) {
        if (books.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.library_books_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(emptyMessage, textAlign: TextAlign.center),
                  if (emptyActionLabel != null && onEmptyAction != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onEmptyAction,
                      child: Text(emptyActionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: books.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final book = books[index];
            return Card(
              child: ListTile(
                title: Text(book.title),
                subtitle: Text(book.author),
                onTap: () => onTapBook(book),
                trailing: onDeleteBook != null
                    ? IconButton(
                        tooltip: 'Delete book',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onDeleteBook!(book),
                      )
                    : const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }
}
