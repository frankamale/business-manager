import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../back_pos/config.dart';
import '../../back_pos/models/customer.dart';

class CustomerAuthService {
  final String baseUrl = AppConfig.baseUrl;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Build-time credentials from --dart-define
  static const String _envBotUsername = String.fromEnvironment('BOT_USERNAME');
  static const String _envBotPassword = String.fromEnvironment('BOT_PASSWORD');

  // Secure storage keys for bot credentials
  static const String _botUsernameKey = 'bot_username';
  static const String _botPasswordKey = 'bot_password';
  static const String _botTokenKey = 'bot_token';

  /// Initialize bot credentials from dart-define to secure storage (call on app start)
  Future<void> initBotCredentials() async {
    // Only initialize if dart-define values are provided and not already stored
    if (_envBotUsername.isNotEmpty && _envBotPassword.isNotEmpty) {
      final existing = await _secureStorage.read(key: _botUsernameKey);
      if (existing == null || existing.isEmpty) {
        await saveBotCredentials(_envBotUsername, _envBotPassword);
      }
    }
  }

  /// Check if bot credentials are configured
  Future<bool> hasBotCredentials() async {
    final username = await _secureStorage.read(key: _botUsernameKey);
    return username != null && username.isNotEmpty;
  }

  /// Save bot credentials to secure storage
  Future<void> saveBotCredentials(String username, String password) async {
    await Future.wait([
      _secureStorage.write(key: _botUsernameKey, value: username),
      _secureStorage.write(key: _botPasswordKey, value: password),
    ]);
  }

  /// Get bot credentials from secure storage
  Future<Map<String, String?>> getBotCredentials() async {
    final results = await Future.wait([
      _secureStorage.read(key: _botUsernameKey),
      _secureStorage.read(key: _botPasswordKey),
    ]);
    return {'username': results[0], 'password': results[1]};
  }

  /// Authenticate bot and get token
  Future<String> getBotToken() async {
    // Check for cached token first
    final cachedToken = await _secureStorage.read(key: _botTokenKey);
    if (cachedToken != null && cachedToken.isNotEmpty) {
      return cachedToken;
    }

    // Get bot credentials
    final credentials = await getBotCredentials();
    if (credentials['username'] == null || credentials['password'] == null) {
      throw Exception('Bot credentials not configured');
    }

    // Authenticate
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signin'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': credentials['username'],
        'password': credentials['password'],
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['accessToken'] as String;
      // Cache the token
      await _secureStorage.write(key: _botTokenKey, value: token);
      return token;
    } else {
      throw Exception('Failed to authenticate bot: ${response.statusCode}');
    }
  }

  /// Clear cached bot token (call when token expires)
  Future<void> clearBotToken() async {
    await _secureStorage.delete(key: _botTokenKey);
  }

  /// Fetch all customers using bot token (in-memory only)
  Future<List<Customer>> fetchCustomers(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/bp/customers'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => Customer.fromMap(json)).toList();
    } else if (response.statusCode == 401) {
      // Token expired, clear and retry
      await clearBotToken();
      throw Exception('Bot token expired');
    } else {
      throw Exception('Failed to fetch customers: ${response.statusCode}');
    }
  }

  /// Find customer by email, phone, or posusername
  Customer? findCustomerByIdentifier(
    List<Customer> customers,
    String identifier,
  ) {
    final normalized = identifier.toLowerCase().trim();
    for (final customer in customers) {
      if (customer.email?.toLowerCase() == normalized ||
          customer.phone1 == normalized ||
          customer.posusername?.toLowerCase() == normalized) {
        return customer;
      }
    }
    return null;
  }

  /// Validate customer PIN using bcrypt comparison
  bool validateCustomerPin(Customer customer, String pin) {
    final storedHash = customer.pospassword;
    if (storedHash == null || storedHash.isEmpty) {
      return false;
    }
    // Use bcrypt to verify the pin against the stored hash
    return BCrypt.checkpw(pin, storedHash);
  }
}
