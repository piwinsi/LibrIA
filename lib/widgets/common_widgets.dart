import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/genres.dart';
import '../models/book.dart';
import '../services/local_storage_service.dart';

/// Portada del libro. Si no hay imagen (o falla la carga), muestra una
/// portada generada con el título.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.title,
    this.url,
    this.width = 56,
    this.height = 84,
  });

  final String title;
  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final placeholder = _GeneratedCover(title: title, width: width, height: height);
    final imageUrl = url;
    return Semantics(
      label: 'Portada de $title',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.12),
        child: SizedBox(
          width: width,
          height: height,
          child: imageUrl == null || imageUrl.isEmpty
              ? placeholder
              : imageUrl.startsWith('local:')
                  ? _localCover(imageUrl.substring(6), placeholder)
                  : Image.network(
                  imageUrl,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => placeholder,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : placeholder,
                ),
        ),
      ),
    );
  }
}

/// Portada personalizada guardada en el dispositivo.
Widget _localCover(String bookId, Widget placeholder) {
  final bytes = LocalStorageService.instance.loadCover(bookId);
  if (bytes == null) return placeholder;
  return Image.memory(
    bytes,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    errorBuilder: (context, error, stackTrace) => placeholder,
  );
}

class _GeneratedCover extends StatelessWidget {
  const _GeneratedCover({
    required this.title,
    required this.width,
    required this.height,
  });

  final String title;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.coverPalette[
        title.codeUnits.fold<int>(0, (a, b) => a + b) %
            AppColors.coverPalette.length];
    final showTitle = width >= 70;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(width * 0.08),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
        ),
      ),
      child: showTitle
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded,
                    color: Colors.white70, size: width * 0.25),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: width * 0.11,
                  ),
                ),
              ],
            )
          : Center(
              child: Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: width * 0.45),
            ),
    );
  }
}

/// Etiqueta con el estado de lectura.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.dense = false});

  final ReadingStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: dense ? 13 : 16, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.w600,
              fontSize: dense ? 11 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Estrellas de valoración (1 a 5). Si [onChanged] es nulo, solo muestra.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 28,
  });

  final double? rating;
  final ValueChanged<double>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = rating ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = index + 1;
        final icon = Icon(
          value >= star
              ? Icons.star_rounded
              : (value >= star - 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded),
          color: AppColors.star,
          size: size,
        );
        if (onChanged == null) return icon;
        return IconButton(
          tooltip: '$star ${star == 1 ? 'estrella' : 'estrellas'}',
          visualDensity: VisualDensity.compact,
          icon: icon,
          onPressed: () => onChanged!(star.toDouble()),
        );
      }),
    );
  }
}

/// Mensaje para listas vacías con una acción opcional.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Título de sección con acción opcional a la derecha.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Selector múltiple de géneros (onboarding, formulario y perfil).
class GenreSelector extends StatelessWidget {
  const GenreSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final genre in Genres.all)
          FilterChip(
            key: ValueKey('genre_${genre.id}'),
            avatar: Icon(genre.icon, size: 18),
            label: Text(genre.label),
            selected: selected.contains(genre.id),
            onSelected: (isSelected) {
              final next = Set<String>.from(selected);
              if (isSelected) {
                next.add(genre.id);
              } else {
                next.remove(genre.id);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

/// Chips pequeños de solo lectura con los géneros de un libro.
class GenreTags extends StatelessWidget {
  const GenreTags({super.key, required this.genres, this.max = 3});

  final List<String> genres;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final genre in genres.take(max))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              Genres.labelOf(genre),
              style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
            ),
          ),
      ],
    );
  }
}

void showSnack(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

/// Diálogo de confirmación reutilizable.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Diálogo con un campo de texto multilínea. Devuelve `null` si se cancela.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String hint = '',
  String confirmLabel = 'Guardar',
  int maxLines = 5,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _TextPromptDialog(
      title: title,
      initialValue: initialValue,
      hint: hint,
      confirmLabel: confirmLabel,
      maxLines: maxLines,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initialValue,
    required this.hint,
    required this.confirmLabel,
    required this.maxLines,
  });

  final String title;
  final String initialValue;
  final String hint;
  final String confirmLabel;
  final int maxLines;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
