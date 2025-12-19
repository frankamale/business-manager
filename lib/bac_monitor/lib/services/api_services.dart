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
 String? _cachedToken;
  String? cachedCompanyId;
  bool _isInitialized = false;

  Future<void>? _initializationFuture;

  Future<String?> getStoredToken() async {
    if (_cachedToken != null) {
      return _cachedToken;
    }

    _cachedToken = await _secureStorage.read(key: "access_token");
    print('DEBUG: MonitorApiService.getStoredToken() retrieved and cached token');
    return _cachedToken;
  }

  Future<void> storeToken(String token) async {
    await _secureStorage.write(key: 'access_token', value: token);
    _cachedToken = token; 
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
    cachedCompanyId = companyId; // Update cache
  }

  Future<String?> getStoredCompanyId() async {
    // Return cached company ID if available
    if (cachedCompanyId != null) {
      return cachedCompanyId;
    }

    // Otherwise fetch and cache
    cachedCompanyId = await _secureStorage.read(key: 'company_id');
    return cachedCompanyId;
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
  /// This should be called ONCE early in the app initialization process
  /// Uses a singleton pattern to prevent multiple simultaneous calls
  Future<void> initializeCompanyId() async {
    // If already initialized, return immediately
    if (_isInitialized && cachedCompanyId != null) {
      print('DEBUG: MonitorApiService.initializeCompanyId() - Already initialized, skipping');
      return;
    }

    // If initialization is in progress, wait for it
    if (_initializationFuture != null) {
      print('DEBUG: MonitorApiService.initializeCompanyId() - Initialization in progress, waiting...');
      await _initializationFuture;
      return;
    }

    // Start initialization
    _initializationFuture = _performInitialization();
    await _initializationFuture;
    _initializationFuture = null;
  }

  Future<void> _performInitialization() async {
    try {
      print('DEBUG: MonitorApiService._performInitialization() - Starting company ID initialization');

      // Try to get from cache first
      final cachedId = await getStoredCompanyId();
      if (cachedId != null && cachedId.isNotEmpty) {
        print('DEBUG: MonitorApiService._performInitialization() - Using cached company ID: $cachedId');
        cachedCompanyId = cachedId;
        _isInitialized = true;

        // Switch to company database
        if (cachedId != 'default_offline_company') {
          try {
            await _dbHelper.switchCompany(cachedId);
            print('DEBUG: MonitorApiService._performInitialization() - Switched to company database: $cachedId');
          } catch (e) {
            print('ERROR: MonitorApiService._performInitialization() - Failed to switch company database: $e');
          }
        }
        return;
      }

      // If not cached, fetch from API
      final companyId = await _fetchCompanyIdOnce();
      print('DEBUG: MonitorApiService._performInitialization() - Company ID initialized: $companyId');

      // Switch to the company's database if we have a valid company ID
      if (companyId != null && companyId.isNotEmpty && companyId != 'default_offline_company') {
        try {
          await _dbHelper.switchCompany(companyId);
          print('DEBUG: MonitorApiService._performInitialization() - Switched to company database: $companyId');
        } catch (e) {
          print('ERROR: MonitorApiService._performInitialization() - Failed to switch company database: $e');
        }
      }

      _isInitialized = true;
    } catch (e) {
      print('ERROR: MonitorApiService._performInitialization() - Failed to initialize company ID: $e');
      _isInitialized = false;
    }
  }

  /// Fetch company ID from API (internal method, only called once)
  Future<String> _fetchCompanyIdOnce() async {
    try {
      print('DEBUG: MonitorApiService._fetchCompanyIdOnce() - Starting company ID fetch');
      final response = await getWithAuth('/company/details');
      final companyDetails = json.decode(response.body);
      print('DEBUG: MonitorApiService._fetchCompanyIdOnce() - Company details response received');

      if (companyDetails.containsKey('company')) {
        final companyId = companyDetails['company'];
        print('DEBUG: MonitorApiService._fetchCompanyIdOnce() - Found company ID: $companyId');
        await storeCompanyId(companyId.toString());
        return companyId.toString();
      } else {
        print('ERROR: MonitorApiService._fetchCompanyIdOnce() - Company ID not found in company details');
        throw Exception('Company ID not found in company details');
      }
    } catch (e) {
      print('ERROR: MonitorApiService._fetchCompanyIdOnce() - Failed to fetch company ID: $e');
      debugPrint("ApiService: Failed to fetch company ID -> $e");
      throw Exception('Failed to fetch company ID: $e');
    }
  }

  /// Get company ID - returns cached value immediately
  /// No API calls unless company ID is not available
  Future<String> ensureCompanyIdAvailable() async {
    // Return cached company ID immediately if available
    if (cachedCompanyId != null && cachedCompanyId!.isNotEmpty) {
      return cachedCompanyId!;
    }

    // Try to get from storage
    final storedCompanyId = await getStoredCompanyId();
    if (storedCompanyId != null && storedCompanyId.isNotEmpty) {
      cachedCompanyId = storedCompanyId;
      return storedCompanyId;
    }

    // If not available, this is an error - initialization should have been called
    print('ERROR: MonitorApiService.ensureCompanyIdAvailable() - Company ID not initialized!');
    throw Exception('Company ID not initialized. Call initializeCompanyId() first.');
  }

  Future<Map<String, dynamic>> post(
      String endpoint,
      Map<String, dynamic> data, {
        bool useToken = true,
      }) async {
    try {
      print('DEBUG: MonitorApiService.post() called for endpoint: $endpoint');
      final headers = {'Content-Type': 'application/json'};
      if (useToken) {
        final token = await getStoredToken();
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

    // Clear cache
    _cachedToken = null;
    cachedCompanyId = null;
    _isInitialized = false;
  }

  /// Switch to a different company
  /// This will update the stored company ID and switch the database
  Future<void> switchCompany(String newCompanyId) async {
    try {
      // Store the new company ID and update cache
      await storeCompanyId(newCompanyId);
      cachedCompanyId = newCompanyId;

      // Switch to the new company's database
      await _dbHelper.switchCompany(newCompanyId);

      debugPrint("ApiService: Successfully switched to company: $newCompanyId");

      await clearInitialSyncFlag();
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
    await storeLastSyncTimestamp(now.millisecondsSinceEpoch);
    await setInitialSyncCompleted();

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
    final token = await getStoredToken();

    if (token == null) {
      print('ERROR: MonitorApiService.getWithAuth() - Authentication token not found for GET request.');
      throw Exception('Authentication token not found for GET request.');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint("ApiService: Successfully fetched data from $endpoint");
      return response;
    } else {
      _handleResponse(response);
      throw Exception(
        'Failed to load data from $endpoint: ${response.statusCode}',
      );
    }
  }

  Future<void> setInitialSyncCompleted() async {
    await _secureStorage.write(key: 'initial_sync_completed', value: 'true');
  }

  Future<bool> isInitialSyncCompleted() async {
    final value = await _secureStorage.read(key: 'initial_sync_completed');
    return value == 'true';
  }

  Future<void> clearInitialSyncFlag() async {
    await _secureStorage.delete(key: 'initial_sync_completed');
  }

}