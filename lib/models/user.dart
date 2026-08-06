class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.bio,
    this.favoriteGenres = const [],
    this.booksRead = 0,
    this.followers = 0,
    this.following = 0,
  });

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final List<String> favoriteGenres;
  final int booksRead;
  final int followers;
  final int following;

  AppUser copyWith({
    String? name,
    String? bio,
    List<String>? favoriteGenres,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      avatarUrl: avatarUrl,
      bio: bio ?? this.bio,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      booksRead: booksRead,
      followers: followers,
      following: following,
    );
  }
}
