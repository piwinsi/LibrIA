import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/screens/welcome_screen.dart';
import '../main_navigation_screen.dart';
import '../providers/auth_provider.dart';
import 'theme.dart';

class LibrIAApp extends StatelessWidget {
  const LibrIAApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;

    return MaterialApp(
      title: 'LibrIA',
      theme: buildAppTheme(),
      home: isLoggedIn ? const MainNavigationScreen() : const WelcomeScreen(),
    );
  }
}
