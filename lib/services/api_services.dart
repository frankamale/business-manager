import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/users.dart';
import '../models/auth_response.dart';
import '../models/service_point.dart';
import '../models/inventory_item.dart';

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
      print('FETCHING COMPANY INFO REQUEST STARTED');

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

      print('Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await saveCompanyInfo(data);
        print('Company info stored successfully');
        return data;
      } else {
        throw Exception("Failed to fetch company info: ${response.statusCode}");
      }
    } catch (e) {
      print('Error fetching company info: $e');
      rethrow;
    }
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

  Future<List<ServicePoint>> fetchServicePoints() async {
    try {
      print('FETCHING SERVICE POINTS REQUEST STARTED');

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
        Uri.parse("$baseurl/servicepoints"),
        headers: headers,
      );

      print(' Status Code: ${response.statusCode}');
      print(' Response Body Length: ${response.body.length} characters');

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        print('Successfully parsed ${data.length} service points from API endpoint');

        final servicePoints = data.map((json) => ServicePoint.fromMap(json)).toList();

        print('Service points received from endpoint:');
        for (var i = 0; i < servicePoints.length; i++) {
          print('   ${i + 1}. ${servicePoints[i].name}');
          print('      - Code: ${servicePoints[i].code}');
          print('      - Type: ${servicePoints[i].servicepointtype}');
          print('      - Full Name: ${servicePoints[i].fullName}');
          print('      - Sales: ${servicePoints[i].sales}');
          print('      ---');
        }

        return servicePoints;
      } else {
        print(' Status Code: ${response.statusCode}');
        print(' Response: ${response.body}');
        throw Exception("Failed to load service points");
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

  Future<List<InventoryItem>> fetchInventory() async {
    try {
      print('FETCHING INVENTORY REQUEST STARTED');

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
        Uri.parse("$baseurl/inventory/"),
        headers: headers,
      );

      print(' Status Code: ${response.statusCode}');
      print(' Response Body Length: ${response.body.length} characters');

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        print('✅ Successfully parsed ${data.length} inventory items from API endpoint');

        // Debug: Print first item's raw JSON to see field names
        if (data.isNotEmpty) {
          print('🔍 DEBUG: First inventory item raw JSON:');
          print(json.encode(data[0]));
        }

        final inventoryItems = data.map((json) => InventoryItem.fromMap(json)).toList();

        print('📦 Inventory items received from endpoint: ${inventoryItems.length} items');
        if (inventoryItems.isNotEmpty) {
          print('   Sample items:');
          for (var i = 0; i < (inventoryItems.length < 5 ? inventoryItems.length : 5); i++) {
            print('   ${i + 1}. ${inventoryItems[i].name}');
            print('      - ID: ${inventoryItems[i].id} (type: ${inventoryItems[i].id.runtimeType})');
            print('      - IPDID: ${inventoryItems[i].ipdid}');
            print('      - Code: ${inventoryItems[i].code}');
            print('      - Category: ${inventoryItems[i].category}');
            print('      - Price: UGX ${inventoryItems[i].price}');
            print('      ---');
          }
        }

        return inventoryItems;
      } else {
        print(' Status Code: ${response.statusCode}');
        print(' Response: ${response.body}');
        throw Exception("Failed to load inventory");
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

  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    try {
      print('═══════════════════════════════════════════════════');
      print('CREATING SALE REQUEST STARTED');
      print('═══════════════════════════════════════════════════');

      final token = await getAccessToken();

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      print('📤 REQUEST URL: $baseurl/sales/');
      print('📋 REQUEST HEADERS:');
      headers.forEach((key, value) {
        if (key == 'Authorization') {
          print('   $key: Bearer ${value.substring(7, 27)}...');
        } else {
          print('   $key: $value');
        }
      });

      print('\n📦 SALE PAYLOAD (Main Fields):');
      print('   id: ${saleData['id']} ${_validateField(saleData['id'], 'UUID')}');
      print('   transactionDate: ${saleData['transactionDate']} ${_validateField(saleData['transactionDate'], 'number')}');
      print('   clientid: ${saleData['clientid']} ${_validateField(saleData['clientid'], 'UUID')}');
      print('   transactionstatusid: ${saleData['transactionstatusid']} ${_validateField(saleData['transactionstatusid'], 'number')}');
      print('   salespersonid: ${saleData['salespersonid']} ${_validateField(saleData['salespersonid'], 'UUID')}');
      print('   servicepointid: ${saleData['servicepointid']} ${_validateField(saleData['servicepointid'], 'UUID')}');
      print('   modeid: ${saleData['modeid']} ${_validateField(saleData['modeid'], 'number')}');
      print('   remarks: "${saleData['remarks']}" ${_validateField(saleData['remarks'], 'string')}');
      print('   otherRemarks: "${saleData['otherRemarks']}" ${_validateField(saleData['otherRemarks'], 'string')}');
      print('   branchId: ${saleData['branchId']} ${_validateField(saleData['branchId'], 'UUID')}');
      print('   companyId: ${saleData['companyId']} ${_validateField(saleData['companyId'], 'UUID')}');
      print('   glproxySubCategoryId: ${saleData['glproxySubCategoryId']} ${_validateField(saleData['glproxySubCategoryId'], 'UUID')}');
      print('   receiptnumber: ${saleData['receiptnumber']} ${_validateField(saleData['receiptnumber'], 'string')}');
      print('   saleActionId: ${saleData['saleActionId']} ${_validateField(saleData['saleActionId'], 'number')}');

      final lineItems = saleData['lineItems'] as List<dynamic>? ?? [];
      print('\n📋 LINE ITEMS (${lineItems.length} items):');
      for (var i = 0; i < lineItems.length; i++) {
        final item = lineItems[i] as Map<String, dynamic>;
        print('   Item ${i + 1}:');
        print('      id: ${item['id']}');
        print('      itemName: ${item['itemName']}');
        print('      category: ${item['category']}');
        print('      quantity: ${item['quantity']}');
        print('      sellingprice: ${item['sellingprice']}');
        print('      sellingprice_original: ${item['sellingprice_original']}');
        print('      costprice: ${item['costprice']}');
        print('      packsize: ${item['packsize']}');
        print('      inventoryid: ${item['inventoryid']}');
        print('      packagingid: ${item['packagingid']}');
        print('      salesid: ${item['salesid']}');
        print('      transactionstatusid: ${item['transactionstatusid']}');
        print('      servicepointid: ${item['servicepointid']}');
        print('      ordernumber: ${item['ordernumber']}');
        print('      complimentaryid: ${item['complimentaryid']}');
        print('      ipdid: ${item['ipdid']}');
        print('      remarks: ${item['remarks']}');
        print('      notes: ${item['notes']}');
      }

      print('\n📤 FULL JSON PAYLOAD:');
      final jsonPayload = json.encode(saleData);
      print(jsonPayload);

      final response = await http.post(
        Uri.parse("$baseurl/sales/"),
        headers: headers,
        body: jsonPayload,
      );

      print('\n📥 RESPONSE:');
      print('   Status Code: ${response.statusCode}');
      print('   Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ SALE CREATED SUCCESSFULLY');
        print('═══════════════════════════════════════════════════');
        return json.decode(response.body);
      } else {
        print('❌ SALE CREATION FAILED');
        print('   Status: ${response.statusCode}');
        print('   Error: ${response.body}');
        print('═══════════════════════════════════════════════════');
        throw Exception("Failed to create sale: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print('❌ ERROR CREATING SALE: $e');
      print('═══════════════════════════════════════════════════');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchSingleTransaction(String saleId) async {
    try {
      print('FETCHING SINGLE TRANSACTION REQUEST STARTED');

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

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Failed to fetch transaction: ${response.statusCode}");
      }
    } catch (e) {
      print('Error fetching transaction: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> paymentData) async {
    try {
      print('CREATING PAYMENT REQUEST STARTED');

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

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception("Failed to create payment: ${response.statusCode}");
      }
    } catch (e) {
      print('Error creating payment: $e');
      rethrow;
    }
  }

  // Helper method to validate fields in logging
  String _validateField(dynamic value, String expectedType) {
    if (value == null) {
      return '⚠️ NULL';
    }
    if (value is String && value.isEmpty) {
      return '⚠️ EMPTY';
    }
    if (expectedType == 'UUID') {
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      if (value is String && !uuidRegex.hasMatch(value)) {
        return '❌ INVALID UUID';
      }
    }
    if (expectedType == 'number' && value is! int && value is! double) {
      return '❌ NOT A NUMBER';
    }
    return '✓';
  }
}
