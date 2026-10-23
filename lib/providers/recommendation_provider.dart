import 'package:flutter/foundation.dart';

import '../core/genres.dart';
import '../core/utils.dart';
import '../data/local_catalog.dart';
import '../models/book.dart';
import '../models/catalog_book.dart';
import '../services/book_lookup_service.dart';
import '../services/recommendation_engine.dart';
import 'auth_provider.dart';
import 'library_provider.dart';

/// Expone las sugerencias de lectura y las mantiene actualizadas cada vez
/// que cambian los géneros favoritos o la biblioteca del usuario.
class RecommendationProvider extends ChangeNotifier {
  RecommendationProvider({
    required this.lookup,
    required this._auth,
    required this._library,
  }) {
    _auth.addListener(_onSourcesChanged);
    _library.addListener(_onSourcesChanged);
    _onSourcesChanged();
  }

  final BookLookupService lookup;
  final AuthProvider _auth;
  final LibraryProvider _library;

  /// Resultados en línea guardados en memoria durante la sesión.
  final Map<String, List<CatalogBook>> _byGenre = {};
  final Map<String, List<CatalogBook>> _byAuthor = {};
  final Set<String> _inFlight = {};

  TasteProfile _profile = RecommendationEngine.buildProfile(
    favoriteGenres: const [],
    books: const [],
  );
  List<Recommendation> _forYou = [];

  TasteProfile get profile => _profile;
  List<Recommendation> get forYou => List.unmodifiable(_forYou);
  bool get isLoadingOnline => _inFlight.isNotEmpty;

  Iterable<CatalogBook> get _pool sync* {
    for (final list in _byAuthor.values) {
      yield* list;
    }
    for (final list in _byGenre.values) {
      yield* list;
    }
    yield* localCatalog;
  }

  /// Sugerencias filtradas por un género.
  List<Recommendation> forGenre(String genreId, {int limit = 20}) {
    return RecommendationEngine.rank(
      profile: _profile,
      candidates: _pool,
      library: _library.books,
      dismissedKeys: _library.dismissedKeys,
      onlyGenre: genreId,
      limit: limit,
    );
  }

  /// Libros parecidos a uno de la biblioteca.
  List<Recommendation> similarTo(Book book, {int limit = 10}) {
    final profile = RecommendationEngine.profileForBook(book);
    if (profile.isEmpty) return const [];
    return RecommendationEngine.rank(
      profile: profile,
      candidates: _pool,
      library: _library.books,
      dismissedKeys: _library.dismissedKeys,
      anchor: book,
      limit: limit,
    );
  }

  /// Descarga candidatos de un género (llamar fuera de `build`).
  Future<void> ensureGenre(String genreId) async {
    final genre = Genres.byId(genreId);
    if (genre == null || !lookup.enabled) return;
    final flightKey = 'g:$genreId';
    if (_byGenre.containsKey(genreId) || _inFlight.contains(flightKey)) return;
    _inFlight.add(flightKey);
    final results = await lookup.byGenre(genre);
    _inFlight.remove(flightKey);
    _byGenre[genreId] = results;
    _recompute();
    notifyListeners();
  }

  /// Descarga otros libros de un autor (llamar fuera de `build`).
  Future<void> ensureAuthor(String author) async {
    final key = normalizeText(author);
    if (key.isEmpty || key == 'autor desconocido' || !lookup.enabled) return;
    final flightKey = 'a:$key';
    if (_byAuthor.containsKey(key) || _inFlight.contains(flightKey)) return;
    _inFlight.add(flightKey);
    final results = await lookup.byAuthor(author);
    _inFlight.remove(flightKey);
    _byAuthor[key] = results;
    _recompute();
    notifyListeners();
  }

  /// Vuelve a consultar los catálogos en línea.
  Future<void> refresh() async {
    _byGenre.clear();
    _byAuthor.clear();
    _recompute();
    notifyListeners();
    await _fetchForProfile();
  }

  void _onSourcesChanged() {
    final user = _auth.currentUser;
    _profile = RecommendationEngine.buildProfile(
      favoriteGenres: user?.favoriteGenres ?? const [],
      books: _library.books,
    );
    _recompute();
    notifyListeners();
    if (user != null) _fetchForProfile();
  }

  void _recompute() {
    if (_auth.currentUser == null) {
      _forYou = [];
      return;
    }
    _forYou = RecommendationEngine.rank(
      profile: _profile,
      candidates: _pool,
      library: _library.books,
      dismissedKeys: _library.dismissedKeys,
      limit: 30,
    );
  }

  Future<void> _fetchForProfile() async {
    final futures = <Future<void>>[
      for (final genre in _profile.topGenres(4)) ensureGenre(genre),
      for (final author in _profile.topAuthors(2)) ensureAuthor(author),
    ];
    await Future.wait(futures);
  }

  @override
  void dispose() {
    _auth.removeListener(_onSourcesChanged);
    _library.removeListener(_onSourcesChanged);
    super.dispose();
  }
}
