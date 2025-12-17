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
      
      // Ensure company ID is available
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
      // Don't throw exception to allow app to continue in offline mode
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
    
    // If we have a stored company ID, use it immediately for offline scenarios
    if (storedCompanyId != null && storedCompanyId.isNotEmpty) {
      print('DEBUG: MonitorApiService.ensureCompanyIdAvailable() - Using stored company ID: $storedCompanyId');
      return storedCompanyId;
    }
    
    // If not stored, try to fetch it from API
    try {
      print('DEBUG: MonitorApiService.ensureCompanyIdAvailable() - Attempting to fetch company ID from API');
      return await fetchCompanyId();
    } catch (e) {
      print('ERROR: MonitorApiService.ensureCompanyIdAvailable() - Failed to fetch company ID: $e');
      
      // Graceful fallback for offline scenarios
      if (e.toString().contains('Authentication token not found') ||
          e.toString().contains('Failed to load data') ||
          e.toString().contains('Network error') ||
          e.toString().contains('Failed to fetch company ID')) {
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
      
      // Log the start of data fetching process
      debugPrint("ApiService: Starting data fetching process - online mode");

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
        debugPrint("ApiService: Attempting to fetch company details from API");
        companyDetailsRes = await getWithAuth('/company/details');
        debugPrint("ApiService: Successfully fetched company details with status: ${companyDetailsRes.statusCode}");
        debugPrint("ApiService: Company details response body: ${companyDetailsRes.body}");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /company/details -> $e");
        // In offline mode, we can continue without fresh company details
        companyDetailsRes = null;
      }

      try {
        final endDate = dateFormatter.format(now);
        debugPrint("ApiService: Attempting to fetch sales reports from 2023-09-01 to $endDate");
        salesRes = await getWithAuth(
          '/sales/reports/transaction/detail?startDate=2023-09-01&endDate=$endDate',
        );
        debugPrint(
          "ApiService: Successfully fetched sales reports with status: ${salesRes.statusCode}",
        );
        debugPrint("ApiService: Sales reports response body length: ${salesRes.body.length}");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /reports/sales -> $e");
        // In offline mode, we can continue without fresh sales data
        salesRes = null;
      }

      try {
        // Fetch sales details with salesperson and payment info
        debugPrint("ApiService: Attempting to fetch sales details");
        salesDetailsRes = await getWithAuth(
          '/sales/?pagecount=0&pagesize=5000',
        );
        debugPrint("ApiService: Successfully fetched sales details with status: ${salesDetailsRes.statusCode}");
        debugPrint("ApiService: Sales details response body length: ${salesDetailsRes.body.length}");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /sales/ -> $e");
        salesDetailsRes = null;
      }

      try {
        debugPrint("ApiService: Attempting to fetch inventory");
        inventoryRes = await getWithAuth('/inventory/');
        debugPrint("ApiService: Successfully fetched inventory with status: ${inventoryRes.statusCode}");
        debugPrint("ApiService: Inventory response body length: ${inventoryRes.body.length}");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /inventory -> $e");
        inventoryRes = null;
      }

      // In offline mode, we don't require any endpoints to succeed
      // We'll work with whatever data we can get
      debugPrint("ApiService: Proceeding with available data (offline mode tolerant)");

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
      if (companyDetailsRes != null && companyDetailsRes.body.isNotEmpty) {
        try {
          companyDetailsData = json.decode(companyDetailsRes.body);
          debugPrint("ApiService: Parsed company details successfully");
        } catch (e) {
          debugPrint("ApiService: Failed to parse company details JSON -> $e");
          // In offline mode, we can continue with empty company details
          companyDetailsData = {};
        }
      } else if (companyDetailsRes != null) {
        debugPrint("ApiService: Company details response is empty");
        companyDetailsData = {};
      }

      List<dynamic> salesData = [];
      if (salesRes != null && salesRes.body.isNotEmpty) {
        try {
          salesData = json.decode(salesRes.body);
          debugPrint("ApiService: Parsed ${salesData.length} sales records");
        } catch (e) {
          debugPrint("ApiService: Failed to parse sales JSON -> $e");
          // In offline mode, we can continue with empty sales data
          salesData = [];
        }
      } else if (salesRes != null) {
        debugPrint("ApiService: Sales response is empty");
        salesData = [];
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
      } else if (inventoryRes != null) {
        debugPrint(
          "ApiService: Inventory response is empty (will continue without it)",
        );
      }

      final db = await _dbHelper.database;
      debugPrint("ApiService: Database connection established, starting transaction");
      
      await db.transaction((txn) async {
        // Only clear tables if we have new data to insert
        bool hasDataToInsert = companyDetailsData.isNotEmpty ||
                              salesData.isNotEmpty ||
                              inventoryData.isNotEmpty ||
                              servicePointsData.isNotEmpty;
        
        if (hasDataToInsert) {
          debugPrint("ApiService: Clearing old data before inserting fresh data");
          await txn.delete('service_points');
          await txn.delete('company_details');
          await txn.delete('sales');
        }

        if (inventoryData.isNotEmpty) {
          debugPrint(
            "ApiService: Inserting ${inventoryData.length} inventory items",
          );
          for (final item in inventoryData) {
            await _dbHelper.insertInventoryItem(item, db: txn);
          }
        } else {
          debugPrint("ApiService: No inventory data available, skipping insertion");
        }

        // Only insert company details if we have valid data
        if (companyDetailsData.isNotEmpty) {
          await _dbHelper.insertCompanyDetails(companyDetailsData, db: txn);
        } else {
          debugPrint("ApiService: No company details data available, skipping insertion");
        }

        // Only insert service points if data is available
        if (servicePointsData.isNotEmpty) {
          debugPrint(
            "ApiService: Inserting ${servicePointsData.length} service points",
          );
          for (final item in servicePointsData) {
            await _dbHelper.insertServicePoint(item, db: txn);
          }
        } else {
          debugPrint("ApiService: No service points data available, skipping insertion");
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

        if (hasDataToInsert) {
          await _dbHelper.mapSalesToServicePoints(db: txn);
        }
      });

      await storeLastSyncTimestamp(now.millisecondsSinceEpoch);
      debugPrint(
        "ApiService: All data fetched successfully, and local DB updated.",
      );
      debugPrint("ApiService: Data fetching and caching completed successfully in online mode");

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
      debugPrint("ApiService: Authentication token missing - cannot make authenticated request");
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
    debugPrint("ApiService: GET request to $endpoint returned status: ${response.statusCode}");
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint("ApiService: Successfully fetched data from $endpoint");
      return response;
    } else {
      debugPrint("ApiService: Failed to load data from $endpoint with status: ${response.statusCode}");
      debugPrint("ApiService: Response body: ${response.body}");
      _handleResponse(
        response,
      ); // Use handleResponse for centralized error handling
      throw Exception(
        'Failed to load data from $endpoint: ${response.statusCode}',
      );
    }
  }

  /// Test method to verify data fetching and caching works correctly when online
  Future<bool> testDataFetchingAndCaching() async {
    try {
      debugPrint("ApiService: Starting test of data fetching and caching logic");

      // Check if we have authentication token
      final token = await getStoredToken();
      if (token == null) {
        debugPrint("ApiService: Test failed - no authentication token available");
        return false;
      }
      debugPrint("ApiService: Authentication token available for testing");

      // Test individual API endpoints
      bool companyDetailsSuccess = false;
      bool salesSuccess = false;
      bool inventorySuccess = false;

      try {
        final companyResponse = await getWithAuth('/company/details');
        if (companyResponse.statusCode == 200 && companyResponse.body.isNotEmpty) {
          companyDetailsSuccess = true;
          debugPrint("ApiService: Company details endpoint test passed");
        }
      } catch (e) {
        debugPrint("ApiService: Company details endpoint test failed: $e");
      }

      try {
        final now = DateTime.now();
        final endDate = DateFormat('yyyy-MM-dd').format(now);
        final salesResponse = await getWithAuth(
          '/sales/reports/transaction/detail?startDate=2023-09-01&endDate=$endDate',
        );
        if (salesResponse.statusCode == 200) {
          salesSuccess = true;
          debugPrint("ApiService: Sales endpoint test passed");
        }
      } catch (e) {
        debugPrint("ApiService: Sales endpoint test failed: $e");
      }

      try {
        final inventoryResponse = await getWithAuth('/inventory/');
        if (inventoryResponse.statusCode == 200) {
          inventorySuccess = true;
          debugPrint("ApiService: Inventory endpoint test passed");
        }
      } catch (e) {
        debugPrint("ApiService: Inventory endpoint test failed: $e");
      }

      // Test the full data fetching and caching process
      if (companyDetailsSuccess || salesSuccess || inventorySuccess) {
        await fetchAndCacheAllData();
        debugPrint("ApiService: Full data fetching and caching test completed");
        return true;
      } else {
        debugPrint("ApiService: Test failed - all endpoint tests failed");
        return false;
      }
    } catch (e) {
      debugPrint("ApiService: Data fetching and caching test failed with exception: $e");
      return false;
    }
  }
}
