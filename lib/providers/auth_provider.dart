import 'package:flutter/foundation.dart';

import '../core/utils.dart';
import '../data/demo_seed.dart';
import '../models/user.dart';
import '../services/local_storage_service.dart';
import '../services/password_hasher.dart';

/// Gestión de cuentas locales (RF-01), perfil (RF-02), privacidad (RNF-03)
/// y credenciales protegidas con hash (RNF-04).
class AuthProvider extends ChangeNotifier {
  AuthProvider({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService.instance;

  final LocalStorageService _storage;
  List<AppUser> _users = [];
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get needsOnboarding =>
      _currentUser != null && !_currentUser!.onboardingCompleted;

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
    final user = _findByEmail(email);
    if (user == null ||
        !PasswordHasher.verify(password, user.salt, user.passwordHash)) {
      return 'Correo o contraseña incorrectos.';
    }
    await _startSession(user);
    return null;
  }

  /// Ingresa con la cuenta de demostración; la crea con datos de ejemplo la
  /// primera vez.
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
    _currentUser = null;
    await _storage.writeString(LocalStorageService.sessionKey, null);
    notifyListeners();
  }

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
    if (!PasswordHasher.verify(current, user.salt, user.passwordHash)) {
      return 'La contraseña actual no es correcta.';
    }
    if (newPassword.length < 8) {
      return 'La nueva contraseña debe tener al menos 8 caracteres.';
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

  /// Elimina la cuenta actual y todos sus datos del dispositivo.
  Future<void> deleteAccount() async {
    final user = _currentUser;
    if (user == null) return;
    _users.removeWhere((u) => u.id == user.id);
    await _saveUsers();
    await _storage.removeUserData(user.id);
    await logout();
  }

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
  }

  Future<void> _saveUsers() => _storage.writeList(
        LocalStorageService.usersKey,
        _users.map((u) => u.toJson()).toList(),
      );
}
