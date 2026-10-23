import 'package:flutter/material.dart';

import 'book_form_screen.dart';
import 'book_search_screen.dart';
import 'isbn_scanner_screen.dart';

/// Menú con las tres formas de registrar un libro (RF-03).
Future<void> showAddBookSheet(BuildContext context) {
  final navigator = Navigator.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      void open(Widget screen) {
        Navigator.of(sheetContext).pop();
        navigator.push(MaterialPageRoute(builder: (_) => screen));
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Agregar un libro',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              key: const Key('add_scan'),
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Escanear código ISBN'),
              subtitle: const Text('Usa la cámara sobre el código de barras'),
              onTap: () => open(const IsbnScannerScreen()),
            ),
            ListTile(
              key: const Key('add_search'),
              leading: const Icon(Icons.search),
              title: const Text('Buscar por título o autor'),
              subtitle: const Text('Encuentra el libro en catálogos públicos'),
              onTap: () => open(const BookSearchScreen()),
            ),
            ListTile(
              key: const Key('add_manual'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Ingresar manualmente'),
              subtitle: const Text('Completa tú mismo los datos'),
              onTap: () => open(const BookFormScreen()),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
