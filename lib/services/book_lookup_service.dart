import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/genres.dart';
import '../core/utils.dart';
import '../models/catalog_book.dart';

/// Consulta catálogos bibliográficos públicos para:
/// - completar los datos de un libro a partir de su ISBN (escáner);
/// - buscar libros por título o autor;
/// - obtener candidatos para las recomendaciones por género o autor.
///
/// Se usa Google Books como fuente principal (buena cobertura de ediciones
/// en español) y Open Library como respaldo. Ninguna de las dos requiere
/// clave de API. Si no hay conexión, todos los métodos devuelven resultados
/// vacíos y la app sigue funcionando con su catálogo local.
class BookLookupService {
  BookLookupService({http.Client? client, this.enabled = true})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Permite desactivar la red (por ejemplo, en pruebas automatizadas).
  final bool enabled;

  static const _timeout = Duration(seconds: 12);

  /// Busca un libro por ISBN-10 o ISBN-13.
  ///
  /// Se prueban varias fuentes en cascada, porque ninguna cubre todas las
  /// ediciones (las ediciones en español y latinoamericanas suelen faltar en
  /// Google Books):
  /// 1. Google Books con el ISBN-13 y el ISBN-10 equivalente.
  /// 2. Open Library con ambas formas.
  /// 3. Inventaire.io (datos abiertos basados en Wikidata, con buena
  ///    cobertura de ediciones europeas y en español).
  /// 4. Google Books como búsqueda de texto libre del número.
  Future<CatalogBook?> lookupIsbn(String rawIsbn) async {
    if (!enabled) return null;
    final isbn = cleanIsbn(rawIsbn);
    final variants = isbnVariants(isbn);

    for (final variant in variants) {
      final google = await _googleSearch('isbn:$variant', maxResults: 1);
      if (google.isNotEmpty) return google.first.copyWith(isbn: isbn);
    }

    for (final variant in variants) {
      final openLibrary = await _openLibraryIsbn(variant);
      if (openLibrary != null) return openLibrary.copyWith(isbn: isbn);
    }

    final inventaire = await _inventaireIsbn(variants.first);
    if (inventaire != null) return inventaire.copyWith(isbn: isbn);

    final loose = await _googleSearch(isbn, maxResults: 5);
    for (final book in loose) {
      final found = book.isbn;
      if (found != null && variants.contains(cleanIsbn(found))) {
        return book.copyWith(isbn: isbn);
      }
    }
    return null;
  }

