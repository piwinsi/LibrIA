import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../models/book.dart';
import '../../../providers/library_provider.dart';
import 'update_progress_screen.dart';

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  String _statusLabel(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.pending:
        return 'Pendiente';
      case ReadingStatus.reading:
        return 'En lectura';
      case ReadingStatus.completed:
        return 'Leído';
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = context.watch<LibraryProvider>().bookById(bookId);

    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 140,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 56,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            book.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            book.author,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              Chip(label: Text(book.genre)),
              Chip(label: Text(_statusLabel(book.status))),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Progreso: ${book.currentPage} / ${book.totalPages} páginas '
            '(${(book.progress * 100).round()}%)',
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: book.progress),
          const SizedBox(height: 24),
          Text(
            'Descripción',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(book.description),
          const SizedBox(height: 24),
          if (book.status == ReadingStatus.completed)
            _RatingSelector(book: book)
          else
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UpdateProgressScreen(book: book),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Actualizar progreso'),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingSelector extends StatelessWidget {
  const _RatingSelector({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final rating = book.rating ?? 0;

    return Column(
      children: [
        Text(
          'Tu calificación',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return IconButton(
              icon: Icon(
                starValue <= rating ? Icons.star : Icons.star_border,
                color: AppColors.secondary,
              ),
              onPressed: () {
                context.read<LibraryProvider>().rateBook(
                  book.id,
                  starValue.toDouble(),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
