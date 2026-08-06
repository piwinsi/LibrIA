import 'package:flutter/foundation.dart';

import '../data/mock_readers.dart';
import '../models/reader_profile.dart';

class SocialProvider extends ChangeNotifier {
  final List<ReaderProfile> _readers = List.of(mockReaders);

  List<ReaderProfile> get readers => List.unmodifiable(_readers);

  void toggleFollow(String readerId) {
    final index = _readers.indexWhere((reader) => reader.id == readerId);
    if (index == -1) return;

    _readers[index] = _readers[index].copyWith(
      isFollowing: !_readers[index].isFollowing,
    );
    notifyListeners();
  }
}
