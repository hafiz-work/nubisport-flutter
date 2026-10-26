/// Single source of truth for demo accounts.
///
/// Both the auth mock (login/register) and the activity mock reference these,
/// so an activity's `userId` always points at a real demo account. Keep this
/// file free of Flutter/domain imports: features map it to their own models.
class MockAccount {
  const MockAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.password = 'Password123!',
    this.appRoles = const {},
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String password;
  final Map<String, String> appRoles;
}

abstract final class MockAccounts {
  static const ahli = MockAccount(
    id: 1,
    name: 'Ahli Demo',
    email: 'ahli@nubi.test',
    role: 'user',
    appRoles: {'nubi': 'ahli'},
  );

  static const admin = MockAccount(
    id: 2,
    name: 'Admin Demo',
    email: 'admin@nubi.test',
    role: 'admin',
    appRoles: {'nubi': 'admin'},
  );

  static const aina = MockAccount(
    id: 3,
    name: 'Aina Rahman',
    email: 'aina@nubi.test',
    role: 'user',
    appRoles: {'nubi': 'ahli'},
  );

  static const haziq = MockAccount(
    id: 4,
    name: 'Haziq Omar',
    email: 'haziq@nubi.test',
    role: 'user',
    appRoles: {'nubi': 'ahli'},
  );

  static const meiLing = MockAccount(
    id: 5,
    name: 'Mei Ling',
    email: 'meiling@nubi.test',
    role: 'user',
    appRoles: {'nubi': 'ahli'},
  );

  static const farid = MockAccount(
    id: 6,
    name: 'Farid Zul',
    email: 'farid@nubi.test',
    role: 'user',
    appRoles: {'nubi': 'ahli'},
  );

  static const all = [ahli, admin, aina, haziq, meiLing, farid];

  static MockAccount? byEmail(String email) {
    final key = email.trim().toLowerCase();
    for (final account in all) {
      if (account.email == key) return account;
    }
    return null;
  }
}
