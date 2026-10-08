class AuthSession {
  const AuthSession({
    required this.token,
    required this.companyId,
    required this.companyName,
  });

  /// El token del panel en macOS y Windows, que viaja como `Bearer`. Null
  /// en el navegador: ahí la sesión es la cookie HttpOnly que puso el login
  /// y la página no la ve (YaVieneBackend, `cookie_panel.ts`).
  final String? token;
  final String companyId;
  final String companyName;
}
