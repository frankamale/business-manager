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
  static const String _botCompanyIdKey = 'bot_company_id';
  static const String _botCompanyNameKey = 'bot_company_name';

  // Secure storage key for cached staff accounts
  static const String _cachedStaffAccountsKey = 'cached_staff_accounts';

  // Secure storage key for cached customer accounts
  static const String _cachedCustomerAccountsKey = 'cached_customer_accounts';

  // Cache expiry duration (24 hours)
  static const int _cacheExpiryHours = 24;

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

  /// Fetch and store bot's company info from /rest/company/details
  Future<void> fetchAndStoreBotCompanyInfo() async {
    final token = await getBotToken();

    final response = await http.get(
      Uri.parse('$baseUrl/company/details'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final companyId = data['company'] as String?;
      final companyName = data['activeBranch']?['company']?['name'] as String?;

      if (companyId != null) {
        await _secureStorage.write(key: _botCompanyIdKey, value: companyId);
      }
      if (companyName != null) {
        await _secureStorage.write(key: _botCompanyNameKey, value: companyName);
      }
    } else if (response.statusCode == 401) {
      await clearBotToken();
      throw Exception('Bot token expired');
    } else {
      throw Exception('Failed to fetch company details: ${response.statusCode}');
    }
  }

  /// Get the stored bot company ID
  Future<String?> getBotCompanyId() async {
    return await _secureStorage.read(key: _botCompanyIdKey);
  }

  /// Get the stored bot company name
  Future<String?> getBotCompanyName() async {
    return await _secureStorage.read(key: _botCompanyNameKey);
  }

  /// Check if bot company info is stored
  Future<bool> hasBotCompanyInfo() async {
    final companyId = await _secureStorage.read(key: _botCompanyIdKey);
    return companyId != null && companyId.isNotEmpty;
  }

  // ============================================================
  // STAFF ACCOUNT CACHING (for offline/faster login)
  // ============================================================

  /// Cache a staff account after successful server login
  Future<void> cacheStaffAccount({
    required String username,
    required String password,
    required String companyId,
    required List<dynamic> roles,
    required Map<String, dynamic> userData,
  }) async {
    // Hash the password with bcrypt for secure storage
    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

    final account = {
      'username': username.toLowerCase(),
      'passwordHash': passwordHash,
      'companyId': companyId,
      'roles': roles,
      'userData': userData,
      'lastLogin': DateTime.now().millisecondsSinceEpoch,
    };

    // Get existing cached accounts
    final accounts = await _getCachedStaffAccounts();

    // Remove existing entry for this username if exists
    accounts.removeWhere(
      (a) => a['username']?.toString().toLowerCase() == username.toLowerCase(),
    );

    // Add the new/updated account
    accounts.add(account);

    // Save back to secure storage
    await _secureStorage.write(
      key: _cachedStaffAccountsKey,
      value: json.encode(accounts),
    );
  }

  /// Get all cached staff accounts
  Future<List<Map<String, dynamic>>> _getCachedStaffAccounts() async {
    final data = await _secureStorage.read(key: _cachedStaffAccountsKey);
    if (data == null || data.isEmpty) {
      return [];
    }
    try {
      final List decoded = json.decode(data);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Validate cached staff login
  /// Returns the cached account data if valid, null otherwise
  Future<Map<String, dynamic>?> validateCachedStaffLogin({
    required String username,
    required String password,
  }) async {
    final accounts = await _getCachedStaffAccounts();

    // Find account by username
    final account = accounts.cast<Map<String, dynamic>?>().firstWhere(
      (a) => a?['username']?.toString().toLowerCase() == username.toLowerCase(),
      orElse: () => null,
    );

    if (account == null) {
      return null;
    }

    // Check if cache has expired (24 hours)
    final lastLogin = account['lastLogin'] as int?;
    if (lastLogin == null) {
      return null;
    }

    final lastLoginTime = DateTime.fromMillisecondsSinceEpoch(lastLogin);
    final now = DateTime.now();
    final hoursSinceLogin = now.difference(lastLoginTime).inHours;

    if (hoursSinceLogin >= _cacheExpiryHours) {
      // Cache expired, need fresh server login
      return null;
    }

    // Validate password using bcrypt
    final passwordHash = account['passwordHash'] as String?;
    if (passwordHash == null || !BCrypt.checkpw(password, passwordHash)) {
      return null;
    }

    // Validate company ID against bot's company (for flavored apps)
    final accountCompanyId = account['companyId'] as String?;
    final botCompanyId = await getBotCompanyId();
    if (botCompanyId != null && botCompanyId.isNotEmpty) {
      if (accountCompanyId != botCompanyId) {
        return null;
      }
    }

    // All validations passed, return the cached account
    return account;
  }

  /// Check if a cached account exists and is valid (not expired)
  Future<bool> hasCachedStaffAccount(String username) async {
    final accounts = await _getCachedStaffAccounts();
    final account = accounts.cast<Map<String, dynamic>?>().firstWhere(
      (a) => a?['username']?.toString().toLowerCase() == username.toLowerCase(),
      orElse: () => null,
    );

    if (account == null) return false;

    final lastLogin = account['lastLogin'] as int?;
    if (lastLogin == null) return false;

    final lastLoginTime = DateTime.fromMillisecondsSinceEpoch(lastLogin);
    final hoursSinceLogin = DateTime.now().difference(lastLoginTime).inHours;

    return hoursSinceLogin < _cacheExpiryHours;
  }

  /// Clear a specific cached staff account
  Future<void> clearCachedStaffAccount(String username) async {
    final accounts = await _getCachedStaffAccounts();
    accounts.removeWhere(
      (a) => a['username']?.toString().toLowerCase() == username.toLowerCase(),
    );
    await _secureStorage.write(
      key: _cachedStaffAccountsKey,
      value: json.encode(accounts),
    );
  }

  /// Clear all cached staff accounts
  Future<void> clearAllCachedStaffAccounts() async {
    await _secureStorage.delete(key: _cachedStaffAccountsKey);
  }

  /// Remove expired cached accounts (cleanup)
  Future<void> cleanupExpiredStaffAccounts() async {
    final accounts = await _getCachedStaffAccounts();
    final now = DateTime.now();

    accounts.removeWhere((account) {
      final lastLogin = account['lastLogin'] as int?;
      if (lastLogin == null) return true;
      final lastLoginTime = DateTime.fromMillisecondsSinceEpoch(lastLogin);
      return now.difference(lastLoginTime).inHours >= _cacheExpiryHours;
    });

    await _secureStorage.write(
      key: _cachedStaffAccountsKey,
      value: json.encode(accounts),
    );
  }

  // ============================================================
  // CUSTOMER ACCOUNT CACHING (for offline/faster login)
  // ============================================================

  /// Cache a customer account after successful login
  Future<void> cacheCustomerAccount(Customer customer) async {
    final account = {
      'customerData': customer.toMap(),
      'lastLogin': DateTime.now().millisecondsSinceEpoch,
    };

    // Get existing cached accounts
    final accounts = await _getCachedCustomerAccounts();

    // Remove existing entry for this customer if exists (by any identifier)
    accounts.removeWhere((a) {
      final data = a['customerData'] as Map<String, dynamic>?;
      if (data == null) return false;
      return data['email']?.toString().toLowerCase() ==
              customer.email?.toLowerCase() ||
          data['phone1'] == customer.phone1 ||
          data['posusername']?.toString().toLowerCase() ==
              customer.posusername?.toLowerCase();
    });

    // Add the new/updated account
    accounts.add(account);

    // Save back to secure storage
    await _secureStorage.write(
      key: _cachedCustomerAccountsKey,
      value: json.encode(accounts),
    );
  }

  /// Get all cached customer accounts
  Future<List<Map<String, dynamic>>> _getCachedCustomerAccounts() async {
    final data = await _secureStorage.read(key: _cachedCustomerAccountsKey);
    if (data == null || data.isEmpty) {
      return [];
    }
    try {
      final List decoded = json.decode(data);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Find cached customer by identifier (email, phone, or posusername)
  Future<Map<String, dynamic>?> findCachedCustomer(String identifier) async {
    final normalized = identifier.toLowerCase().trim();
    final accounts = await _getCachedCustomerAccounts();

    for (final account in accounts) {
      final data = account['customerData'] as Map<String, dynamic>?;
      if (data == null) continue;

      if (data['email']?.toString().toLowerCase() == normalized ||
          data['phone1'] == normalized ||
          data['posusername']?.toString().toLowerCase() == normalized) {
        return account;
      }
    }
    return null;
  }

  /// Validate cached customer login
  /// Returns the Customer if valid, null otherwise
  Future<Customer?> validateCachedCustomerLogin({
    required String identifier,
    required String pin,
  }) async {
    final cachedAccount = await findCachedCustomer(identifier);
    if (cachedAccount == null) {
      return null;
    }

    // Check if cache has expired (24 hours)
    final lastLogin = cachedAccount['lastLogin'] as int?;
    if (lastLogin == null) {
      return null;
    }

    final lastLoginTime = DateTime.fromMillisecondsSinceEpoch(lastLogin);
    final now = DateTime.now();
    final hoursSinceLogin = now.difference(lastLoginTime).inHours;

    if (hoursSinceLogin >= _cacheExpiryHours) {
      // Cache expired, need fresh server login
      return null;
    }

    // Reconstruct Customer from cached data
    final customerData = cachedAccount['customerData'] as Map<String, dynamic>?;
    if (customerData == null) {
      return null;
    }

    final customer = Customer.fromMap(customerData);

    // Check if customer account is enabled
    if (customer.posenabled != true) {
      return null;
    }

    // Validate PIN using bcrypt (password hash is stored in customer data)
    if (!validateCustomerPin(customer, pin)) {
      return null;
    }

    // All validations passed
    return customer;
  }

  /// Clear a specific cached customer account
  Future<void> clearCachedCustomerAccount(String identifier) async {
    final normalized = identifier.toLowerCase().trim();
    final accounts = await _getCachedCustomerAccounts();

    accounts.removeWhere((a) {
      final data = a['customerData'] as Map<String, dynamic>?;
      if (data == null) return false;
      return data['email']?.toString().toLowerCase() == normalized ||
          data['phone1'] == normalized ||
          data['posusername']?.toString().toLowerCase() == normalized;
    });

    await _secureStorage.write(
      key: _cachedCustomerAccountsKey,
      value: json.encode(accounts),
    );
  }

  /// Clear all cached customer accounts
  Future<void> clearAllCachedCustomerAccounts() async {
    await _secureStorage.delete(key: _cachedCustomerAccountsKey);
  }

  /// Remove expired cached customer accounts (cleanup)
  Future<void> cleanupExpiredCustomerAccounts() async {
    final accounts = await _getCachedCustomerAccounts();
    final now = DateTime.now();

    accounts.removeWhere((account) {
      final lastLogin = account['lastLogin'] as int?;
      if (lastLogin == null) return true;
      final lastLoginTime = DateTime.fromMillisecondsSinceEpoch(lastLogin);
      return now.difference(lastLoginTime).inHours >= _cacheExpiryHours;
    });

    await _secureStorage.write(
      key: _cachedCustomerAccountsKey,
      value: json.encode(accounts),
    );
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
