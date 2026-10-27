/// The signed-in account, as the app needs it (subset of GET /me).
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.apps = const {},
    this.username = '',
    this.bio = '',
    this.location = '',
    this.profilePublic = false,
  });

  final int id;
  final String name;
  final String email;

  /// Account role: `owner`, `admin` or `user`.
  final String role;

  /// Per-app roles, e.g. `{ 'nubi': 'ahli' }`.
  final Map<String, String> apps;

  /// Public profile bits (PATCH /me on the web).
  final String username;
  final String bio;
  final String location;
  final bool profilePublic;

  /// Nubi member (ahli/admin) or the owner - same rule as the web's `isMember`.
  bool get isMember => role == 'owner' || apps['nubi'] == 'ahli' || apps['nubi'] == 'admin';

  AppUser copyWith({String? name, String? username, String? bio, String? location, bool? profilePublic}) => AppUser(
    id: id,
    name: name ?? this.name,
    email: email,
    role: role,
    apps: apps,
    username: username ?? this.username,
    bio: bio ?? this.bio,
    location: location ?? this.location,
    profilePublic: profilePublic ?? this.profilePublic,
  );
}
