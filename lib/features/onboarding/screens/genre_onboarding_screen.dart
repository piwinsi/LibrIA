import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common_widgets.dart';

/// Selección de géneros favoritos. Se muestra al crear la cuenta y luego
/// puede editarse desde el perfil. Estos géneros alimentan las primeras
/// recomendaciones.
class GenreOnboardingScreen extends StatefulWidget {
  const GenreOnboardingScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  State<GenreOnboardingScreen> createState() => _GenreOnboardingScreenState();
}

class _GenreOnboardingScreenState extends State<GenreOnboardingScreen> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _selected = Set<String>.from(user?.favoriteGenres ?? const <String>[]);
  }

  Future<void> _save({bool skip = false}) async {
    setState(() => _saving = true);
    await context
        .read<AuthProvider>()
        .setFavoriteGenres(skip ? <String>[] : _selected.toList());
    if (!mounted) return;
    if (widget.isEditing) {
      Navigator.of(context).pop();
      showSnack(context, 'Actualizamos tus géneros favoritos.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final count = _selected.length;

    return Scaffold(
      appBar: widget.isEditing
          ? AppBar(title: const Text('Géneros favoritos'))
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (!widget.isEditing) ...[
                    Text(
                      'Hola, ${firstName(user?.name ?? '')} 👋',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    '¿Qué te gusta leer?',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Elige tus géneros favoritos. Te recomendaremos libros a '
                    'partir de ellos y, a medida que registres tus lecturas, '
                    'las sugerencias se ajustarán a lo que realmente lees.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  GenreSelector(
                    selected: _selected,
                    onChanged: (next) => setState(() => _selected = next),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    count == 0
                        ? 'Selecciona al menos un género (te sugerimos 3 o más).'
                        : '$count ${count == 1 ? 'género seleccionado' : 'géneros seleccionados'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('onboarding_continue'),
                    onPressed: count == 0 || _saving ? null : () => _save(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(widget.isEditing ? 'Guardar' : 'Continuar'),
                    ),
                  ),
                  if (!widget.isEditing)
                    TextButton(
                      onPressed: _saving ? null : () => _save(skip: true),
                      child: const Text('Omitir por ahora'),
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
