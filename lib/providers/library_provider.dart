import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/mock_books.dart';
import '../models/book.dart';
import '../services/local_storage_service.dart';

class LibraryProvider extends ChangeNotifier {
  final List<Book> _books = List.of(mockBooks);

  List<Book> get books => List.unmodifiable(_books);

  Book bookById(String id) => _books.firstWhere((book) => book.id == id);

  Future<void> updateProgress(String bookId, int currentPage) async {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index == -1) return;

    final book = _books[index];
    final clampedPage = currentPage.clamp(0, book.totalPages);
    final isCompleted = clampedPage >= book.totalPages;

    _books[index] = book.copyWith(
      currentPage: clampedPage,
      status: isCompleted
          ? ReadingStatus.completed
          : (clampedPage > 0 ? ReadingStatus.reading : ReadingStatus.pending),
      finishDate: isCompleted ? DateTime.now() : book.finishDate,
    );
    notifyListeners();
    // Se espera (await) la escritura en disco: sin esto, cerrar el
    // debugger justo tras guardar podía cortar la escritura a mitad de
    // camino y el avance de lectura se perdía al reabrir la app.
    await persist();
  }

  Future<void> rateBook(String bookId, double rating) async {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index == -1) return;

    _books[index] = _books[index].copyWith(rating: rating);
    notifyListeners();
    await persist();
  }

  /// Lee el estado de biblioteca serializado desde [LocalStorageService] y
  /// reemplaza los libros en memoria por los persistidos. Debe esperarse
  /// (`await`) antes de `runApp()`.
  Future<void> hydrate() async {
    final stored = LocalStorageService.instance.loadLibrary();
    if (stored == null) return;

    try {
      final list = jsonDecode(stored) as List<dynamic>;
      final hydratedBooks = list.map((raw) {
        final map = raw as Map<String, dynamic>;
        return Book(
          id: map['id'] as String,
          title: map['title'] as String,
          author: map['author'] as String,
          description: map['description'] as String,
          coverUrl: map['coverUrl'] as String,
          genre: map['genre'] as String,
          totalPages: map['totalPages'] as int,
          currentPage: map['currentPage'] as int,
          status: ReadingStatus.values.byName(map['status'] as String),
          rating: (map['rating'] as num?)?.toDouble(),
          startDate: map['startDate'] == null
              ? null
              : DateTime.parse(map['startDate'] as String),
          finishDate: map['finishDate'] == null
              ? null
              : DateTime.parse(map['finishDate'] as String),
        );
      }).toList();

      _books
        ..clear()
        ..addAll(hydratedBooks);
      notifyListeners();
    } catch (_) {
      // Estado corrupto o de una versión anterior: se mantienen los datos
      // de demostración en lugar de bloquear el arranque de la app.
    }
  }

  /// Serializa la biblioteca actual y la guarda mediante
  /// [LocalStorageService]. Se invoca automáticamente tras cada cambio de
  /// progreso o calificación.
  Future<void> persist() async {
    final list = _books
        .map((book) => {
              'id': book.id,
              'title': book.title,
              'author': book.author,
              'description': book.description,
              'coverUrl': book.coverUrl,
              'genre': book.genre,
              'totalPages': book.totalPages,
              'currentPage': book.currentPage,
              'status': book.status.name,
              'rating': book.rating,
              'startDate': book.startDate?.toIso8601String(),
              'finishDate': book.finishDate?.toIso8601String(),
            })
        .toList();
    await LocalStorageService.instance.saveLibrary(jsonEncode(list));
  }
}
