import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/library_provider.dart';
import 'providers/recommendation_provider.dart';
import 'services/book_lookup_service.dart';
import 'services/cloud_backend.dart';
import 'services/firebase_cloud_backend.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cloud = await initCloud();
  final app = await LibrIADemo.bootstrap(cloud: cloud);
  runApp(app);
}

/// Inicializa Firebase en las plataformas configuradas (Android y web).
/// En el resto (por ejemplo Windows), o si falla la inicialización, la app
/// funciona solo con datos locales.
Future<CloudBackend> initCloud() async {
  final supported =
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;
  if (!supported) return const NoCloudBackend();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Espera a que Firebase restaure la sesión guardada antes de mostrar la
    // app, para saber si la cuenta en sesión puede sincronizar.
    await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    return FirebaseCloudBackend();
  } catch (e) {
    debugPrint('Firebase no disponible; se usa solo almacenamiento local: $e');
    return const NoCloudBackend();
  }
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
  /// [lookup] permite inyectar un servicio sin red en las pruebas y [cloud]
  /// el servicio de respaldo (sin nube por defecto).
  static Future<LibrIADemo> bootstrap({
    BookLookupService? lookup,
    CloudBackend cloud = const NoCloudBackend(),
  }) async {
    await LocalStorageService.instance.init();
    final lookupService = lookup ?? BookLookupService();
    final auth = AuthProvider(cloud: cloud);
    final library = LibraryProvider(cloud: cloud);
    await auth.hydrate();

    // La biblioteca siempre corresponde al usuario en sesión.
    void bind() => library.bindUser(
          auth.currentUser?.id,
          cloudUid: auth.currentUser?.cloudUid,
        );
    bind();
    auth.addListener(bind);
    // Antes de cerrar la sesión en la nube se envían los cambios pendientes.
    auth.onBeforeCloudSignOut = library.flushSync;

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
