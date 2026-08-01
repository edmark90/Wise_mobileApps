/// Result of a successful login/signup: the access token plus the user map
/// returned by the server.
class AuthResult {
  final String token;
  final Map<String, dynamic> user;

  const AuthResult({required this.token, required this.user});
}
