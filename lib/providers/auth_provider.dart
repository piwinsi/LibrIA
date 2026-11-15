import 'package:flutter/foundation.dart';

import '../core/utils.dart';
import '../data/demo_seed.dart';
import '../models/user.dart';
import '../services/cloud_backend.dart';
import '../services/local_storage_service.dart';
import '../services/password_hasher.dart';

/// Gestión de cuentas (RF-01), perfil (RF-02), privacidad (RNF-03) y
/// credenciales (RNF-04).
///
/// Cuando hay servicio en la nube ([CloudBackend.isAvailable]), las cuentas
/// se crean y validan en Firebase Authentication y el dispositivo no guarda
/// contraseñas. Sin nube (Windows, pruebas) y para la cuenta de
/// demostración, las cuentas son locales con hash y sal.
class AuthProvider extends ChangeNotifier {
  AuthProvider({LocalStorageService? storage, CloudBackend? cloud})
      : _storage = storage ?? LocalStorageService.instance,
        _cloud = cloud ?? const NoCloudBackend();

  final LocalStorageService _storage;
  final CloudBackend _cloud;
  List<AppUser> _users = [];

  /// Se ejecuta antes de cerrar la sesión en la nube (por ejemplo, para
  /// enviar los cambios pendientes de la biblioteca).
  Future<void> Function()? onBeforeCloudSignOut;
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get needsOnboarding =>
      _currentUser != null && !_currentUser!.onboardingCompleted;

  /// `true` si esta plataforma tiene respaldo en la nube.
  bool get cloudAvailable => _cloud.isAvailable;

  /// `true` si la cuenta en sesión está autenticada en la nube.
  bool get isCloudSessionActive {
    final uid = _currentUser?.cloudUid;
    return uid != null && _cloud.isAvailable && _cloud.currentUid == uid;
  }

  /// Carga cuentas y sesión guardadas. Debe esperarse antes de `runApp()`.
  Future<void> hydrate() async {
    _users = [];
    for (final json in _storage.readList(LocalStorageService.usersKey)) {
      try {
        _users.add(AppUser.fromJson(json));
      } catch (_) {
        // Registro corrupto: se omite.
      }
    }
    final sessionId = _storage.readString(LocalStorageService.sessionKey);
    _currentUser = _findById(sessionId);
    notifyListeners();
  }

