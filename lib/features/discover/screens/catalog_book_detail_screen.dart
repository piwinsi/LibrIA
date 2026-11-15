import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../models/book.dart';
import '../../../models/catalog_book.dart';
import '../../../providers/library_provider.dart';
import '../../../widgets/book_tiles.dart';
import '../../../widgets/common_widgets.dart';
import '../../library/screens/book_detail_screen.dart';
import '../../library/screens/book_form_screen.dart';

/// Vista previa de un libro sugerido o encontrado que aún no está en la
/// biblioteca.
class CatalogBookDetailScreen extends StatelessWidget {
  const CatalogBookDetailScreen({super.key, required this.book, this.reason});

  final CatalogBook book;
  final String? reason;

  Future<void> _add(BuildContext context, ReadingStatus status) async {
    final library = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final added = await library.addFromCatalog(book, status: status);
    // Si se llegó desde una sugerencia, cuenta como aceptada (OE3).
    if (reason != null) await library.recordSuggestionAccepted(book.key);
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: added.id)),
    );
    messenger.showSnackBar(
      SnackBar(content: Text('«${added.title}» se agregó como ${status.label.toLowerCase()}.')),
    );
  }

  Future<void> _dismiss(BuildContext context) async {
    final navigator = Navigator.of(context);
    await dismissSuggestion(context, book);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final existing = context.watch<LibraryProvider>().findCatalogBook(book);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Center(
            child: BookCover(title: book.title, url: book.coverUrl, width: 140, height: 210),
          ),
          const SizedBox(height: 16),
          Text(
            book.title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            book.author,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Center(child: GenreTags(genres: book.genres, max: 5)),
          if (book.pageCount != null ||
              book.isbn != null ||
              book.editionLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (book.editionLabel.isNotEmpty) book.editionLabel,
                if (book.pageCount != null) '${book.pageCount} páginas',
                if (book.isbn != null) 'ISBN ${book.isbn}',
              ].join(' · '),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (reason != null) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.secondary.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ReasonLabel(reason: reason!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (existing != null)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => BookDetailScreen(bookId: existing.id),
                ),
              ),
              icon: const Icon(Icons.check_circle),
              label: const Text('Ya está en tu biblioteca · Ver'),
            )
          else ...[
            FilledButton.icon(
              key: const Key('catalog_add_pending'),
              onPressed: () => _add(context, ReadingStatus.pending),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Quiero leerlo'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _add(context, ReadingStatus.reading),
                    child: const Text('Lo estoy leyendo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _add(context, ReadingStatus.completed),
                    child: const Text('Ya lo leí'),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => BookFormScreen(prefill: book, source: 'busqueda'),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Revisar datos antes de agregar'),
            ),
            if (reason != null)
              TextButton.icon(
                onPressed: () => _dismiss(context),
                icon: const Icon(Icons.thumb_down_alt_outlined),
                label: const Text('No me interesa'),
              ),
          ],
          if (book.description.isNotEmpty) ...[
            const SectionHeader(title: 'Descripción'),
            Text(book.description),
          ],
          if (book.pageCount == null) ...[
            const SizedBox(height: 16),
            const Text(
              'No conocemos el número de páginas de esta edición; podrás editarlo después de agregarlo.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
