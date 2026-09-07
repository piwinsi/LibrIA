import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'providers/auth_provider.dart';
import 'providers/library_provider.dart';
import 'providers/social_provider.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Persistencia local (RNF-07): se inicializa el servicio y se hidratan
  // los tres providers desde almacenamiento local antes de construir la UI,
  // de modo que la app arranque ya con el último estado guardado.
  await LocalStorageService.instance.init();

  final authProvider = AuthProvider();
  final libraryProvider = LibraryProvider();
  final socialProvider = SocialProvider();

  await Future.wait([
    authProvider.hydrate(),
    libraryProvider.hydrate(),
    socialProvider.hydrate(),
  ]);

  runApp(LibrIADemo(
    authProvider: authProvider,
    libraryProvider: libraryProvider,
    socialProvider: socialProvider,
  ));
}

class LibrIADemo extends StatelessWidget {
  const LibrIADemo({
    super.key,
    this.authProvider,
    this.libraryProvider,
    this.socialProvider,
  });

  final AuthProvider? authProvider;
  final LibraryProvider? libraryProvider;
  final SocialProvider? socialProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authProvider ?? AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => libraryProvider ?? LibraryProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => socialProvider ?? SocialProvider(),
        ),
      ],
      child: const LibrIAApp(),
    );
  }
}
