enum ReadingStatus { pending, reading, completed }

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    required this.genre,
    required this.totalPages,
    required this.currentPage,
    required this.status,
    this.rating,
    this.startDate,
    this.finishDate,
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final String genre;
  final int totalPages;
  final int currentPage;
  final ReadingStatus status;
  final double? rating;
  final DateTime? startDate;
  final DateTime? finishDate;

  double get progress => totalPages == 0 ? 0 : currentPage / totalPages;

  Book copyWith({
    int? currentPage,
    ReadingStatus? status,
    double? rating,
    DateTime? startDate,
    DateTime? finishDate,
  }) {
    return Book(
      id: id,
      title: title,
      author: author,
      description: description,
      coverUrl: coverUrl,
      genre: genre,
      totalPages: totalPages,
      currentPage: currentPage ?? this.currentPage,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      startDate: startDate ?? this.startDate,
      finishDate: finishDate ?? this.finishDate,
    );
  }
}
