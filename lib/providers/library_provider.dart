import 'package:flutter/foundation.dart';

import '../data/mock_books.dart';
import '../models/book.dart';

class LibraryProvider extends ChangeNotifier {
  final List<Book> _books = List.of(mockBooks);

  List<Book> get books => List.unmodifiable(_books);

  Book bookById(String id) => _books.firstWhere((book) => book.id == id);

  void updateProgress(String bookId, int currentPage) {
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
  }

  void rateBook(String bookId, double rating) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index == -1) return;

    _books[index] = _books[index].copyWith(rating: rating);
    notifyListeners();
  }
}
