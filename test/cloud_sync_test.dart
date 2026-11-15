import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libria_v01/models/book.dart';
import 'package:libria_v01/providers/auth_provider.dart';
import 'package:libria_v01/providers/library_provider.dart';
import 'package:libria_v01/services/cloud_backend.dart';
import 'package:libria_v01/services/local_storage_service.dart';

/// Nube simulada en memoria: reproduce Firebase Authentication y Firestore
/// para probar el respaldo sin red.
class FakeCloud extends CloudBackend {
  final Map<String, ({String uid, String password})> accounts = {};
  final Map<String, Map<String, Map<String, Map<String, dynamic>>>> data = {};
  String? _uid;
  int _next = 1;

  @override
  bool get isAvailable => true;

  @override
  String? get currentUid => _uid;

  @override
  Future<String> signUp({required String email, required String password}) async {
    if (accounts.containsKey(email)) {
      throw const CloudAuthException(CloudAuthException.emailInUse, 'Ya existe.');
    }
    final uid = 'uid${_next++}';
    accounts[email] = (uid: uid, password: password);
    _uid = uid;
    return uid;
  }

  @override
  Future<String> signIn({required String email, required String password}) async {
    final account = accounts[email];
    if (account == null || account.password != password) {
      throw const CloudAuthException(
        CloudAuthException.invalidCredential,
        'Correo o contraseña incorrectos.',
      );
    }
    _uid = account.uid;
    return account.uid;
  }

  @override
  Future<void> signOut() async => _uid = null;

  @override
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final account = accounts[email]!;
    if (account.password != currentPassword) {
      throw const CloudAuthException(CloudAuthException.invalidCredential, 'x');
    }
    accounts[email] = (uid: account.uid, password: newPassword);
  }

  @override
  Future<void> deleteAccount({
    required String uid,
    required String email,
    required String password,
  }) async {
    if (accounts[email]?.password != password) {
      throw const CloudAuthException(CloudAuthException.invalidCredential, 'x');
    }
    accounts.remove(email);
    data.remove(uid);
    _uid = null;
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> download(
    String uid,
    List<String> collections,
  ) async =>
      {
        for (final c in collections)
          c: [
            for (final entry in (data[uid]?[c] ?? const {}).entries)
              {...entry.value, 'id': entry.key},
          ],
      };

  @override
  Future<Map<String, dynamic>?> getDoc(String uid, String collection, String id) async =>
      data[uid]?[collection]?[id];

  @override
  Future<void> commit(String uid, List<CloudWrite> writes) async {
    if (_uid != uid) throw StateError('Permiso denegado por las reglas');
    for (final w in writes) {
      data.putIfAbsent(uid, () => {}).putIfAbsent(w.collection, () => {})[w.id] =
          Map<String, dynamic>.from(w.data);
    }
  }

  Map<String, Map<String, dynamic>> docs(String uid, String collection) =>
      data[uid]?[collection] ?? const {};
}

/// Simula un teléfono: almacenamiento local vacío y providers conectados
/// igual que en `main.dart`.
Future<({AuthProvider auth, LibraryProvider library})> newDevice(
  FakeCloud cloud,
) async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorageService.instance.resetForTests();
  final auth = AuthProvider(cloud: cloud);
  final library = LibraryProvider(cloud: cloud);
  await auth.hydrate();
  void bind() => library.bindUser(
        auth.currentUser?.id,
        cloudUid: auth.currentUser?.cloudUid,
      );
  bind();
  auth.addListener(bind);
  auth.onBeforeCloudSignOut = library.flushSync;
  return (auth: auth, library: library);
}