  /// Búsqueda libre por título, autor o palabras clave.
  ///
  /// Si se indica [publisher], primero se buscan ediciones de esa editorial
  /// (Google Books `inpublisher:` y Open Library `publisher=`) y luego se
  /// completa con resultados generales, ordenando arriba los que coinciden.
  Future<List<CatalogBook>> search(String query, {String? publisher}) async {
    final text = query.trim();
    final editorial = publisher?.trim() ?? '';
    if (!enabled || (text.isEmpty && editorial.isEmpty)) return [];

    final results = <CatalogBook>[];
    if (editorial.isNotEmpty) {
      final restricted = [
        if (text.isNotEmpty) text,
        'inpublisher:"$editorial"',
      ].join(' ');
      results.addAll(await _googleSearch(restricted, maxResults: 20));
      if (results.length < 5) {
        results.addAll(await _openLibrarySearch(text, publisher: editorial));
      }
    }
    if (text.isNotEmpty && results.length < 10) {
      final general = await _googleSearch(text, maxResults: 20);
      results.addAll(
        general.isNotEmpty ? general : await _openLibrarySearch(text),
      );
    }

    // Títulos traducidos: Inventaire (Wikidata) relaciona "Amanecer en la
    // cosecha" con la obra original "Sunrise on the Reaping". Se agrega la
    // obra con su título en español y luego se buscan sus ediciones por el
    // título original y el autor.
    if (text.isNotEmpty) {
      final works = await _inventaireWorkSearch(text);
      results.insertAll(0, works.map((w) => w.book));
      for (final work in works.take(2)) {
        final original = work.originalTitle;
        if (original == null ||
            normalizeText(original) == normalizeText(work.book.title)) {
          continue;
        }
        final author = work.book.author == 'Autor desconocido'
            ? ''
            : ' inauthor:"${splitAuthors(work.book.author).first}"';
        results.addAll(
          await _googleSearch('intitle:"$original"$author', maxResults: 10),
        );
      }
    }

    // Sin duplicados (misma edición).
    final seen = <String>{};
    final unique = results
        .where((b) => seen.add('${b.key}|${normalizeText(b.publisher ?? '')}'))
        .toList();

    // Orden: editorial buscada, luego títulos que contienen lo escrito,
    // luego el resto (manteniendo el orden de relevancia de cada fuente).
    final wantedPublisher = normalizeText(editorial);
    final wantedTitle = normalizeText(text);
    int rank(CatalogBook b) {
      var score = 0;
      if (wantedPublisher.isNotEmpty &&
          normalizeText(b.publisher ?? '').contains(wantedPublisher)) {
        score -= 2;
      }
      if (wantedTitle.isNotEmpty &&
          normalizeText(b.title).contains(wantedTitle)) {
        score -= 1;
      }
      return score;
    }

    final indexed = unique.asMap().entries.toList()
      ..sort((a, b) {
        final byRank = rank(a.value).compareTo(rank(b.value));
        return byRank != 0 ? byRank : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  /// Libros de un género, priorizando ediciones en español.
  Future<List<CatalogBook>> byGenre(Genre genre, {int maxResults = 20}) async {
    if (!enabled) return [];
    var results = await _googleSearch(
      'subject:"${genre.searchSubject}"',
      maxResults: maxResults,
      langRestrict: 'es',
    );
    if (results.length < 5) {
      results = [
        ...results,
        ...await _googleSearch(
          'subject:"${genre.searchSubject}"',
          maxResults: maxResults,
        ),
      ];
    }
    if (results.isEmpty) {
      results = await _openLibrarySubject(genre.searchSubject);
    }
    // El género consultado se agrega explícitamente, porque las categorías
    // de los catálogos suelen ser genéricas ("Fiction").
    return results.map((book) => book.withExtraGenres([genre.id])).toList();
  }

  /// Otros libros de un autor.
  Future<List<CatalogBook>> byAuthor(String author, {int maxResults = 10}) {
    if (!enabled) return Future.value(const []);
    return _googleSearch('inauthor:"$author"', maxResults: maxResults);
  }

  // ---------------------------------------------------------------------
  // Google Books
  // ---------------------------------------------------------------------

  Future<List<CatalogBook>> _googleSearch(
    String query, {
    int maxResults = 20,
    String? langRestrict,
  }) async {
    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': query,
      'maxResults': '$maxResults',
      'printType': 'books',
      'langRestrict': ?langRestrict,
    });
    final json = await _getJson(uri);
    if (json is! Map) return [];
    final items = json['items'];
    if (items is! List) return [];

    final books = <CatalogBook>[];
    for (final item in items.whereType<Map>()) {
      final info = item['volumeInfo'];
      if (info is! Map) continue;
      final title = (info['title'] as String?)?.trim();
      if (title == null || title.isEmpty) continue;

      final authors = (info['authors'] as List?)?.whereType<String>().toList();
      final categories =
          (info['categories'] as List?)?.whereType<String>().toList() ??
              const <String>[];
      final images = info['imageLinks'];
      String? cover;
      if (images is Map) {
        cover = (images['thumbnail'] ?? images['smallThumbnail']) as String?;
        cover = cover
            ?.replaceFirst('http://', 'https://')
            .replaceAll('&edge=curl', '');
      }

      String? isbn;
      final identifiers = info['industryIdentifiers'];
      if (identifiers is List) {
        for (final id in identifiers.whereType<Map>()) {
          if (id['type'] == 'ISBN_13') isbn = id['identifier'] as String?;
        }
        if (isbn == null) {
          for (final id in identifiers.whereType<Map>()) {
            if (id['type'] == 'ISBN_10') isbn = id['identifier'] as String?;
          }
        }
      }

      books.add(
        CatalogBook(
          id: 'gb_${item['id']}',
          title: title,
          author: (authors == null || authors.isEmpty)
              ? 'Autor desconocido'
              : authors.join(', '),
          description: _stripHtml(info['description'] as String? ?? ''),
          coverUrl: cover,
          isbn: isbn,
          publisher: info['publisher'] as String?,
          publishedDate: info['publishedDate'] as String?,
          genres: Genres.fromCategories(categories),
          pageCount: (info['pageCount'] as num?)?.toInt(),
          source: 'google',
        ),
      );
    }
    return books;
  }

  // ---------------------------------------------------------------------
  // Open Library
  // ---------------------------------------------------------------------

  Future<CatalogBook?> _openLibraryIsbn(String isbn) async {
    final uri = Uri.https('openlibrary.org', '/api/books', {
      'bibkeys': 'ISBN:$isbn',
      'format': 'json',
      'jscmd': 'data',
    });
    final json = await _getJson(uri);
    if (json is! Map) return null;
    final data = json['ISBN:$isbn'];
    if (data is! Map) return null;

    final authors = (data['authors'] as List?)
        ?.whereType<Map>()
        .map((a) => a['name'])
        .whereType<String>()
        .toList();
    final subjects = (data['subjects'] as List?)
            ?.whereType<Map>()
            .map((s) => s['name'])
            .whereType<String>()
            .toList() ??
        const <String>[];
    final cover = data['cover'];

    return CatalogBook(
      id: 'ol_isbn_$isbn',
      title: data['title'] as String? ?? 'Sin título',
      author: (authors == null || authors.isEmpty)
          ? 'Autor desconocido'
          : authors.join(', '),
      coverUrl: cover is Map ? cover['medium'] as String? : null,
      isbn: isbn,
      publisher: (data['publishers'] as List?)
          ?.whereType<Map>()
          .map((p) => p['name'])
          .whereType<String>()
          .firstOrNull,
      publishedDate: data['publish_date'] as String?,
      genres: Genres.fromCategories(subjects),
      pageCount: (data['number_of_pages'] as num?)?.toInt(),
      source: 'openlibrary',
    );
  }

  Future<List<CatalogBook>> _openLibrarySearch(
    String query, {
    String? publisher,
  }) async {
    final uri = Uri.https('openlibrary.org', '/search.json', {
      if (query.isNotEmpty) 'q': query,
      if (publisher != null && publisher.isNotEmpty) 'publisher': publisher,
      'limit': '20',
      'fields':
          'key,title,author_name,number_of_pages_median,subject,isbn,cover_i,publisher,first_publish_year',
    });
    final json = await _getJson(uri);
    if (json is! Map) return [];
    final docs = json['docs'];
    if (docs is! List) return [];

    return docs.whereType<Map>().where((d) => d['title'] is String).map((doc) {
      final authors =
          (doc['author_name'] as List?)?.whereType<String>().toList();
      final isbns = (doc['isbn'] as List?)?.whereType<String>().toList();
      final subjects =
          (doc['subject'] as List?)?.whereType<String>().take(15).toList() ??
              const <String>[];
      final coverId = doc['cover_i'];
      return CatalogBook(
        id: 'ol_${doc['key']}',
        title: doc['title'] as String,
        author: (authors == null || authors.isEmpty)
            ? 'Autor desconocido'
            : authors.take(2).join(', '),
        coverUrl: coverId is num
            ? 'https://covers.openlibrary.org/b/id/${coverId.toInt()}-M.jpg'
            : null,
        isbn: (isbns == null || isbns.isEmpty) ? null : isbns.first,
        genres: Genres.fromCategories(subjects),
        pageCount: (doc['number_of_pages_median'] as num?)?.toInt(),
        publisher: _pickPublisher(
          (doc['publisher'] as List?)?.whereType<String>().toList(),
          publisher,
        ),
        publishedDate: (doc['first_publish_year'] as num?)?.toString(),
        source: 'openlibrary',
      );
    }).toList();
  }

  Future<List<CatalogBook>> _openLibrarySubject(String subject) async {
    final slug = subject.toLowerCase().replaceAll(' ', '_');
    final uri = Uri.https('openlibrary.org', '/subjects/$slug.json', {
      'limit': '20',
    });
    final json = await _getJson(uri);
    if (json is! Map) return [];
    final works = json['works'];
    if (works is! List) return [];

    return works.whereType<Map>().where((w) => w['title'] is String).map((work) {
      final authors = (work['authors'] as List?)
          ?.whereType<Map>()
          .map((a) => a['name'])
          .whereType<String>()
          .toList();
      final subjects =
          (work['subject'] as List?)?.whereType<String>().take(15).toList() ??
              const <String>[];
      final coverId = work['cover_id'];
      return CatalogBook(
        id: 'ol_${work['key']}',
        title: work['title'] as String,
        author: (authors == null || authors.isEmpty)
            ? 'Autor desconocido'
            : authors.take(2).join(', '),
        coverUrl: coverId is num
            ? 'https://covers.openlibrary.org/b/id/${coverId.toInt()}-M.jpg'
            : null,
        genres: Genres.fromCategories(subjects),
        source: 'openlibrary',
      );
    }).toList();
  }

  // ---------------------------------------------------------------------
  // Inventaire.io (sin clave; datos de Wikidata y de su comunidad)
  // ---------------------------------------------------------------------

  /// Devuelve las entidades de Inventaire para una lista de URIs
  /// (`isbn:...`, `wd:Q...`, `inv:...`).
  Future<List<Map<dynamic, dynamic>>> _inventaireEntities(
    List<String> uris,
  ) async {
    if (uris.isEmpty) return const [];
    final uri = Uri.https('inventaire.io', '/api/entities', {
      'action': 'by-uris',
      'uris': uris.join('|'),
    });
    final json = await _getJson(uri);
    if (json is! Map) return const [];
    final entities = json['entities'];
    if (entities is! Map) return const [];
    return entities.values.whereType<Map>().toList();
  }

  Future<CatalogBook?> _inventaireIsbn(String isbn13) async {
    final editions = await _inventaireEntities(['isbn:$isbn13']);
    if (editions.isEmpty) return null;
    final edition = editions.first;

    final title =
        _claimStrings(edition, 'wdt:P1476').firstOrNull ?? _label(edition);
    if (title == null || title.trim().isEmpty) return null;

    // Autor: a veces viene como texto en la edición (P2093); si no, está en
    // la obra (P629) como referencia a otra entidad (P50).
    var authors = _claimStrings(edition, 'wdt:P2093');
    var description = '';
    if (authors.isEmpty) {
      final works =
          await _inventaireEntities(_claimStrings(edition, 'wdt:P629'));
      final authorUris = <String>[];
      for (final work in works) {
        authorUris.addAll(_claimStrings(work, 'wdt:P50'));
        final workDescription = _description(work);
        if (description.isEmpty && workDescription != null) {
          description = workDescription;
        }
      }
      final authorEntities = await _inventaireEntities(authorUris.take(3).toList());
      authors = authorEntities.map(_label).whereType<String>().toList();
    }

    final publisherEntities =
        await _inventaireEntities(_claimStrings(edition, 'wdt:P123').take(1).toList());
    final publisher = publisherEntities.map(_label).whereType<String>().firstOrNull;
    final publishedDate = _claimStrings(edition, 'wdt:P577').firstOrNull;

    final pages = (edition['claims'] is Map)
        ? ((edition['claims'] as Map)['wdt:P1104'] as List?)
            ?.whereType<num>()
            .firstOrNull
            ?.toInt()
        : null;

    String? cover;
    final image = edition['image'];
    if (image is Map && image['url'] is String) {
      final url = image['url'] as String;
      cover = url.startsWith('http') ? url : 'https://inventaire.io$url';
    }

    return CatalogBook(
      id: 'inv_$isbn13',
      title: title.trim(),
      author: authors.isEmpty ? 'Autor desconocido' : authors.join(', '),
      description: description,
      coverUrl: cover,
      isbn: isbn13,
      publisher: publisher,
      publishedDate: publishedDate,
      pageCount: pages,
      source: 'inventaire',
    );
  }

  /// Busca obras por título en Inventaire (en español) y devuelve, para las
  /// más relevantes, el libro con su título en español y su título original.
  Future<List<_InventaireWork>> _inventaireWorkSearch(String text) async {
    final uri = Uri.https('inventaire.io', '/api/search', {
      'types': 'works',
      'search': text,
      'lang': 'es',
      'limit': '5',
    });
    final json = await _getJson(uri);
    if (json is! Map) return const [];
    final hits = json['results'];
    if (hits is! List) return const [];

    // Solo resultados cuyo título contiene lo buscado (evita ruido).
    final wanted = normalizeText(text);
    final relevant = hits
        .whereType<Map>()
        .where((h) =>
            h['uri'] is String &&
            h['label'] is String &&
            normalizeText(h['label'] as String).contains(wanted))
        .take(3)
        .toList();
    if (relevant.isEmpty) return const [];

    final works =
        await _inventaireEntities(relevant.map((h) => h['uri'] as String).toList());
    final byUri = {
      for (final w in works)
        if (w['uri'] is String) w['uri'] as String: w,
    };

    final authorUris = <String>{
      for (final w in works) ..._claimStrings(w, 'wdt:P50').take(2),
    };
    final authorEntities = await _inventaireEntities(authorUris.toList());
    final authorNames = {
      for (final a in authorEntities)
        if (a['uri'] is String && _label(a) != null) a['uri'] as String: _label(a)!,
    };

    final result = <_InventaireWork>[];
    for (final hit in relevant) {
      final uri = hit['uri'] as String;
      final work = byUri[uri];
      final authors = work == null
          ? <String>[]
          : _claimStrings(work, 'wdt:P50')
              .map((u) => authorNames[u])
              .whereType<String>()
              .toList();
      final image = hit['image'];
      final original = work == null
          ? null
          : (_claimStrings(work, 'wdt:P1476').firstOrNull ??
              _labelIn(work, work['originalLang'] as String?));
      final date = work == null ? null : _claimStrings(work, 'wdt:P577').firstOrNull;
      final description = [
        if (original != null &&
            normalizeText(original) != normalizeText(hit['label'] as String))
          'Título original: $original.',
        if (hit['description'] is String) hit['description'] as String,
      ].join(' ');
      result.add(
        _InventaireWork(
          CatalogBook(
            id: 'inv_$uri',
            title: hit['label'] as String,
            author: authors.isEmpty ? 'Autor desconocido' : authors.join(', '),
            description: description,
            coverUrl: image is String && image.isNotEmpty
                ? (image.startsWith('http') ? image : 'https://inventaire.io$image')
                : null,
            publishedDate: date,
            source: 'inventaire',
          ),
          original,
        ),
      );
    }
    return result;
  }

  static String? _labelIn(Map<dynamic, dynamic> entity, String? lang) {
    final labels = entity['labels'];
    if (labels is! Map || lang == null) return null;
    final value = labels[lang];
    return value is String ? value : null;
  }

  /// De la lista de editoriales de una obra, elige la que coincide con la
  /// buscada o, si no, la primera.
  static String? _pickPublisher(List<String>? publishers, String? wanted) {
    if (publishers == null || publishers.isEmpty) return null;
    if (wanted != null && wanted.isNotEmpty) {
      final target = normalizeText(wanted);
      for (final name in publishers) {
        if (normalizeText(name).contains(target)) return name;
      }
    }
    return publishers.first;
  }

  static List<String> _claimStrings(Map<dynamic, dynamic> entity, String property) {
    final claims = entity['claims'];
    if (claims is! Map) return const [];
    final values = claims[property];
    if (values is! List) return const [];
    return values.whereType<String>().toList();
  }

  /// Etiqueta en español, o en inglés, o la primera disponible.
  static String? _label(Map<dynamic, dynamic> entity) {
    final labels = entity['labels'];
    if (labels is! Map || labels.isEmpty) return null;
    final value = labels['es'] ?? labels['en'] ?? labels.values.first;
    return value is String ? value : null;
  }

  static String? _description(Map<dynamic, dynamic> entity) {
    final descriptions = entity['descriptions'];
    if (descriptions is! Map || descriptions.isEmpty) return null;
    final value = descriptions['es'] ?? descriptions['en'];
    return value is String ? value : null;
  }

  // ---------------------------------------------------------------------

  Future<Object?> _getJson(Uri uri) async {
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      // Sin conexión, tiempo de espera o respuesta inválida.
      return null;
    }
  }

  static String _stripHtml(String value) => value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&#39;', "'")
      .trim();
}

/// Obra encontrada en Inventaire: el libro (título en español) y su título
/// original, que sirve para buscar sus ediciones en otros catálogos.
class _InventaireWork {
  const _InventaireWork(this.book, this.originalTitle);

  final CatalogBook book;
  final String? originalTitle;
}
