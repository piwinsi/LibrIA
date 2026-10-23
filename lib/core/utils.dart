import 'dart:math';

final _random = Random();

/// Genera un identificador único local (no requiere paquetes externos).
String newId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}';

const _monthsShort = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

const _monthsLong = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _two(int value) => value.toString().padLeft(2, '0');

/// 22-10-2026
String formatDate(DateTime date) =>
    '${_two(date.day)}-${_two(date.month)}-${date.year}';

/// 22 de octubre de 2026
String formatDateLong(DateTime date) =>
    '${date.day} de ${_monthsLong[date.month - 1]} de ${date.year}';

/// 22-10-2026 14:05
String formatDateTime(DateTime date) =>
    '${formatDate(date)} ${_two(date.hour)}:${_two(date.minute)}';

String monthShort(int month) => _monthsShort[month - 1];

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Texto en minúsculas, sin tildes y sin signos, para comparar títulos.
String normalizeText(String value) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiioooouuuunc';
  var text = value.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    text = text.replaceAll(from[i], to[i]);
  }
  text = text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Clave para detectar duplicados entre la biblioteca y las sugerencias.
String bookKey(String title, String author) {
  final firstAuthor = author.split(RegExp(r'[,;&]')).first;
  return '${normalizeText(title)}|${normalizeText(firstAuthor)}';
}

/// Separa una cadena de autores ("A, B y C") en una lista normalizada.
List<String> splitAuthors(String author) => author
    .split(RegExp(r',|;|&| y | and '))
    .map((a) => a.trim())
    .where((a) => a.isNotEmpty)
    .toList();

/// Deja solo dígitos (y una X final para ISBN-10).
String cleanIsbn(String raw) {
  final upper = raw.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');
  if (upper.length == 10) return upper;
  return upper.replaceAll('X', '');
}

/// Valida el dígito verificador de un ISBN-10 o ISBN-13.
bool isValidIsbn(String raw) {
  final isbn = cleanIsbn(raw);
  if (isbn.length == 13) {
    if (!RegExp(r'^\d{13}$').hasMatch(isbn)) return false;
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      final digit = int.parse(isbn[i]);
      sum += i.isEven ? digit : digit * 3;
    }
    return sum % 10 == 0;
  }
  if (isbn.length == 10) {
    if (!RegExp(r'^\d{9}[\dX]$').hasMatch(isbn)) return false;
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      final char = isbn[i];
      final value = char == 'X' ? 10 : int.parse(char);
      sum += value * (10 - i);
    }
    return sum % 11 == 0;
  }
  return false;
}

/// Nombre de pila para saludos.
String firstName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  return parts.isEmpty ? '' : parts.first;
}

/// Devuelve el ISBN en sus dos formas: primero ISBN-13 y, cuando existe,
/// el ISBN-10 equivalente (solo los prefijos 978 tienen ISBN-10).
List<String> isbnVariants(String raw) {
  final isbn = cleanIsbn(raw);
  if (isbn.length == 10) {
    final core = '978${isbn.substring(0, 9)}';
    return [core + _isbn13Check(core), isbn];
  }
  if (isbn.length == 13 && isbn.startsWith('978')) {
    final core = isbn.substring(3, 12);
    return [isbn, core + _isbn10Check(core)];
  }
  return [isbn];
}

String _isbn13Check(String twelveDigits) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final digit = int.parse(twelveDigits[i]);
    sum += i.isEven ? digit : digit * 3;
  }
  return '${(10 - sum % 10) % 10}';
}

String _isbn10Check(String nineDigits) {
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    sum += int.parse(nineDigits[i]) * (10 - i);
  }
  final check = (11 - sum % 11) % 11;
  return check == 10 ? 'X' : '$check';
}
