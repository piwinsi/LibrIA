import '../models/book.dart';

final List<Book> mockBooks = [
  const Book(
    id: 'book_001',
    title: 'Hábitos atómicos',
    author: 'James Clear',
    description:
        'Libro sobre la creación de hábitos mediante cambios pequeños y constantes.',
    coverUrl: 'assets/images/habitos_atomicos.jpg',
    genre: 'Desarrollo personal',
    totalPages: 328,
    currentPage: 190,
    status: ReadingStatus.reading,
  ),
  const Book(
    id: 'book_002',
    title: '1984',
    author: 'George Orwell',
    description:
        'Novela distópica sobre vigilancia, poder y control social.',
    coverUrl: 'assets/images/1984.jpg',
    genre: 'Ciencia ficción',
    totalPages: 352,
    currentPage: 352,
    status: ReadingStatus.completed,
    rating: 4.5,
  ),
  const Book(
    id: 'book_003',
    title: 'El problema de los tres cuerpos',
    author: 'Liu Cixin',
    description:
        'Novela de ciencia ficción relacionada con el contacto entre civilizaciones.',
    coverUrl: 'assets/images/tres_cuerpos.jpg',
    genre: 'Ciencia ficción',
    totalPages: 416,
    currentPage: 0,
    status: ReadingStatus.pending,
  ),
  const Book(
    id: 'book_004',
    title: 'El nombre del viento',
    author: 'Patrick Rothfuss',
    description:
        'Historia fantástica centrada en la vida y las aventuras de Kvothe.',
    coverUrl: 'assets/images/nombre_del_viento.jpg',
    genre: 'Fantasía',
    totalPages: 872,
    currentPage: 872,
    status: ReadingStatus.completed,
    rating: 5.0,
  ),
];
