import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/utils.dart';
import '../models/book.dart';
import '../models/book_comment.dart';
import '../models/catalog_book.dart';
import '../models/reading_event.dart';
import '../models/shared_recommendation.dart';
import '../services/cloud_backend.dart';
import '../services/local_storage_service.dart';

/// Estado del respaldo en la nube que se muestra en el perfil.
enum SyncStatus {
  /// Cuenta solo local (demo o plataforma sin nube).
  localOnly,

  /// La cuenta tiene respaldo, pero no hay sesión activa en la nube.
  signedOut,

  syncing,
  synced,
  error,
}

/// Biblioteca personal del usuario en sesión: libros (RF-03), estados
/// (RF-04), avance y fechas (RF-05), valoraciones, reseñas y comentarios
/// (RF-06), historial (RF-07) y recomendaciones compartidas (RF-08).
///
/// Sigue un enfoque *local-first*: toda operación se guarda primero en el
/// dispositivo y, si la cuenta tiene respaldo en la nube, los cambios se
/// envían a Firestore unos segundos después (ver "Respaldo en la nube").
class LibraryProvider extends ChangeNotifier {
  LibraryProvider({LocalStorageService? storage, CloudBackend? cloud})
      : _storage = storage ?? LocalStorageService.instance,
        _cloud = cloud ?? const NoCloudBackend();

  final LocalStorageService _storage;
  final CloudBackend _cloud;

  String? _userId;
  List<Book> _books = [];
  List<ReadingEvent> _events = [];
  List<BookComment> _comments = [];
  List<SharedRecommendation> _recommendations = [];
  Set<String> _dismissedKeys = {};
  Set<String> _shownSuggestions = {};
  Set<String> _acceptedSuggestions = {};
  bool _shownFlushScheduled = false;

  String? get userId => _userId;

  /// Libros ordenados por última actividad.
  List<Book> get books {
    final list = List.of(_books)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(list);
  }

  List<Book> booksWithStatus(ReadingStatus status) =>
      books.where((b) => b.status == status).toList();

