import 'package:flutter/foundation.dart';

import '../data/mock_users.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;

  bool get isLoggedIn => _currentUser != null;
  AppUser? get currentUser => _currentUser;

  bool login(String email, String password) {
    if (email.trim() == demoCredentialEmail &&
        password == demoCredentialPassword) {
      _currentUser = mockDemoUser;
      notifyListeners();
      return true;
    }
    return false;
  }

  void register(String name, String email) {
    _currentUser = AppUser(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
    );
    notifyListeners();
  }

  void updateProfile({String? name, String? bio, List<String>? favoriteGenres}) {
    final user = _currentUser;
    if (user == null) return;

    _currentUser = user.copyWith(
      name: name,
      bio: bio,
      favoriteGenres: favoriteGenres,
    );
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
