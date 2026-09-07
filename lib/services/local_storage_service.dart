import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de persistencia local (RNF-07).
///
/// Encapsula `shared_preferences` y expone métodos save*/load* para cada
/// dominio de estado de la app (biblioteca, perfil, actividad social y
/// sesión activa), serializado como JSON por cada provider antes de
/// guardarse.
///
/// Nota sobre Flutter Web y el debugger: al depurar con `flutter run -d
/// chrome`, detener la sesión desde VSCode (botón "Stop") puede cerrar la
/// pestaña de forma más abrupta que un cierre manual y cortar una
/// escritura en curso. Esta es una limitación conocida del flujo de
/// depuración web, no del comportamiento de la app para un usuario final
/// (que solo cierra pestañas o recarga normalmente) ni de un build de
/// producción o de la versión Android/desktop empaquetada.
class LocalStorageService {
  LocalStorageService._();
  static final instance = LocalStorageService._();

  static const _libraryKey = 'libria_library_state_v1';
  static const _profileKey = 'libria_profile_state_v1';
  static const _socialKey = 'libria_social_state_v1';
  static const _sessionActiveKey = 'libria_session_active_v1';

  SharedPreferences? _prefs;

  /// Debe llamarse una vez al inicio (por ejemplo, desde `main()`) antes de
  /// usar cualquiera de los métodos load*, para que la instancia de
  /// SharedPreferences esté cacheada y las lecturas sean síncronas.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveLibrary(String jsonState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_libraryKey, jsonState);
  }

  String? loadLibrary() {
    return _prefs?.getString(_libraryKey);
  }

  Future<void> saveProfile(String jsonState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonState);
  }

  String? loadProfile() {
    return _prefs?.getString(_profileKey);
  }

  Future<void> saveSocial(String jsonState) async {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionActiveKey, active);
  }

  bool loadSessionActive() {
    return _prefs?.getBool(_sessionActiveKey) ?? false;
  }
}
