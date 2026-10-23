import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../models/reading_event.dart';
import '../../../providers/library_provider.dart';
import '../../../widgets/book_tiles.dart';
import '../../../widgets/common_widgets.dart';

/// Historial de la trayectoria lectora (RF-07), agrupado por día.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = context.watch<LibraryProvider>().events;

    final groups = <DateTime, List<ReadingEvent>>{};
    for (final event in events) {
      groups.putIfAbsent(dateOnly(event.createdAt), () => []).add(event);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de lectura')),
      body: events.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'Aún no hay actividad',
              message:
                  'Cada libro que agregues, comiences, avances o termines quedará registrado aquí.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  '${events.length} registros desde el ${formatDateLong(events.last.createdAt)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                for (final entry in groups.entries) ...[
                  SectionHeader(title: formatDateLong(entry.key)),
                  Card(
                    child: Column(
                      children: [
                        for (final event in entry.value) EventTile(event: event),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Fila de un evento del historial.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, this.dense = false});

  final ReadingEvent event;
  final bool dense;

  IconData get _icon => switch (event.type) {
        ReadingEventType.added => Icons.library_add_outlined,
        ReadingEventType.started => Icons.play_circle_outline,
        ReadingEventType.progress => Icons.trending_up,
        ReadingEventType.paused => Icons.pause_circle_outline,
        ReadingEventType.resumed => Icons.play_arrow,
        ReadingEventType.completed => Icons.check_circle_outline,
        ReadingEventType.abandoned => Icons.do_not_disturb_on_outlined,
        ReadingEventType.restarted => Icons.replay,
        ReadingEventType.markedPending => Icons.bookmark_border,
        ReadingEventType.rated => Icons.star_outline,
        ReadingEventType.reviewed => Icons.rate_review_outlined,
        ReadingEventType.commented => Icons.format_quote,
        ReadingEventType.recommended => Icons.volunteer_activism_outlined,
      };

  String get _text {
    final title = '«${event.bookTitle}»';
    final delta = (event.value ?? 0).round();
    return switch (event.type) {
      ReadingEventType.added => 'Agregaste $title a tu biblioteca',
      ReadingEventType.started => 'Comenzaste a leer $title',
      ReadingEventType.progress => delta > 0
          ? 'Avanzaste $delta págs. en $title (pág. ${event.page})'
          : 'Actualizaste tu avance en $title (pág. ${event.page})',
      ReadingEventType.paused => 'Pausaste $title',
      ReadingEventType.resumed => 'Retomaste $title',
      ReadingEventType.completed => 'Terminaste $title',
      ReadingEventType.abandoned => 'Abandonaste $title',
      ReadingEventType.restarted => 'Comenzaste a releer $title',
      ReadingEventType.markedPending =>
        'Volviste a dejar $title en «Quiero leerlo»',
      ReadingEventType.rated =>
        'Calificaste $title con ${(event.value ?? 0).toStringAsFixed(0)} ★',
      ReadingEventType.reviewed => 'Escribiste una reseña de $title',
      ReadingEventType.commented => 'Comentaste $title',
      ReadingEventType.recommended => 'Recomendaste $title',
    };
  }

  @override
  Widget build(BuildContext context) {
    final exists = context.watch<LibraryProvider>().bookById(event.bookId) != null;
    final time =
        '${event.createdAt.hour.toString().padLeft(2, '0')}:${event.createdAt.minute.toString().padLeft(2, '0')}';
    return ListTile(
      dense: dense,
      leading: Icon(_icon, color: AppColors.secondary),
      title: Text(_text),
      subtitle: Text(dense ? formatDateTime(event.createdAt) : time),
      onTap: exists ? () => openBookDetail(context, event.bookId) : null,
    );
  }
}
