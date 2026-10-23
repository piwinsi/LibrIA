import 'dart:math';

import '../core/genres.dart';
import '../core/utils.dart';
import '../models/book.dart';
import '../models/catalog_book.dart';

/// Sugerencia de lectura con su puntaje y la explicación que ve el usuario.
class Recommendation {
  const Recommendation({
    required this.book,
    required this.score,
    required this.reason,
  });

  final CatalogBook book;
  final double score;
  final String reason;
}

/// Perfil de gustos del lector, calculado a partir de los géneros elegidos
/// en el onboarding y de su actividad real de lectura.
class TasteProfile {
  const TasteProfile({
    required this.genreWeights,
    required this.readingGenreWeights,
    required this.authorWeights,
    required this.authorNames,
    required this.favoriteGenres,
    required this.onboardingWeight,
    required this.activity,
  });

  /// Peso total por género (onboarding + lecturas).
  final Map<String, double> genreWeights;

  /// Peso por género proveniente solo de la biblioteca.
  final Map<String, double> readingGenreWeights;

  /// Peso por autor (clave normalizada).
  final Map<String, double> authorWeights;

  /// Nombre visible de cada autor normalizado.
  final Map<String, String> authorNames;

  final Set<String> favoriteGenres;

  /// Peso que conservan los géneros del onboarding. Disminuye a medida que
  /// el usuario registra actividad, de modo que las recomendaciones se
  /// apegan cada vez más a lo que realmente lee.
  final double onboardingWeight;

  /// Cantidad de libros con actividad (no pendientes).
  final int activity;

  bool get isEmpty =>
      genreWeights.values.every((w) => w <= 0) &&
      authorWeights.values.every((w) => w <= 0);

  List<String> topGenres(int count) {
    final entries = genreWeights.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(count).map((e) => e.key).toList();
  }

  /// Autores con mejor peso (nombres visibles).
  List<String> topAuthors(int count) {
    final entries = authorWeights.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(count)
        .map((e) => authorNames[e.key] ?? e.key)
        .toList();
  }
}

class _Scored {
  _Scored(this.book, this.score, this.reason, this.primaryGenre);

  final CatalogBook book;
  final double score;
  final String reason;
  final String primaryGenre;
}

/// Motor de recomendaciones basado en contenido (sin IA ni servidores):
///
/// 1. Al inicio, el perfil se forma con los géneros elegidos en el
///    onboarding.
/// 2. Cada libro registrado suma (o resta) peso a sus géneros y autores
///    según su estado: terminado y bien valorado suma mucho, en lectura
///    suma, abandonado resta.
/// 3. El peso del onboarding decae con la actividad, por lo que las
///    sugerencias se ajustan progresivamente a lo que el usuario lee.
/// 4. Los candidatos se ordenan por afinidad, se excluyen los que ya están
///    en la biblioteca o fueron descartados, y se diversifican los géneros.
class RecommendationEngine {
  RecommendationEngine._();

  static TasteProfile buildProfile({
    required List<String> favoriteGenres,
    required List<Book> books,
  }) {
    final readingGenres = <String, double>{};
    final authors = <String, double>{};
    final authorNames = <String, String>{};
    var activity = 0;

    for (final book in books) {
      final weight = statusWeight(book);
      if (book.status != ReadingStatus.pending) activity++;

      if (book.genres.isNotEmpty) {
        final share = weight / sqrt(book.genres.length);
        for (final genre in book.genres) {
          readingGenres[genre] = (readingGenres[genre] ?? 0) + share;
        }
      }

      for (final author in splitAuthors(book.author)) {
        final key = normalizeText(author);
        if (key.isEmpty || key == 'autor desconocido') continue;
        authors[key] = (authors[key] ?? 0) + weight;
        authorNames[key] = author;
      }
    }

    final onboardingWeight = 3.0 * max(0.25, 1 - activity / 8);
    final total = Map<String, double>.from(readingGenres);
    for (final genre in favoriteGenres) {
      total[genre] = (total[genre] ?? 0) + onboardingWeight;
    }

    return TasteProfile(
      genreWeights: total,
      readingGenreWeights: readingGenres,
      authorWeights: authors,
      authorNames: authorNames,
      favoriteGenres: favoriteGenres.toSet(),
      onboardingWeight: onboardingWeight,
      activity: activity,
    );
  }

  /// Aporte de un libro al perfil según su estado y valoración.
  static double statusWeight(Book book) {
    return switch (book.status) {
      ReadingStatus.pending => 0.6,
      ReadingStatus.reading => 1.5,
      ReadingStatus.paused => 0.5,
      ReadingStatus.abandoned => -1.5,
      ReadingStatus.completed =>
        book.rating == null ? 2.0 : 2.0 + (book.rating! - 3.0),
    };
  }

  /// Perfil centrado en un único libro, para "Libros similares".
  static TasteProfile profileForBook(Book book) {
    final authorWeights = <String, double>{};
    final authorNames = <String, String>{};
    for (final author in splitAuthors(book.author)) {
      final key = normalizeText(author);
      if (key.isEmpty || key == 'autor desconocido') continue;
      authorWeights[key] = 3.0;
      authorNames[key] = author;
    }
    final genres = {for (final g in book.genres) g: 2.0};
    return TasteProfile(
      genreWeights: genres,
      readingGenreWeights: genres,
      authorWeights: authorWeights,
      authorNames: authorNames,
      favoriteGenres: const {},
      onboardingWeight: 0,
      activity: 1,
    );
  }

