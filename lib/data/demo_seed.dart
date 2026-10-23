import '../core/utils.dart';
import '../models/book.dart';
import '../models/book_comment.dart';
import '../models/catalog_book.dart';
import '../models/reading_event.dart';
import '../models/shared_recommendation.dart';
import '../services/local_storage_service.dart';
import 'local_catalog.dart';

/// Credenciales de la cuenta de demostración (para presentaciones y
/// pruebas). La contraseña se guarda con hash como cualquier otra cuenta.
const demoEmail = 'demo@libria.cl';
const demoPassword = 'libria123';
const demoName = 'Lector Demo';
const demoGenres = ['ciencia_ficcion', 'fantasia', 'desarrollo_personal'];

/// Carga una biblioteca de ejemplo con libros en los cinco estados, avance,
/// valoraciones, reseñas, comentarios y una recomendación compartida.
class DemoSeed {
  DemoSeed._();

  static Future<void> write(LocalStorageService storage, String userId) async {
    final now = DateTime.now();
    DateTime daysAgo(int days) => now.subtract(Duration(days: days));

    Book fromCatalog(
      String catalogId, {
      required ReadingStatus status,
      required int currentPage,
      required DateTime addedAt,
      DateTime? startDate,
      DateTime? finishDate,
      double? rating,
      String? review,
    }) {
      final CatalogBook c = localCatalogById(catalogId)!;
      return Book(
        id: newId('book'),
        title: c.title,
        author: c.author,
        description: c.description,
        genres: c.genres,
        totalPages: c.pageCount ?? 300,
        currentPage: currentPage,
        status: status,
        rating: rating,
        review: review,
        addedAt: addedAt,
        updatedAt: finishDate ?? startDate ?? addedAt,
        startDate: startDate,
        finishDate: finishDate,
        source: 'demo',
      );
    }

    final orwell = fromCatalog(
      'local_012',
      status: ReadingStatus.completed,
      currentPage: 352,
      addedAt: daysAgo(120),
      startDate: daysAgo(100),
      finishDate: daysAgo(75),
      rating: 5,
      review:
          'Inquietante y vigente. La idea de reescribir el pasado me dejó pensando varios días.',
    );
    final viento = fromCatalog(
      'local_001',
      status: ReadingStatus.completed,
      currentPage: 872,
      addedAt: daysAgo(70),
      startDate: daysAgo(65),
      finishDate: daysAgo(28),
      rating: 5,
      review: 'La mejor narración en primera persona que he leído en años.',
    );
    final habitos = fromCatalog(
      'local_130',
      status: ReadingStatus.reading,
      currentPage: 190,
      addedAt: daysAgo(20),
      startDate: daysAgo(14),
    );
    final dune = fromCatalog(
      'local_010',
      status: ReadingStatus.paused,
      currentPage: 210,
      addedAt: daysAgo(40),
      startDate: daysAgo(35),
    );
    final crimen = fromCatalog(
      'local_055',
      status: ReadingStatus.abandoned,
      currentPage: 120,
      addedAt: daysAgo(90),
      startDate: daysAgo(88),
      rating: 3,
    );
    final tresCuerpos = fromCatalog(
      'local_015',
      status: ReadingStatus.pending,
      currentPage: 0,
      addedAt: daysAgo(5),
    );

    final books = [habitos, tresCuerpos, viento, dune, orwell, crimen];

    ReadingEvent event(
      Book book,
      ReadingEventType type,
      DateTime at, {
      int? page,
      double? value,
    }) =>
        ReadingEvent(
          id: newId('evt'),
          bookId: book.id,
          bookTitle: book.title,
          type: type,
          createdAt: at,
          page: page,
          value: value,
        );

    final events = <ReadingEvent>[
      event(orwell, ReadingEventType.added, daysAgo(120)),
      event(orwell, ReadingEventType.started, daysAgo(100)),
      event(orwell, ReadingEventType.progress, daysAgo(90), page: 160, value: 160),
      event(orwell, ReadingEventType.completed, daysAgo(75), page: 352, value: 192),
      event(orwell, ReadingEventType.rated, daysAgo(75), value: 5),
      event(orwell, ReadingEventType.reviewed, daysAgo(75)),
      event(crimen, ReadingEventType.added, daysAgo(90)),
      event(crimen, ReadingEventType.started, daysAgo(88)),
      event(crimen, ReadingEventType.progress, daysAgo(80), page: 120, value: 120),
      event(crimen, ReadingEventType.abandoned, daysAgo(60), page: 120),
      event(viento, ReadingEventType.added, daysAgo(70)),
      event(viento, ReadingEventType.started, daysAgo(65)),
      event(viento, ReadingEventType.progress, daysAgo(50), page: 400, value: 400),
      event(viento, ReadingEventType.completed, daysAgo(28), page: 872, value: 472),
      event(viento, ReadingEventType.rated, daysAgo(28), value: 5),
      event(dune, ReadingEventType.added, daysAgo(40)),
      event(dune, ReadingEventType.started, daysAgo(35)),
      event(dune, ReadingEventType.progress, daysAgo(30), page: 210, value: 210),
      event(dune, ReadingEventType.paused, daysAgo(22), page: 210),
      event(habitos, ReadingEventType.added, daysAgo(20)),
      event(habitos, ReadingEventType.started, daysAgo(14)),
      event(habitos, ReadingEventType.progress, daysAgo(9), page: 95, value: 95),
      event(habitos, ReadingEventType.commented, daysAgo(8)),
      event(habitos, ReadingEventType.progress, daysAgo(2), page: 190, value: 95),
      event(tresCuerpos, ReadingEventType.added, daysAgo(5)),
      event(orwell, ReadingEventType.recommended, daysAgo(3)),
    ];

    final comments = [
      BookComment(
        id: newId('cmt'),
        bookId: habitos.id,
        text:
            'Mejorar un 1 % cada día parece poco, pero acumulado durante un año es enorme.',
        page: 18,
        createdAt: daysAgo(8),
      ),
      BookComment(
        id: newId('cmt'),
        bookId: orwell.id,
        text: 'La neolengua como forma de limitar el pensamiento es lo más aterrador.',
        page: 310,
        createdAt: daysAgo(80),
      ),
    ];

    final recommendations = [
      SharedRecommendation(
        id: newId('rec'),
        bookId: orwell.id,
        bookTitle: orwell.title,
        bookAuthor: orwell.author,
        message: 'Si te gustan las distopías, este es obligatorio.',
        rating: 5,
        createdAt: daysAgo(3),
      ),
    ];

    await storage.writeList(
      LocalStorageService.userKey(userId, LocalStorageService.booksDomain),
      books.map((b) => b.toJson()).toList(),
    );
    await storage.writeList(
      LocalStorageService.userKey(userId, LocalStorageService.eventsDomain),
      events.map((e) => e.toJson()).toList(),
    );
    await storage.writeList(
      LocalStorageService.userKey(userId, LocalStorageService.commentsDomain),
      comments.map((c) => c.toJson()).toList(),
    );
    await storage.writeList(
      LocalStorageService.userKey(
        userId,
        LocalStorageService.recommendationsDomain,
      ),
      recommendations.map((r) => r.toJson()).toList(),
    );
  }
}
