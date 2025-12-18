import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/users.dart';
import '../models/auth_response.dart';
import '../models/service_point.dart';
import '../models/inventory_item.dart';
import '../models/customer.dart';
import '../models/sale_transaction.dart';
import '../database/db_helper.dart';
import '../config.dart';

class PosApiService extends GetxService {
  final String baseurl = AppConfig.baseUrl;

  // Initialize secure storage
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  DatabaseHelper _dbHelper = DatabaseHelper();

  // Keys for secure storage
  static const String _tokenKey = 'access_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _rolesKey = 'roles';
  static const String _isAdminKey = 'is_admin';
  static const String _branchIdKey = 'branch_id';
  static const String _companyIdKey = 'company_id';
  static const String _servicePointIdKey = 'service_point_id';
  static const String _serverUsernameKey = 'server_username';
  static const String _serverPasswordKey = 'server_password';

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

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(json.decode(response.body));
        await _saveAuthData(authResponse);
        return authResponse;
      } else {
        throw Exception("Failed to sign in: ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }

  // Admin sign in with credentials
  Future<AuthResponse> adminSignIn(String username, String password) async {
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
      print(requestBody);

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(json.decode(response.body));
        await _saveAuthData(authResponse);
        return authResponse;
      } else {
        throw Exception("Failed to admin sign in: ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }

  // Save authentication data to secure storage
  Future<void> _saveAuthData(AuthResponse authResponse) async {
    print(
      'DEBUG: _saveAuthData called with token: ${authResponse.accessToken}',
    );
    await _secureStorage.write(key: _tokenKey, value: authResponse.accessToken);
    await _secureStorage.write(key: _userIdKey, value: authResponse.id);
    await _secureStorage.write(key: _usernameKey, value: authResponse.username);
    await _secureStorage.write(
      key: _rolesKey,
      value: json.encode(authResponse.roles),
    );

    // Verify the token was actually stored
    final savedToken = await _secureStorage.read(key: _tokenKey);
    print('DEBUG: Verified saved token: $savedToken');

    if (savedToken != authResponse.accessToken) {
      print('ERROR: Token storage verification failed!');
      throw Exception('Failed to verify token storage');
    }
  }

  // Save authentication data from map (for account switching)
  Future<void> saveAuthDataFromMap(Map<String, dynamic> authData) async {
    await _secureStorage.write(key: _tokenKey, value: authData['accessToken']);
    await _secureStorage.write(key: _userIdKey, value: authData['userId']);
    await _secureStorage.write(key: _usernameKey, value: authData['username']);
    if (authData.containsKey('roles')) {
      await _secureStorage.write(
        key: _rolesKey,
        value: json.encode(authData['roles']),
      );
    }
    if (authData.containsKey('isAdmin')) {
      await _secureStorage.write(
        key: _isAdminKey,
        value: authData['isAdmin'].toString(),
      );
    }
  }

  // Get stored access token
  Future<String?> getAccessToken() async {
    final token = await _secureStorage.read(key: _tokenKey);
    print('DEBUG: getAccessToken() retrieved token: $token');
    return token;
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
    final isAdminStr = await _secureStorage.read(key: _isAdminKey);
    final isAdmin = isAdminStr == 'true';

    return {
      'userId': userId,
      'username': username,
      'roles': roles,
      'isAdmin': isAdmin,
      'accessToken': token,
    };
  }

  // Clear authentication data (logout)
  Future<void> clearAuthData() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _rolesKey);
    await _secureStorage.delete(key: _branchIdKey);
    await _secureStorage.delete(key: _companyIdKey);
    await _secureStorage.delete(key: _servicePointIdKey);
  }

  // Save server credentials
  Future<void> saveServerCredentials(String username, String password) async {
    await _secureStorage.write(key: _serverUsernameKey, value: username);
    await _secureStorage.write(key: _serverPasswordKey, value: password);
  }

  // Get stored server credentials
  Future<Map<String, String?>> getServerCredentials() async {
    final username = await _secureStorage.read(key: _serverUsernameKey);
    final password = await _secureStorage.read(key: _serverPasswordKey);
    return {'username': username, 'password': password};
  }

  Future<List<Map<String, dynamic>>> fetchCashAccounts() async {
    final token = await getAccessToken();

    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.get(
      Uri.parse('$baseurl/rest/cashaccounts'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch cash accounts');
    }
  }

  // Check if server credentials are stored
  Future<bool> hasServerCredentials() async {
    final username = await _secureStorage.read(key: _serverUsernameKey);
    return username != null && username.isNotEmpty;
  }

  // Clear server credentials
  Future<void> clearServerCredentials() async {
    await _secureStorage.delete(key: _serverUsernameKey);
    await _secureStorage.delete(key: _serverPasswordKey);
  }

  // Save company info
  Future<void> saveCompanyInfo(Map<String, dynamic> companyInfo) async {
    final branchId = companyInfo['branch'] ?? '';
    final companyId = companyInfo['company'] ?? '';
    final servicePointId =
        companyInfo['sellingPointId'] ?? companyInfo['branch'] ?? '';

    await _secureStorage.write(key: _branchIdKey, value: branchId);
    await _secureStorage.write(key: _companyIdKey, value: companyId);
    await _secureStorage.write(key: _servicePointIdKey, value: servicePointId);
  }

  // Get company info
  Future<Map<String, String>> getCompanyInfo() async {
    return {
      'branchId': await _secureStorage.read(key: _branchIdKey) ?? '',
      'companyId': await _secureStorage.read(key: _companyIdKey) ?? '',
      'servicePointId':
          await _secureStorage.read(key: _servicePointIdKey) ?? '',
    };
  }

  // Validate token by fetching company info
  Future<void> validateToken() async {
    await fetchAndStoreCompanyInfo();
  }

  // Open database for company
  Future<void> openDatabaseForCompany(String companyId) async {
    await _dbHelper.openForCompany(companyId);
  }

  // Fetch company info from API and store it
  Future<Map<String, dynamic>> fetchAndStoreCompanyInfo() async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse("$baseurl/company/details"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await saveCompanyInfo(data);
        return data;
      } else {
        throw Exception("Failed to fetch company info: ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<User>> fetchUsers() async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse("$baseurl/users"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final users = data.map((json) => User.fromMap(json)).toList();
        return users;
      } else {
        throw Exception("Failed to load user");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ServicePoint>> fetchServicePoints() async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse("$baseurl/servicepoints"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final servicePoints = data
            .map((json) => ServicePoint.fromMap(json))
            .toList();
        return servicePoints;
      } else {
        throw Exception("Failed to load service points");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<InventoryItem>> fetchInventory() async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse("$baseurl/inventory/"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final inventoryItems = data
            .map((json) => InventoryItem.fromMap(json))
            .toList();
        return inventoryItems;
      } else {
        throw Exception("Failed to load inventory");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Customer>> fetchCustomers() async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse("$baseurl/bp/customers"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final customers = data.map((json) => Customer.fromMap(json)).toList();
        return customers;
      } else {
        throw Exception("Failed to load customers");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final jsonPayload = json.encode(saleData);

      final response = await http.post(
        Uri.parse("$baseurl/sales/"),
        headers: headers,
        body: jsonPayload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception(
          "Failed to create sale: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateSale(
    String saleId,
    Map<String, dynamic> saleData,
  ) async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final jsonPayload = json.encode(saleData);

      final response = await http.put(
        Uri.parse("$baseurl/sales/$saleId"),
        headers: headers,
        body: jsonPayload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception(
          "Failed to update sale: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchSingleTransaction(String saleId) async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse("$baseurl/sales/$saleId"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Failed to fetch transaction: ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPayment(
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse("$baseurl/payments/"),
        headers: headers,
        body: json.encode(paymentData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception("Failed to create payment: ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> postSale(Map<String, dynamic> saleData) async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final jsonPayload = json.encode(saleData);

      final response = await http.post(
        Uri.parse("$baseurl/payment/"),
        headers: headers,
        body: jsonPayload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception(
          "Failed to post sale: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // Fetch sales data for sync
  Future<List<Map<String, dynamic>>> fetchSalesForSync({
    required String startDate,
    required String endDate,
    int pageCount = 0,
    int pageSize = 20,
  }) async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final queryParams = {
        'pagecount': pageCount.toString(),
        'pagesize': pageSize.toString(),
        'querry': '',
        'startdate': startDate,
        'enddate': endDate,
      };

      final uri = Uri.parse(
        "$baseurl/sales/",
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception("Failed to fetch sales: ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }
}
