import 'package:flutter/material.dart';

/// Género literario utilizado para el onboarding, la clasificación de libros
/// y el motor de recomendaciones.
class Genre {
  const Genre({
    required this.id,
    required this.label,
    required this.icon,
    required this.searchSubject,
    required this.keywords,
  });

  /// Identificador estable que se guarda en el almacenamiento local.
  final String id;

  /// Nombre visible en la interfaz.
  final String label;

  final IconData icon;

  /// Materia (en inglés) usada para consultar catálogos externos
  /// (Google Books / Open Library).
  final String searchSubject;

  /// Palabras clave (en minúsculas y sin tildes) que permiten mapear las
  /// categorías que entregan los catálogos externos a este género.
  final List<String> keywords;
}

class Genres {
  Genres._();

  static const all = <Genre>[
    Genre(
      id: 'fantasia',
      label: 'Fantasía',
      icon: Icons.auto_awesome,
      searchSubject: 'fantasy',
      keywords: ['fantasy', 'fantasia', 'magic', 'dragons'],
    ),
    Genre(
      id: 'ciencia_ficcion',
      label: 'Ciencia ficción',
      icon: Icons.rocket_launch,
      searchSubject: 'science fiction',
      keywords: [
        'science fiction',
        'ciencia ficcion',
        'sci-fi',
        'dystopia',
        'distopia',
        'space opera',
      ],
    ),
    Genre(
      id: 'misterio',
      label: 'Misterio',
      icon: Icons.search,
      searchSubject: 'mystery',
      keywords: ['mystery', 'misterio', 'detective', 'policial', 'crime'],
    ),
    Genre(
      id: 'thriller',
      label: 'Thriller',
      icon: Icons.bolt,
      searchSubject: 'thriller',
      keywords: ['thriller', 'suspense', 'suspenso'],
    ),
    Genre(
      id: 'romance',
      label: 'Romance',
      icon: Icons.favorite,
      searchSubject: 'romance',
      keywords: ['romance', 'love stories', 'romantica', 'amor'],
    ),
    Genre(
      id: 'terror',
      label: 'Terror',
      icon: Icons.dark_mode,
      searchSubject: 'horror',
      keywords: ['horror', 'terror', 'ghost', 'paranormal'],
    ),
    Genre(
      id: 'historica',
      label: 'Novela histórica',
      icon: Icons.history_edu,
      searchSubject: 'historical fiction',
      keywords: ['historical fiction', 'novela historica', 'ficcion historica'],
    ),
    Genre(
      id: 'clasicos',
      label: 'Clásicos',
      icon: Icons.workspace_premium,
      searchSubject: 'classics',
      keywords: ['classic', 'clasico', 'clasicos'],
    ),
    Genre(
      id: 'juvenil',
      label: 'Juvenil',
      icon: Icons.emoji_people,
      searchSubject: 'young adult fiction',
      keywords: ['young adult', 'juvenil', 'juvenile', 'teen'],
    ),
    Genre(
      id: 'poesia',
      label: 'Poesía',
      icon: Icons.edit_note,
      searchSubject: 'poetry',
      keywords: ['poetry', 'poesia', 'poems', 'poemas'],
    ),
    Genre(
      id: 'comic',
      label: 'Cómic y novela gráfica',
      icon: Icons.palette,
      searchSubject: 'comics',
      keywords: ['comic', 'graphic novel', 'manga', 'novela grafica'],
    ),
    Genre(
      id: 'biografia',
      label: 'Biografías',
      icon: Icons.person,
      searchSubject: 'biography',
      keywords: ['biography', 'autobiography', 'biografia', 'memoir', 'memorias'],
    ),
    Genre(
      id: 'historia',
      label: 'Historia',
      icon: Icons.public,
      searchSubject: 'history',
      keywords: ['history', 'historia'],
    ),
    Genre(
      id: 'ciencia',
      label: 'Ciencia y divulgación',
      icon: Icons.science,
      searchSubject: 'science',
      keywords: [
        'science',
        'ciencia',
        'physics',
        'biology',
        'astronomy',
        'nature',
        'mathematics',
      ],
    ),
    Genre(
      id: 'desarrollo_personal',
      label: 'Desarrollo personal',
      icon: Icons.self_improvement,
      searchSubject: 'self-help',
      keywords: [
        'self-help',
        'self help',
        'autoayuda',
        'desarrollo personal',
        'success',
        'habits',
        'motivation',
      ],
    ),
    Genre(
      id: 'psicologia',
      label: 'Psicología',
      icon: Icons.psychology,
      searchSubject: 'psychology',
      keywords: ['psychology', 'psicologia'],
    ),
    Genre(
      id: 'filosofia',
      label: 'Filosofía',
      icon: Icons.lightbulb,
      searchSubject: 'philosophy',
      keywords: ['philosophy', 'filosofia'],
    ),
    Genre(
      id: 'negocios',
      label: 'Negocios y economía',
      icon: Icons.business_center,
      searchSubject: 'business',
      keywords: [
        'business',
        'economics',
        'negocios',
        'economia',
        'management',
        'finance',
      ],
    ),
    Genre(
      id: 'tecnologia',
      label: 'Tecnología',
      icon: Icons.computer,
      searchSubject: 'computers',
      keywords: [
        'computers',
        'computer',
        'technology',
        'tecnologia',
        'programming',
        'software',
        'informatica',
      ],
    ),
    Genre(
      id: 'novela',
      label: 'Novela contemporánea',
      icon: Icons.auto_stories,
      searchSubject: 'fiction',
      // Se usa como último recurso cuando una categoría es ficción genérica.
      keywords: ['fiction', 'ficcion', 'novela', 'novel', 'literary'],
    ),
  ];

  static final Map<String, Genre> _byId = {for (final g in all) g.id: g};

  static Genre? byId(String id) => _byId[id];

  static String labelOf(String id) => _byId[id]?.label ?? id;

  static IconData iconOf(String id) => _byId[id]?.icon ?? Icons.book;

  /// Convierte categorías libres (por ejemplo "Fiction / Fantasy / Epic")
  /// en identificadores de género de LibrIA.
  static List<String> fromCategories(Iterable<String> categories) {
    final result = <String>{};
    for (final raw in categories) {
      final category = _simplify(raw);
      var matchedSpecific = false;
      for (final genre in all) {
        if (genre.id == 'novela') continue;
        if (genre.id == 'ciencia' &&
            (category.contains('fiction') || category.contains('ficcion'))) {
          continue;
        }
        if (genre.id == 'historia' &&
            (category.contains('historical fiction') ||
                category.contains('novela historica'))) {
          continue;
        }
        if (genre.keywords.any(category.contains)) {
          result.add(genre.id);
          matchedSpecific = true;
        }
      }
      if (!matchedSpecific &&
          byId('novela')!.keywords.any(category.contains)) {
        result.add('novela');
      }
    }
    return result.toList();
  }

  static String _simplify(String value) {
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    var text = value.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      text = text.replaceAll(from[i], to[i]);
    }
    return text;
  }
}
