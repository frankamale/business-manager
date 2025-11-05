class AuthResponse {
  final String id;
  final String username;
  final String email;
  final List<String> roles;
  final String accessToken;
  final String tokenType;

  AuthResponse({
    required this.id,
    required this.username,
    required this.email,
    required this.roles,
    required this.accessToken,
    required this.tokenType,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      roles: List<String>.from(json['roles'] ?? []),
      accessToken: json['accessToken'] ?? '',
      tokenType: json['tokenType'] ?? 'Bearer',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'roles': roles,
      'accessToken': accessToken,
      'tokenType': tokenType,
    };
  }
}
