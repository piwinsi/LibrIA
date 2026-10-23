import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libria_v01/main.dart';
import 'package:libria_v01/services/book_lookup_service.dart';
import 'package:libria_v01/services/local_storage_service.dart';

/// Pantalla de teléfono alta para que las secciones queden visibles.
void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<LibrIADemo> _buildApp() async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorageService.instance.resetForTests();
  return LibrIADemo.bootstrap(lookup: BookLookupService(enabled: false));
}

void main() {
  testWidgets('La bienvenida muestra las opciones de ingreso', (tester) async {
    _usePhoneSize(tester);
    final app = await _buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('LibrIA'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets('Registro → selección de géneros → navegación principal',
      (tester) async {
    _usePhoneSize(tester);
    final app = await _buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('register_name')), 'Ana Lectora');
    await tester.enterText(find.byKey(const Key('register_email')), 'ana@correo.cl');
    await tester.enterText(find.byKey(const Key('register_password')), 'claveSegura1');
    await tester.enterText(find.byKey(const Key('register_confirm')), 'claveSegura1');
    await tester.ensureVisible(find.byKey(const Key('register_submit')));
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué te gusta leer?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('genre_fantasia')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_continue')));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Hola, Ana'), findsOneWidget);
    // Con Fantasía elegida, el inicio ya muestra recomendaciones del catálogo.
    expect(find.text('Recomendados para ti'), findsOneWidget);
    expect(find.text('Porque te gusta Fantasía'), findsWidgets);
  });

  testWidgets('La cuenta demo carga una biblioteca de ejemplo', (tester) async {
    _usePhoneSize(tester);
    final app = await _buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explorar con la cuenta de demostración'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Hábitos atómicos'), findsWidgets);
  });
}
