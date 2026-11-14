import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';

/// Reader screen shell displaying bundled or local text content.
class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookByIdProvider(bookId));

    return Scaffold(
      appBar: AppBar(title: const Text('Reader')),
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Unable to open book.')),
        data: (book) {
          if (book == null) {
            return const Center(child: Text('Book not found.'));
          }
          if (book.localFilePath == 'assets/seed/sample_classic.txt') {
            return FutureBuilder<String>(
              future: rootBundle.loadString('assets/seed/sample_classic.txt'),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Failed to read bundled sample text.'),
                  );
                }
                final text = snapshot.data ?? '';
                if (text.trim().isEmpty) {
                  return const Center(
                    child: Text('This section has no text content.'),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                  ),
                );
              },
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${book.title}\n\nEPUB/PDF normalization & AI TTS playback arrive in Milestones 3–4.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
