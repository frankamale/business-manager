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

class ApiService extends GetxService {
  final String baseurl = AppConfig.baseUrl;

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
  static const String _branchIdKey = 'branch_id';
  static const String _companyIdKey = 'company_id';
  static const String _servicePointIdKey = 'service_point_id';

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
    await _secureStorage.delete(key: _branchIdKey);
    await _secureStorage.delete(key: _companyIdKey);
    await _secureStorage.delete(key: _servicePointIdKey);
  }

  // Save company info
  Future<void> saveCompanyInfo(Map<String, dynamic> companyInfo) async {
    final branchId = companyInfo['branch'] ?? '';
    final companyId = companyInfo['company'] ?? '';
    final servicePointId = companyInfo['sellingPointId'] ?? companyInfo['branch'] ?? '';

    await _secureStorage.write(key: _branchIdKey, value: branchId);
    await _secureStorage.write(key: _companyIdKey, value: companyId);
    await _secureStorage.write(key: _servicePointIdKey, value: servicePointId);
  }

  // Get company info
  Future<Map<String, String>> getCompanyInfo() async {
    return {
      'branchId': await _secureStorage.read(key: _branchIdKey) ?? '',
      'companyId': await _secureStorage.read(key: _companyIdKey) ?? '',
      'servicePointId': await _secureStorage.read(key: _servicePointIdKey) ?? '',
    };
  }

  // Fetch company info from API and store it
  Future<Map<String, dynamic>> fetchAndStoreCompanyInfo() async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

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

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

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

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse("$baseurl/servicepoints"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final servicePoints = data.map((json) => ServicePoint.fromMap(json)).toList();
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

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse("$baseurl/inventory/"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final inventoryItems = data.map((json) => InventoryItem.fromMap(json)).toList();
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

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

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

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

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
        throw Exception("Failed to create sale: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchSingleTransaction(String saleId) async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

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

  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> paymentData) async {
    try {
      final token = await getAccessToken();

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

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

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

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
        throw Exception("Failed to post sale: ${response.statusCode} - ${response.body}");
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

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

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

      final uri = Uri.parse("$baseurl/sales/").replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: headers,
      );

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
