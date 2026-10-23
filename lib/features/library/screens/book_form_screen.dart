import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../models/book.dart';
import '../../../models/catalog_book.dart';
import '../../../providers/library_provider.dart';
import '../../../widgets/common_widgets.dart';
import 'book_detail_screen.dart';

/// Formulario para registrar un libro nuevo (manual, desde el ISBN o desde
/// la búsqueda) o editar uno existente. Incluye editorial, año de edición
/// y portada personalizada (galería o cámara).
class BookFormScreen extends StatefulWidget {
  const BookFormScreen({
    super.key,
    this.prefill,
    this.editBookId,
    this.source = 'manual',
  });

  /// Datos sugeridos por el escáner o la búsqueda.
  final CatalogBook? prefill;

  /// Si se indica, el formulario edita ese libro.
  final String? editBookId;

  final String source;

  bool get isEditing => editBookId != null;

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

enum _DuplicateChoice { open, addAnyway }

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _pages;
  late final TextEditingController _isbn;
  late final TextEditingController _publisher;
  late final TextEditingController _year;
  late final TextEditingController _description;
  late final TextEditingController _coverUrl;
  late Set<String> _genres;
  ReadingStatus _initialStatus = ReadingStatus.pending;
  bool _saving = false;

  /// Foto elegida en este formulario (aún no guardada).
  Uint8List? _pickedCover;

  /// Portada local ya guardada del libro que se edita (`local:<id>`).
  String? _existingLocalCover;

  bool get _cameraAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    final editing = widget.editBookId == null
        ? null
        : context.read<LibraryProvider>().bookById(widget.editBookId!);
    final prefill = widget.prefill;

    _title = TextEditingController(text: editing?.title ?? prefill?.title ?? '');
    _author = TextEditingController(text: editing?.author ?? prefill?.author ?? '');
    final pages = editing?.totalPages ?? prefill?.pageCount;
    _pages = TextEditingController(
      text: pages == null || pages == 0 ? '' : '$pages',
    );
    _isbn = TextEditingController(text: editing?.isbn ?? prefill?.isbn ?? '');
    _publisher = TextEditingController(
      text: editing?.publisher ?? prefill?.publisher ?? '',
    );
    final date = editing?.publishedDate ?? prefill?.publishedDate ?? '';
    _year = TextEditingController(text: date.split('-').first);
    _description = TextEditingController(
      text: editing?.description ?? prefill?.description ?? '',
    );

