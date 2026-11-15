import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libria_v01/data/local_catalog.dart';
import 'package:libria_v01/providers/auth_provider.dart';
import 'package:libria_v01/providers/library_provider.dart';
import 'package:libria_v01/services/local_storage_service.dart';
import 'package:libria_v01/services/recommendation_evaluator.dart';

/// Evaluación fuera de línea del motor de recomendaciones (OE3) y de la
/// métrica de aceptación de sugerencias.
///
/// Umbrales definidos en la Tabla 7 del informe: hit rate@10 ≥ 0,30,
/// cobertura ≥ 40 % y al menos 3 géneros distintos en el top 10.
/// Ejecutar con `flutter test test/recommendation_eval_test.dart`; los
/// valores obtenidos se imprimen en la consola.
void main() {
  group('Evaluación fuera de línea (leave-one-out)', () {
    late EvaluationReport report;

    setUpAll(() {
      report = RecommendationEvaluator.leaveOneOut(catalog: localCatalog);
      // ignore: avoid_print
      print(report);
    });

    test('se evalúan casos de todos los géneros con datos suficientes', () {
      expect(report.trials, greaterThan(50));
      expect(report.lists, report.trials);
    });

    test('hit rate@10 ≥ 0,30 y supera a la recomendación al azar', () {
      expect(report.hitRate, greaterThanOrEqualTo(0.30));
      expect(report.hitRate, greaterThan(report.randomBaseline * 2));
    });

    test('cobertura del catálogo ≥ 40 %', () {
      expect(report.coverage, greaterThanOrEqualTo(0.40));
    });

    test('diversidad: en promedio ≥ 3 géneros distintos en el top 10', () {
      expect(report.meanDiversity, greaterThanOrEqualTo(3));
      expect(report.shareDiverseLists, greaterThanOrEqualTo(0.9));
    });

    test('la evaluación es determinista', () {
      final again = RecommendationEvaluator.leaveOneOut(catalog: localCatalog);
      expect(again.hits, report.hits);
      expect(again.recommendedTitles, report.recommendedTitles);
    });
  });

  group('Métrica de aceptación de sugerencias', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService.instance.resetForTests();
    });

    test('cuenta sugerencias únicas mostradas y aceptadas, y persiste', () async {
      final auth = AuthProvider();
      await auth.hydrate();
      await auth.register(name: 'Eva', email: 'eva@t.cl', password: '12345678');
      final userId = auth.currentUser!.id;
      final library = LibraryProvider()..bindUser(userId);

      expect(library.acceptanceRate, isNull);

      for (final key in ['a|x', 'b|y', 'c|z', 'd|w', 'a|x']) {
        library.recordSuggestionShown(key);
      }
      await library.recordSuggestionAccepted('b|y');
      await library.dismissSuggestion('c|z');
      await Future<void>.delayed(Duration.zero);

      expect(library.suggestionsShown, 4);
      expect(library.suggestionsAccepted, 1);
      expect(library.suggestionsDismissed, 1);
      expect(library.acceptanceRate, closeTo(0.25, 1e-9));

      // Los contadores se recuperan al volver a cargar la cuenta.
      final reloaded = LibraryProvider()..bindUser(userId);
      expect(reloaded.suggestionsShown, 4);
      expect(reloaded.suggestionsAccepted, 1);
    });

    test('aceptar una sugerencia no vista también la cuenta como mostrada',
        () async {
      final auth = AuthProvider();
      await auth.hydrate();
      await auth.register(name: 'Leo', email: 'leo@t.cl', password: '12345678');
      final library = LibraryProvider()..bindUser(auth.currentUser!.id);

      await library.recordSuggestionAccepted('e|v');
      expect(library.suggestionsShown, 1);
      expect(library.acceptanceRate, 1);
    });
  });
}
