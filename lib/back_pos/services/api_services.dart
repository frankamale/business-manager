import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/services/token_refresh_interceptor.dart';
import '../models/users.dart';
import '../models/auth_response.dart';
import '../models/service_point.dart';
import '../models/inventory_item.dart';
import '../models/customer.dart';
import '../../shared/database/unified_db_helper.dart';
import '../config.dart';

class PosApiService extends GetxService {
  final String baseurl = AppConfig.baseUrl;

  // Initialize secure storage
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Token refresh interceptor for automatic token refresh on 401 errors
  late final TokenRefreshInterceptor _tokenRefreshInterceptor;

  final _dbHelper = UnifiedDatabaseHelper.instance;

  @override
  void onInit() {
    super.onInit();
    // Initialize the token refresh interceptor with base URL and secure storage
    _tokenRefreshInterceptor = TokenRefreshInterceptor(
      baseUrl: baseurl,
      secureStorage: _secureStorage,
    );
  }

  @override
  void onClose() {
    // Close the interceptor when the service is disposed
    _tokenRefreshInterceptor.close();
    super.onClose();
  }

  // Keys for secure storage
  static const String _tokenKey = 'access_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _rolesKey = 'roles';
  static const String _isAdminKey = 'is_admin';
  static const String _branchIdKey = 'branch_id';
  static const String _companyIdKey = 'company_id';
  static const String _companyNameKey = 'company_name';
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
    // Write all auth data in parallel to reduce GC pressure
    await Future.wait([
      _secureStorage.write(key: _tokenKey, value: authResponse.accessToken),
      _secureStorage.write(key: _userIdKey, value: authResponse.id),
      _secureStorage.write(key: _usernameKey, value: authResponse.username),
      _secureStorage.write(key: _rolesKey, value: json.encode(authResponse.roles)),
    ]);
  }

  // Save authentication data from map (for account switching)
  Future<void> saveAuthDataFromMap(Map<String, dynamic> authData) async {
    // Collect all write operations
    final writes = <Future<void>>[
      _secureStorage.write(key: _tokenKey, value: authData['accessToken']),
      _secureStorage.write(key: _userIdKey, value: authData['userId']),
      _secureStorage.write(key: _usernameKey, value: authData['username']),
    ];
    if (authData.containsKey('roles')) {
      writes.add(_secureStorage.write(key: _rolesKey, value: json.encode(authData['roles'])));
    }
    if (authData.containsKey('isAdmin')) {
      writes.add(_secureStorage.write(key: _isAdminKey, value: authData['isAdmin'].toString()));
    }
    // Execute all writes in parallel
    await Future.wait(writes);
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
    // Read all user data in parallel to reduce GC pressure
    final results = await Future.wait([
      _secureStorage.read(key: _tokenKey),
      _secureStorage.read(key: _userIdKey),
      _secureStorage.read(key: _usernameKey),
      _secureStorage.read(key: _rolesKey),
      _secureStorage.read(key: _isAdminKey),
    ]);

    final token = results[0];
    if (token == null) return null;

    final userId = results[1];
    final username = results[2];
    final rolesJson = results[3];
    final isAdminStr = results[4];

    List<String>? roles;
    if (rolesJson != null) {
      roles = List<String>.from(json.decode(rolesJson));
    }
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
    // Delete all auth data in parallel
    await Future.wait([
      _secureStorage.delete(key: _tokenKey),
      _secureStorage.delete(key: _userIdKey),
      _secureStorage.delete(key: _usernameKey),
      _secureStorage.delete(key: _rolesKey),
      _secureStorage.delete(key: _branchIdKey),
      _secureStorage.delete(key: _companyIdKey),
      _secureStorage.delete(key: _servicePointIdKey),
    ]);
  }

  // Save server credentials
  Future<void> saveServerCredentials(String username, String password) async {
    // Write both credentials in parallel
    await Future.wait([
      _secureStorage.write(key: _serverUsernameKey, value: username),
      _secureStorage.write(key: _serverPasswordKey, value: password),
    ]);
  }

  // Get stored server credentials
  Future<Map<String, String?>> getServerCredentials() async {
    // Read both credentials in parallel
    final results = await Future.wait([
      _secureStorage.read(key: _serverUsernameKey),
      _secureStorage.read(key: _serverPasswordKey),
    ]);
    return {'username': results[0], 'password': results[1]};
  }

  Future<List<Map<String, dynamic>>> fetchCashAccounts() async {
    final request = http.Request('GET', Uri.parse('$baseurl/cashaccounts'));
    request.headers['Content-Type'] = 'application/json';

    final streamedResponse = await _tokenRefreshInterceptor.send(request);
    final response = await http.Response.fromStream(streamedResponse);

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

    // Persist the real business name (activeBranch.company.name) so receipts
    // can display it instead of the hard-coded flavor/app name.
    final activeBranch = companyInfo['activeBranch'];
    final company = activeBranch is Map ? activeBranch['company'] : null;
    final companyName = company is Map ? company['name'] as String? : null;
    print('[PosApiService] saveCompanyInfo - resolved companyName: $companyName');
    if (companyName != null && companyName.trim().isNotEmpty) {
      await _secureStorage.write(key: _companyNameKey, value: companyName);
    }
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
      final request = http.Request('GET', Uri.parse("$baseurl/company/details"));
      request.headers['Content-Type'] = 'application/json';

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

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
      final request = http.Request('GET', Uri.parse("$baseurl/users"));
      request.headers['Content-Type'] = 'application/json';

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

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
      final request = http.Request('GET', Uri.parse("$baseurl/servicepoints"));
      request.headers['Content-Type'] = 'application/json';

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

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
      final request = http.Request('GET', Uri.parse("$baseurl/inventory/"));
      request.headers['Content-Type'] = 'application/json';

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

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
      final request = http.Request('GET', Uri.parse("$baseurl/bp/customers"));
      request.headers['Content-Type'] = 'application/json';

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

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
      final request = http.Request('POST', Uri.parse("$baseurl/sales/"));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode(saleData);

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

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
      final request = http.Request('PUT', Uri.parse("$baseurl/sales/$saleId"));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode(saleData);

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

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
      final request = http.Request('GET', Uri.parse("$baseurl/sales/$saleId"));
      request.headers['Content-Type'] = 'application/json';

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

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
      final request = http.Request('POST', Uri.parse("$baseurl/payments/"));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode(paymentData);

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

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
      final request = http.Request('POST', Uri.parse("$baseurl/payment/sale"));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode(saleData);

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

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

      final request = http.Request('GET', uri);
      request.headers['Content-Type'] = 'application/json';

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

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

  /// Create adhoc payment (expense)
  Future<Map<String, dynamic>> createAdhocPayment(
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final request = http.Request('POST', Uri.parse("$baseurl/payment/adhoc"));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode(paymentData);

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception(
          "Failed to create adhoc payment: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Change password for the currently logged in user
  Future<Map<String, dynamic>> changePassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseurl/password/'
        '?t=$userId'
        '&p=${Uri.encodeComponent(newPassword)}'
        '&s=${Uri.encodeComponent('password change')}',
      );

      final request = http.Request('GET', uri);
      request.headers['Content-Type'] = 'application/json';

      final streamedResponse = await _tokenRefreshInterceptor.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to change password: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