  /// Eventos del más reciente al más antiguo.
  List<ReadingEvent> get events {
    final list = List.of(_events)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  List<ReadingEvent> eventsFor(String bookId) =>
      events.where((e) => e.bookId == bookId).toList();

  List<BookComment> commentsFor(String bookId) {
    final list = _comments.where((c) => c.bookId == bookId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int get commentCount => _comments.length;

  List<SharedRecommendation> get sharedRecommendations {
    final list = List.of(_recommendations)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  Set<String> get dismissedKeys => Set.unmodifiable(_dismissedKeys);

  Book? bookById(String id) {
    for (final book in _books) {
      if (book.id == id) return book;
    }
    return null;
  }

  /// Busca si un libro del catálogo ya está en la biblioteca.
  Book? findMatching({String? isbn, required String title, required String author}) {
    final cleaned = isbn == null ? null : cleanIsbn(isbn);
    final key = bookKey(title, author);
    for (final book in _books) {
      if (cleaned != null &&
          cleaned.isNotEmpty &&
          book.isbn != null &&
          cleanIsbn(book.isbn!) == cleaned) {
        return book;
      }
      if (bookKey(book.title, book.author) == key) return book;
    }
    return null;
  }

  Book? findByIsbn(String isbn) {
    final cleaned = cleanIsbn(isbn);
    for (final book in _books) {
      if (book.isbn != null && cleanIsbn(book.isbn!) == cleaned) return book;
    }
    return null;
  }

  Book? findCatalogBook(CatalogBook c) =>
      findMatching(isbn: c.isbn, title: c.title, author: c.author);

  // -------------------------------------------------------------------
  // Sesión
  // -------------------------------------------------------------------

  /// Carga (o limpia) los datos del usuario indicado. [cloudUid] es el
  /// identificador de la cuenta en la nube, si tiene respaldo.
  void bindUser(String? userId, {String? cloudUid}) {
    final userChanged = userId != _userId;
    final effectiveCloudUid = userId == null ? null : cloudUid;
    if (!userChanged && effectiveCloudUid == _cloudUid) return;

    if (userChanged) {
      // Los cambios pendientes del usuario anterior se envían antes de
      // cambiar de cuenta (_push toma la foto de los datos de inmediato).
      if (_pushTimer?.isActive ?? false) {
        _pushTimer!.cancel();
        unawaited(_push());
      }
      _pushed = {};
      _lastSyncAt = null;
      _syncError = null;
      _loadLocal(userId);
    }
    _cloudUid = effectiveCloudUid;
    _syncStatus = _idleStatus;
    notifyListeners();
    if (_cloudActive) unawaited(syncNow());
  }

  void _loadLocal(String? userId) {
    _userId = userId;
    if (userId == null) {
      _books = [];
      _events = [];
      _comments = [];
      _recommendations = [];
      _dismissedKeys = {};
      _shownSuggestions = {};
      _acceptedSuggestions = {};
    } else {
      _books = _read(LocalStorageService.booksDomain, Book.fromJson);
      _events = _read(LocalStorageService.eventsDomain, ReadingEvent.fromJson);
      _comments = _read(LocalStorageService.commentsDomain, BookComment.fromJson);
      _recommendations = _read(
        LocalStorageService.recommendationsDomain,
        SharedRecommendation.fromJson,
      );
      _dismissedKeys = _storage
          .readStrings(
            LocalStorageService.userKey(userId, LocalStorageService.dismissedDomain),
          )
          .toSet();
      _shownSuggestions = _storage
          .readStrings(
            LocalStorageService.userKey(
              userId,
              LocalStorageService.shownSuggestionsDomain,
            ),
          )
          .toSet();
      _acceptedSuggestions = _storage
          .readStrings(
            LocalStorageService.userKey(
              userId,
              LocalStorageService.acceptedSuggestionsDomain,
            ),
          )
          .toSet();
    }
  }

  List<T> _read<T>(String domain, T Function(Map<String, dynamic>) parse) {
    final result = <T>[];
    for (final json in _storage.readList(LocalStorageService.userKey(_userId!, domain))) {
      try {
        result.add(parse(json));
      } catch (_) {
        // Registro corrupto: se omite.
      }
    }
    return result;
  }

  // -------------------------------------------------------------------
  // Libros (RF-03)
  // -------------------------------------------------------------------

  Future<Book> addBook({
    required String title,
    required String author,
    required int totalPages,
    String description = '',
    String? coverUrl,
    Uint8List? coverBytes,
    String? isbn,
    String? publisher,
    String? publishedDate,
    List<String> genres = const [],
    ReadingStatus initialStatus = ReadingStatus.pending,
    String source = 'manual',
  }) async {
    final now = DateTime.now();
    final pages = totalPages < 0 ? 0 : totalPages;
    final id = newId('book');
    String? cover = (coverUrl ?? '').trim().isEmpty ? null : coverUrl!.trim();
    if (coverBytes != null) {
      await _storage.saveCover(id, coverBytes);
      cover = 'local:$id';
    }
    var book = Book(
      id: id,
      title: title.trim(),
      author: author.trim().isEmpty ? 'Autor desconocido' : author.trim(),
      description: description.trim(),
      coverUrl: cover,
      isbn: (isbn ?? '').trim().isEmpty ? null : cleanIsbn(isbn!),
      publisher: _clean(publisher),
      publishedDate: _clean(publishedDate),
      genres: genres,
      totalPages: pages,
      addedAt: now,
      updatedAt: now,
      source: source,
    );
    _books.add(book);
    _log(book, ReadingEventType.added);

    if (initialStatus == ReadingStatus.reading) {
      book = _replace(book.copyWith(status: ReadingStatus.reading, startDate: now));
      _log(book, ReadingEventType.started);
    } else if (initialStatus == ReadingStatus.completed) {
      book = _replace(
        book.copyWith(
          status: ReadingStatus.completed,
          currentPage: pages,
          startDate: now,
          finishDate: now,
        ),
      );
      _log(book, ReadingEventType.completed, page: pages, value: pages.toDouble());
    }

    notifyListeners();
    await _saveAll();
    return book;
  }

  Future<Book> addFromCatalog(
    CatalogBook catalogBook, {
    ReadingStatus status = ReadingStatus.pending,
    String source = 'recomendacion',
  }) {
    return addBook(
      title: catalogBook.title,
      author: catalogBook.author,
      totalPages: catalogBook.pageCount ?? 0,
      description: catalogBook.description,
      coverUrl: catalogBook.coverUrl,
      isbn: catalogBook.isbn,
      publisher: catalogBook.publisher,
      publishedDate: catalogBook.publishedDate,
      genres: catalogBook.genres,
      initialStatus: status,
      source: source,
    );
  }

  /// Edita los datos bibliográficos de un libro.
  Future<void> updateBookInfo(
    String id, {
    required String title,
    required String author,
    required int totalPages,
    required String description,
    required List<String> genres,
    String? isbn,
    String? publisher,
    String? publishedDate,
    String? coverUrl,
    Uint8List? coverBytes,
  }) async {
    final book = bookById(id);
    if (book == null) return;
    final pages = totalPages < 0 ? 0 : totalPages;

    // Portada: una foto nueva reemplaza a la anterior; si la portada local
    // ya no se usa, se borra del dispositivo.
    var cover = (coverUrl ?? '').trim();
    if (coverBytes != null) {
      await _storage.saveCover(id, coverBytes);
      cover = 'local:$id';
    } else if (book.hasLocalCover && cover != book.coverUrl) {
      await _storage.removeCover(id);
    }

    _replace(
      book.copyWith(
        title: title.trim(),
        author: author.trim(),
        totalPages: pages,
        currentPage: book.currentPage > pages ? pages : book.currentPage,
        description: description.trim(),
        genres: genres,
        isbn: (isbn ?? '').trim().isEmpty ? null : cleanIsbn(isbn!),
        clearIsbn: (isbn ?? '').trim().isEmpty,
        publisher: _clean(publisher),
        clearPublisher: _clean(publisher) == null,
        publishedDate: _clean(publishedDate),
        clearPublishedDate: _clean(publishedDate) == null,
        coverUrl: cover.isEmpty ? null : cover,
        clearCover: cover.isEmpty,
      ),
    );
    notifyListeners();
    await _saveBooks();
  }

  Future<void> removeBook(String id) async {
    if (bookById(id)?.hasLocalCover ?? false) await _storage.removeCover(id);
    _books.removeWhere((b) => b.id == id);
    _events.removeWhere((e) => e.bookId == id);
    _comments.removeWhere((c) => c.bookId == id);
    notifyListeners();
    await _saveAll();
  }

  // -------------------------------------------------------------------
  // Estados y avance (RF-04, RF-05)
  // -------------------------------------------------------------------

  /// Cambia el estado a cualquiera de los cinco, aplicando las reglas de
  /// fechas y avance que corresponden (para corregir un estado mal puesto).
  Future<void> setStatus(String id, ReadingStatus status) async {
    final book = bookById(id);
    if (book == null || book.status == status) return;
    switch (status) {
      case ReadingStatus.pending:
        await markAsPending(id);
      case ReadingStatus.reading:
        if (book.status == ReadingStatus.pending) {
          await startReading(id);
        } else {
          // Desde terminado se vuelve a la página 0 (no se había terminado
          // realmente); desde pausado o abandonado se conserva la página.
          final fromCompleted = book.status == ReadingStatus.completed;
          final updated = _replace(
            book.copyWith(
              status: ReadingStatus.reading,
              currentPage: fromCompleted ? 0 : book.currentPage,
              startDate: book.startDate ?? DateTime.now(),
              clearFinishDate: true,
            ),
          );
          _log(updated, ReadingEventType.resumed, page: updated.currentPage);
          notifyListeners();
          await _saveAll();
        }
      case ReadingStatus.paused:
        await _applySimpleStatus(book, ReadingStatus.paused, ReadingEventType.paused);
      case ReadingStatus.completed:
        await markCompleted(id);
      case ReadingStatus.abandoned:
        await _applySimpleStatus(book, ReadingStatus.abandoned, ReadingEventType.abandoned);
    }
  }

  Future<void> _applySimpleStatus(
    Book book,
    ReadingStatus status,
    ReadingEventType eventType,
  ) async {
    final updated = _replace(
      book.copyWith(
        status: status,
        startDate: book.startDate ?? DateTime.now(),
        clearFinishDate: true,
      ),
    );
    _log(updated, eventType, page: updated.currentPage);
    notifyListeners();
    await _saveAll();
  }

  /// Devuelve el libro a "Quiero leerlo": sin avance ni fechas de lectura.
  /// Se conservan la valoración, la reseña y los comentarios.
  Future<void> markAsPending(String id) async {
    final book = bookById(id);
    if (book == null) return;
    final updated = _replace(
      book.copyWith(
        status: ReadingStatus.pending,
        currentPage: 0,
        clearStartDate: true,
        clearFinishDate: true,
      ),
    );
    _log(updated, ReadingEventType.markedPending);
    notifyListeners();
    await _saveAll();
  }

  Future<void> startReading(String id) async {
    final book = bookById(id);
    if (book == null) return;
    final now = DateTime.now();
    final updated = _replace(
      book.copyWith(status: ReadingStatus.reading, startDate: book.startDate ?? now),
    );
    _log(updated, ReadingEventType.started, page: updated.currentPage);
    notifyListeners();
    await _saveAll();
  }

  Future<void> pauseReading(String id) =>
      _changeStatus(id, ReadingStatus.paused, ReadingEventType.paused);

  Future<void> resumeReading(String id) async {
    final book = bookById(id);
    if (book == null) return;
    final updated = _replace(
      book.copyWith(
        status: ReadingStatus.reading,
        startDate: book.startDate ?? DateTime.now(),
      ),
    );
    _log(updated, ReadingEventType.resumed, page: updated.currentPage);
    notifyListeners();
    await _saveAll();
  }

  Future<void> abandonBook(String id) =>
      _changeStatus(id, ReadingStatus.abandoned, ReadingEventType.abandoned);

  Future<void> markCompleted(String id) async {
    final book = bookById(id);
    if (book == null) return;
    final now = DateTime.now();
    final delta = book.totalPages - book.currentPage;
    final updated = _replace(
      book.copyWith(
        status: ReadingStatus.completed,
        currentPage: book.totalPages,
        startDate: book.startDate ?? now,
        finishDate: now,
      ),
    );
    _log(
      updated,
      ReadingEventType.completed,
      page: updated.totalPages,
      value: delta > 0 ? delta.toDouble() : 0,
    );
    notifyListeners();
    await _saveAll();
  }

  /// Vuelve a leer un libro terminado desde la primera página.
  Future<void> restartReading(String id) async {
    final book = bookById(id);
    if (book == null) return;
    final updated = _replace(
      book.copyWith(
        status: ReadingStatus.reading,
        currentPage: 0,
        startDate: DateTime.now(),
        clearFinishDate: true,
      ),
    );
    _log(updated, ReadingEventType.restarted, page: 0);
    notifyListeners();
    await _saveAll();
  }

  /// Registra la página actual. Si llega a la última, el libro se marca
  /// como terminado.
  Future<void> updateProgress(String id, int page) async {
    final book = bookById(id);
    if (book == null) return;
    final now = DateTime.now();
    final safePage = page < 0 ? 0 : page;
    final clamped = book.totalPages > 0 && safePage > book.totalPages
        ? book.totalPages
        : safePage;
    final delta = clamped - book.currentPage;
    final completes = book.totalPages > 0 && clamped >= book.totalPages;

    final updated = _replace(
      book.copyWith(
        currentPage: clamped,
        status: completes ? ReadingStatus.completed : ReadingStatus.reading,
        startDate: book.startDate ?? now,
        finishDate: completes ? now : null,
        clearFinishDate: !completes,
      ),
    );

    if (book.status == ReadingStatus.pending) {
      _log(updated, ReadingEventType.started, page: book.currentPage);
    } else if (book.status == ReadingStatus.paused ||
        book.status == ReadingStatus.abandoned) {
      _log(updated, ReadingEventType.resumed, page: book.currentPage);
    }
    _log(
      updated,
      completes ? ReadingEventType.completed : ReadingEventType.progress,
      page: clamped,
      value: delta > 0 ? delta.toDouble() : 0,
    );
    notifyListeners();
    await _saveAll();
  }

  /// Corrige manualmente las fechas de inicio y término.
  Future<void> setDates(String id, {DateTime? startDate, DateTime? finishDate}) async {
    final book = bookById(id);
    if (book == null) return;
    _replace(
      book.copyWith(
        startDate: startDate,
        finishDate: finishDate,
        clearStartDate: startDate == null,
        clearFinishDate: finishDate == null,
      ),
    );
    notifyListeners();
    await _saveBooks();
  }

  Future<void> _changeStatus(
    String id,
    ReadingStatus status,
    ReadingEventType eventType,
  ) async {
    final book = bookById(id);
    if (book == null) return;
    final updated = _replace(book.copyWith(status: status));
    _log(updated, eventType, page: updated.currentPage);
    notifyListeners();
    await _saveAll();
  }

  // -------------------------------------------------------------------
  // Valoración, reseña y comentarios (RF-06)
  // -------------------------------------------------------------------

  Future<void> rateBook(String id, double rating) async {
    final book = bookById(id);
    if (book == null) return;
    final updated = _replace(book.copyWith(rating: rating.clamp(1, 5).toDouble()));
    _log(updated, ReadingEventType.rated, value: updated.rating);
    notifyListeners();
    await _saveAll();
  }

  Future<void> saveReview(String id, String review) async {
    final book = bookById(id);
    if (book == null) return;
    final text = review.trim();
    final updated = _replace(book.copyWith(review: text));
    if (text.isNotEmpty) _log(updated, ReadingEventType.reviewed);
    notifyListeners();
    await _saveAll();
  }

  Future<void> addComment(String bookId, String text, {int? page}) async {
    final book = bookById(bookId);
    if (book == null || text.trim().isEmpty) return;
    _comments.add(
      BookComment(
        id: newId('cmt'),
        bookId: bookId,
        text: text.trim(),
        page: page,
        createdAt: DateTime.now(),
      ),
    );
    _replace(book.copyWith());
    _log(book, ReadingEventType.commented, page: page);
    notifyListeners();
    await _saveAll();
  }

  Future<void> deleteComment(String commentId) async {
    _comments.removeWhere((c) => c.id == commentId);
    notifyListeners();
    await _saveComments();
  }

  // -------------------------------------------------------------------
  // Recomendaciones compartidas (RF-08) y sugerencias descartadas
  // -------------------------------------------------------------------

  Future<SharedRecommendation?> addSharedRecommendation(
    String bookId,
    String message,
  ) async {
    final book = bookById(bookId);
    if (book == null) return null;
    final recommendation = SharedRecommendation(
      id: newId('rec'),
      bookId: book.id,
      bookTitle: book.title,
      bookAuthor: book.author,
      message: message.trim(),
      rating: book.rating,
      createdAt: DateTime.now(),
    );
    _recommendations.add(recommendation);
    _log(book, ReadingEventType.recommended);
    notifyListeners();
    await _saveAll();
    return recommendation;
  }

  Future<void> deleteSharedRecommendation(String id) async {
    _recommendations.removeWhere((r) => r.id == id);
    notifyListeners();
    await _saveRecommendations();
  }

  /// Oculta una sugerencia ("No me interesa").
  Future<void> dismissSuggestion(String key) async {
    _dismissedKeys.add(key);
    notifyListeners();
    final userId = _userId;
    if (userId == null) return;
    await _storage.writeStrings(
      LocalStorageService.userKey(userId, LocalStorageService.dismissedDomain),
      _dismissedKeys.toList(),
    );
    _schedulePush();
  }

  // -------------------------------------------------------------------
  // Métrica de aceptación de sugerencias (OE3)
  // -------------------------------------------------------------------
  //
  // Una sugerencia se cuenta como "mostrada" la primera vez que su tarjeta
  // se dibuja en pantalla, y como "aceptada" cuando el usuario la agrega a
  // su biblioteca desde la sugerencia. Se cuentan libros únicos (por clave
  // título|autor), de modo que volver a ver la misma sugerencia no infla
  // el denominador.

  int get suggestionsShown => _shownSuggestions.length;
  int get suggestionsAccepted => _acceptedSuggestions.length;
  int get suggestionsDismissed => _dismissedKeys.length;

  /// Sugerencias aceptadas sobre sugerencias mostradas (`null` si aún no
  /// se ha mostrado ninguna).
  double? get acceptanceRate => _shownSuggestions.isEmpty
      ? null
      : _acceptedSuggestions.length / _shownSuggestions.length;

  /// Registra que una sugerencia se mostró al usuario.
  ///
  /// No notifica a los oyentes (se llama mientras se dibuja la lista) y
  /// agrupa las escrituras en una sola por cuadro.
  void recordSuggestionShown(String key) {
    if (_userId == null || !_shownSuggestions.add(key)) return;
    if (_shownFlushScheduled) return;
    _shownFlushScheduled = true;
    Future.microtask(() async {
      _shownFlushScheduled = false;
      final userId = _userId;
      if (userId == null) return;
      await _storage.writeStrings(
        LocalStorageService.userKey(
          userId,
          LocalStorageService.shownSuggestionsDomain,
        ),
        _shownSuggestions.toList(),
      );
      _schedulePush();
    });
  }

  /// Registra que el usuario agregó una sugerencia a su biblioteca.
  Future<void> recordSuggestionAccepted(String key) async {
    final userId = _userId;
    if (userId == null) return;
    final newlyShown = _shownSuggestions.add(key);
    if (!_acceptedSuggestions.add(key) && !newlyShown) return;
    notifyListeners();
    await _storage.writeStrings(
      LocalStorageService.userKey(
        userId,
        LocalStorageService.acceptedSuggestionsDomain,
      ),
      _acceptedSuggestions.toList(),
    );
    if (newlyShown) {
      await _storage.writeStrings(
        LocalStorageService.userKey(
          userId,
          LocalStorageService.shownSuggestionsDomain,
        ),
        _shownSuggestions.toList(),
      );
    }
    _schedulePush();
  }

  // -------------------------------------------------------------------
  // Estadísticas (RF-07)
  // -------------------------------------------------------------------

  int countByStatus(ReadingStatus status) =>
      _books.where((b) => b.status == status).length;

  int get pagesRead => _books.fold(0, (sum, b) => sum + b.currentPage);

  int pagesInMonth(DateTime month) => _events
      .where(
        (e) =>
            (e.type == ReadingEventType.progress ||
                e.type == ReadingEventType.completed) &&
            e.createdAt.year == month.year &&
            e.createdAt.month == month.month,
      )
      .fold(0, (sum, e) => sum + (e.value ?? 0).round());

  double? get averageRating {
    final rated = _books.where((b) => b.rating != null).toList();
    if (rated.isEmpty) return null;
    return rated.fold<double>(0, (sum, b) => sum + b.rating!) / rated.length;
  }

  /// Libros terminados por mes durante los últimos [months] meses
  /// (del más antiguo al más reciente).
  List<MapEntry<DateTime, int>> completedPerMonth({int months = 6}) {
    final now = DateTime.now();
    return List.generate(months, (index) {
      final month = DateTime(now.year, now.month - (months - 1 - index));
      final count = _books
          .where(
            (b) =>
                b.status == ReadingStatus.completed &&
                b.finishDate != null &&
                b.finishDate!.year == month.year &&
                b.finishDate!.month == month.month,
          )
          .length;
      return MapEntry(month, count);
    });
  }

  /// Géneros con más actividad (libros en lectura o terminados).
  List<MapEntry<String, int>> topGenres({int limit = 5}) {
    final counts = <String, int>{};
    for (final book in _books) {
      if (book.status != ReadingStatus.completed &&
          book.status != ReadingStatus.reading) {
        continue;
      }
      for (final genre in book.genres) {
        counts[genre] = (counts[genre] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  // -------------------------------------------------------------------
  // Internos
  // -------------------------------------------------------------------

  static String? _clean(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Book _replace(Book updated) {
    final index = _books.indexWhere((b) => b.id == updated.id);
    if (index != -1) _books[index] = updated;
    return updated;
  }

  void _log(Book book, ReadingEventType type, {int? page, double? value}) {
    _events.add(
      ReadingEvent(
        id: newId('evt'),
        bookId: book.id,
        bookTitle: book.title,
        type: type,
        createdAt: DateTime.now(),
        page: page,
        value: value,
      ),
    );
  }

  Future<void> _saveAll() async {
    await _saveBooks();
    await _saveEvents();
    await _saveComments();
    await _saveRecommendations();
  }

  Future<void> _write(String domain, List<Map<String, dynamic>> items) async {
    final userId = _userId;
    if (userId == null) return;
    await _storage.writeList(LocalStorageService.userKey(userId, domain), items);
    _schedulePush();
  }

  Future<void> _saveBooks() => _write(
        LocalStorageService.booksDomain,
        _books.map((b) => b.toJson()).toList(),
      );

  Future<void> _saveEvents() => _write(
        LocalStorageService.eventsDomain,
        _events.map((e) => e.toJson()).toList(),
      );

  Future<void> _saveComments() => _write(
        LocalStorageService.commentsDomain,
        _comments.map((c) => c.toJson()).toList(),
      );

  Future<void> _saveRecommendations() => _write(
        LocalStorageService.recommendationsDomain,
        _recommendations.map((r) => r.toJson()).toList(),
      );

  // -------------------------------------------------------------------
  // Respaldo en la nube (Firestore)
  // -------------------------------------------------------------------
  //
  // - Cada cambio local programa un envío a los 2 segundos; varios cambios
  //   seguidos se agrupan en un solo envío.
  // - Solo se envían los documentos que cambiaron desde el último envío
  //   (se comparan en formato JSON canónico).
  // - Al borrar un elemento se deja una "lápida" ({deleted: true}) para que
  //   otros dispositivos también lo borren al sincronizar.
  // - Al iniciar sesión se descargan los datos y se combinan con los
  //   locales (consistencia eventual): en los libros gana la versión con
  //   `updatedAt` más reciente; eventos, comentarios y recomendaciones solo
  //   se agregan y se unen por identificador.

  static const _collections = ['books', 'events', 'comments', 'recommendations'];
  static const _metaCollection = 'meta';
  static const _suggestionsDoc = 'suggestions';
  static const _pushDelay = Duration(seconds: 2);

  String? _cloudUid;
  Timer? _pushTimer;

  /// Cola que ejecuta las operaciones de sincronización de a una.
  Future<void> _queue = Future<void>.value();

  /// Último estado enviado o descargado: 'colección/id' → JSON canónico.
  Map<String, String> _pushed = {};

  SyncStatus _syncStatus = SyncStatus.localOnly;
  DateTime? _lastSyncAt;
  String? _syncError;

  SyncStatus get syncStatus => _syncStatus;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get syncError => _syncError;

  bool get _cloudActive =>
      _userId != null &&
      _cloudUid != null &&
      _cloud.isAvailable &&
      _cloud.currentUid == _cloudUid;

  SyncStatus get _idleStatus {
    if (_cloudUid == null || !_cloud.isAvailable) return SyncStatus.localOnly;
    if (!_cloudActive) return SyncStatus.signedOut;
    return _lastSyncAt == null ? SyncStatus.syncing : SyncStatus.synced;
  }

  void _setStatus(SyncStatus status, {String? error}) {
    _syncStatus = status;
    _syncError = error;
    notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _queue.then((_) => operation()).catchError((Object e) {
      debugPrint('Error de sincronización: $e');
    });
    _queue = next;
    return next;
  }

  void _schedulePush() {
    if (!_cloudActive) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(_pushDelay, () => unawaited(_push()));
  }

  /// Envía de inmediato los cambios pendientes y espera a que termine
  /// cualquier sincronización en curso.
  Future<void> flushSync() {
    _pushTimer?.cancel();
    return _push();
  }

  /// Descarga los datos respaldados, los combina con los locales y envía
  /// lo que falte en la nube. Se ejecuta al iniciar sesión y desde el
  /// botón "Sincronizar ahora" del perfil.
  Future<void> syncNow() {
    if (!_cloudActive) {
      _setStatus(_idleStatus);
      return _queue;
    }
    final uid = _cloudUid!;
    final userId = _userId;
    return _enqueue(() async {
      // La sesión pudo cambiar mientras esperaba en la cola.
      if (userId != _userId || uid != _cloudUid || !_cloudActive) return;
      _setStatus(SyncStatus.syncing);
      try {
        final remote = await _cloud.download(uid, [
          ..._collections,
          _metaCollection,
        ]);
        if (userId != _userId || uid != _cloudUid) return;
        _mergeRemote(remote);
        _pushed = _encodeRemote(remote);
        notifyListeners();
        await _saveMergedLocally();
        _pushTimer?.cancel();
        await _pushSnapshot(uid, _snapshot(), _pushed);
      } catch (e) {
        debugPrint('Error al sincronizar: $e');
        if (userId == _userId) {
          _setStatus(
            SyncStatus.error,
            error: 'No se pudo sincronizar. Revisa tu conexión.',
          );
        }
      }
    });
  }

  /// Programa el envío del estado actual. La foto de los datos se toma en
  /// este instante, aunque el envío espere su turno en la cola.
  Future<void> _push() {
    if (!_cloudActive) return _queue;
    final uid = _cloudUid!;
    final snapshot = _snapshot();
    final pushedBefore = _pushed;
    return _enqueue(() {
      // Si la cuenta sigue siendo la misma, se compara con lo último
      // enviado (que pudo cambiar mientras esperaba en la cola).
      final baseline = uid == _cloudUid ? _pushed : pushedBefore;
      return _pushSnapshot(uid, snapshot, baseline);
    });
  }

  Future<void> _pushSnapshot(
    String uid,
    Map<String, Map<String, dynamic>> current,
    Map<String, String> baseline,
  ) async {
    final encoded = {
      for (final entry in current.entries) entry.key: _canonical(entry.value),
    };
    final writes = <CloudWrite>[];
    encoded.forEach((key, json) {
      if (baseline[key] != json) writes.add(_writeFor(key, current[key]!));
    });
    final deletedAt = DateTime.now().toIso8601String();
    for (final key in baseline.keys) {
      if (!encoded.containsKey(key)) {
        final id = key.substring(key.indexOf('/') + 1);
        writes.add(
          _writeFor(key, {'id': id, 'deleted': true, 'deletedAt': deletedAt}),
        );
      }
    }
    try {
      if (writes.isNotEmpty) await _cloud.commit(uid, writes);
      if (uid == _cloudUid) {
        _pushed = encoded;
        _lastSyncAt = DateTime.now();
        _setStatus(SyncStatus.synced);
      }
    } catch (e) {
      debugPrint('Error al respaldar: $e');
      if (uid == _cloudUid) {
        _setStatus(
          SyncStatus.error,
          error: 'Hay cambios pendientes de respaldo. Se reintentará.',
        );
      }
    }
  }

  CloudWrite _writeFor(String key, Map<String, dynamic> data) {
    final slash = key.indexOf('/');
    return CloudWrite(key.substring(0, slash), key.substring(slash + 1), data);
  }

  /// Estado local actual como documentos 'colección/id'.
  Map<String, Map<String, dynamic>> _snapshot() {
    final sorted = (Set<String> set) => (set.toList()..sort());
    return {
      for (final b in _books) 'books/${b.id}': b.toJson(),
      for (final e in _events) 'events/${e.id}': e.toJson(),
      for (final c in _comments) 'comments/${c.id}': c.toJson(),
      for (final r in _recommendations) 'recommendations/${r.id}': r.toJson(),
      '$_metaCollection/$_suggestionsDoc': {
        'id': _suggestionsDoc,
        'dismissed': sorted(_dismissedKeys),
        'shown': sorted(_shownSuggestions),
        'accepted': sorted(_acceptedSuggestions),
      },
    };
  }

  /// Documentos vigentes en la nube (sin lápidas ni el perfil, que lo
  /// gestiona AuthProvider).
  Map<String, String> _encodeRemote(Map<String, List<Map<String, dynamic>>> remote) {
    final result = <String, String>{};
    for (final collection in _collections) {
      for (final doc in remote[collection] ?? const <Map<String, dynamic>>[]) {
        if (doc['deleted'] == true) continue;
        result['$collection/${doc['id']}'] = _canonical(doc);
      }
    }
    for (final doc in remote[_metaCollection] ?? const <Map<String, dynamic>>[]) {
      if (doc['id'] == _suggestionsDoc) {
        result['$_metaCollection/$_suggestionsDoc'] = _canonical(doc);
      }
    }
    return result;
  }

  void _mergeRemote(Map<String, List<Map<String, dynamic>>> remote) {
    // Libros: gana la versión modificada más recientemente.
    for (final doc in remote['books'] ?? const <Map<String, dynamic>>[]) {
      final id = doc['id'] as String?;
      if (id == null) continue;
      final index = _books.indexWhere((b) => b.id == id);
      if (doc['deleted'] == true) {
        final deletedAt = DateTime.tryParse(doc['deletedAt'] as String? ?? '');
        if (index != -1 &&
            (deletedAt == null || !_books[index].updatedAt.isAfter(deletedAt))) {
          _books.removeAt(index);
        }
        continue;
      }
      final Book remoteBook;
      try {
        remoteBook = Book.fromJson(doc);
      } catch (_) {
        continue;
      }
      if (index == -1) {
        _books.add(remoteBook);
      } else if (remoteBook.updatedAt.isAfter(_books[index].updatedAt)) {
        _books[index] = remoteBook;
      }
    }

    // Eventos, comentarios y recomendaciones: unión por identificador.
    _mergeAppendOnly(remote['events'], _events, (e) => e.id, ReadingEvent.fromJson);
    _mergeAppendOnly(remote['comments'], _comments, (c) => c.id, BookComment.fromJson);
    _mergeAppendOnly(
      remote['recommendations'],
      _recommendations,
      (r) => r.id,
      SharedRecommendation.fromJson,
    );

    // Métricas de sugerencias: unión de conjuntos.
    for (final doc in remote[_metaCollection] ?? const <Map<String, dynamic>>[]) {
      if (doc['id'] != _suggestionsDoc) continue;
      Set<String> read(String field) =>
          (doc[field] as List? ?? const []).whereType<String>().toSet();
      _dismissedKeys.addAll(read('dismissed'));
      _shownSuggestions.addAll(read('shown'));
      _acceptedSuggestions.addAll(read('accepted'));
    }
  }

  void _mergeAppendOnly<T>(
    List<Map<String, dynamic>>? docs,
    List<T> local,
    String Function(T) idOf,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (docs == null) return;
    final known = local.map(idOf).toSet();
    for (final doc in docs) {
      final id = doc['id'] as String?;
      if (id == null) continue;
      if (doc['deleted'] == true) {
        local.removeWhere((item) => idOf(item) == id);
        continue;
      }
      if (known.contains(id)) continue;
      try {
        local.add(parse(doc));
        known.add(id);
      } catch (_) {
        // Documento con formato inválido: se omite.
      }
    }
  }

  Future<void> _saveMergedLocally() async {
    await _saveAll();
    final userId = _userId;
    if (userId == null) return;
    await _storage.writeStrings(
      LocalStorageService.userKey(userId, LocalStorageService.dismissedDomain),
      _dismissedKeys.toList(),
    );
    await _storage.writeStrings(
      LocalStorageService.userKey(userId, LocalStorageService.shownSuggestionsDomain),
      _shownSuggestions.toList(),
    );
    await _storage.writeStrings(
      LocalStorageService.userKey(userId, LocalStorageService.acceptedSuggestionsDomain),
      _acceptedSuggestions.toList(),
    );
  }

  /// JSON con las claves ordenadas, para comparar documentos sin depender
  /// del orden en que la nube devuelve los campos.
  static String _canonical(Object? value) => jsonEncode(_sortKeys(value));

  static Object? _sortKeys(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _sortKeys(value[k])};
    }
    if (value is List) return value.map(_sortKeys).toList();
    return value;
  }

  @override
  void dispose() {
    _pushTimer?.cancel();
    super.dispose();
  }
}
