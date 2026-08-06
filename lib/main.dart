import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'providers/auth_provider.dart';
import 'providers/library_provider.dart';
import 'providers/social_provider.dart';

void main() {
  runApp(const LibrIADemo());
}

class LibrIADemo extends StatelessWidget {
  const LibrIADemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => SocialProvider()),
      ],
      child: const LibrIAApp(),
    );
  }
}
