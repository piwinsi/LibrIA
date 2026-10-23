import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../features/discover/screens/catalog_book_detail_screen.dart';
import '../features/library/screens/book_detail_screen.dart';
import '../models/book.dart';
import '../models/catalog_book.dart';
import '../providers/library_provider.dart';
import '../services/recommendation_engine.dart';
import 'common_widgets.dart';

/// Fila de un libro de la biblioteca.
class BookListTile extends StatelessWidget {
  const BookListTile({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final showProgress = book.status == ReadingStatus.reading ||
        book.status == ReadingStatus.paused;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openBookDetail(context, book.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(title: book.title, url: book.coverUrl, width: 52, height: 78),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.editionLabel.isEmpty
                          ? book.author
                          : '${book.author} · ${book.editionLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusChip(status: book.status, dense: true),
                        const Spacer(),
                        if (book.rating != null)
                          RatingStars(rating: book.rating, size: 14),
                      ],
                    ),
                    if (showProgress) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: book.progress,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${book.progressPercent}%',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sugerencia en formato de lista (pantalla Descubrir).
class RecommendationTile extends StatelessWidget {
  const RecommendationTile({super.key, required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final book = recommendation.book;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openCatalogBook(context, book, reason: recommendation.reason),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(title: book.title, url: book.coverUrl, width: 60, height: 90),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    ReasonLabel(reason: recommendation.reason),
                    const SizedBox(height: 6),
                    GenreTags(genres: book.genres),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Quiero leerlo',
                    icon: const Icon(Icons.bookmark_add_outlined),
                    onPressed: () => addCatalogBookToLibrary(context, book),
                  ),
                  IconButton(
                    tooltip: 'No me interesa',
                    icon: const Icon(Icons.close),
                    onPressed: () => dismissSuggestion(context, book),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sugerencia en formato tarjeta vertical (carrusel del inicio y detalle).
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({super.key, required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final book = recommendation.book;
    return SizedBox(
      width: 120,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openCatalogBook(context, book, reason: recommendation.reason),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(title: book.title, url: book.coverUrl, width: 120, height: 170),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              recommendation.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista horizontal de sugerencias.
class RecommendationCarousel extends StatelessWidget {
  const RecommendationCarousel({super.key, required this.recommendations});

  final List<Recommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recommendations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            RecommendationCard(recommendation: recommendations[index]),
      ),
    );
  }
}

/// Explicación de por qué se sugiere un libro.
class ReasonLabel extends StatelessWidget {
  const ReasonLabel({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome, size: 14, color: AppColors.secondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Acciones compartidas
// ---------------------------------------------------------------------

void openBookDetail(BuildContext context, String bookId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: bookId)),
  );
}

void openCatalogBook(BuildContext context, CatalogBook book, {String? reason}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CatalogBookDetailScreen(book: book, reason: reason),
    ),
  );
}

/// Agrega una sugerencia a la biblioteca (por defecto como pendiente).
///
/// Se capturan el [ScaffoldMessenger] y el [Navigator] antes de las
/// operaciones asíncronas, porque la tarjeta que originó la acción
/// desaparece de la lista apenas el libro entra a la biblioteca.
Future<void> addCatalogBookToLibrary(
  BuildContext context,
  CatalogBook book, {
  ReadingStatus status = ReadingStatus.pending,
}) async {
  final library = context.read<LibraryProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  void openDetail(String id) => navigator.push(
        MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: id)),
      );

  final existing = library.findCatalogBook(book);
  if (existing != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('«${book.title}» ya está en tu biblioteca.'),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => openDetail(existing.id),
          ),
        ),
      );
    return;
  }
  final added = await library.addFromCatalog(book, status: status);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'Agregaste «${added.title}» como ${status.label.toLowerCase()}.',
        ),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => openDetail(added.id),
        ),
      ),
    );
}

Future<void> dismissSuggestion(BuildContext context, CatalogBook book) async {
  final messenger = ScaffoldMessenger.of(context);
  await context.read<LibraryProvider>().dismissSuggestion(book.key);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('No volveremos a sugerirte «${book.title}».')),
    );
}
