import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/book.dart';
import '../../../providers/library_provider.dart';
import 'book_detail_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

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
    final books = context.watch<LibraryProvider>().books;

    final groups = <ReadingStatus, List<Book>>{
      ReadingStatus.reading: [],
      ReadingStatus.pending: [],
      ReadingStatus.completed: [],
    };
    for (final book in books) {
      groups[book.status]!.add(book);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final status in groups.keys) ...[
            if (groups[status]!.isNotEmpty) ...[
              Text(
                _statusLabel(status),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...groups[status]!.map(
                (book) => Card(
                  child: ListTile(
                    title: Text(book.title),
                    subtitle: Text(book.author),
                    trailing: book.rating != null
                        ? Text('★ ${book.rating}')
                        : null,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookDetailScreen(bookId: book.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
  }
}
