import '../core/utils.dart';

/// Libro proveniente de un catálogo (local, Google Books u Open Library)
/// que todavía no forma parte de la biblioteca del usuario. Se usa en el
/// escáner ISBN, la búsqueda y las recomendaciones.
class CatalogBook {
  const CatalogBook({
    required this.id,
    required this.title,
    required this.author,
    this.description = '',
    this.coverUrl,
    this.isbn,
    this.publisher,
    this.publishedDate,
    this.genres = const [],
    this.pageCount,
    this.source = 'local',
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final String? coverUrl;
  final String? isbn;
  final String? publisher;
  final String? publishedDate;
  final List<String> genres;
  final int? pageCount;

  /// local, google u openlibrary.
  final String source;

  String get key => bookKey(title, author);

  /// "Penguin Clásicos · 2015" o lo que haya disponible.
  String get editionLabel => [
        if ((publisher ?? '').trim().isNotEmpty) publisher!.trim(),
        if ((publishedDate ?? '').trim().isNotEmpty)
          publishedDate!.trim().split('-').first,
      ].join(' · ');

  CatalogBook copyWith({
    String? isbn,
    String? publisher,
    String? publishedDate,
    List<String>? genres,
    String? description,
    int? pageCount,
  }) {
    return CatalogBook(
      id: id,
      title: title,
      author: author,
      description: description ?? this.description,
      coverUrl: coverUrl,
      isbn: isbn ?? this.isbn,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
      genres: genres ?? this.genres,
      pageCount: pageCount ?? this.pageCount,
      source: source,
    );
  }

  /// Agrega géneros sin duplicar.
  CatalogBook withExtraGenres(Iterable<String> extra) {
    final merged = <String>{...genres, ...extra}.toList();
    return copyWith(genres: merged);
  }
}
