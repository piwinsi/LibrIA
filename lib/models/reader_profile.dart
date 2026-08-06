class ReaderProfile {
  const ReaderProfile({
    required this.id,
    required this.name,
    required this.bio,
    required this.booksRead,
    this.isFollowing = false,
  });

  final String id;
  final String name;
  final String bio;
  final int booksRead;
  final bool isFollowing;

  ReaderProfile copyWith({bool? isFollowing}) {
    return ReaderProfile(
      id: id,
      name: name,
      bio: bio,
      booksRead: booksRead,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}
