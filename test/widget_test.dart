import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libria_v01/main.dart';

void main() {
  setUp(() {
    // Persistencia local (RNF-07): las pantallas ahora leen/escriben estado
    // vía SharedPreferences, así que se inicializa un mock en memoria antes
    // de cada prueba para que LocalStorageService pueda operar sin acceso
    // real a almacenamiento de plataforma.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Welcome screen shows login button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LibrIADemo());

    expect(find.text('LibrIA'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('Login with demo credentials opens main navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LibrIADemo());

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Inicio'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
