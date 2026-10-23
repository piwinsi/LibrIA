import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/screens/welcome_screen.dart';
import '../features/onboarding/screens/genre_onboarding_screen.dart';
import '../main_navigation_screen.dart';
import '../providers/auth_provider.dart';
import 'theme.dart';

class LibrIAApp extends StatelessWidget {
  const LibrIAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibrIA',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const RootGate(),
    );
  }
}

/// Decide qué mostrar según la sesión: bienvenida, selección de géneros
/// (primer ingreso) o la navegación principal.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) return const WelcomeScreen();
    if (auth.needsOnboarding) return const GenreOnboardingScreen();
    return MainNavigationScreen(key: ValueKey(auth.currentUser!.id));
  }
}
