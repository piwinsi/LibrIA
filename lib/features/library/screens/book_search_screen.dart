import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../data/local_catalog.dart';
import '../../../models/catalog_book.dart';
import '../../../providers/library_provider.dart';
import '../../../services/book_lookup_service.dart';
import '../../../widgets/book_tiles.dart';
import '../../../widgets/common_widgets.dart';
import 'book_form_screen.dart';

/// Búsqueda de libros por título, autor o palabras clave.
class BookSearchScreen extends StatefulWidget {
  const BookSearchScreen({super.key});

  @override
  State<BookSearchScreen> createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends State<BookSearchScreen> {
  final _controller = TextEditingController();
  final _publisherController = TextEditingController();
  List<CatalogBook> _results = [];
  bool _loading = false;
  bool _searched = false;
  bool _onlineFailed = false;

  @override
  void dispose() {
    _controller.dispose();
    _publisherController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    final publisher = _publisherController.text.trim();
    if (query.isEmpty && publisher.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
    });

    final local = query.isEmpty ? const <CatalogBook>[] : searchLocalCatalog(query);
    final online = await context
        .read<BookLookupService>()
        .search(query, publisher: publisher);
    if (!mounted) return;

    final seen = <String>{};
    final merged = <CatalogBook>[];
    // Se distinguen ediciones: mismo título y autor, distinta editorial.
    for (final book in [...online, ...local]) {
      if (seen.add('${book.key}|${normalizeText(book.publisher ?? '')}')) {
        merged.add(book);
      }
    }
    setState(() {
      _results = merged;
      _loading = false;
      _onlineFailed = online.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar libro')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('search_query'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Título, autor o palabra clave',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const Key('search_publisher'),
              controller: _publisherController,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                hintText: 'Editorial (opcional), ej.: Penguin',
                prefixIcon: Icon(Icons.apartment_outlined),
                isDense: true,
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_searched && !_loading && _onlineFailed && _results.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Sin resultados en línea: se muestran coincidencias del catálogo local.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          Expanded(
            child: !_searched
                ? const EmptyState(
                    icon: Icons.travel_explore,
                    title: 'Busca un libro',
                    message:
                        'Escribe el título o el autor. Luego podrás revisar los datos antes de agregarlo.',
                  )
                : (!_loading && _results.isEmpty)
                    ? EmptyState(
                        icon: Icons.search_off,
                        title: 'Sin resultados',
                        message:
                            'No encontramos coincidencias (o no hay conexión). Puedes ingresarlo manualmente.',
                        actionLabel: 'Ingresar manualmente',
                        onAction: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const BookFormScreen()),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final book = _results[index];
                          final inLibrary = library.findCatalogBook(book) != null;
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(8),
                              leading: BookCover(
                                title: book.title,
                                url: book.coverUrl,
                                width: 44,
                                height: 66,
                              ),
                              title: Text(
                                book.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                [
                                  book.author,
                                  if (book.editionLabel.isNotEmpty) book.editionLabel,
                                  if (book.pageCount != null) '${book.pageCount} págs.',
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: inLibrary
                                  ? const Tooltip(
                                      message: 'Ya está en tu biblioteca',
                                      child: Icon(Icons.check_circle,
                                          color: AppColors.success),
                                    )
                                  : IconButton(
                                      tooltip: 'Revisar y agregar',
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => BookFormScreen(
                                            prefill: book,
                                            source: 'busqueda',
                                          ),
                                        ),
                                      ),
                                    ),
                              onTap: () => openCatalogBook(context, book),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
