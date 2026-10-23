/// Recomendación que el usuario comparte a partir de un libro registrado
/// (RF-08).
class SharedRecommendation {
  const SharedRecommendation({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.message,
    required this.createdAt,
    this.rating,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String message;
  final DateTime createdAt;
  final double? rating;

  /// Texto listo para compartir por otras aplicaciones.
  String get shareText {
    final buffer = StringBuffer()
      ..writeln('📚 Te recomiendo «$bookTitle», de $bookAuthor.');
    if (rating != null) {
      buffer.writeln('⭐ Mi valoración: ${rating!.toStringAsFixed(0)}/5');
    }
    if (message.trim().isNotEmpty) {
      buffer.writeln('"${message.trim()}"');
    }
    buffer.write('— Compartido desde LibrIA');
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'bookAuthor': bookAuthor,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'rating': rating,
      };

  factory SharedRecommendation.fromJson(Map<String, dynamic> json) =>
      SharedRecommendation(
        id: json['id'] as String,
        bookId: json['bookId'] as String? ?? '',
        bookTitle: json['bookTitle'] as String? ?? '',
        bookAuthor: json['bookAuthor'] as String? ?? '',
        message: json['message'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        rating: (json['rating'] as num?)?.toDouble(),
      );
}