  static List<Recommendation> rank({
    required TasteProfile profile,
    required Iterable<CatalogBook> candidates,
    required List<Book> library,
    Set<String> dismissedKeys = const {},
    String? onlyGenre,
    Book? anchor,
    int limit = 20,
  }) {
    final libraryKeys = library.map((b) => bookKey(b.title, b.author)).toSet();
    final libraryIsbns = library
        .map((b) => b.isbn)
        .whereType<String>()
        .map(cleanIsbn)
        .toSet();

    final seen = <String>{};
    final scored = <_Scored>[];

    for (final candidate in candidates) {
      final key = candidate.key;
      if (!seen.add(key)) continue;
      if (libraryKeys.contains(key) || dismissedKeys.contains(key)) continue;
      final isbn = candidate.isbn;
      if (isbn != null && libraryIsbns.contains(cleanIsbn(isbn))) continue;
      if (onlyGenre != null && !candidate.genres.contains(onlyGenre)) continue;

      var genreScore = 0.0;
      String? bestGenre;
      var bestGenreWeight = double.negativeInfinity;
      for (final genre in candidate.genres) {
        final weight = profile.genreWeights[genre] ?? 0;
        genreScore += weight;
        if (weight > bestGenreWeight) {
          bestGenreWeight = weight;
          bestGenre = genre;
        }
      }
      if (candidate.genres.length > 1) {
        genreScore /= sqrt(candidate.genres.length);
      }

      var authorScore = 0.0;
      String? matchedAuthor;
      for (final author in splitAuthors(candidate.author)) {
        final weight = profile.authorWeights[normalizeText(author)] ?? 0;
        if (weight.abs() > authorScore.abs()) {
          authorScore = weight;
          matchedAuthor = author;
        }
      }

      var score = genreScore + authorScore * 1.2;
      if (candidate.description.isNotEmpty) score += 0.15;
      if (candidate.coverUrl != null) score += 0.1;

      if (onlyGenre == null && !profile.isEmpty && score <= 0.3) continue;

      scored.add(
        _Scored(
          candidate,
          score,
          _reason(
            profile: profile,
            matchedAuthor: authorScore > 0 ? matchedAuthor : null,
            bestGenre: bestGenre,
            library: library,
            anchor: anchor,
          ),
          bestGenre ?? '',
        ),
      );
    }

    // Selección con diversidad: cada género repetido pierde un 15 %.
    final result = <Recommendation>[];
    final genreCount = <String, int>{};
    final pool = List.of(scored);
    double adjusted(_Scored s) =>
        s.score * pow(0.85, genreCount[s.primaryGenre] ?? 0).toDouble();

    while (result.length < limit && pool.isNotEmpty) {
      pool.sort((a, b) => adjusted(b).compareTo(adjusted(a)));
      final best = pool.removeAt(0);
      result.add(
        Recommendation(book: best.book, score: best.score, reason: best.reason),
      );
      genreCount[best.primaryGenre] = (genreCount[best.primaryGenre] ?? 0) + 1;
    }
    return result;
  }

  static String _reason({
    required TasteProfile profile,
    required String? matchedAuthor,
    required String? bestGenre,
    required List<Book> library,
    Book? anchor,
  }) {
    if (matchedAuthor != null) {
      if (anchor != null) return 'Más de $matchedAuthor';
      final authorKey = normalizeText(matchedAuthor);
      final readIt = library.any(
        (b) =>
            normalizeText(b.author).contains(authorKey) &&
            (b.status == ReadingStatus.completed ||
                b.status == ReadingStatus.reading),
      );
      return readIt
          ? 'Porque leíste a $matchedAuthor'
          : 'De $matchedAuthor, un autor que te interesa';
    }

    if (bestGenre != null && bestGenre.isNotEmpty) {
      final label = Genres.labelOf(bestGenre);
      if ((profile.genreWeights[bestGenre] ?? 0) > 0) {
        if (anchor != null) return 'Similar a «${anchor.title}»';
        final fromReading = profile.readingGenreWeights[bestGenre] ?? 0;
        final fromOnboarding = profile.favoriteGenres.contains(bestGenre)
            ? profile.onboardingWeight
            : 0.0;
        if (fromReading > 0 && fromReading >= fromOnboarding * 0.5) {
          final related = library
              .where(
                (b) =>
                    b.genres.contains(bestGenre) &&
                    (b.status == ReadingStatus.completed ||
                        b.status == ReadingStatus.reading),
              )
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          if (related.isNotEmpty) {
            return 'Similar a «${related.first.title}»';
          }
          return 'Afín a tus lecturas de $label';
        }
        if (profile.favoriteGenres.contains(bestGenre)) {
          return 'Porque te gusta $label';
        }
        return 'Afín a tus lecturas de $label';
      }
      return 'Popular en $label';
    }
    return 'Para explorar algo nuevo';
  }
}
