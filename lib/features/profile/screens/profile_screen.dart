import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/genres.dart';
import '../../../models/book.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../onboarding/screens/genre_onboarding_screen.dart';
import '../../statistics/screens/history_screen.dart';
import 'edit_profile_screen.dart';
import 'my_recommendations_screen.dart';

/// Perfil lector (RF-02) con privacidad configurable (RNF-03).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Cerrar sesión',
      message: '¿Seguro que quieres cerrar tu sesión? Tus datos seguirán guardados en este dispositivo.',
      confirmLabel: 'Cerrar sesión',
    );
    if (ok && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final library = context.watch<LibraryProvider>();
    if (user == null) return const SizedBox.shrink();

    final reviews = library.books.where((b) => b.hasReview).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            tooltip: 'Editar perfil',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 32, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if ((user.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(user.bio!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 8),
          Center(
            child: Chip(
              avatar: Icon(user.isProfilePrivate ? Icons.lock : Icons.public, size: 16),
              label: Text(user.isProfilePrivate ? 'Perfil privado' : 'Perfil visible al compartir'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ProfileStat(label: 'Terminados', value: library.countByStatus(ReadingStatus.completed)),
                  _ProfileStat(label: 'En lectura', value: library.countByStatus(ReadingStatus.reading)),
                  _ProfileStat(label: 'Reseñas', value: reviews),
                  _ProfileStat(label: 'Comentarios', value: library.commentCount),
                ],
              ),
            ),
          ),
          SectionHeader(
            title: 'Géneros favoritos',
            actionLabel: 'Editar',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GenreOnboardingScreen(isEditing: true),
              ),
            ),
          ),
          if (user.favoriteGenres.isEmpty)
            const Text(
              'Aún no eliges géneros. Hazlo para mejorar tus recomendaciones.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final genre in user.favoriteGenres)
                  Chip(
                    avatar: Icon(Genres.iconOf(genre), size: 16),
                    label: Text(Genres.labelOf(genre)),
                  ),
              ],
            ),
          const SectionHeader(title: 'Mi actividad'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Historial de lectura'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.volunteer_activism_outlined),
                  title: const Text('Mis recomendaciones'),
                  subtitle: Text('${library.sharedRecommendations.length} compartidas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyRecommendationsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Privacidad'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: const Text('Perfil privado'),
              subtitle: const Text(
                'Tu actividad lectora no se publica. Solo sale de la app cuando tú compartes una recomendación.',
              ),
              value: user.isProfilePrivate,
              onChanged: (value) =>
                  context.read<AuthProvider>().setProfilePrivate(value),
            ),
          ),
          const SectionHeader(title: 'Respaldo en la nube'),
          _SyncCard(library: library, isCloudAccount: user.isCloudAccount),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('logout_button'),
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
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
        Text(
          '$value',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Estado del respaldo en Firestore y acción para sincronizar a mano.
class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.library, required this.isCloudAccount});

  final LibraryProvider library;
  final bool isCloudAccount;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String title, String subtitle) = switch (library.syncStatus) {
      SyncStatus.localOnly => (
          Icons.phone_android,
          'Solo en este dispositivo',
          isCloudAccount
              ? 'El respaldo no está disponible en esta plataforma.'
              : 'Esta cuenta no tiene respaldo en la nube.',
        ),
      SyncStatus.signedOut => (
          Icons.cloud_off_outlined,
          'Respaldo en pausa',
          'Cierra sesión y vuelve a ingresar para reanudar el respaldo.',
        ),
      SyncStatus.syncing => (
          Icons.cloud_sync_outlined,
          'Sincronizando...',
          'Respaldando tu biblioteca en la nube.',
        ),
      SyncStatus.synced => (
          Icons.cloud_done_outlined,
          'Respaldo al día',
          library.lastSyncAt == null
              ? 'Tus datos están respaldados.'
              : 'Última sincronización: ${_time(library.lastSyncAt!)}',
        ),
      SyncStatus.error => (
          Icons.cloud_off_outlined,
          'Respaldo pendiente',
          library.syncError ?? 'No se pudo sincronizar.',
        ),
    };
    final canSync = library.syncStatus == SyncStatus.synced ||
        library.syncStatus == SyncStatus.error;
    return Card(
      child: ListTile(
        key: const Key('sync_status'),
        leading: Icon(icon, color: AppColors.secondary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: canSync
            ? IconButton(
                tooltip: 'Sincronizar ahora',
                icon: const Icon(Icons.sync),
                onPressed: library.syncNow,
              )
            : null,
      ),
    );
  }

  static String _time(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}-${two(t.month)}-${t.year} ${two(t.hour)}:${two(t.minute)}';
  }
}
