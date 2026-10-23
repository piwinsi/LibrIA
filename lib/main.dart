import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'providers/auth_provider.dart';
import 'providers/library_provider.dart';
import 'providers/recommendation_provider.dart';
import 'services/book_lookup_service.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await LibrIADemo.bootstrap();
  runApp(app);
}

/// Raíz de la aplicación: crea los servicios y providers, los conecta y
/// restaura la sesión guardada en el dispositivo.
class LibrIADemo extends StatelessWidget {
  const LibrIADemo({
    super.key,
    required this.auth,
    required this.library,
    required this.recommendations,
    required this.lookup,
  });

  final AuthProvider auth;
  final LibraryProvider library;
  final RecommendationProvider recommendations;
  final BookLookupService lookup;

  /// Inicializa el almacenamiento local y conecta los providers.
  /// [lookup] permite inyectar un servicio sin red en las pruebas.
  static Future<LibrIADemo> bootstrap({BookLookupService? lookup}) async {
    await LocalStorageService.instance.init();
    final lookupService = lookup ?? BookLookupService();
    final auth = AuthProvider();
    final library = LibraryProvider();
    await auth.hydrate();

    // La biblioteca siempre corresponde al usuario en sesión.
    library.bindUser(auth.currentUser?.id);
    auth.addListener(() => library.bindUser(auth.currentUser?.id));

    final recommendations = RecommendationProvider(
      lookup: lookupService,
      auth: auth,
      library: library,
    );

    return LibrIADemo(
      auth: auth,
      library: library,
      recommendations: recommendations,
      lookup: lookupService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BookLookupService>.value(value: lookup),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<LibraryProvider>.value(value: library),
        ChangeNotifierProvider<RecommendationProvider>.value(
          value: recommendations,
        ),
      ],
      child: const LibrIAApp(),
    );
  }
}
