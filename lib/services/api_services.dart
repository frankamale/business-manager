import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/users.dart';
import '../models/auth_response.dart';

class ApiService extends GetxService {
  final String baseurl = "http://52.30.142.12:8080/rest";

  // Initialize secure storage
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Keys for secure storage
  static const String _tokenKey = 'access_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _rolesKey = 'roles';

  // Sign in with credentials
  Future<AuthResponse> signIn(String username, String password) async {
    try {

      final requestBody = json.encode({
        'username': username,
        'password': password,
      });

      final response = await http.post(
        Uri.parse("$baseurl/auth/signin"),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );
      print('📊 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('Authentication successful!');
        final authResponse = AuthResponse.fromJson(json.decode(response.body));

        await _saveAuthData(authResponse);
        print(' Auth data stored successfully');

        return authResponse;
      } else {
        print('Status Code: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception("Failed to sign in: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      print(' Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      rethrow;
    }
  }

  // Save authentication data to secure storage
  Future<void> _saveAuthData(AuthResponse authResponse) async {
    await _secureStorage.write(key: _tokenKey, value: authResponse.accessToken);
    await _secureStorage.write(key: _userIdKey, value: authResponse.id);
    await _secureStorage.write(key: _usernameKey, value: authResponse.username);
    await _secureStorage.write(
      key: _rolesKey,
      value: json.encode(authResponse.roles),
    );
  }

  // Get stored access token
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // Get stored user data
  Future<Map<String, dynamic>?> getStoredUserData() async {
    final token = await _secureStorage.read(key: _tokenKey);

    if (token == null) return null;

    final userId = await _secureStorage.read(key: _userIdKey);
    final username = await _secureStorage.read(key: _usernameKey);
    final rolesJson = await _secureStorage.read(key: _rolesKey);

    List<String>? roles;
    if (rolesJson != null) {
      roles = List<String>.from(json.decode(rolesJson));
    }

    return {
      'userId': userId,
      'username': username,
      'roles': roles,
      'accessToken': token,
    };
  }

  // Clear authentication data (logout)
  Future<void> clearAuthData() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _rolesKey);
  }

  Future<List<User>> fetchUsers() async {
    try {
      print('FETCHING USERS REQUEST STARTED');

      final token = await getAccessToken();
      print(' Token retrieved: ${token != null ? "${token.substring(0, 20)}..." : "No token"}');

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        print(' Authorization header added');
      } else {
        print(' No authorization token available');
      }

      final response = await http.get(
        Uri.parse("$baseurl/users"),
        headers: headers,
      );

      print(' Status Code: ${response.statusCode}');
      print(' Response Body Length: ${response.body.length} characters');


      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        print('✅ Successfully parsed ${data.length} users from API endpoint');

        final users = data.map((json) => User.fromMap(json)).toList();

        print('📋 Users received from endpoint:');
        for (var i = 0; i < users.length; i++) {
          print('   ${i + 1}. ${users[i].name}');
          print('      - Username: ${users[i].username}');
          print('      - Role: ${users[i].role}');
          print('      - Branch: ${users[i].branchname}');
          print('      - Company: ${users[i].companyName}');
          print('      ---');
        }

        return users;
      } else {
        print(' Status Code: ${response.statusCode}');
        print(' Response: ${response.body}');
        throw Exception("Failed to load user");
      }
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════');
      print(' Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      print('Stack Trace:');
      print(stackTrace);
      rethrow;
    }
  }
}
