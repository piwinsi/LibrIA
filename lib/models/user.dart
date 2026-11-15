/// Cuenta de usuario (RF-01, RF-02, RNF-03 y RNF-04).
///
/// Si la cuenta está respaldada en la nube, [cloudUid] guarda su
/// identificador en Firebase Authentication y [passwordHash]/[salt] quedan
/// vacíos: la contraseña la gestiona Firebase y no se guarda en el
/// dispositivo. Las cuentas solo locales (cuenta demo, o plataformas sin
/// Firebase) conservan el hash con sal.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    this.bio,
    this.favoriteGenres = const [],
    this.onboardingCompleted = false,
    this.isProfilePrivate = true,
    this.cloudUid,
  });

  final String id;
  final String name;
  final String email;

  /// Hash (SHA-256 iterado con sal) de la contraseña. Nunca se guarda la
  /// contraseña en texto plano (RNF-04).
  final String passwordHash;
  final String salt;
  final DateTime createdAt;
  final String? bio;

  /// Géneros elegidos en el onboarding; alimentan las primeras
  /// recomendaciones.
  final List<String> favoriteGenres;
  final bool onboardingCompleted;

  /// Privado por defecto (RNF-03): la actividad solo sale del dispositivo
  /// cuando el usuario decide compartirla.
  final bool isProfilePrivate;

  /// Identificador de la cuenta en Firebase Authentication, o `null` si la
  /// cuenta es solo local.
  final String? cloudUid;

  bool get isCloudAccount => cloudUid != null;

  AppUser copyWith({
    String? name,
    String? bio,
    List<String>? favoriteGenres,
    bool? onboardingCompleted,
    bool? isProfilePrivate,
    String? passwordHash,
    String? salt,
    String? cloudUid,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      createdAt: createdAt,
      bio: bio ?? this.bio,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isProfilePrivate: isProfilePrivate ?? this.isProfilePrivate,
      cloudUid: cloudUid ?? this.cloudUid,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'salt': salt,
        'createdAt': createdAt.toIso8601String(),
        'bio': bio,
        'favoriteGenres': favoriteGenres,
        'onboardingCompleted': onboardingCompleted,
        'isProfilePrivate': isProfilePrivate,
        'cloudUid': cloudUid,
      };

  /// Datos del perfil que se respaldan en la nube (sin credenciales).
  Map<String, dynamic> toProfileJson() => {
        'name': name,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
        'bio': bio,
        'favoriteGenres': favoriteGenres,
        'onboardingCompleted': onboardingCompleted,
        'isProfilePrivate': isProfilePrivate,
      };

  /// Reconstruye la cuenta en un dispositivo nuevo a partir del perfil
  /// respaldado.
  factory AppUser.fromCloudProfile({
    required String id,
    required String uid,
    required String email,
    Map<String, dynamic>? profile,
  }) {
    final data = profile ?? const <String, dynamic>{};
    return AppUser(
      id: id,
      name: data['name'] as String? ?? email.split('@').first,
      email: email,
      passwordHash: '',
      salt: '',
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
      bio: data['bio'] as String?,
      favoriteGenres:
          List<String>.from(data['favoriteGenres'] as List? ?? const []),
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      isProfilePrivate: data['isProfilePrivate'] as bool? ?? true,
      cloudUid: uid,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        passwordHash: json['passwordHash'] as String? ?? '',
        salt: json['salt'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        bio: json['bio'] as String?,
        favoriteGenres:
            List<String>.from(json['favoriteGenres'] as List? ?? const []),
        onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
        isProfilePrivate: json['isProfilePrivate'] as bool? ?? true,
        cloudUid: json['cloudUid'] as String?,
      );
}
