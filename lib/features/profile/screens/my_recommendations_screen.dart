import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../providers/library_provider.dart';
import '../../../widgets/book_tiles.dart';
import '../../../widgets/common_widgets.dart';

/// Recomendaciones que el usuario ha compartido (RF-08).
class MyRecommendationsScreen extends StatelessWidget {
  const MyRecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final items = library.sharedRecommendations;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis recomendaciones')),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.volunteer_activism_outlined,
              title: 'Aún no recomiendas libros',
              message:
                  'Desde la ficha de cualquier libro de tu biblioteca puedes escribir una recomendación y compartirla.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final rec = items[index];
                final exists = library.bookById(rec.bookId) != null;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.bookTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(rec.bookAuthor,
                            style: const TextStyle(color: AppColors.textSecondary)),
                        if (rec.rating != null) ...[
                          const SizedBox(height: 4),
                          RatingStars(rating: rec.rating, size: 16),
                        ],
                        if (rec.message.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('"${rec.message}"',
                              style: const TextStyle(fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          formatDateTime(rec.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (exists)
                              TextButton(
                                onPressed: () => openBookDetail(context, rec.bookId),
                                child: const Text('Ver libro'),
                              ),
                            IconButton(
                              tooltip: 'Compartir de nuevo',
                              icon: const Icon(Icons.share_outlined),
                              onPressed: () => SharePlus.instance.share(
                                ShareParams(text: rec.shareText),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await confirmAction(
                                  context,
                                  title: 'Eliminar recomendación',
                                  message: 'Se eliminará de tu registro (no de donde la compartiste).',
                                  confirmLabel: 'Eliminar',
                                  destructive: true,
                                );
                                if (ok && context.mounted) {
                                  await context
                                      .read<LibraryProvider>()
                                      .deleteSharedRecommendation(rec.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
