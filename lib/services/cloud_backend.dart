/// Contrato del servicio en la nube (autenticación y respaldo).
///
/// LibrIA es *local-first*: la app lee y escribe primero en el dispositivo
/// y usa este servicio para autenticar la cuenta (RF-01, RNF-04) y para
/// respaldar y restaurar los datos del lector. La implementación real usa
/// Firebase ([FirebaseCloudBackend]); en plataformas sin Firebase
/// configurado (Windows) y en las pruebas automatizadas se usa
/// [NoCloudBackend] o un servicio simulado en memoria.
///
/// Estructura de datos en la nube:
///
/// ```text
/// users/{uid}/books/{id}            libros (gana la versión más reciente)
/// users/{uid}/events/{id}           eventos de lectura (solo se agregan)
/// users/{uid}/comments/{id}         comentarios por página
/// users/{uid}/recommendations/{id}  recomendaciones compartidas
/// users/{uid}/meta/profile          perfil lector
/// users/{uid}/meta/suggestions      sugerencias mostradas/aceptadas/descartadas
/// ```
abstract class CloudBackend {
  const CloudBackend();

  /// `true` si el servicio está configurado en esta plataforma.
  bool get isAvailable;

  /// Identificador del usuario autenticado en la nube, o `null`.
  String? get currentUid;

  /// Crea la cuenta y devuelve su uid. Lanza [CloudAuthException].
  Future<String> signUp({required String email, required String password});

  /// Inicia sesión y devuelve el uid. Lanza [CloudAuthException].
  Future<String> signIn({required String email, required String password});

  Future<void> signOut();

  /// Cambia la contraseña verificando primero la actual.
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  });

  /// Borra los datos respaldados y la cuenta en la nube.
  Future<void> deleteAccount({
    required String uid,
    required String email,
    required String password,
  });

  /// Descarga todos los documentos de las colecciones indicadas.
  Future<Map<String, List<Map<String, dynamic>>>> download(
    String uid,
    List<String> collections,
  );

  /// Lee un documento puntual (por ejemplo `meta/profile`).
  Future<Map<String, dynamic>?> getDoc(String uid, String collection, String id);

  /// Escribe (crea o reemplaza) los documentos indicados.
  Future<void> commit(String uid, List<CloudWrite> writes);
}

/// Escritura de un documento `users/{uid}/{collection}/{id}`.
class CloudWrite {
  const CloudWrite(this.collection, this.id, this.data);

  final String collection;
  final String id;
  final Map<String, dynamic> data;
}

/// Error de autenticación con un mensaje listo para mostrar.
class CloudAuthException implements Exception {
  const CloudAuthException(this.code, this.message);

  /// Código normalizado: `invalid-credential`, `email-already-in-use`,
  /// `weak-password`, `invalid-email`, `network`, `requires-recent-login`,
  /// `too-many-requests` o `unknown`.
  final String code;
  final String message;

  static const invalidCredential = 'invalid-credential';
  static const emailInUse = 'email-already-in-use';
  static const network = 'network';
  static const requiresRecentLogin = 'requires-recent-login';

  @override
  String toString() => 'CloudAuthException($code): $message';
}

/// Sin servicio en la nube: la app funciona solo con datos locales.
class NoCloudBackend extends CloudBackend {
  const NoCloudBackend();

  @override
  bool get isAvailable => false;

  @override
  String? get currentUid => null;

  Never _unavailable() => throw const CloudAuthException(
        'unavailable',
        'El respaldo en la nube no está disponible en esta plataforma.',
      );

  @override
  Future<String> signUp({required String email, required String password}) async =>
      _unavailable();

  @override
  Future<String> signIn({required String email, required String password}) async =>
      _unavailable();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async =>
      _unavailable();

  @override
  Future<void> deleteAccount({
    required String uid,
    required String email,
    required String password,
  }) async {}

  @override
  Future<Map<String, List<Map<String, dynamic>>>> download(
    String uid,
    List<String> collections,
  ) async =>
      {for (final c in collections) c: const []};

  @override
  Future<Map<String, dynamic>?> getDoc(
    String uid,
    String collection,
    String id,
  ) async =>
      null;

  @override
  Future<void> commit(String uid, List<CloudWrite> writes) async {}
}
