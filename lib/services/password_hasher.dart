import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Protección de credenciales (RNF-04): las contraseñas se guardan como
/// hash SHA-256 iterado con una sal aleatoria por usuario, nunca en texto
/// plano.
class PasswordHasher {
  PasswordHasher._();

  static const _iterations = 5000;

  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hash(String password, String salt) {
    final saltBytes = utf8.encode(salt);
    var digest = sha256.convert(utf8.encode('$salt:$password')).bytes;
    for (var i = 1; i < _iterations; i++) {
      digest = sha256.convert([...digest, ...saltBytes]).bytes;
    }
    return base64UrlEncode(digest);
  }

  static bool verify(String password, String salt, String expectedHash) =>
      hash(password, salt) == expectedHash;
}
