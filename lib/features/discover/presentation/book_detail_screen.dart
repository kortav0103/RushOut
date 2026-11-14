import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_providers.dart';

/// Displays metadata, favorite toggle, and offline reading/download actions for a book.
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookByIdProvider(bookId));

    return Scaffold(
      appBar: AppBar(title: const Text('Book Details')),
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load book details.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(bookByIdProvider(bookId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (book) {
          if (book == null) {
            return const Center(child: Text('Book not found in local catalog.'));
          }
          final genres = (jsonDecode(book.genresJson) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
          final synopsis = book.description.trim().isEmpty
              ? 'No synopsis available for this public domain edition.'
              : book.description;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'by ${book.author}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: genres.map((g) => Chip(label: Text(g))).toList(),
                ),
                const SizedBox(height: 16),
                Text(synopsis, style: Theme.of(context).textTheme.bodyLarge),
                const Spacer(),
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: book.isFavorite
                          ? 'Remove from Favorites'
                          : 'Add to Favorites',
                      onPressed: () =>
                          ref.read(bookActionsProvider).toggleFavorite(book.id),
                      icon: Icon(
                        book.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: book.isDownloaded
                            ? () => context.push('/reader/${book.id}')
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'EPUB downloader activates in Milestone 2.',
                                    ),
                                  ),
                                );
                              },
                        icon: Icon(
                          book.isDownloaded
                              ? Icons.menu_book_rounded
                              : Icons.download_rounded,
                        ),
                        label: Text(book.isDownloaded ? 'Read Now' : 'Download'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
