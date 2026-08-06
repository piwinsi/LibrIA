import '../models/user.dart';

const AppUser mockDemoUser = AppUser(
  id: 'user_001',
  name: 'Felipe',
  email: 'demo@booktrack.cl',
  bio:
      'Lector interesado en tecnología, ciencia ficción y desarrollo personal.',
  favoriteGenres: ['Ciencia ficción', 'Tecnología', 'Misterio'],
  booksRead: 12,
  followers: 24,
  following: 17,
);

const String demoCredentialEmail = 'demo@booktrack.cl';
const String demoCredentialPassword = '123456';
