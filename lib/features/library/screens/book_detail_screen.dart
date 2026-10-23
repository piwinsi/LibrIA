import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../models/book.dart';
import '../../../models/book_comment.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/recommendation_provider.dart';
import '../../../widgets/book_tiles.dart';
import '../../../widgets/common_widgets.dart';
import 'book_form_screen.dart';
import 'update_progress_screen.dart';

/// Ficha del libro: estado, avance y fechas (RF-04, RF-05), valoración,
/// reseña y comentarios (RF-06), recomendación (RF-08) y libros similares.
class BookDetailScreen extends StatefulWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Descarga sugerencias relacionadas fuera del ciclo de construcción.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final book = context.read<LibraryProvider>().bookById(widget.bookId);
      if (book == null) return;
      final recommendations = context.read<RecommendationProvider>();
      recommendations.ensureAuthor(splitAuthors(book.author).firstOrNull ?? book.author);
      for (final genre in book.genres.take(2)) {
        recommendations.ensureGenre(genre);
      }
    });
  }

  LibraryProvider get _library => context.read<LibraryProvider>();

  void _openProgress(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UpdateProgressScreen(bookId: book.id)),
    );
  }

  Future<void> _abandon(Book book) async {
    final ok = await confirmAction(
      context,
      title: 'Abandonar lectura',
      message:
          'Se guardará tu avance actual (pág. ${book.currentPage}). Podrás retomarlo cuando quieras.',
      confirmLabel: 'Abandonar',
      destructive: true,
    );
    if (ok) await _library.abandonBook(book.id);
  }

  Future<void> _complete(Book book) async {
    await _library.markCompleted(book.id);
    if (!mounted) return;
    showSnack(context, '¡Terminaste «${book.title}»! Puedes valorarlo abajo.');
  }

  Future<void> _restart(Book book) async {
    final ok = await confirmAction(
      context,
      title: 'Volver a leer',
      message: 'El avance volverá a la página 0 y se registrará una nueva lectura.',
      confirmLabel: 'Releer',
    );
    if (ok) await _library.restartReading(book.id);
  }

  Future<void> _editDates(Book book) async {
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      helpText: 'Fecha de inicio',
      initialDate: book.startDate ?? now,
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (start == null || !mounted) return;
    DateTime? finish = book.finishDate;
    if (book.status == ReadingStatus.completed) {
      final initialFinish = (book.finishDate ?? now).isBefore(start)
          ? start
          : (book.finishDate ?? now);
      finish = await showDatePicker(
        context: context,
        helpText: 'Fecha de término',
        initialDate: initialFinish,
        firstDate: start,
        lastDate: now,
      );
      if (finish == null) return;
    }
    await _library.setDates(book.id, startDate: start, finishDate: finish);
    if (!mounted) return;
    showSnack(context, 'Fechas actualizadas.');
  }

  Future<void> _editReview(Book book) async {
    final text = await promptText(
      context,
      title: book.hasReview ? 'Editar reseña' : 'Escribir reseña',
      initialValue: book.review ?? '',
      hint: '¿Qué te pareció? ¿Qué te dejó este libro?',
      maxLines: 8,
    );
    if (text == null) return;
    await _library.saveReview(book.id, text);
  }

  Future<void> _addComment(Book book) async {
    final result = await showDialog<_CommentInput>(
      context: context,
      builder: (_) => _CommentDialog(defaultPage: book.currentPage),
    );
    if (result == null || result.text.trim().isEmpty) return;
    await _library.addComment(book.id, result.text, page: result.page);
    if (!mounted) return;
    showSnack(context, 'Comentario guardado.');
  }

  Future<void> _deleteComment(BookComment comment) async {
    final ok = await confirmAction(
      context,
      title: 'Eliminar comentario',
      message: '¿Seguro que quieres eliminar este comentario?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (ok) await _library.deleteComment(comment.id);
  }

  Future<void> _recommend(Book book) async {
    final message = await promptText(
      context,
      title: 'Recomendar «${book.title}»',
      hint: '¿Por qué lo recomiendas? (opcional)',
      confirmLabel: 'Compartir',
      maxLines: 4,
    );
    if (message == null) return;
    final recommendation = await _library.addSharedRecommendation(book.id, message);
    if (recommendation == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: recommendation.shareText,
          subject: 'Te recomiendo «${book.title}»',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showSnack(context, 'Recomendación guardada. No se pudo abrir el menú para compartir.');
    }
  }

  /// Permite corregir el estado: cualquier estado, incluido volver a
  /// "Quiero leerlo" (pendiente).
  Future<void> _changeStatus(Book book) async {
    final selected = await showModalBottomSheet<ReadingStatus>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Cambiar estado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            for (final status in ReadingStatus.values)
              ListTile(
                key: ValueKey('status_${status.name}'),
                leading: Icon(status.icon, color: status.color),
                title: Text(
                  status == ReadingStatus.pending
                      ? 'Quiero leerlo (pendiente)'
                      : status.label,
                ),
                trailing: status == book.status
                    ? const Icon(Icons.check, color: AppColors.success)
                    : null,
                onTap: () => Navigator.pop(sheetContext, status),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || selected == book.status || !mounted) return;

    if (selected == ReadingStatus.pending &&
        (book.currentPage > 0 || book.startDate != null)) {
      final ok = await confirmAction(
        context,
        title: 'Volver a "Quiero leerlo"',
        message:
            'Se borrarán el avance (pág. ${book.currentPage}) y las fechas de lectura. '
            'Tu valoración, reseña y comentarios se conservan.',
        confirmLabel: 'Cambiar',
      );
      if (!ok) return;
    }
    await _library.setStatus(book.id, selected);
    if (!mounted) return;
    showSnack(
      context,
      selected == ReadingStatus.pending
          ? '«${book.title}» volvió a tu lista de pendientes.'
          : 'Estado cambiado a ${selected.label.toLowerCase()}.',
    );
  }

  Future<void> _delete(Book book) async {
    final ok = await confirmAction(
      context,
      title: 'Eliminar libro',
      message:
          'Se eliminarán «${book.title}», su avance, sus comentarios y su historial. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    await _library.removeBook(book.id);
    messenger.showSnackBar(
      SnackBar(content: Text('«${book.title}» se eliminó de tu biblioteca.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final book = library.bookById(widget.bookId);

    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Libro no disponible',
          message: 'Este libro ya no está en tu biblioteca.',
        ),
      );
    }

    final comments = library.commentsFor(book.id);
    final similar = context.watch<RecommendationProvider>().similarTo(book);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Recomendar',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _recommend(book),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookFormScreen(editBookId: book.id),
                  ),
                );
              } else if (value == 'delete') {
                _delete(book);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar datos'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.danger),
                  title: Text('Eliminar libro'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _Header(book: book, onChangeStatus: () => _changeStatus(book)),
          const SizedBox(height: 16),
          _ActionsCard(
            book: book,
            onStart: () => _library.startReading(book.id),
            onProgress: () => _openProgress(book),
            onPause: () => _library.pauseReading(book.id),
            onResume: () => _library.resumeReading(book.id),
            onAbandon: () => _abandon(book),
            onComplete: () => _complete(book),
            onRestart: () => _restart(book),
            onEditDates: () => _editDates(book),
            onChangeStatus: () => _changeStatus(book),
          ),
          if (book.status != ReadingStatus.pending) ...[
            const SectionHeader(title: 'Tu valoración'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: RatingStars(
                        rating: book.rating,
                        size: 32,
                        onChanged: (value) => _library.rateBook(book.id, value),
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Reseña personal',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _editReview(book),
                          icon: Icon(book.hasReview ? Icons.edit : Icons.rate_review_outlined),
                          label: Text(book.hasReview ? 'Editar' : 'Escribir'),
                        ),
                      ],
                    ),
                    Text(
                      book.hasReview
                          ? book.review!
                          : 'Aún no escribes una reseña de este libro.',
                      style: TextStyle(
                        color: book.hasReview
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontStyle: book.hasReview ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          SectionHeader(
            title: 'Comentarios y reflexiones (${comments.length})',
            actionLabel: 'Agregar',
            onAction: () => _addComment(book),
          ),
          if (comments.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Anota ideas, citas o reflexiones mientras lees. Solo tú puedes verlas.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...comments.map(
              (comment) => Card(
                child: ListTile(
                  leading: const Icon(Icons.format_quote, color: AppColors.secondary),
                  title: Text(comment.text),
                  subtitle: Text(
                    [
                      if (comment.page != null) 'Pág. ${comment.page}',
                      formatDateTime(comment.createdAt),
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Eliminar comentario',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteComment(comment),
                  ),
                ),
              ),
            ),
          if (book.description.isNotEmpty) ...[
            const SectionHeader(title: 'Descripción'),
            Text(book.description),
          ],
          const SectionHeader(title: 'Recomendar'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.volunteer_activism_outlined,
                  color: AppColors.secondary),
              title: const Text('Recomienda este libro'),
              subtitle: const Text(
                'Escribe por qué lo recomiendas y compártelo por WhatsApp, correo u otras apps.',
              ),
              onTap: () => _recommend(book),
            ),
          ),
          if (similar.isNotEmpty) ...[
            const SectionHeader(title: 'Si te gustó, podrías leer'),
            RecommendationCarousel(recommendations: similar),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.book, required this.onChangeStatus});

  final Book book;
  final VoidCallback onChangeStatus;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookCover(title: book.title, url: book.coverUrl, width: 110, height: 165),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(book.author, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onChangeStatus,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(status: book.status),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              GenreTags(genres: book.genres, max: 4),
              const SizedBox(height: 8),
              Text(
                [
                  '${book.totalPages} páginas',
                  if (book.isbn != null) 'ISBN ${book.isbn}',
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (book.editionLabel.isNotEmpty)
                Text(
                  book.editionLabel,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              Text(
                'Agregado el ${formatDate(book.addedAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.book,
    required this.onStart,
    required this.onProgress,
    required this.onPause,
    required this.onResume,
    required this.onAbandon,
    required this.onComplete,
    required this.onRestart,
    required this.onEditDates,
    required this.onChangeStatus,
  });

  final Book book;
  final VoidCallback onStart;
  final VoidCallback onProgress;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onAbandon;
  final VoidCallback onComplete;
  final VoidCallback onRestart;
  final VoidCallback onEditDates;
  final VoidCallback onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];
    switch (book.status) {
      case ReadingStatus.pending:
        buttons.add(
          FilledButton.icon(
            key: const Key('action_start'),
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Comenzar lectura'),
          ),
        );
        buttons.add(
          OutlinedButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.check),
            label: const Text('Ya lo leí'),
          ),
        );
      case ReadingStatus.reading:
        buttons.addAll([
          FilledButton.icon(
            key: const Key('action_progress'),
            onPressed: onProgress,
            icon: const Icon(Icons.edit_note),
            label: const Text('Actualizar progreso'),
          ),
          OutlinedButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.check),
            label: const Text('Terminar'),
          ),
          OutlinedButton.icon(
            onPressed: onPause,
            icon: const Icon(Icons.pause),
            label: const Text('Pausar'),
          ),
          OutlinedButton.icon(
            onPressed: onAbandon,
            icon: const Icon(Icons.do_not_disturb_on_outlined),
            label: const Text('Abandonar'),
          ),
        ]);
      case ReadingStatus.paused:
        buttons.addAll([
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Retomar'),
          ),
          OutlinedButton.icon(
            onPressed: onProgress,
            icon: const Icon(Icons.edit_note),
            label: const Text('Actualizar progreso'),
          ),
          OutlinedButton.icon(
            onPressed: onAbandon,
            icon: const Icon(Icons.do_not_disturb_on_outlined),
            label: const Text('Abandonar'),
          ),
        ]);
      case ReadingStatus.completed:
        buttons.add(
          OutlinedButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.replay),
            label: const Text('Volver a leer'),
          ),
        );
      case ReadingStatus.abandoned:
        buttons.add(
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Retomar lectura'),
          ),
        );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.status != ReadingStatus.pending) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Página ${book.currentPage} de ${book.totalPages}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text('${book.progressPercent}%'),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: book.progress, minHeight: 8),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: onEditDates,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.event, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            'Inicio: ${book.startDate == null ? '—' : formatDate(book.startDate!)}',
                            if (book.status == ReadingStatus.completed)
                              'Término: ${book.finishDate == null ? '—' : formatDate(book.finishDate!)}',
                          ].join('   '),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Este libro está en tu lista de pendientes.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            Wrap(spacing: 8, runSpacing: 8, children: buttons),
            const SizedBox(height: 4),
            TextButton.icon(
              key: const Key('action_change_status'),
              onPressed: onChangeStatus,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Cambiar estado (¿te equivocaste?)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentInput {
  const _CommentInput(this.text, this.page);

  final String text;
  final int? page;
}

class _CommentDialog extends StatefulWidget {
  const _CommentDialog({required this.defaultPage});

  final int defaultPage;

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final _text = TextEditingController();
  late final TextEditingController _page = TextEditingController(
    text: widget.defaultPage > 0 ? '${widget.defaultPage}' : '',
  );

  @override
  void dispose() {
    _text.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo comentario'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('comment_text'),
            controller: _text,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Una idea, una cita o una reflexión...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _page,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Página (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('comment_save'),
          onPressed: () => Navigator.pop(
            context,
            _CommentInput(_text.text, int.tryParse(_page.text.trim())),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
