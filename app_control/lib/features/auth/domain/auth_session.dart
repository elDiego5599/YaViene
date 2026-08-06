class AuthSession {
  const AuthSession({
    required this.token,
    required this.companyId,
    required this.companyName,
  });

  final String token;
  final String companyId;
  final String companyName;
}
