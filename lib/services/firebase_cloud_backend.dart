import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cloud_backend.dart';

/// Implementación de [CloudBackend] con Firebase Authentication y Cloud
/// Firestore.
///
/// - Las credenciales las gestiona Firebase Authentication: la app no
///   guarda contraseñas ni sus hash (RNF-04).
/// - Los datos de cada lector viven en `users/{uid}/...`; las reglas de
///   Firestore (`firestore.rules`) solo permiten que cada usuario lea y
///   escriba lo suyo.
/// - En Android, Firestore mantiene una caché local y encola las escrituras
///   sin conexión, que se envían al recuperar la red.
class FirebaseCloudBackend extends CloudBackend {
  FirebaseCloudBackend({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Límite de operaciones por lote de Firestore (500), con margen.
  static const _batchSize = 400;

  @override
  bool get isAvailable => true;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<String> signUp({required String email, required String password}) =>
      _guard(() async {
        final result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        return result.user!.uid;
      });

  @override
  Future<String> signIn({required String email, required String password}) =>
      _guard(() async {
        final result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return result.user!.uid;
      });

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) =>
      _guard(() async {
        final user = _auth.currentUser;
        if (user == null) {
          throw const CloudAuthException(
            CloudAuthException.requiresRecentLogin,
            'Vuelve a iniciar sesión para cambiar tu contraseña.',
          );
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: currentPassword),
        );
        await user.updatePassword(newPassword);
      });

  @override
  Future<void> deleteAccount({
    required String uid,
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final user = _auth.currentUser;
        if (user == null || user.uid != uid) {
          throw const CloudAuthException(
            CloudAuthException.requiresRecentLogin,
            'Vuelve a iniciar sesión para eliminar tu cuenta.',
          );
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
        // Primero los datos (las reglas exigen estar autenticado) y luego
        // la cuenta.
        final userDoc = _db.collection('users').doc(uid);
        for (final collection in const [
          'books',
          'events',
          'comments',
          'recommendations',
          'meta',
        ]) {
          final snapshot = await userDoc.collection(collection).get();
          final refs = snapshot.docs.map((d) => d.reference).toList();
          for (var i = 0; i < refs.length; i += _batchSize) {
            final batch = _db.batch();
            for (final ref in refs.skip(i).take(_batchSize)) {
              batch.delete(ref);
            }
            await batch.commit();
          }
        }
        await user.delete();
      });

  @override
  Future<Map<String, List<Map<String, dynamic>>>> download(
    String uid,
    List<String> collections,
  ) async {
    final userDoc = _db.collection('users').doc(uid);
    final result = <String, List<Map<String, dynamic>>>{};
    for (final collection in collections) {
      final snapshot = await userDoc.collection(collection).get();
      result[collection] = [
        for (final doc in snapshot.docs) {...doc.data(), 'id': doc.id},
      ];
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>?> getDoc(
    String uid,
    String collection,
    String id,
  ) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection(collection)
        .doc(id)
        .get();
    return snapshot.data();
  }

  @override
  Future<void> commit(String uid, List<CloudWrite> writes) async {
    final userDoc = _db.collection('users').doc(uid);
    for (var i = 0; i < writes.length; i += _batchSize) {
      final batch = _db.batch();
      for (final write in writes.skip(i).take(_batchSize)) {
        batch.set(userDoc.collection(write.collection).doc(write.id), write.data);
      }
      await batch.commit();
    }
  }

  /// Traduce los errores de Firebase a mensajes en español.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw _translate(e);
    }
  }

  CloudAuthException _translate(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-login-credentials':
        return const CloudAuthException(
          CloudAuthException.invalidCredential,
          'Correo o contraseña incorrectos.',
        );
      case 'email-already-in-use':
        return const CloudAuthException(
          CloudAuthException.emailInUse,
          'Ya existe una cuenta con ese correo.',
        );
      case 'weak-password':
        return const CloudAuthException(
          'weak-password',
          'La contraseña es demasiado débil.',
        );
      case 'invalid-email':
        return const CloudAuthException('invalid-email', 'Ingresa un correo válido.');
      case 'network-request-failed':
        return const CloudAuthException(
          CloudAuthException.network,
          'No hay conexión a internet. Inténtalo de nuevo.',
        );
      case 'too-many-requests':
        return const CloudAuthException(
          'too-many-requests',
          'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
        );
      case 'requires-recent-login':
        return const CloudAuthException(
          CloudAuthException.requiresRecentLogin,
          'Por seguridad, cierra sesión y vuelve a ingresar antes de hacer este cambio.',
        );
      default:
        return CloudAuthException(
          'unknown',
          'No se pudo completar la operación (${e.code}).',
        );
    }
  }
}
