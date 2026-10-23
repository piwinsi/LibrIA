/// Estados de lectura definidos en RF-04.
enum ReadingStatus { pending, reading, paused, completed, abandoned }

ReadingStatus readingStatusFromName(String? name) {
  for (final status in ReadingStatus.values) {
    if (status.name == name) return status;
  }
  return ReadingStatus.pending;
}

/// Libro registrado en la biblioteca personal de un usuario (RF-03).
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.totalPages,
    required this.addedAt,
    required this.updatedAt,
    this.description = '',
    this.coverUrl,
    this.isbn,
    this.publisher,
    this.publishedDate,
    this.genres = const [],
    this.currentPage = 0,
    this.status = ReadingStatus.pending,
    this.rating,
    this.review,
    this.startDate,
    this.finishDate,
    this.source = 'manual',
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final String? coverUrl;
  final String? isbn;

  /// Editorial de la edición registrada (ayuda a identificar la edición).
  final String? publisher;

  /// Fecha o año de publicación tal como lo entrega el catálogo ("2015").
  final String? publishedDate;

  final List<String> genres;
  final int totalPages;
  final int currentPage;
  final ReadingStatus status;
  final double? rating;
  final String? review;
  final DateTime addedAt;
  final DateTime updatedAt;
  final DateTime? startDate;
  final DateTime? finishDate;

  /// Origen del registro: manual, isbn, busqueda, recomendacion o demo.
  final String source;

  double get progress =>
      totalPages <= 0 ? 0 : (currentPage / totalPages).clamp(0.0, 1.0);

  int get progressPercent => (progress * 100).round();

  bool get hasReview => (review ?? '').trim().isNotEmpty;

  /// Portada guardada en el dispositivo (foto o imagen elegida).
  bool get hasLocalCover => coverUrl?.startsWith('local:') ?? false;

  /// "Penguin Clásicos · 2015" o lo que haya disponible.
  String get editionLabel => [
        if ((publisher ?? '').trim().isNotEmpty) publisher!.trim(),
        if ((publishedDate ?? '').trim().isNotEmpty)
          publishedDate!.trim().split('-').first,
      ].join(' · ');

  Book copyWith({
    String? title,
    String? author,
    String? description,
    String? coverUrl,
    String? isbn,
    String? publisher,
    String? publishedDate,
    List<String>? genres,
    int? totalPages,
    int? currentPage,
    ReadingStatus? status,
    double? rating,
    String? review,
    DateTime? updatedAt,
    DateTime? startDate,
    DateTime? finishDate,
    bool clearCover = false,
    bool clearIsbn = false,
    bool clearPublisher = false,
    bool clearPublishedDate = false,
    bool clearRating = false,
    bool clearStartDate = false,
    bool clearFinishDate = false,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      coverUrl: clearCover ? null : (coverUrl ?? this.coverUrl),
      isbn: clearIsbn ? null : (isbn ?? this.isbn),
      publisher: clearPublisher ? null : (publisher ?? this.publisher),
      publishedDate:
          clearPublishedDate ? null : (publishedDate ?? this.publishedDate),
      genres: genres ?? this.genres,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      status: status ?? this.status,
      rating: clearRating ? null : (rating ?? this.rating),
      review: review ?? this.review,
      addedAt: addedAt,
      updatedAt: updatedAt ?? DateTime.now(),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      finishDate: clearFinishDate ? null : (finishDate ?? this.finishDate),
      source: source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'description': description,
        'coverUrl': coverUrl,
        'isbn': isbn,
        'publisher': publisher,
        'publishedDate': publishedDate,
        'genres': genres,
        'totalPages': totalPages,
        'currentPage': currentPage,
        'status': status.name,
        'rating': rating,
        'review': review,
        'addedAt': addedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'startDate': startDate?.toIso8601String(),
        'finishDate': finishDate?.toIso8601String(),
        'source': source,
      };

  factory Book.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;

    final addedAt = parseDate(json['addedAt']) ?? DateTime.now();
    return Book(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Sin título',
      author: json['author'] as String? ?? 'Autor desconocido',
      description: json['description'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      isbn: json['isbn'] as String?,
      publisher: json['publisher'] as String?,
      publishedDate: json['publishedDate'] as String?,
      genres: List<String>.from(json['genres'] as List? ?? const []),
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      currentPage: (json['currentPage'] as num?)?.toInt() ?? 0,
      status: readingStatusFromName(json['status'] as String?),
      rating: (json['rating'] as num?)?.toDouble(),
      review: json['review'] as String?,
      addedAt: addedAt,
      updatedAt: parseDate(json['updatedAt']) ?? addedAt,
      startDate: parseDate(json['startDate']),
      finishDate: parseDate(json['finishDate']),
      source: json['source'] as String? ?? 'manual',
    );
  }
}