void main() {
  group('Cuentas en la nube (RF-01, RNF-04)', () {
    test('el registro usa la nube y no guarda la contraseña', () async {
      final cloud = FakeCloud();
      final device = await newDevice(cloud);
      final error = await device.auth.register(
        name: 'Ana',
        email: 'ana@correo.cl',
        password: 'claveSegura1',
      );
      expect(error, isNull);
      final user = device.auth.currentUser!;
      expect(user.cloudUid, isNotNull);
      expect(user.passwordHash, isEmpty);
      expect(user.salt, isEmpty);
      expect(cloud.docs(user.cloudUid!, 'meta')['profile']?['name'], 'Ana');
    });

    test('credenciales incorrectas muestran un mensaje claro', () async {
      final cloud = FakeCloud();
      final device = await newDevice(cloud);
      await device.auth.register(name: 'Ana', email: 'ana@correo.cl', password: 'claveSegura1');
      await device.auth.logout();
      expect(
        await device.auth.login('ana@correo.cl', 'otraClave99'),
        'Correo o contraseña incorrectos.',
      );
    });
  });

  group('Respaldo y recuperación (local-first)', () {
    test('los cambios se respaldan en la nube', () async {
      final cloud = FakeCloud();
      final device = await newDevice(cloud);
      await device.auth.register(name: 'Ana', email: 'ana@correo.cl', password: 'claveSegura1');
      await device.library.flushSync();

      final book = await device.library.addBook(
        title: 'Rayuela',
        author: 'Julio Cortázar',
        totalPages: 600,
      );
      await device.library.updateProgress(book.id, 120);
      await device.library.addComment(book.id, 'Capítulo 7', page: 40);
      await device.library.flushSync();

      final uid = device.auth.currentUser!.cloudUid!;
      expect(cloud.docs(uid, 'books')[book.id]?['title'], 'Rayuela');
      expect(cloud.docs(uid, 'events'), isNotEmpty);
      expect(cloud.docs(uid, 'comments'), hasLength(1));
      expect(device.library.syncStatus, SyncStatus.synced);
    });

    test('prueba de recuperación: un dispositivo nuevo restaura todo', () async {
      final cloud = FakeCloud();
      final phoneA = await newDevice(cloud);
      await phoneA.auth.register(name: 'Ana', email: 'ana@correo.cl', password: 'claveSegura1');
      await phoneA.auth.setFavoriteGenres(['fantasia']);
      final book = await phoneA.library.addBook(
        title: 'El nombre del viento',
        author: 'Patrick Rothfuss',
        totalPages: 872,
        genres: const ['fantasia'],
      );
      await phoneA.library.markCompleted(book.id);
      await phoneA.library.rateBook(book.id, 5);
      await phoneA.library.saveReview(book.id, 'Excelente');
      await phoneA.library.recordSuggestionAccepted('el hobbit|j r r tolkien');
      await phoneA.library.flushSync();

      // Se pierde el teléfono: el almacenamiento local queda vacío.
      final phoneB = await newDevice(cloud);
      expect(phoneB.library.books, isEmpty);
      expect(await phoneB.auth.login('ana@correo.cl', 'claveSegura1'), isNull);
      await phoneB.library.syncNow();

      final user = phoneB.auth.currentUser!;
      expect(user.name, 'Ana');
      expect(user.favoriteGenres, ['fantasia']);
      expect(user.onboardingCompleted, isTrue);

      final restored = phoneB.library.bookById(book.id)!;
      expect(restored.status, ReadingStatus.completed);
      expect(restored.rating, 5);
      expect(restored.review, 'Excelente');
      expect(phoneB.library.eventsFor(book.id), isNotEmpty);
      expect(phoneB.library.suggestionsAccepted, 1);
    });

    test('al combinar gana la versión más reciente de cada libro', () async {
      final cloud = FakeCloud();
      final phoneA = await newDevice(cloud);
      await phoneA.auth.register(name: 'Ana', email: 'ana@correo.cl', password: 'claveSegura1');
      final book = await phoneA.library.addBook(title: 'Dune', author: 'Frank Herbert', totalPages: 600);
      await phoneA.library.flushSync();
      final uid = phoneA.auth.currentUser!.cloudUid!;

      // Otro dispositivo actualizó el libro después.
      final newer = Map<String, dynamic>.from(cloud.docs(uid, 'books')[book.id]!)
        ..['currentPage'] = 300
        ..['status'] = 'reading'
        ..['updatedAt'] = DateTime.now().add(const Duration(minutes: 5)).toIso8601String();
      cloud.data[uid]!['books']![book.id] = newer;

      await phoneA.library.syncNow();
      expect(phoneA.library.bookById(book.id)!.currentPage, 300);
      expect(phoneA.library.bookById(book.id)!.status, ReadingStatus.reading);
    });

    test('un libro borrado deja una lápida y no reaparece', () async {
      final cloud = FakeCloud();
      final phoneA = await newDevice(cloud);
      await phoneA.auth.register(name: 'Ana', email: 'ana@correo.cl', password: 'claveSegura1');
      final book = await phoneA.library.addBook(title: 'Borrable', author: 'X', totalPages: 10);
      await phoneA.library.flushSync();
      await phoneA.library.removeBook(book.id);
      await phoneA.library.flushSync();

      final uid = phoneA.auth.currentUser!.cloudUid!;
      expect(cloud.docs(uid, 'books')[book.id]?['deleted'], isTrue);

      final phoneB = await newDevice(cloud);
      await phoneB.auth.login('ana@correo.cl', 'claveSegura1');
      await phoneB.library.syncNow();
      expect(phoneB.library.bookById(book.id), isNull);
    });

    test('eliminar la cuenta borra los datos en la nube', () async {
      final cloud = FakeCloud();
      final device = await newDevice(cloud);
      await device.auth.register(name: 'Ana', email: 'ana@correo.cl', password: 'claveSegura1');
      await device.library.addBook(title: 'Libro', author: 'A', totalPages: 10);
      await device.library.flushSync();
      final uid = device.auth.currentUser!.cloudUid!;

      expect(await device.auth.deleteAccount(password: 'mala'), isNotNull);
      expect(await device.auth.deleteAccount(password: 'claveSegura1'), isNull);
      expect(cloud.data.containsKey(uid), isFalse);
      expect(device.auth.isLoggedIn, isFalse);
    });

    test('la cuenta demo sigue siendo local', () async {
      final cloud = FakeCloud();
      final device = await newDevice(cloud);
      await device.auth.loginDemo();
      expect(device.auth.currentUser!.cloudUid, isNull);
      expect(device.library.syncStatus, SyncStatus.localOnly);
      expect(cloud.data, isEmpty);
    });
  });
}
