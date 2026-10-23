import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de persistencia local.
///
/// Toda la información de LibrIA vive en el dispositivo (enfoque
/// local-first). Se utiliza `shared_preferences` con documentos JSON,
/// separados por usuario mediante el prefijo `libria_u_<id>_`, lo que
/// permite tener varias cuentas en un mismo teléfono sin mezclar datos.
/// Funciona igual en Android, iOS, Windows y web.
class LocalStorageService {
  LocalStorageService._();
  static final instance = LocalStorageService._();

  static const usersKey = 'libria_users_v2';
  static const sessionKey = 'libria_session_user_v2';

  static const booksDomain = 'books';
  static const eventsDomain = 'events';
  static const commentsDomain = 'comments';
  static const recommendationsDomain = 'recommendations';
  static const dismissedDomain = 'dismissed';

  /// Claves de la versión anterior de la demo (datos mock), que ya no se
  /// usan y se eliminan al iniciar.
  static const _legacyKeys = [
    'libria_library_state_v1',
    'libria_profile_state_v1',
    'libria_social_state_v1',
    'libria_session_active_v1',
  ];

  SharedPreferences? _prefs;

  /// Debe llamarse una vez antes de usar el servicio.
  Future<void> init({bool force = false}) async {
    if (_prefs != null && !force) return;
    _prefs = await SharedPreferences.getInstance();
    for (final key in _legacyKeys) {
      if (_prefs!.containsKey(key)) await _prefs!.remove(key);
    }
  }

  /// Reinicia la instancia en pruebas automatizadas.
  @visibleForTesting
  Future<void> resetForTests() => init(force: true);

  SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('LocalStorageService.init() no ha sido llamado.');
    }
    return prefs;
  }

  static String userKey(String userId, String domain) =>
      'libria_u_${userId}_${domain}_v2';

  String? readString(String key) => _p.getString(key);

  Future<void> writeString(String key, String? value) async {
    if (value == null) {
      await _p.remove(key);
    } else {
      await _p.setString(key, value);
    }
  }

  List<Map<String, dynamic>> readList(String key) {
    final raw = _p.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      // Documento corrupto: se ignora en lugar de bloquear la app.
      return [];
    }
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> items) =>
      _p.setString(key, jsonEncode(items));

  List<String> readStrings(String key) => _p.getStringList(key) ?? [];

  Future<void> writeStrings(String key, List<String> values) =>
      _p.setStringList(key, values);

  // -------------------------------------------------------------------
  // Portadas personalizadas
  // -------------------------------------------------------------------
  //
  // Las fotos que el usuario elige como portada se guardan comprimidas
  // (JPEG, ~40 KB) en base64, cada una en su propia clave. Así la lista de
  // libros sigue siendo liviana y la portada funciona en todas las
  // plataformas, incluida la web.

  static String coverKey(String bookId) => 'libria_cover_${bookId}_v2';

  Future<void> saveCover(String bookId, List<int> bytes) =>
      _p.setString(coverKey(bookId), base64Encode(bytes));

  Uint8List? loadCover(String bookId) {
    final raw = _p.getString(coverKey(bookId));
    if (raw == null) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> removeCover(String bookId) => _p.remove(coverKey(bookId));

  /// Elimina todos los datos asociados a un usuario.
  Future<void> removeUserData(String userId) async {
    for (final book in readList(userKey(userId, booksDomain))) {
      final id = book['id'];
      if (id is String) await removeCover(id);
    }
    for (final domain in [
      booksDomain,
      eventsDomain,
      commentsDomain,
      recommendationsDomain,
      dismissedDomain,
    ]) {
      await _p.remove(userKey(userId, domain));
    }
  }
}
