import 'package:flutter/foundation.dart';

import '../core/utils.dart';
import '../models/book.dart';
import '../models/book_comment.dart';
import '../models/catalog_book.dart';
import '../models/reading_event.dart';
import '../models/shared_recommendation.dart';
import '../services/local_storage_service.dart';

/// Biblioteca personal del usuario en sesión: libros (RF-03), estados
/// (RF-04), avance y fechas (RF-05), valoraciones, reseñas y comentarios
/// (RF-06), historial (RF-07) y recomendaciones compartidas (RF-08).
class LibraryProvider extends ChangeNotifier {
  LibraryProvider({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService.instance;

  final LocalStorageService _storage;

  String? _userId;
  List<Book> _books = [];
  List<ReadingEvent> _events = [];
  List<BookComment> _comments = [];
  List<SharedRecommendation> _recommendations = [];
  Set<String> _dismissedKeys = {};

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

  /// Carga (o limpia) los datos del usuario indicado.
  void bindUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    if (userId == null) {
      _books = [];
      _events = [];
      _comments = [];
      _recommendations = [];
      _dismissedKeys = {};
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
    }
    notifyListeners();
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
}
