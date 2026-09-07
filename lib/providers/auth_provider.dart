import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/mock_users.dart';
import '../models/user.dart';
import '../services/local_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;

  bool get isLoggedIn => _currentUser != null;
  AppUser? get currentUser => _currentUser;

  Future<bool> login(String email, String password) async {
    if (email.trim() == demoCredentialEmail &&
        password == demoCredentialPassword) {
      // Si ya existe un perfil guardado (por ejemplo, editado en una sesión
      // anterior), se reutiliza tal cual en vez de sobrescribirlo con el
      // usuario de demostración. Solo se usa mockDemoUser cuando todavía no
      // hay nada persistido (primer inicio de sesión).
      final storedProfile = await _loadStoredProfileOrNull();
      _currentUser = storedProfile ?? mockDemoUser;
      notifyListeners();
      // Se espera (await) la escritura en disco para evitar una condición
      // de carrera: si el proceso se detiene (hot restart, cierre del
      // debugger) justo después de este cambio, sin este await el Future
      // de persist() podía quedar interrumpido a mitad de camino y el
      // cambio se perdía silenciosamente.
      await persist();
      await LocalStorageService.instance.saveSessionActive(true);
      return true;
    }
    return false;
  }

  Future<void> register(String name, String email) async {
    _currentUser = AppUser(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
    );
    notifyListeners();
    await persist();
    await LocalStorageService.instance.saveSessionActive(true);
  }

  Future<void> updateProfile({
    String? name,
    String? bio,
    List<String>? favoriteGenres,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    _currentUser = user.copyWith(
      name: name,
      bio: bio,
      favoriteGenres: favoriteGenres,
    );
    notifyListeners();
    await persist();
  }

  Future<void> logout() async {
    // Importante: cerrar sesión solo debe limpiar el usuario en memoria y
    // marcar que no hay sesión activa; NO debe borrar el perfil ya
    // persistido en disco. Antes, logout() llamaba a persist(), que con
    // _currentUser == null sobrescribía el almacenamiento con "sin
    // perfil", perdiendo cualquier edición hecha antes de cerrar sesión.
    _currentUser = null;
    notifyListeners();
    await LocalStorageService.instance.saveSessionActive(false);
  }

  /// Lee el perfil persistido (si existe) y lo devuelve como [AppUser], sin
  /// modificar el estado en memoria. Usado por [login] para no pisar un
  /// perfil ya editado con los datos de demostración.
  Future<AppUser?> _loadStoredProfileOrNull() async {
    final stored = LocalStorageService.instance.loadProfile();
    if (stored == null) return null;

    try {
      final decoded = jsonDecode(stored);
      if (decoded == null) return null;
      final map = decoded as Map<String, dynamic>;
      return AppUser(
        id: map['id'] as String,
        name: map['name'] as String,
        email: map['email'] as String,
        avatarUrl: map['avatarUrl'] as String?,
        bio: map['bio'] as String?,
        favoriteGenres: List<String>.from(map['favoriteGenres'] as List? ?? []),
        booksRead: map['booksRead'] as int? ?? 0,
        followers: map['followers'] as int? ?? 0,
        following: map['following'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Lee el estado de sesión/perfil serializado desde [LocalStorageService]
  /// y lo carga en memoria. Debe esperarse (`await`) antes de `runApp()`.
  ///
  /// Importante: el perfil y la sesión activa se guardan por separado. Si
  /// el usuario cerró sesión, el perfil sigue en disco (para reutilizarlo
  /// en el próximo login), pero `hydrate()` no debe dejarlo logueado
  /// automáticamente: por eso solo restaura `_currentUser` cuando la
  /// bandera de sesión activa está en `true`.
  Future<void> hydrate() async {
    if (!LocalStorageService.instance.loadSessionActive()) return;

    final storedProfile = await _loadStoredProfileOrNull();
    if (storedProfile == null) return;

    _currentUser = storedProfile;
    notifyListeners();
  }

  /// Serializa el estado actual (usuario en sesión, si existe) y lo guarda
  /// mediante [LocalStorageService]. Se invoca automáticamente tras cada
  /// cambio de estado (login, registro, edición de perfil, logout).
  Future<void> persist() async {
    final user = _currentUser;
    if (user == null) {
      await LocalStorageService.instance.saveProfile(jsonEncode(null));
      return;
    }

    final map = {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'avatarUrl': user.avatarUrl,
      'bio': user.bio,
      'favoriteGenres': user.favoriteGenres,
      'booksRead': user.booksRead,
      'followers': user.followers,
      'following': user.following,
    };
    await LocalStorageService.instance.saveProfile(jsonEncode(map));
  }
}
