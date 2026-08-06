import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/book.dart';
import '../../../providers/library_provider.dart';

class UpdateProgressScreen extends StatefulWidget {
  const UpdateProgressScreen({super.key, required this.book});

  final Book book;

  @override
  State<UpdateProgressScreen> createState() => _UpdateProgressScreenState();
}

class _UpdateProgressScreenState extends State<UpdateProgressScreen> {
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.currentPage;
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.book.totalPages;
    final percent = totalPages == 0 ? 0.0 : _currentPage / totalPages;

    return Scaffold(
      appBar: AppBar(title: const Text('Actualizar progreso')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.book.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Página $_currentPage de $totalPages'),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: percent),
            const SizedBox(height: 24),
            Slider(
              value: _currentPage.toDouble(),
              min: 0,
              max: totalPages.toDouble(),
              divisions: totalPages > 0 ? totalPages : null,
              label: '$_currentPage',
              onChanged: (value) {
                setState(() => _currentPage = value.round());
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                context.read<LibraryProvider>().updateProgress(
                  widget.book.id,
                  _currentPage,
                );
                Navigator.of(context).pop();
              },
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
