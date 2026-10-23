import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libria_v01/core/genres.dart';
import 'package:libria_v01/core/utils.dart';
import 'package:libria_v01/models/book.dart';
import 'package:libria_v01/models/catalog_book.dart';
import 'package:libria_v01/models/reading_event.dart';
import 'package:libria_v01/providers/auth_provider.dart';
import 'package:libria_v01/providers/library_provider.dart';
import 'package:libria_v01/services/local_storage_service.dart';
import 'package:libria_v01/services/password_hasher.dart';
import 'package:libria_v01/services/recommendation_engine.dart';

Book _book(
  String title,
  List<String> genres, {
  ReadingStatus status = ReadingStatus.completed,
  double? rating,
  String author = 'Autor X',
}) {
  final now = DateTime.now();
  return Book(
    id: title,
    title: title,
    author: author,
    totalPages: 100,
    addedAt: now,
    updatedAt: now,
    genres: genres,
    status: status,
    rating: rating,
  );
}

const _fantasy = CatalogBook(id: 'f', title: 'Libro de fantasía', author: 'A', genres: ['fantasia']);
const _scifi = CatalogBook(id: 's', title: 'Libro espacial', author: 'B', genres: ['ciencia_ficcion']);
const _romance = CatalogBook(id: 'r', title: 'Libro romántico', author: 'C', genres: ['romance']);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.instance.resetForTests();
  });

  group('Utilidades', () {
    test('valida ISBN-13 e ISBN-10', () {
      expect(isValidIsbn('978-0-306-40615-7'), isTrue);
      expect(isValidIsbn('9780306406158'), isFalse);
      expect(isValidIsbn('0-306-40615-2'), isTrue);
      expect(isValidIsbn('123'), isFalse);
    });

    test('convierte entre ISBN-13 e ISBN-10', () {
      expect(isbnVariants('9780306406157'), ['9780306406157', '0306406152']);
      expect(isbnVariants('0306406152'), ['9780306406157', '0306406152']);
      expect(isbnVariants('9791034304540'), ['9791034304540']);
    });

    test('mapea categorías externas a géneros', () {
      expect(Genres.fromCategories(['Fiction / Fantasy / Epic']), contains('fantasia'));
      expect(Genres.fromCategories(['Science Fiction']), ['ciencia_ficcion']);
      expect(Genres.fromCategories(['Fiction']), ['novela']);
    });

    test('el hash de contraseña no guarda el texto plano', () {
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hash('secreta123', salt);
      expect(hash, isNot(contains('secreta123')));
      expect(PasswordHasher.verify('secreta123', salt, hash), isTrue);
      expect(PasswordHasher.verify('otra', salt, hash), isFalse);
    });
  });

  group('Motor de recomendaciones', () {
    test('sin lecturas, prioriza los géneros del onboarding', () {
      final profile = RecommendationEngine.buildProfile(
        favoriteGenres: ['fantasia'],
        books: const [],
      );
      final result = RecommendationEngine.rank(
        profile: profile,
        candidates: [_scifi, _fantasy, _romance],
        library: const [],
      );
      expect(result.first.book.id, 'f');
      expect(result.first.reason, 'Porque te gusta Fantasía');
    });

    test('lo que el usuario lee termina pesando más que el onboarding', () {
      final books = [
        for (var i = 0; i < 6; i++)
          _book('SF $i', ['ciencia_ficcion'], rating: 5),
      ];
      final profile = RecommendationEngine.buildProfile(
        favoriteGenres: ['fantasia'],
        books: books,
      );
      final result = RecommendationEngine.rank(
        profile: profile,
        candidates: [_fantasy, _scifi],
        library: books,
      );
      expect(result.first.book.id, 's');
      expect(result.first.reason, startsWith('Similar a'));
    });

    test('excluye libros de la biblioteca, descartados y géneros abandonados', () {
      final books = [
        _book('Libro romántico', ['romance'], status: ReadingStatus.abandoned, author: 'C'),
      ];
      final profile = RecommendationEngine.buildProfile(
        favoriteGenres: ['fantasia', 'ciencia_ficcion'],
        books: books,
      );
      final result = RecommendationEngine.rank(
        profile: profile,
        candidates: [_fantasy, _scifi, _romance],
        library: books,
        dismissedKeys: {_scifi.key},
      );
      expect(result.map((r) => r.book.id), ['f']);
    });
  });

  group('Biblioteca', () {
    test('flujo agregar → comenzar → avanzar → terminar → valorar', () async {
      final auth = AuthProvider();
      await auth.hydrate();
      await auth.register(name: 'Test', email: 't@t.cl', password: '12345678');
      final library = LibraryProvider()..bindUser(auth.currentUser!.id);

      final book = await library.addBook(title: 'Libro', author: 'Autora', totalPages: 200);
      expect(library.bookById(book.id)!.status, ReadingStatus.pending);

      await library.startReading(book.id);
      expect(library.bookById(book.id)!.status, ReadingStatus.reading);
      expect(library.bookById(book.id)!.startDate, isNotNull);

      await library.updateProgress(book.id, 120);
      expect(library.bookById(book.id)!.currentPage, 120);

      await library.pauseReading(book.id);
      expect(library.bookById(book.id)!.status, ReadingStatus.paused);

      await library.updateProgress(book.id, 250);
      final finished = library.bookById(book.id)!;
      expect(finished.status, ReadingStatus.completed);
      expect(finished.currentPage, 200);
      expect(finished.finishDate, isNotNull);

      await library.rateBook(book.id, 4);
      await library.saveReview(book.id, 'Muy bueno');
      await library.addComment(book.id, 'Gran capítulo', page: 50);

      expect(library.bookById(book.id)!.rating, 4);
      expect(library.commentsFor(book.id), hasLength(1));
      final types = library.eventsFor(book.id).map((e) => e.type).toSet();
      expect(
        types,
        containsAll([
          ReadingEventType.added,
          ReadingEventType.started,
          ReadingEventType.progress,
          ReadingEventType.paused,
          ReadingEventType.resumed,
          ReadingEventType.completed,
          ReadingEventType.rated,
          ReadingEventType.reviewed,
          ReadingEventType.commented,
        ]),
      );

      // Los datos persisten y se recuperan al volver a cargar el usuario.
      final reloaded = LibraryProvider()..bindUser(auth.currentUser!.id);
      expect(reloaded.bookById(book.id)!.status, ReadingStatus.completed);
    });

    test('un libro marcado por error puede volver a "Quiero leerlo"', () async {
      final auth = AuthProvider();
      await auth.hydrate();
      await auth.register(name: 'Tres', email: 'tres@t.cl', password: '12345678');
      final library = LibraryProvider()..bindUser(auth.currentUser!.id);
      final book = await library.addBook(
        title: 'El arte de la guerra',
        author: 'Sun Tzu',
        totalPages: 160,
        publisher: 'Penguin Clásicos',
        publishedDate: '2015',
        initialStatus: ReadingStatus.completed,
      );
      expect(library.bookById(book.id)!.editionLabel, 'Penguin Clásicos · 2015');

      await library.setStatus(book.id, ReadingStatus.pending);
      final pending = library.bookById(book.id)!;
      expect(pending.status, ReadingStatus.pending);
      expect(pending.currentPage, 0);
      expect(pending.startDate, isNull);
      expect(pending.finishDate, isNull);

      await library.setStatus(book.id, ReadingStatus.paused);
      expect(library.bookById(book.id)!.status, ReadingStatus.paused);
      expect(
        library.eventsFor(book.id).map((e) => e.type),
        contains(ReadingEventType.markedPending),
      );
    });

    test('los datos de cada cuenta están separados', () async {
      final auth = AuthProvider();
      await auth.hydrate();
      await auth.register(name: 'Uno', email: 'uno@t.cl', password: '12345678');
      final library = LibraryProvider()..bindUser(auth.currentUser!.id);
      await library.addBook(title: 'Solo de Uno', author: 'X', totalPages: 10);

      await auth.logout();
      await auth.register(name: 'Dos', email: 'dos@t.cl', password: '12345678');
      library.bindUser(auth.currentUser!.id);
      expect(library.books, isEmpty);
    });
  });
}
