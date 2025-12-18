import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../controllers/mon_operator_controller.dart';
import '../controllers/mon_sync_controller.dart';
import '../db/db_helper.dart';

class MonitorApiService extends GetxService {
  static const String _baseUrl = 'http://52.30.142.12:8080/rest';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  final _dbHelper = DatabaseHelper();

  Future<String?> getStoredToken() async {
    final token = await _secureStorage.read(key: "access_token");
    print('DEBUG: MonitorApiService.getStoredToken() retrieved token: $token');
    return token;
  }

  Future<void> storeToken(String token) async {
    await _secureStorage.write(key: 'access_token', value: token);
    print('DEBUG: MonitorApiService.storeToken() stored token');
  }

  Future<String?> getStoredCode() async {
    return await _secureStorage.read(key: 'persistent_code');
  }

  Future<void> storeCode(String code) async {
    print('DEBUG: MonitorApiService.storeCode() called with code: $code');
    await _secureStorage.write(key: 'persistent_code', value: code);
    final savedCode = await _secureStorage.read(key: 'persistent_code');
    print('DEBUG: MonitorApiService.storeCode() verified saved code: $savedCode');
  }

  Future<void> storeUserData(Map<String, dynamic> data) async {
    await _secureStorage.write(key: 'user_data', value: jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getStoredUserData() async {
    final userDataString = await _secureStorage.read(key: 'user_data');
    return userDataString != null ? jsonDecode(userDataString) : null;
  }

  Future<void> storeLastSyncTimestamp(int timestamp) async {
    await _secureStorage.write(key: 'last_sync_timestamp', value: timestamp.toString());
  }

  Future<int?> getStoredLastSyncTimestamp() async {
    final timestampString = await _secureStorage.read(key: 'last_sync_timestamp');
    return timestampString != null ? int.parse(timestampString) : null;
  }

  Future<void> storeCompanyId(String companyId) async {
    await _secureStorage.write(key: 'company_id', value: companyId);
  }

  Future<String?> getStoredCompanyId() async {
    return await _secureStorage.read(key: 'company_id');
  }

  // Save server credentials
  Future<void> saveServerCredentials(String username, String password) async {
    await _secureStorage.write(key: 'server_username', value: username);
    await _secureStorage.write(key: 'server_password', value: password);
  }

  // Get stored server credentials
  Future<Map<String, String?>> getServerCredentials() async {
    final username = await _secureStorage.read(key: 'server_username');
    final password = await _secureStorage.read(key: 'server_password');
    return {
      'username': username,
      'password': password,
    };
  }

  /// Initialize company ID during app startup
  /// This should be called early in the app initialization process
  Future<void> initializeCompanyId() async {
    try {
      print('DEBUG: MonitorApiService.initializeCompanyId() - Starting company ID initialization');
      final companyId = await ensureCompanyIdAvailable();
      print('DEBUG: MonitorApiService.initializeCompanyId() - Company ID initialized: $companyId');
      
      // Switch to the company's database if we have a valid company ID
      if (companyId != null && companyId.isNotEmpty && companyId != 'default_offline_company') {
        try {
          await _dbHelper.switchCompany(companyId);
          print('DEBUG: MonitorApiService.initializeCompanyId() - Switched to company database: $companyId');
        } catch (e) {
          print('ERROR: MonitorApiService.initializeCompanyId() - Failed to switch company database: $e');
          // Don't fail the entire initialization if database switch fails
        }
      }
      
    } catch (e) {
      print('ERROR: MonitorApiService.initializeCompanyId() - Failed to initialize company ID: $e');
    }
  }

  Future<String> fetchCompanyId() async {
    try {
      print('DEBUG: MonitorApiService.fetchCompanyId() - Starting company ID fetch');
      final response = await getWithAuth('/company/details');
      final companyDetails = json.decode(response.body);
      print('DEBUG: MonitorApiService.fetchCompanyId() - Company details response: $companyDetails');

      if (companyDetails.containsKey('company')) {
        final companyId = companyDetails['company'];
        print('DEBUG: MonitorApiService.fetchCompanyId() - Found company ID: $companyId');
        await storeCompanyId(companyId.toString());
        
        // Verify the company ID was stored correctly
        final storedCompanyId = await getStoredCompanyId();
        if (storedCompanyId == companyId.toString()) {
          print('DEBUG: MonitorApiService.fetchCompanyId() - Company ID stored successfully');
        } else {
          print('ERROR: MonitorApiService.fetchCompanyId() - Company ID storage verification failed');
          throw Exception('Failed to verify company ID storage');
        }
        
        return companyId.toString();
      } else {
        print('ERROR: MonitorApiService.fetchCompanyId() - Company ID not found in company details');
        throw Exception('Company ID not found in company details');
      }
    } catch (e) {
      print('ERROR: MonitorApiService.fetchCompanyId() - Failed to fetch company ID: $e');
      debugPrint("ApiService: Failed to fetch company ID -> $e");
      throw Exception('Failed to fetch company ID: $e');
    }
  }

  Future<String> ensureCompanyIdAvailable() async {
    print('DEBUG: MonitorApiService.ensureCompanyIdAvailable() - Checking for stored company ID');
    
    // Check if company ID is already stored
    final storedCompanyId = await getStoredCompanyId();
    print('DEBUG: MonitorApiService.ensureCompanyIdAvailable() - Stored company ID: $storedCompanyId');
    
    if (storedCompanyId != null && storedCompanyId.isNotEmpty) {
      print('DEBUG: MonitorApiService.ensureCompanyIdAvailable() - Using stored company ID');
      
      // Verify the stored company ID is still valid by checking if we can access company data
      try {
        final token = await getStoredToken();
        if (token != null) {
          // Try to fetch company details to verify the company ID is still valid
          final response = await getWithAuth('/company/details');
          final companyDetails = json.decode(response.body);
          if (companyDetails.containsKey('company') && companyDetails['company'].toString() == storedCompanyId) {
            print('DEBUG: MonitorApiService.ensureCompanyIdAvailable() - Stored company ID is still valid');
            return storedCompanyId;
          }
        }
      } catch (e) {
        print('WARNING: MonitorApiService.ensureCompanyIdAvailable() - Failed to verify stored company ID: $e');
        // Continue to fetch fresh company ID
      }
    }

    // If not stored or verification failed, try to fetch it
    try {
      print('DEBUG: MonitorApiService.ensureCompanyIdAvailable() - Attempting to fetch company ID from API');
      return await fetchCompanyId();
    } catch (e) {
      print('ERROR: MonitorApiService.ensureCompanyIdAvailable() - Failed to fetch company ID: $e');
      
      // Graceful fallback for offline scenarios
      if (e.toString().contains('Authentication token not found') ||
          e.toString().contains('Failed to load data') ||
          e.toString().contains('Network error')) {
        print('WARNING: MonitorApiService.ensureCompanyIdAvailable() - Offline mode detected, using default company ID');
        
        // Use a default company ID for offline mode
        final defaultCompanyId = 'default_offline_company';
        await storeCompanyId(defaultCompanyId);
        return defaultCompanyId;
      }
      
      debugPrint("ApiService: Failed to ensure company ID is available -> $e");
      throw Exception('Company ID is not available: $e');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool useToken = true,
  }) async {
    try {
      print('DEBUG: MonitorApiService.post() called for endpoint: $endpoint, useToken: $useToken');
      final headers = {'Content-Type': 'application/json'};
      if (useToken) {
        final token = await getStoredToken();
        print('DEBUG: MonitorApiService.post() retrieved token: $token');
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        } else {
          print('ERROR: MonitorApiService.post() - Authentication token not found.');
          throw Exception('Authentication token not found.');
        }
      }
      print('DEBUG: MonitorApiService.post() - Making POST request to $_baseUrl$endpoint');
      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );
      print('DEBUG: MonitorApiService.post() - Received response with status: ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('ERROR: MonitorApiService.post() - Network error: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<void> login(String email, String password) async {
    print("login begin ----- ");

    final response = await post('/auth/signin', {
      'username': email.trim().toLowerCase(),
      'password': password.trim(),
    }, useToken: false);
    print("next .....");
    print(response);
    if (response.containsKey('accessToken')) {
      await storeToken(response['accessToken']);

      final userData = {
        'id': response['id'],
        'username': response['username'],
        'email': response['email'],
        'roles': response['roles'],
      };
      await storeUserData(userData);

      // Store server credentials for re-authentication
      await saveServerCredentials(email, password);

      print("login success ----- authentication completed");

      await storeCode(DateTime.now().millisecondsSinceEpoch.toString());
    } else {
      throw Exception('Login failed: Token not provided in response.');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      } else {
        return {};
      }
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Bad credentials or expired token.');
    } else {
      throw Exception('API error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> logout() async {
    Get.find<MonSyncController>().onClose();
    await Get.delete<MonSyncController>(force: true);

    // Close all database instances on logout
    await _dbHelper.closeAllDatabases();

    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'user_data');
    await _secureStorage.delete(key: 'persistent_code');
    await _secureStorage.delete(key: 'last_sync_timestamp');
    await _secureStorage.delete(key: 'company_id');
  }

  /// Switch to a different company
  /// This will update the stored company ID and switch the database
  Future<void> switchCompany(String newCompanyId) async {
    try {
      // Store the new company ID
      await storeCompanyId(newCompanyId);

      // Switch to the new company's database
      await _dbHelper.switchCompany(newCompanyId);

      debugPrint("ApiService: Successfully switched to company: $newCompanyId");

      // Fetch and cache data for the new company
      await fetchAndCacheAllData();
    } catch (e) {
      debugPrint("ApiService: Failed to switch company: $e");
      rethrow;
    }
  }

  Future<void> fetchAndCacheAllData() async {
    final now = DateTime.now();
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final currentDate = dateFormatter.format(now);

    try {
      debugPrint("ApiService: Starting to fetch all data...");

      // Individual calls with logging to find the failing one
      http.Response? servicePointsRes;
      http.Response? companyDetailsRes;
      http.Response? salesRes;
      http.Response? salesDetailsRes;
      http.Response? inventoryRes;

      // Service points is now OPTIONAL - don't fail if it returns 404
      try {
        servicePointsRes = await getWithAuth('/servicepoints');
        debugPrint("ApiService: Successfully fetched service points");
      } catch (e) {
        debugPrint(
          "ApiService: Service points endpoint failed (will continue without it) -> $e",
        );
        servicePointsRes = null; // Explicitly set to null to continue
      }

      try {
        companyDetailsRes = await getWithAuth('/company/details');
        debugPrint("ApiService: Successfully fetched company details");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /company/details -> $e");
      }

      try {
        final endDate = dateFormatter.format(now);
        salesRes = await getWithAuth(
          '/sales/reports/transaction/detail?startDate=2023-09-01&endDate=$endDate',
        );
        debugPrint(
          "ApiService: Successfully fetched sales reports from 2023-09-01 to $endDate",
        );
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /reports/sales -> $e");
      }

      try {
        // Fetch sales details with salesperson and payment info
        salesDetailsRes = await getWithAuth(
          '/sales/?pagecount=0&pagesize=5000',
        );
        debugPrint("ApiService: Successfully fetched sales details");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /sales/ -> $e");
      }

      try {
        inventoryRes = await getWithAuth('/inventory/');
        debugPrint("ApiService: Successfully fetched inventory");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /inventory -> $e");
      }

      // Changed validation - only company details and sales are required
      if (companyDetailsRes == null || salesRes == null) {
        throw Exception(
          "One or more REQUIRED data endpoints failed to respond correctly.",
        );
      }

      // Parse service points only if available and has valid body
      List<dynamic> servicePointsData = [];
      if (servicePointsRes != null && servicePointsRes.body.isNotEmpty) {
        try {
          servicePointsData = json.decode(servicePointsRes.body);
        } catch (e) {
          debugPrint("ApiService: Failed to parse service points JSON -> $e");
        }
      }

      Map<String, dynamic> companyDetailsData = {};
      if (companyDetailsRes.body.isNotEmpty) {
        try {
          companyDetailsData = json.decode(companyDetailsRes.body);
        } catch (e) {
          debugPrint("ApiService: Failed to parse company details JSON -> $e");
          throw Exception("Failed to parse company details: $e");
        }
      } else {
        throw Exception("Company details response is empty");
      }

      List<dynamic> salesData = [];
      if (salesRes.body.isNotEmpty) {
        try {
          salesData = json.decode(salesRes.body);
        } catch (e) {
          debugPrint("ApiService: Failed to parse sales JSON -> $e");
          throw Exception("Failed to parse sales data: $e");
        }
      } else {
        throw Exception("Sales response is empty");
      }

      List<dynamic> salesDetailsData = [];
      if (salesDetailsRes != null && salesDetailsRes.body.isNotEmpty) {
        try {
          salesDetailsData = json.decode(salesDetailsRes.body);
        } catch (e) {
          debugPrint("ApiService: Failed to parse sales details JSON -> $e");
        }
      }

      List<dynamic> inventoryData = [];
      if (inventoryRes != null && inventoryRes.body.isNotEmpty) {
        try {
          inventoryData = json.decode(inventoryRes.body);
          debugPrint(
            "ApiService: Parsed ${inventoryData.length} inventory items",
          );
        } catch (e) {
          debugPrint(
            "ApiService: Failed to parse inventory JSON (will continue without it) -> $e",
          );
        }
      } else {
        debugPrint(
          "ApiService: Inventory response is empty (will continue without it)",
        );
      }

      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        await txn.delete('service_points');
        await txn.delete('company_details');
        await txn.delete('sales');

        if (inventoryData.isNotEmpty) {
          debugPrint(
            "ApiService: Inserting ${inventoryData.length} inventory items",
          );
          for (final item in inventoryData) {
            await _dbHelper.insertInventoryItem(item, db: txn);
          }
        } else {
          debugPrint(
            "ApiService: No inventory data available, skipping insertion",
          );
        }

        await _dbHelper.insertCompanyDetails(companyDetailsData, db: txn);

        // Only insert service points if data is available
        if (servicePointsData.isNotEmpty) {
          debugPrint(
            "ApiService: Inserting ${servicePointsData.length} service points",
          );
          for (final item in servicePointsData) {
            await _dbHelper.insertServicePoint(item, db: txn);
          }
        } else {
          debugPrint(
            "ApiService: No service points data available, skipping insertion",
          );
        }

        for (final item in salesData) {
          await _dbHelper.insertSale(item, db: txn);
        }

        // Update with salesperson and payment info from sales details
        for (final detail in salesDetailsData) {
          if (detail['id'] != null) {
            await txn.update(
              'sales',
              {
                'salesperson': detail['salesperson'],
                'paymentmode': detail['paymentmode'],
              },
              where: 'salesId = ?',
              whereArgs: [detail['id']],
            );
          }
        }

        await _dbHelper.mapSalesToServicePoints(db: txn);
      });

      await storeLastSyncTimestamp(now.millisecondsSinceEpoch);
      debugPrint(
        "ApiService: All data fetched successfully, and local DB updated.",
      );

      if (Get.isRegistered<MonOperatorController>()) {
        await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();
      }
    } catch (e) {
      debugPrint("ApiService: fetchAndCacheAllData() failed -> $e");
      rethrow;
    }
  }

  Future<void> syncRecentSales() async {
    try {
      debugPrint("ApiService: Starting recent sales sync...");
      final now = DateTime.now();

      final lastSyncTimestamp =
          (await getStoredLastSyncTimestamp()) ??
          now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(
        lastSyncTimestamp,
      );

      final dateFormatter = DateFormat('yyyy-MM-dd');
      final startDate = dateFormatter.format(lastSyncDate);
      final endDate = dateFormatter.format(now);

      debugPrint("ApiService: Syncing from $startDate to $endDate.");

      final response = await getWithAuth(
        '/sales/reports/transaction/detail?startDate=$startDate&endDate=$endDate',
      );

      final List<dynamic> salesData = json.decode(response.body);

      // Also fetch sales details for salesperson info
      http.Response? salesDetailsRes;
      try {
        salesDetailsRes = await getWithAuth(
          '/sales/?pagecount=0&pagesize=5000&startdate=$startDate&enddate=$endDate',
        );
      } catch (e) {
        debugPrint(
          "ApiService: Failed to fetch sales details during sync -> $e",
        );
      }

      final List<dynamic> salesDetailsData = salesDetailsRes != null
          ? json.decode(salesDetailsRes.body)
          : [];

      final db = await _dbHelper.database;

      final startOfDayToClear = DateTime(
        lastSyncDate.year,
        lastSyncDate.month,
        lastSyncDate.day,
      );
      final startOfDayMillis = startOfDayToClear.millisecondsSinceEpoch;

      debugPrint(
        "ApiService: Deleting local sales from ${startOfDayToClear.toIso8601String()} onwards before inserting updates.",
      );

      await db.transaction((txn) async {
        await txn.delete(
          'sales',
          where: 'transactiondate >= ?',
          whereArgs: [startOfDayMillis],
        );
        for (final item in salesData) {
          await _dbHelper.insertSale(item, db: txn);
        }

        // Update with salesperson and payment info from sales details
        for (final detail in salesDetailsData) {
          if (detail['id'] != null) {
            await txn.update(
              'sales',
              {
                'salesperson': detail['salesperson'],
                'paymentmode': detail['paymentmode'],
              },
              where: 'salesId = ?',
              whereArgs: [detail['id']],
            );
          }
        }

        await _dbHelper.mapSalesToServicePoints(db: txn);
      });

      debugPrint(
        "ApiService: Successfully synced and replaced ${salesData.length} sales records for the specified period.",
      );

      await storeLastSyncTimestamp(now.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("ApiService: Error during recent sales sync: $e");
    }
  }

  Future<http.Response> getWithAuth(String endpoint) async {
    print('DEBUG: MonitorApiService._getWithAuth() called for endpoint: $endpoint');
    final token = await getStoredToken();
    print('DEBUG: MonitorApiService._getWithAuth() retrieved token: $token');
    
    if (token == null) {
      print('ERROR: MonitorApiService._getWithAuth() - Authentication token not found for GET request.');
      throw Exception('Authentication token not found for GET request.');
    }
    
    print('DEBUG: MonitorApiService._getWithAuth() - Making authenticated request to $_baseUrl$endpoint');
    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('DEBUG: MonitorApiService._getWithAuth() - Received response with status: ${response.statusCode}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      _handleResponse(
        response,
      ); // Use handleResponse for centralized error handling
      throw Exception(
        'Failed to load data from $endpoint: ${response.statusCode}',
      );
    }
  }
}
