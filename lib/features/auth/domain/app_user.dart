/// The signed-in account, as the app needs it (subset of GET /me).
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.apps = const {},
  });

  final int id;
  final String name;
  final String email;

  /// Account role: `owner`, `admin` or `user`.
  final String role;

  /// Per-app roles, e.g. `{ 'nubi': 'ahli' }`.
  final Map<String, String> apps;

  /// Nubi member (ahli/admin) or the owner - same rule as the web's `isMember`.
  bool get isMember =>
      role == 'owner' || apps['nubi'] == 'ahli' || apps['nubi'] == 'admin';
}
