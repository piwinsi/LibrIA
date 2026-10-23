import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../models/catalog_book.dart';
import '../../../providers/library_provider.dart';
import '../../../services/book_lookup_service.dart';
import 'book_detail_screen.dart';
import 'book_form_screen.dart';

/// Registro de libros mediante el código de barras ISBN.
///
/// La cámara lee el código EAN-13 impreso en la contraparte del libro; con
/// ese ISBN se consultan Google Books y Open Library para completar título,
/// autor, páginas, géneros y portada. El usuario revisa los datos antes de
/// guardarlos. Si la cámara no está disponible (por ejemplo en Windows),
/// el ISBN puede escribirse a mano.
class IsbnScannerScreen extends StatefulWidget {
  const IsbnScannerScreen({super.key});

  @override
  State<IsbnScannerScreen> createState() => _IsbnScannerScreenState();
}

class _IsbnScannerScreenState extends State<IsbnScannerScreen> {
  final _manualController = TextEditingController();
  bool _processing = false;
  String? _status;

  bool get _cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final isbn = cleanIsbn(raw);
      if (isValidIsbn(isbn)) {
        _lookup(isbn);
        return;
      }
    }
  }

  Future<void> _submitManual() async {
    final isbn = cleanIsbn(_manualController.text);
    if (!isValidIsbn(isbn)) {
      setState(() => _status =
          'El ISBN no es válido. Revisa que tenga 10 o 13 dígitos.');
      return;
    }
    FocusScope.of(context).unfocus();
    await _lookup(isbn);
  }

  Future<void> _lookup(String isbn) async {
    setState(() {
      _processing = true;
      _status = 'Buscando ISBN $isbn...';
    });
    HapticFeedback.mediumImpact();

    final library = context.read<LibraryProvider>();
    final lookup = context.read<BookLookupService>();
    final navigator = Navigator.of(context);

    final existing = library.findByIsbn(isbn);
    if (existing != null) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: existing.id)),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${existing.title}» ya está en tu biblioteca.')),
      );
      return;
    }

    final result = await lookup.lookupIsbn(isbn);
    if (!mounted) return;

    if (result != null) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookFormScreen(prefill: result, source: 'isbn'),
        ),
      );
      return;
    }

    final manual = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No encontramos el libro'),
        content: Text(
          'No hay datos para el ISBN $isbn en los catálogos consultados '
          '(o no hay conexión). Puedes registrarlo completando los datos a mano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Escanear otro'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ingresar a mano'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (manual == true) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookFormScreen(
            prefill: CatalogBook(
              id: 'isbn_$isbn',
              title: '',
              author: '',
              isbn: isbn,
              source: 'isbn',
            ),
            source: 'isbn',
          ),
        ),
      );
    } else {
      setState(() {
        _processing = false;
        _status = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear ISBN')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _cameraSupported
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(onDetect: _onDetect, fit: BoxFit.cover),
                        const _ScanFrame(),
                        if (_processing)
                          Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                      ],
                    )
                  : const _NoCameraInfo(),
            ),
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _status ??
                        (_cameraSupported
                            ? 'Apunta la cámara al código de barras de la contraportada.'
                            : 'Escribe el ISBN que aparece en la contraportada.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('isbn_manual'),
                          controller: _manualController,
                          keyboardType: TextInputType.number,
                          enabled: !_processing,
                          onSubmitted: (_) => _submitManual(),
                          decoration: const InputDecoration(
                            labelText: 'ISBN manual',
                            hintText: '978...',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _processing ? null : _submitManual,
                        child: const Text('Buscar'),
                      ),
                    ],
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

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 280,
          height: 140,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _NoCameraInfo extends StatelessWidget {
  const _NoCameraInfo();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography_outlined, size: 56, color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'La cámara no está disponible en esta plataforma.\n'
              'En el teléfono podrás escanear el código de barras; aquí puedes '
              'escribir el ISBN.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
