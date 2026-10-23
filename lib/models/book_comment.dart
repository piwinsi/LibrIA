/// Comentario o reflexión personal sobre un libro (RF-06).
class BookComment {
  const BookComment({
    required this.id,
    required this.bookId,
    required this.text,
    required this.createdAt,
    this.page,
  });

  final String id;
  final String bookId;
  final String text;
  final DateTime createdAt;

  /// Página a la que se refiere el comentario (opcional).
  final int? page;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'page': page,
      };

  factory BookComment.fromJson(Map<String, dynamic> json) => BookComment(
        id: json['id'] as String,
        bookId: json['bookId'] as String? ?? '',
        text: json['text'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        page: (json['page'] as num?)?.toInt(),
      );
}