    final currentCover = editing?.coverUrl ?? prefill?.coverUrl ?? '';
    if (currentCover.startsWith('local:')) {
      _existingLocalCover = currentCover;
      _coverUrl = TextEditingController();
    } else {
      _coverUrl = TextEditingController(text: currentCover);
    }
    _genres = {...?editing?.genres, ...?prefill?.genres};
    _coverUrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _pages.dispose();
    _isbn.dispose();
    _publisher.dispose();
    _year.dispose();
    _description.dispose();
    _coverUrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 900,
        imageQuality: 75,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedCover = bytes;
        _existingLocalCover = null;
      });
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la imagen. Revisa los permisos.'),
        ),
      );
    }
  }

  void _removeCover() {
    setState(() {
      _pickedCover = null;
      _existingLocalCover = null;
      _coverUrl.clear();
    });
  }

  /// Valor final de portada que se guarda (si no hay foto nueva).
  String get _finalCoverUrl => _existingLocalCover ?? _coverUrl.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final library = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pages = int.parse(_pages.text.trim());

    if (widget.isEditing) {
      setState(() => _saving = true);
      await library.updateBookInfo(
        widget.editBookId!,
        title: _title.text,
        author: _author.text,
        totalPages: pages,
        description: _description.text,
        genres: _genres.toList(),
        isbn: _isbn.text,
        publisher: _publisher.text,
        publishedDate: _year.text,
        coverUrl: _finalCoverUrl,
        coverBytes: _pickedCover,
      );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Cambios guardados.')));
      return;
    }

    final duplicate = library.findMatching(
      isbn: _isbn.text.trim().isEmpty ? null : _isbn.text,
      title: _title.text,
      author: _author.text,
    );
    if (duplicate != null) {
      // Puede ser otra edición del mismo libro: se deja elegir.
      final choice = await showDialog<_DuplicateChoice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ya tienes un libro igual'),
          content: Text(
            '«${duplicate.title}»'
            '${duplicate.editionLabel.isEmpty ? '' : ' (${duplicate.editionLabel})'}'
            ' ya está en tu biblioteca. Si es otra edición, puedes agregarla igual.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _DuplicateChoice.addAnyway),
              child: const Text('Agregar igual'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _DuplicateChoice.open),
              child: const Text('Abrir el mío'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == _DuplicateChoice.open) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: duplicate.id)),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final book = await library.addBook(
      title: _title.text,
      author: _author.text,
      totalPages: pages,
      description: _description.text,
      coverUrl: _finalCoverUrl,
      coverBytes: _pickedCover,
      isbn: _isbn.text,
      publisher: _publisher.text,
      publishedDate: _year.text,
      genres: _genres.toList(),
      initialStatus: _initialStatus,
      source: widget.source,
    );
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
    );
    messenger.showSnackBar(
      SnackBar(content: Text('«${book.title}» se agregó a tu biblioteca.')),
    );
  }

  Widget _coverPreview() {
    const width = 110.0, height = 165.0;
    final picked = _pickedCover;
    if (picked != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(picked, width: width, height: height, fit: BoxFit.cover),
      );
    }
    final url = _finalCoverUrl;
    return BookCover(
      title: _title.text.isEmpty ? 'Libro' : _title.text,
      url: url.isEmpty ? null : url,
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = _pickedCover != null || _finalCoverUrl.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar libro' : 'Nuevo libro'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: _coverPreview()),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('cover_gallery'),
                    onPressed: () => _pickCover(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galería'),
                  ),
                  if (_cameraAvailable)
                    OutlinedButton.icon(
                      onPressed: () => _pickCover(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Tomar foto'),
                    ),
                  if (hasCover)
                    TextButton.icon(
                      onPressed: _removeCover,
                      icon: const Icon(Icons.hide_image_outlined),
                      label: const Text('Quitar'),
                    ),
                ],
              ),
              if (widget.prefill != null && !widget.isEditing) ...[
                const SizedBox(height: 8),
                const Text(
                  'Revisa los datos encontrados y corrígelos si es necesario.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('form_title'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Título *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa el título.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('form_author'),
                controller: _author,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Autor *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa el autor.' : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      key: const Key('form_publisher'),
                      controller: _publisher,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Editorial',
                        hintText: 'Ej.: Penguin Clásicos',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: const Key('form_year'),
                      controller: _year,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Año'),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final year = int.tryParse(text);
                        if (year == null || year < 1400 || year > DateTime.now().year + 1) {
                          return 'Año no válido.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('form_pages'),
                      controller: _pages,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Páginas *'),
                      validator: (v) {
                        final value = int.tryParse(v?.trim() ?? '');
                        if (value == null || value <= 0) return 'Número de páginas.';
                        if (value > 20000) return 'Revisa el número.';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _isbn,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'ISBN (opcional)'),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return null;
                        return isValidIsbn(text) ? null : 'ISBN no válido.';
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 4,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
              ),
              if (_pickedCover == null && _existingLocalCover == null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _coverUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'o pega la URL de una portada (opcional)',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text('Géneros', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                'Se usan para tus estadísticas y recomendaciones.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              GenreSelector(
                selected: _genres,
                onChanged: (next) => setState(() => _genres = next),
              ),
              if (!widget.isEditing) ...[
                const SizedBox(height: 20),
                Text('¿En qué estado está?',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<ReadingStatus>(
                  segments: const [
                    ButtonSegment(
                      value: ReadingStatus.pending,
                      label: Text('Quiero leerlo'),
                      icon: Icon(Icons.bookmark_border),
                    ),
                    ButtonSegment(
                      value: ReadingStatus.reading,
                      label: Text('Leyendo'),
                      icon: Icon(Icons.auto_stories),
                    ),
                    ButtonSegment(
                      value: ReadingStatus.completed,
                      label: Text('Leído'),
                      icon: Icon(Icons.check),
                    ),
                  ],
                  selected: {_initialStatus},
                  onSelectionChanged: (selection) =>
                      setState(() => _initialStatus = selection.first),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Podrás cambiarlo después desde la ficha del libro.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('form_save'),
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(widget.isEditing ? 'Guardar cambios' : 'Agregar a mi biblioteca'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
