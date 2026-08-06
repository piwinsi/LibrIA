import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/auth/screens/welcome_screen.dart';
import '../../../models/book.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/library_provider.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final books = context.watch<LibraryProvider>().books;
    final booksRead = books
        .where((book) => book.status == ReadingStatus.completed)
        .length;
    final booksInProgress = books
        .where((book) => book.status == ReadingStatus.reading)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar perfil',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CircleAvatar(
                  radius: 40,
                  child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Center(child: Text(user.email)),
                if (user.bio != null) ...[
                  const SizedBox(height: 12),
                  Text(user.bio!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ProfileStat(label: 'Leídos', value: booksRead),
                    _ProfileStat(label: 'En progreso', value: booksInProgress),
                    _ProfileStat(label: 'Seguidores', value: user.followers),
                    _ProfileStat(label: 'Siguiendo', value: user.following),
                  ],
                ),
                if (user.favoriteGenres.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Géneros favoritos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: user.favoriteGenres
                        .map((genre) => Chip(label: Text(genre)))
                        .toList(),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleLarge),
        Text(label),
      ],
    );
  }
}
