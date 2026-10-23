import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/genres.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/recommendation_provider.dart';
import '../../../widgets/book_tiles.dart';
import '../../../widgets/common_widgets.dart';
import '../../onboarding/screens/genre_onboarding_screen.dart';

/// Sugerencias de lectura personalizadas.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  /// `null` = "Para ti".
  String? _genre;

  void _selectGenre(String? genre) {
    setState(() => _genre = genre);
    if (genre != null) context.read<RecommendationProvider>().ensureGenre(genre);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecommendationProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final favorites = user?.favoriteGenres ?? const <String>[];
    final orderedGenres = [
      ...favorites.map(Genres.byId).whereType<Genre>(),
      ...Genres.all.where((g) => !favorites.contains(g.id)),
    ];
    final items = _genre == null ? provider.forYou : provider.forGenre(_genre!);
    final profile = provider.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Descubrir'),
        actions: [
          IconButton(
            tooltip: 'Actualizar sugerencias',
            icon: const Icon(Icons.refresh),
            onPressed: provider.refresh,
          ),
          IconButton(
            tooltip: 'Elegir géneros favoritos',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GenreOnboardingScreen(isEditing: true),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    avatar: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Para ti'),
                    selected: _genre == null,
                    onSelected: (_) => _selectGenre(null),
                  ),
                ),
                for (final genre in orderedGenres)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(genre.label),
                      selected: _genre == genre.id,
                      onSelected: (_) => _selectGenre(genre.id),
                    ),
                  ),
              ],
            ),
          ),
          if (provider.isLoadingOnline) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_genre == null) _ProfileSummary(activity: profile.activity, topGenres: profile.topGenres(3)),
                if (items.isEmpty)
                  EmptyState(
                    icon: Icons.explore_outlined,
                    title: 'Sin sugerencias por ahora',
                    message: _genre == null
                        ? 'Elige tus géneros favoritos o registra libros para que podamos recomendarte lecturas.'
                        : 'No encontramos libros de este género que no tengas ya. Revisa tu conexión o prueba con otro.',
                    actionLabel: _genre == null ? 'Elegir géneros' : null,
                    onAction: _genre == null
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const GenreOnboardingScreen(isEditing: true),
                              ),
                            )
                        : null,
                  )
                else
                  ...items.map((r) => RecommendationTile(recommendation: r)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Explica en qué se basan las sugerencias.
class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.activity, required this.topGenres});

  final int activity;
  final List<String> topGenres;

  @override
  Widget build(BuildContext context) {
    if (topGenres.isEmpty) return const SizedBox.shrink();
    final basis = activity == 0
        ? 'Basado en los géneros que elegiste.'
        : activity < 4
            ? 'Basado en tus géneros favoritos y en tus primeras lecturas.'
            : 'Basado principalmente en lo que has leído y valorado.';
    return Card(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.insights, color: AppColors.primaryDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(basis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    'Tus intereses: ${topGenres.map(Genres.labelOf).join(', ')}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
