import '../models/reader_profile.dart';

final List<ReaderProfile> mockReaders = [
  const ReaderProfile(
    id: 'reader_001',
    name: 'Camila Rojas',
    bio: 'Fan de la ciencia ficción y el terror psicológico.',
    booksRead: 34,
    isFollowing: true,
  ),
  const ReaderProfile(
    id: 'reader_002',
    name: 'Matías Fuentes',
    bio: 'Lee principalmente ensayos y desarrollo personal.',
    booksRead: 18,
  ),
  const ReaderProfile(
    id: 'reader_003',
    name: 'Valentina Soto',
    bio: 'Coleccionista de fantasía épica y novela gráfica.',
    booksRead: 52,
  ),
];
