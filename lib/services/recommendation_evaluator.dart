import '../models/book.dart';
import '../models/catalog_book.dart';
import 'recommendation_engine.dart';

/// Resultado de la evaluación fuera de línea del motor de recomendaciones.
class EvaluationReport {
  const EvaluationReport({
    required this.k,
    required this.trials,
    required this.hits,
    required this.randomBaseline,
    required this.catalogSize,
    required this.recommendedTitles,
    required this.meanDiversity,
    required this.minDiversity,
    required this.listsWithAtLeastThreeGenres,
    required this.lists,
  });

  /// Tamaño de la lista evaluada (top-k).
  final int k;

  /// Casos de prueba (un libro oculto por caso).
  final int trials;

  /// Casos en que el libro oculto apareció entre las k primeras sugerencias.
  final int hits;

  /// Hit rate esperado si las k sugerencias se eligieran al azar.
  final double randomBaseline;

  final int catalogSize;

  /// Títulos distintos que aparecieron al menos una vez en alguna lista.
  final int recommendedTitles;

  /// Promedio de géneros distintos en cada lista top-k.
  final double meanDiversity;

  /// Menor cantidad de géneros distintos observada en una lista.
  final int minDiversity;

  /// Listas con al menos tres géneros distintos.
  final int listsWithAtLeastThreeGenres;

  /// Total de listas generadas.
  final int lists;

  /// Hit rate@k.
  double get hitRate => trials == 0 ? 0 : hits / trials;

  /// Cuántas veces supera el hit rate al azar.
  double get lift => randomBaseline == 0 ? 0 : hitRate / randomBaseline;

  /// Cobertura del catálogo.
  double get coverage => catalogSize == 0 ? 0 : recommendedTitles / catalogSize;

  double get shareDiverseLists =>
      lists == 0 ? 0 : listsWithAtLeastThreeGenres / lists;

  @override
  String toString() {
    String pct(double v) => '${(v * 100).toStringAsFixed(1)} %';
    return [
      'Evaluación fuera de línea (leave-one-out, k = $k)',
      '  Casos evaluados: $trials',
      '  Hit rate@$k: ${hitRate.toStringAsFixed(3)} ($hits/$trials)',
      '  Línea base al azar: ${randomBaseline.toStringAsFixed(3)} '
          '(mejora ×${lift.toStringAsFixed(1)})',
      '  Cobertura del catálogo: ${pct(coverage)} '
          '($recommendedTitles/$catalogSize títulos)',
      '  Diversidad top $k: media ${meanDiversity.toStringAsFixed(2)} '
          'géneros, mínimo $minDiversity, '
          '${pct(shareDiverseLists)} de las listas con ≥ 3 géneros',
    ].join('\n');
  }
}

/// Evaluación fuera de línea del motor basado en contenido (OE3).
///
/// Protocolo *leave-one-out* sobre un catálogo de referencia:
///
/// 1. Para cada género con al menos [minBooksPerGenre] libros se simula
///    un lector interesado en ese género.
/// 2. En cada caso se oculta uno de esos libros; el lector tiene en su
///    biblioteca hasta [historySize] de los restantes, terminados y
///    valorados con 4 o 5 estrellas. No se usan géneros del onboarding,
///    para medir solo lo que el motor aprende de la actividad.
/// 3. Se generan las [k] primeras sugerencias sobre todo el catálogo y se
///    registra si el libro oculto aparece (acierto).
///
/// Con todas las listas generadas se calculan además la cobertura del
/// catálogo y la diversidad (géneros principales distintos por lista).
/// El procedimiento es determinista, por lo que se puede repetir y
/// comparar después de ajustar los pesos del motor.
class RecommendationEvaluator {
  RecommendationEvaluator._();

  static EvaluationReport leaveOneOut({
    required List<CatalogBook> catalog,
    int k = 10,
    int historySize = 5,
    int minBooksPerGenre = 3,
  }) {
    final genres = <String>{for (final b in catalog) ...b.genres}.toList()
      ..sort();

    var trials = 0;
    var hits = 0;
    var baselineSum = 0.0;
    var lists = 0;
    var diversitySum = 0;
    var minDiversity = k;
    var diverseLists = 0;
    final recommended = <String>{};

    for (final genre in genres) {
      final relevant = catalog.where((b) => b.genres.contains(genre)).toList();
      if (relevant.length < minBooksPerGenre) continue;

      for (final hidden in relevant) {
        final history = relevant
            .where((b) => !identical(b, hidden))
            .take(historySize)
            .toList();
        final library = [
          for (var i = 0; i < history.length; i++)
            _asCompletedBook(history[i], rating: i.isEven ? 5.0 : 4.0),
        ];

        final profile = RecommendationEngine.buildProfile(
          favoriteGenres: const [],
          books: library,
        );
        final top = RecommendationEngine.rank(
          profile: profile,
          candidates: catalog,
          library: library,
          limit: k,
        );

        trials++;
        if (top.any((r) => r.book.key == hidden.key)) hits++;
        final candidates = catalog.length - library.length;
        baselineSum += candidates <= 0 ? 0 : k / candidates;

        lists++;
        recommended.addAll(top.map((r) => r.book.key));
        final distinct = top
            .where((r) => r.book.genres.isNotEmpty)
            .map((r) => r.book.genres.first)
            .toSet()
            .length;
        diversitySum += distinct;
        if (distinct < minDiversity) minDiversity = distinct;
        if (distinct >= 3) diverseLists++;
      }
    }

    final catalogKeys = catalog.map((b) => b.key).toSet();
    return EvaluationReport(
      k: k,
      trials: trials,
      hits: hits,
      randomBaseline: trials == 0 ? 0 : baselineSum / trials,
      catalogSize: catalogKeys.length,
      recommendedTitles: recommended.intersection(catalogKeys).length,
      meanDiversity: lists == 0 ? 0 : diversitySum / lists,
      minDiversity: lists == 0 ? 0 : minDiversity,
      listsWithAtLeastThreeGenres: diverseLists,
      lists: lists,
    );
  }

  static Book _asCompletedBook(CatalogBook book, {required double rating}) {
    final date = DateTime(2026, 1, 1);
    return Book(
      id: book.id,
      title: book.title,
      author: book.author,
      totalPages: book.pageCount ?? 100,
      currentPage: book.pageCount ?? 100,
      addedAt: date,
      updatedAt: date,
      genres: book.genres,
      status: ReadingStatus.completed,
      rating: rating,
    );
  }
}
