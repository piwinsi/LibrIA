import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../main_navigation_screen.dart';
import '../../../models/book.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/recommendation_provider.dart';
import '../../../widgets/book_tiles.dart';
import '../../../widgets/common_widgets.dart';
import '../../library/screens/add_book_sheet.dart';
import '../../library/screens/update_progress_screen.dart';
import '../../statistics/screens/history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final library = context.watch<LibraryProvider>();
    final recommendations = context.watch<RecommendationProvider>();
    final reading = library.booksWithStatus(ReadingStatus.reading);
    final recentEvents = library.events.take(4).toList();
    final suggestions = recommendations.forYou.take(10).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            tooltip: 'Agregar libro',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => showAddBookSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            'Hola, ${firstName(user?.name ?? '')}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Este es el resumen de tu actividad lectora.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _QuickStat(
                label: 'En lectura',
                value: '${library.countByStatus(ReadingStatus.reading)}',
                icon: Icons.auto_stories,
              ),
              const SizedBox(width: 8),
              _QuickStat(
                label: 'Terminados',
                value: '${library.countByStatus(ReadingStatus.completed)}',
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: 8),
              _QuickStat(
                label: 'Págs. este mes',
                value: '${library.pagesInMonth(DateTime.now())}',
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SectionHeader(title: 'Continúa leyendo'),
          if (reading.isEmpty)
            Card(
              child: EmptyState(
                icon: Icons.auto_stories_outlined,
                title: 'No tienes lecturas en curso',
                message: library.books.isEmpty
                    ? 'Agrega tu primer libro escaneando su ISBN, buscándolo o ingresándolo a mano.'
                    : 'Comienza alguno de tus libros pendientes o agrega uno nuevo.',
                actionLabel: 'Agregar libro',
                onAction: () => showAddBookSheet(context),
              ),
            )
          else
            ...reading.map((book) => _ReadingCard(book: book)),
          SectionHeader(
            title: 'Recomendados para ti',
            actionLabel: 'Ver más',
            onAction: () => MainNavigationScreen.goToTab(
              context,
              MainNavigationScreen.discoverTab,
            ),
          ),
          if (recommendations.isLoadingOnline && suggestions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Buscando sugerencias...')),
            )
          else if (suggestions.isEmpty)
            const Card(
              child: EmptyState(
                icon: Icons.explore_outlined,
                title: 'Aún no tenemos sugerencias',
                message:
                    'Elige tus géneros favoritos en tu perfil o registra libros para recibir recomendaciones.',
              ),
            )
          else
            RecommendationCarousel(recommendations: suggestions),
          if (recentEvents.isNotEmpty) ...[
            SectionHeader(
              title: 'Actividad reciente',
              actionLabel: 'Ver historial',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
            ),
            Card(
              child: Column(
                children: [
                  for (final event in recentEvents)
                    EventTile(event: event, dense: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: AppColors.secondary, size: 20),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openBookDetail(context, book.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              BookCover(title: book.title, url: book.coverUrl, width: 48, height: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Pág. ${book.currentPage} de ${book.totalPages} · ${book.progressPercent}%',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: book.progress, minHeight: 6),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar progreso',
                icon: const Icon(Icons.edit_note),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UpdateProgressScreen(bookId: book.id),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
