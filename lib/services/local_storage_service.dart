import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

/// Servicio de persistencia local (RNF-07).
///
/// Encapsula `shared_preferences` y expone métodos save*/load* para cada
/// dominio de estado de la app (biblioteca, perfil, actividad social y
/// sesión activa), serializado como JSON por cada provider antes de
/// guardarse.
///
/// Nota sobre Flutter Web y el debugger: al depurar con `flutter run -d
/// chrome`, detener la sesión desde el IDE (botón "Stop") puede cerrar la
/// pestaña de un modo más abrupto que un cierre manual, sin dar tiempo a
/// que termine una escritura asíncrona en curso. Para que ningún cambio se
/// pierda en ese escenario, este servicio mantiene en memoria una copia del
/// último valor escrito de cada clave y, en la Web, la vuelve a escribir de
/// forma síncrona sobre `window.localStorage` justo antes de que la
/// pestaña se descargue (evento `beforeunload`), sin depender de que el
/// `Future` de `shared_preferences` haya alcanzado a completarse.
class LocalStorageService {
  LocalStorageService._() {
    if (kIsWeb) {
      _registerBeforeUnloadFlush();
    }
  }
  static final instance = LocalStorageService._();

  static const _libraryKey = 'libria_library_state_v1';
  static const _profileKey = 'libria_profile_state_v1';
  static const _socialKey = 'libria_social_state_v1';
  static const _sessionActiveKey = 'libria_session_active_v1';

  SharedPreferences? _prefs;

  // Último valor conocido de cada clave, usado para el flush síncrono de
  // emergencia en `beforeunload`. Se actualiza en cada save*() exitoso o
  // en curso.
  final Map<String, String> _pendingStringValues = {};
  final Map<String, bool> _pendingBoolValues = {};

  /// Debe llamarse una vez al inicio (por ejemplo, desde `main()`) antes de
  /// usar cualquiera de los métodos load*, para que la instancia de
  /// SharedPreferences esté cacheada y las lecturas sean síncronas.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveLibrary(String jsonState) async {
    _pendingStringValues[_libraryKey] = jsonState;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_libraryKey, jsonState);
  }

  String? loadLibrary() {
    return _prefs?.getString(_libraryKey);
  }

  Future<void> saveProfile(String jsonState) async {
    _pendingStringValues[_profileKey] = jsonState;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonState);
  }

  String? loadProfile() {
    return _prefs?.getString(_profileKey);
  }

  Future<void> saveSocial(String jsonState) async {
    _pendingStringValues[_socialKey] = jsonState;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_socialKey, jsonState);
  }

  String? loadSocial() {
    return _prefs?.getString(_socialKey);
  }

  /// Guarda si hay una sesión activa, independientemente de si el perfil
  /// del usuario está guardado. Esto permite que "Cerrar sesión" oculte al
  /// usuario al reabrir la app sin borrar sus datos de perfil, y que la
  /// próxima vez que inicie sesión recupere el mismo perfil editado.
  Future<void> saveSessionActive(bool active) async {
    _pendingBoolValues[_sessionActiveKey] = active;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionActiveKey, active);
  }

  bool loadSessionActive() {
    return _prefs?.getBool(_sessionActiveKey) ?? false;
  }

  /// Registra un listener de `beforeunload` que escribe de forma síncrona
  /// (sin `await`) los últimos valores conocidos directamente en
  /// `window.localStorage`, usando el mismo prefijo de clave que usa el
  /// backend web de `shared_preferences` (`flutter.<key>`). Esto asegura
  /// que, aunque el `Future` de `SharedPreferences.setString/setBool` no
  /// haya terminado cuando la pestaña se cierra (por ejemplo, al presionar
  /// "Stop" en el debugger), el último estado en memoria de todas formas
  /// quede guardado.
  void _registerBeforeUnloadFlush() {
    web.window.addEventListener(
      'beforeunload',
      (web.Event _) {
        _flushPendingValuesSync();
      }.toJS,
    );
  }

  void _flushPendingValuesSync() {
    for (final entry in _pendingStringValues.entries) {
      web.window.localStorage.setItem('flutter.${entry.key}', entry.value);
    }
    for (final entry in _pendingBoolValues.entries) {
      web.window.localStorage.setItem(
        'flutter.${entry.key}',
        jsonEncode(entry.value),
      );
    }
  }
}
