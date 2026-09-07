import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/mock_readers.dart';
import '../models/reader_profile.dart';
import '../services/local_storage_service.dart';

class SocialProvider extends ChangeNotifier {
  final List<ReaderProfile> _readers = List.of(mockReaders);

  List<ReaderProfile> get readers => List.unmodifiable(_readers);

  Future<void> toggleFollow(String readerId) async {
    final index = _readers.indexWhere((reader) => reader.id == readerId);
    if (index == -1) return;

    _readers[index] = _readers[index].copyWith(
      isFollowing: !_readers[index].isFollowing,
    );
    notifyListeners();
    // Se espera (await) la escritura en disco por la misma razón que en
    // LibraryProvider y AuthProvider: evitar perder el cambio si el
    // proceso se detiene justo después de "Seguir"/"Dejar de seguir".
    await persist();
  }

  /// Lee la actividad social ("Seguir"/"Siguiendo") serializada desde
  /// [LocalStorageService] y la aplica sobre los lectores en memoria. Debe
  /// esperarse (`await`) antes de `runApp()`.
  Future<void> hydrate() async {
    final stored = LocalStorageService.instance.loadSocial();
    if (stored == null) return;

    try {
      final map = jsonDecode(stored) as Map<String, dynamic>;
      final followingIds = Set<String>.from(
        (map['followingIds'] as List? ?? const []).cast<String>(),
      );

      for (var i = 0; i < _readers.length; i++) {
        _readers[i] = _readers[i].copyWith(
          isFollowing: followingIds.contains(_readers[i].id),
        );
      }
      notifyListeners();
    } catch (_) {
      // Estado corrupto o de una versión anterior: se mantiene la
      // actividad social de demostración en lugar de bloquear el arranque.
    }
  }

  /// Serializa qué lectores está siguiendo el usuario y lo guarda mediante
  /// [LocalStorageService]. Se invoca automáticamente tras cada
  /// "Seguir"/"Dejar de seguir".
  Future<void> persist() async {
    final followingIds =
        _readers.where((reader) => reader.isFollowing).map((r) => r.id).toList();
    await LocalStorageService.instance
        .saveSocial(jsonEncode({'followingIds': followingIds}));
  }
}
