import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../models/book.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/library_provider.dart';
import '../../library/screens/book_detail_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = context.watch<AuthProvider>().currentUser?.name ?? '';
    final books = context.watch<LibraryProvider>().books;
    final currentlyReading = books.where(
      (book) => book.status == ReadingStatus.reading,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notificaciones',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hola, $userName',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Este es un resumen de tu actividad lectora.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            'Continúa leyendo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (currentlyReading.isEmpty)
            const Text('No tienes lecturas en progreso.')
          else
            ...currentlyReading.map(
              (book) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.menu_book,
                    color: AppColors.primary,
                  ),
                  title: Text(book.title),
                  subtitle: Text(
                    '${book.author} · ${(book.progress * 100).round()}% leído',
                  ),
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
        ],
      ),
    );
  }
}
