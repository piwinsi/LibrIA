import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/mock_books.dart';
import '../../../providers/social_provider.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final readers = context.watch<SocialProvider>().readers;

    return Scaffold(
      appBar: AppBar(title: const Text('Descubrir')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Recomendado para ti',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...mockBooks.map(
            (book) => Card(
              child: ListTile(
                title: Text(book.title),
                subtitle: Text('${book.author} · ${book.genre}'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Otros lectores',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...readers.map(
            (reader) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(reader.name.isNotEmpty ? reader.name[0] : '?'),
                ),
                title: Text(reader.name),
                subtitle: Text(
                  '${reader.bio}\n${reader.booksRead} libros leídos',
                ),
                isThreeLine: true,
                trailing: OutlinedButton(
                  onPressed: () =>
                      context.read<SocialProvider>().toggleFollow(reader.id),
                  child: Text(
                    reader.isFollowing ? 'Siguiendo' : 'Seguir',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
