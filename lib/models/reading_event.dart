/// Tipos de evento que componen la trayectoria lectora (RF-05 y RF-07).
enum ReadingEventType {
  added,
  started,
  progress,
  paused,
  resumed,
  completed,
  abandoned,
  restarted,
  markedPending,
  rated,
  reviewed,
  commented,
  recommended,
}

ReadingEventType readingEventTypeFromName(String? name) {
  for (final type in ReadingEventType.values) {
    if (type.name == name) return type;
  }
  return ReadingEventType.progress;
}

class ReadingEvent {
  const ReadingEvent({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.type,
    required this.createdAt,
    this.page,
    this.value,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final ReadingEventType type;
  final DateTime createdAt;

  /// Página alcanzada (eventos de avance).
  final int? page;

  /// Valor asociado: páginas avanzadas o estrellas de una calificación.
  final double? value;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'page': page,
        'value': value,
      };

  factory ReadingEvent.fromJson(Map<String, dynamic> json) => ReadingEvent(
        id: json['id'] as String,
        bookId: json['bookId'] as String? ?? '',
        bookTitle: json['bookTitle'] as String? ?? '',
        type: readingEventTypeFromName(json['type'] as String?),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        page: (json['page'] as num?)?.toInt(),
        value: (json['value'] as num?)?.toDouble(),
      );
}