  AppUser? _findById(String? id) {
    if (id == null) return null;
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  AppUser? _findByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final user in _users) {
      if (user.email == normalized) return user;
    }
    return null;
  }

  AppUser? _findByCloudUid(String uid) {
    for (final user in _users) {
      if (user.cloudUid == uid) return user;
    }
    return null;
  }

  // -------------------------------------------------------------------
  // Registro e inicio de sesión
  // -------------------------------------------------------------------

  /// Crea una cuenta. Devuelve un mensaje de error o `null` si tuvo éxito.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (name.trim().isEmpty) return 'Ingresa tu nombre.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail)) {
      return 'Ingresa un correo válido.';
    }
    if (password.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (normalizedEmail == demoEmail) {
      return 'Ese correo está reservado para la cuenta de demostración.';
    }

    if (_cloud.isAvailable) {
      final String uid;
      try {
        uid = await _cloud.signUp(email: normalizedEmail, password: password);
      } on CloudAuthException catch (e) {
        return e.message;
      }
      // Si quedó una cuenta local antigua con el mismo correo, se reemplaza.
      _users.removeWhere((u) => u.email == normalizedEmail);
      final user = AppUser(
        id: newId('user'),
        name: name.trim(),
        email: normalizedEmail,
        passwordHash: '',
        salt: '',
        createdAt: DateTime.now(),
        cloudUid: uid,
      );
      _users.add(user);
      await _saveUsers();
      await _startSession(user);
      await _pushProfile();
      return null;
    }

    if (_findByEmail(normalizedEmail) != null) {
      return 'Ya existe una cuenta con ese correo en este dispositivo.';
    }
    final salt = PasswordHasher.generateSalt();
    final user = AppUser(
      id: newId('user'),
      name: name.trim(),
      email: normalizedEmail,
      passwordHash: PasswordHasher.hash(password, salt),
      salt: salt,
      createdAt: DateTime.now(),
    );
    _users.add(user);
    await _saveUsers();
    await _startSession(user);
    return null;
  }

  /// Inicia sesión. Devuelve un mensaje de error o `null` si tuvo éxito.
  Future<String?> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final local = _findByEmail(normalizedEmail);
    final localPasswordOk = local != null &&
        local.passwordHash.isNotEmpty &&
        PasswordHasher.verify(password, local.salt, local.passwordHash);

    // La cuenta demo y las plataformas sin nube usan solo la verificación
    // local.
    if (!_cloud.isAvailable || normalizedEmail == demoEmail) {
      if (local == null || !localPasswordOk) {
        return 'Correo o contraseña incorrectos.';
      }
      await _startSession(local);
      return null;
    }

    try {
      final uid = await _cloud.signIn(email: normalizedEmail, password: password);
      await _startCloudSession(uid, normalizedEmail);
      return null;
    } on CloudAuthException catch (e) {
      // Cuenta creada antes de incorporar Firebase: se migra a la nube con
      // la misma contraseña, que ya se verificó localmente.
      if (e.code == CloudAuthException.invalidCredential &&
          local != null &&
          localPasswordOk &&
          !local.isCloudAccount) {
        try {
          final uid = await _cloud.signUp(
            email: normalizedEmail,
            password: password,
          );
          await _startCloudSession(uid, normalizedEmail);
          return null;
        } on CloudAuthException catch (signUpError) {
          return signUpError.code == CloudAuthException.emailInUse
              ? 'Correo o contraseña incorrectos.'
              : signUpError.message;
        }
      }
      // Sin conexión: una cuenta local antigua todavía puede entrar.
      if (e.code == CloudAuthException.network &&
          local != null &&
          localPasswordOk) {
        await _startSession(local);
        return null;
      }
      return e.message;
    }
  }

  /// Asocia la sesión de la nube con una cuenta del dispositivo, creándola
  /// a partir del perfil respaldado si es un dispositivo nuevo.
  Future<void> _startCloudSession(String uid, String email) async {
    var user = _findByCloudUid(uid) ?? _findByEmail(email);
    if (user == null) {
      Map<String, dynamic>? profile;
      try {
        profile = await _cloud.getDoc(uid, 'meta', 'profile');
      } catch (e) {
        debugPrint('No se pudo leer el perfil respaldado: $e');
      }
      user = AppUser.fromCloudProfile(
        id: newId('user'),
        uid: uid,
        email: email,
        profile: profile,
      );
      _users.add(user);
    } else {
      // Desde ahora la contraseña la gestiona la nube: se borra el hash
      // local.
      final migrated = user.copyWith(cloudUid: uid, passwordHash: '', salt: '');
      _users = [for (final u in _users) u.id == migrated.id ? migrated : u];
      user = migrated;
    }
    await _saveUsers();
    await _startSession(user);
    await _pushProfile();
  }

  /// Ingresa con la cuenta de demostración; la crea con datos de ejemplo la
  /// primera vez. La cuenta demo es siempre local.
  Future<void> loginDemo() async {
    var user = _findByEmail(demoEmail);
    if (user == null) {
      final salt = PasswordHasher.generateSalt();
      user = AppUser(
        id: newId('user'),
        name: demoName,
        email: demoEmail,
        passwordHash: PasswordHasher.hash(demoPassword, salt),
        salt: salt,
        createdAt: DateTime.now(),
        bio: 'Cuenta de demostración de LibrIA.',
        favoriteGenres: demoGenres,
        onboardingCompleted: true,
      );
      _users.add(user);
      await _saveUsers();
      await DemoSeed.write(_storage, user.id);
    }
    await _startSession(user);
  }

  Future<void> logout() async {
    final wasCloud = _currentUser?.isCloudAccount ?? false;
    if (wasCloud && isCloudSessionActive) {
      try {
        await onBeforeCloudSignOut?.call();
      } catch (e) {
        debugPrint('No se pudieron enviar los cambios pendientes: $e');
      }
    }
    _currentUser = null;
    await _storage.writeString(LocalStorageService.sessionKey, null);
    notifyListeners();
    if (wasCloud) {
      try {
        await _cloud.signOut();
      } catch (e) {
        debugPrint('Error al cerrar la sesión en la nube: $e');
      }
    }
  }

  // -------------------------------------------------------------------
  // Perfil
  // -------------------------------------------------------------------

  Future<void> updateProfile({required String name, String? bio}) async {
    await _replaceCurrent(
      (user) => user.copyWith(name: name.trim(), bio: bio?.trim() ?? ''),
    );
  }

  /// Guarda los géneros favoritos y marca el onboarding como completado.
  Future<void> setFavoriteGenres(List<String> genres) async {
    await _replaceCurrent(
      (user) => user.copyWith(
        favoriteGenres: genres,
        onboardingCompleted: true,
      ),
    );
  }

  Future<void> setProfilePrivate(bool isPrivate) async {
    await _replaceCurrent((user) => user.copyWith(isProfilePrivate: isPrivate));
  }

  /// Cambia la contraseña. Devuelve un mensaje de error o `null`.
  Future<String?> changePassword(String current, String newPassword) async {
    final user = _currentUser;
    if (user == null) return 'No hay una sesión activa.';
    if (newPassword.length < 8) {
      return 'La nueva contraseña debe tener al menos 8 caracteres.';
    }
    if (user.isCloudAccount) {
      if (!_cloud.isAvailable) {
        return 'El cambio de contraseña requiere conexión con la nube.';
      }
      try {
        await _cloud.changePassword(
          email: user.email,
          currentPassword: current,
          newPassword: newPassword,
        );
        return null;
      } on CloudAuthException catch (e) {
        return e.code == CloudAuthException.invalidCredential
            ? 'La contraseña actual no es correcta.'
            : e.message;
      }
    }
    if (!PasswordHasher.verify(current, user.salt, user.passwordHash)) {
      return 'La contraseña actual no es correcta.';
    }
    final salt = PasswordHasher.generateSalt();
    await _replaceCurrent(
      (u) => u.copyWith(
        salt: salt,
        passwordHash: PasswordHasher.hash(newPassword, salt),
      ),
    );
    return null;
  }

  /// `true` si eliminar la cuenta pide la contraseña (cuentas en la nube).
  bool get deleteRequiresPassword => _currentUser?.isCloudAccount ?? false;

  /// Elimina la cuenta actual y todos sus datos, en el dispositivo y, si
  /// corresponde, en la nube. Devuelve un mensaje de error o `null`.
  Future<String?> deleteAccount({String? password}) async {
    final user = _currentUser;
    if (user == null) return null;
    if (user.isCloudAccount) {
      if (!_cloud.isAvailable) {
        return 'Eliminar la cuenta requiere conexión con la nube.';
      }
      if (password == null || password.isEmpty) {
        return 'Ingresa tu contraseña para confirmar.';
      }
      try {
        await _cloud.deleteAccount(
          uid: user.cloudUid!,
          email: user.email,
          password: password,
        );
      } on CloudAuthException catch (e) {
        return e.code == CloudAuthException.invalidCredential
            ? 'La contraseña no es correcta.'
            : e.message;
      }
    }
    _users.removeWhere((u) => u.id == user.id);
    await _saveUsers();
    await _storage.removeUserData(user.id);
    await logout();
    return null;
  }

  // -------------------------------------------------------------------
  // Internos
  // -------------------------------------------------------------------

  Future<void> _startSession(AppUser user) async {
    _currentUser = user;
    await _storage.writeString(LocalStorageService.sessionKey, user.id);
    notifyListeners();
  }

  Future<void> _replaceCurrent(AppUser Function(AppUser) update) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = update(user);
    _currentUser = updated;
    _users = [
      for (final u in _users) u.id == updated.id ? updated : u,
    ];
    notifyListeners();
    await _saveUsers();
    await _pushProfile();
  }

  /// Respalda el perfil en `users/{uid}/meta/profile`. Un fallo de red no
  /// bloquea la app: el perfil se vuelve a enviar en el próximo cambio.
  Future<void> _pushProfile() async {
    final user = _currentUser;
    if (user == null || !isCloudSessionActive) return;
    try {
      await _cloud.commit(user.cloudUid!, [
        CloudWrite('meta', 'profile', user.toProfileJson()),
      ]);
    } catch (e) {
      debugPrint('No se pudo respaldar el perfil: $e');
    }
  }

  Future<void> _saveUsers() => _storage.writeList(
        LocalStorageService.usersKey,
        _users.map((u) => u.toJson()).toList(),
      );
}
