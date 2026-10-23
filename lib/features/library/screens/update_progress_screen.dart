import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../models/book.dart';
import '../../../providers/library_provider.dart';
import '../../../widgets/common_widgets.dart';

/// Registro del avance de lectura (RF-05). Cada actualización queda en el
/// historial; al llegar a la última página el libro se marca como terminado.
class UpdateProgressScreen extends StatefulWidget {
  const UpdateProgressScreen({super.key, required this.bookId});

  final String bookId;

  @override
  State<UpdateProgressScreen> createState() => _UpdateProgressScreenState();
}

class _UpdateProgressScreenState extends State<UpdateProgressScreen> {
  late int _page;
  late final TextEditingController _pageController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final book = context.read<LibraryProvider>().bookById(widget.bookId);
    _page = book?.currentPage ?? 0;
    _pageController = TextEditingController(text: '$_page');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _setPage(int value, int total) {
    final clamped = value < 0 ? 0 : (total > 0 && value > total ? total : value);
    setState(() => _page = clamped);
    final text = '$clamped';
    if (_pageController.text != text) {
      _pageController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  Future<void> _save(Book book) async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final completes = book.totalPages > 0 && _page >= book.totalPages;
    final delta = _page - book.currentPage;
    await context.read<LibraryProvider>().updateProgress(book.id, _page);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          completes
              ? '¡Felicitaciones! Terminaste «${book.title}». No olvides valorarlo.'
              : delta > 0
                  ? 'Avanzaste $delta páginas. ¡Sigue así!'
                  : 'Progreso actualizado.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = context.watch<LibraryProvider>().bookById(widget.bookId);
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

    final total = book.totalPages;
    final percent = total == 0 ? 0.0 : _page / total;
    final willComplete = total > 0 && _page >= total;

    return Scaffold(
      appBar: AppBar(title: const Text('Actualizar progreso')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                BookCover(title: book.title, url: book.coverUrl, width: 56, height: 84),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: Theme.of(context).textTheme.titleLarge),
                      Text(book.author,
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '${(percent * 100).round()}%',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: percent, minHeight: 10),
            ),
            const SizedBox(height: 24),
            if (total > 0)
              Slider(
                value: _page.toDouble(),
                min: 0,
                max: total.toDouble(),
                label: '$_page',
                divisions: total,
                onChanged: (value) => _setPage(value.round(), total),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Restar 10 páginas',
                  onPressed: () => _setPage(_page - 10, total),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('progress_page'),
                    controller: _pageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Página actual',
                      suffixText: 'de $total',
                    ),
                    onChanged: (value) =>
                        _setPage(int.tryParse(value) ?? 0, total),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.outlined(
                  tooltip: 'Sumar 10 páginas',
                  onPressed: () => _setPage(_page + 10, total),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (willComplete)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.celebration, color: AppColors.success),
                  title: Text('Llegaste a la última página'),
                  subtitle: Text('Al guardar, el libro quedará como terminado.'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('progress_save'),
              onPressed: _saving ? null : () => _save(book),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Guardar progreso'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
