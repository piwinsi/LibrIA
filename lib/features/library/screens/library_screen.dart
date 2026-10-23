import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../models/book.dart';
import '../../../providers/library_provider.dart';
import '../../../widgets/book_tiles.dart';
import '../../../widgets/common_widgets.dart';
import 'add_book_sheet.dart';

/// Biblioteca personal clasificada por estado de lectura (RF-03, RF-04).
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  static const _tabs = <ReadingStatus?>[
    null,
    ReadingStatus.reading,
    ReadingStatus.pending,
    ReadingStatus.paused,
    ReadingStatus.completed,
    ReadingStatus.abandoned,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Book> _filter(List<Book> books, ReadingStatus? status) {
    final normalized = normalizeText(_query);
    return books.where((book) {
      if (status != null && book.status != status) return false;
      if (normalized.isEmpty) return true;
      return normalizeText('${book.title} ${book.author} ${book.publisher ?? ''}')
          .contains(normalized);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final books = context.watch<LibraryProvider>().books;

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Biblioteca'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(112),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Buscar por título, autor o editorial',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final status in _tabs)
                      Tab(
                        text: status == null
                            ? 'Todos (${books.length})'
                            : '${status.pluralLabel} (${books.where((b) => b.status == status).length})',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'library_add',
          onPressed: () => showAddBookSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('Agregar libro'),
        ),
        body: TabBarView(
          children: [
            for (final status in _tabs)
              _BookList(
                books: _filter(books, status),
                status: status,
                hasAnyBook: books.isNotEmpty,
                searching: _query.isNotEmpty,
              ),
          ],
        ),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList({
    required this.books,
    required this.status,
    required this.hasAnyBook,
    required this.searching,
  });

  final List<Book> books;
  final ReadingStatus? status;
  final bool hasAnyBook;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return ListView(
        children: [
          EmptyState(
            icon: searching ? Icons.search_off : Icons.menu_book_outlined,
            title: searching
                ? 'Sin coincidencias'
                : (!hasAnyBook
                    ? 'Tu biblioteca está vacía'
                    : 'No hay libros ${status?.pluralLabel.toLowerCase() ?? ''}'),
            message: searching
                ? 'Prueba con otro título o autor.'
                : 'Escanea el código ISBN de un libro, búscalo por título o '
                    'ingrésalo manualmente.',
            actionLabel: searching ? null : 'Agregar libro',
            onAction: searching ? null : () => showAddBookSheet(context),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: books.length,
      itemBuilder: (context, index) => BookListTile(book: books[index]),
    );
  }
}
