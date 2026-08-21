/// Customer and Rider are separate role accounts.
/// Phone uniqueness is scoped to (role, phone), never globally across roles.
enum AccountRole { customer, rider }

class RoleAccount {
  const RoleAccount({
    required this.role,
    required this.phone,
    required this.id,
  });

  final AccountRole role;
  final String phone;
  final String id;
}

class RoleAccountRegistry {
  RoleAccountRegistry();

  final Map<String, RoleAccount> _byKey = <String, RoleAccount>{};

  static String normalizePhone(String raw) {
    final String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (digits.startsWith('91') && digits.length == 12) {
      return '+$digits';
    }
    return raw.startsWith('+') ? raw : '+$digits';
  }

  static String keyFor(AccountRole role, String phone) =>
      '${role.name}:${normalizePhone(phone)}';

  RoleAccount register({
    required AccountRole role,
    required String phone,
    required String id,
  }) {
    final String key = keyFor(role, phone);
    final RoleAccount account = RoleAccount(
      role: role,
      phone: normalizePhone(phone),
      id: id,
    );
    _byKey[key] = account;
    return account;
  }

  RoleAccount? find(AccountRole role, String phone) =>
      _byKey[keyFor(role, phone)];

  bool exists(AccountRole role, String phone) =>
      _byKey.containsKey(keyFor(role, phone));

  /// Same mobile may exist as Customer AND Rider.
  bool canRegister(AccountRole role, String phone) => !exists(role, phone);
}
