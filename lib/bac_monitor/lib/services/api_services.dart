import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../controllers/mon_operator_controller.dart';
import '../controllers/mon_sync_controller.dart';
import '../../../shared/database/unified_db_helper.dart';

class MonitorApiService extends GetxService {
  static const String _baseUrl = 'http://52.30.142.12:8080/rest';
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  final _dbHelper = UnifiedDatabaseHelper.instance;
 String? _cachedToken;
  String? cachedCompanyId;
  bool _isInitialized = false;

  Future<void>? _initializationFuture;

  Future<String?> getStoredToken() async {
    if (_cachedToken != null) {
      return _cachedToken;
    }

    _cachedToken = await secureStorage.read(key: "access_token");
    print('DEBUG: MonitorApiService.getStoredToken() retrieved and cached token');
    return _cachedToken;
  }

  Future<void> storeToken(String token) async {
    await secureStorage.write(key: 'access_token', value: token);
    _cachedToken = token; 
    print('DEBUG: MonitorApiService.storeToken() stored token');
  }

  Future<String?> getStoredCode() async {
    return await secureStorage.read(key: 'persistent_code');
  }

  Future<void> storeCode(String code) async {
    print('DEBUG: MonitorApiService.storeCode() called with code: $code');
    await secureStorage.write(key: 'persistent_code', value: code);
    final savedCode = await secureStorage.read(key: 'persistent_code');
    print('DEBUG: MonitorApiService.storeCode() verified saved code: $savedCode');
  }

  Future<void> storeUserData(Map<String, dynamic> data) async {
    await secureStorage.write(key: 'user_data', value: jsonEncode(data));
    
    // Also store user role separately for easier access
    if (data.containsKey('roles') && data['roles'] is List && data['roles'].isNotEmpty) {
      final userRole = data['roles'].first.toString();
      await secureStorage.write(key: 'user_role', value: userRole);
    }
  }

  Future<Map<String, dynamic>?> getStoredUserData() async {
    final userDataString = await secureStorage.read(key: 'user_data');
    return userDataString != null ? jsonDecode(userDataString) : null;
  }

  Future<String?> getStoredUserRole() async {
    return await secureStorage.read(key: 'user_role');
  }

  Future<void> storeUserRole(String role) async {
    await secureStorage.write(key: 'user_role', value: role);
  }

  Future<void> storeLastSyncTimestamp(int timestamp) async {
    await secureStorage.write(key: 'last_sync_timestamp', value: timestamp.toString());
  }

  Future<int?> getStoredLastSyncTimestamp() async {
    final timestampString = await secureStorage.read(key: 'last_sync_timestamp');
    return timestampString != null ? int.parse(timestampString) : null;
  }

  Future<void> storeCompanyId(String companyId) async {
    await secureStorage.write(key: 'company_id', value: companyId);
    cachedCompanyId = companyId; // Update cache
  }

  Future<String?> getStoredCompanyId() async {
    // Return cached company ID if available
    if (cachedCompanyId != null) {
      return cachedCompanyId;
    }

    // Otherwise fetch and cache
    cachedCompanyId = await secureStorage.read(key: 'company_id');
    return cachedCompanyId;
  }

  // Save server credentials
  Future<void> saveServerCredentials(String username, String password) async {
    await secureStorage.write(key: 'server_username', value: username);
    await secureStorage.write(key: 'server_password', value: password);
  }

  // Get stored server credentials
  Future<Map<String, String?>> getServerCredentials() async {
    final username = await secureStorage.read(key: 'server_username');
    final password = await secureStorage.read(key: 'server_password');
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

      // Try to get from cache/storage first
      final cachedId = await getStoredCompanyId();
      if (cachedId != null && cachedId.isNotEmpty && cachedId != 'default_offline_company') {
        print('DEBUG: MonitorApiService._performInitialization() - Using cached company ID: $cachedId');

        // Check if database is already open for this company
        if (_dbHelper.isDatabaseOpen && _dbHelper.currentCompanyId == cachedId) {
          print('DEBUG: MonitorApiService._performInitialization() - Database already open for company: $cachedId');
          cachedCompanyId = cachedId;
          _isInitialized = true;
          return;
        }

        // Switch to company database (without fetching data - caller will handle that)
        await switchCompany(cachedId, fetchData: false);
        return;
      }

      // If not cached, fetch from API
      print('DEBUG: MonitorApiService._performInitialization() - No cached company ID, fetching from API');
      final companyId = await _fetchCompanyIdOnce();
      print('DEBUG: MonitorApiService._performInitialization() - Company ID fetched: $companyId');

      // Switch to the company's database if we have a valid company ID
      if (companyId.isNotEmpty && companyId != 'default_offline_company') {
        await switchCompany(companyId, fetchData: false);
      }

    } catch (e) {
      print('ERROR: MonitorApiService._performInitialization() - Failed to initialize company ID: $e');
      _isInitialized = false;
      rethrow;
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
    print('DEBUG: MonitorApiService.logout() - Starting logout');

    // Stop sync controller if registered
    try {
      if (Get.isRegistered<MonSyncController>()) {
        Get.find<MonSyncController>().onClose();
        await Get.delete<MonSyncController>(force: true);
      }
    } catch (e) {
      print('DEBUG: MonitorApiService.logout() - Error stopping sync controller: $e');
    }

    // Close database instance on logout
    await _dbHelper.close();
    print('DEBUG: MonitorApiService.logout() - Database closed');

    // Clear all secure storage keys
    await secureStorage.delete(key: 'access_token');
    await secureStorage.delete(key: 'user_data');
    await secureStorage.delete(key: 'user_role');
    await secureStorage.delete(key: 'persistent_code');
    await secureStorage.delete(key: 'last_sync_timestamp');
    await secureStorage.delete(key: 'company_id');
    await secureStorage.delete(key: 'initial_sync_completed');

    // Clear all cached values - IMPORTANT: must be done AFTER storage is cleared
    _cachedToken = null;
    cachedCompanyId = null;
    _isInitialized = false;
    _initializationFuture = null;

    print('DEBUG: MonitorApiService.logout() - Logout completed, all state cleared');
  }

  /// Switch to a different company
  /// This will update the stored company ID and switch the database
  /// Set fetchData to false to skip data fetching (useful when you'll fetch separately)
  Future<void> switchCompany(String newCompanyId, {bool fetchData = true}) async {
    try {
      print('DEBUG: MonitorApiService.switchCompany() - Switching to company: $newCompanyId (current: $cachedCompanyId)');

      // Check if we're already on this company
      if (cachedCompanyId == newCompanyId && _dbHelper.isDatabaseOpen && _dbHelper.currentCompanyId == newCompanyId) {
        print('DEBUG: MonitorApiService.switchCompany() - Already on company $newCompanyId, skipping');
        return;
      }

      // Store the new company ID and update cache
      await storeCompanyId(newCompanyId);
      cachedCompanyId = newCompanyId;

      // Switch to the new company's database
      await _dbHelper.switchCompany(newCompanyId);

      // Mark as initialized since we now have a valid company
      _isInitialized = true;

      print('DEBUG: MonitorApiService.switchCompany() - Successfully switched to company: $newCompanyId');

      if (fetchData) {
        await clearInitialSyncFlag();
        await fetchAndCacheAllData();
      }
    } catch (e) {
      print('ERROR: MonitorApiService.switchCompany() - Failed to switch company: $e');
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

      final db = _dbHelper.database;
      debugPrint("ApiService: Database connection established, starting transactions");

      // Check if we have data to insert
      bool hasDataToInsert = companyDetailsData.isNotEmpty ||
                            salesData.isNotEmpty ||
                            inventoryData.isNotEmpty ||
                            servicePointsData.isNotEmpty;

      // TRANSACTION 1: Clear old data and insert new data
      await db.transaction((txn) async {
        if (hasDataToInsert) {
          debugPrint("ApiService: Clearing old data before inserting fresh data");
          await txn.delete('mon_service_points');
          await txn.delete('company_details');
          await txn.delete('mon_sales');
        }

        // Use chunked batch inserts for better performance (reduces GC pressure)
        if (inventoryData.isNotEmpty) {
          debugPrint("ApiService: Batch inserting ${inventoryData.length} inventory items in chunks");
          const chunkSize = 500;
          for (var i = 0; i < inventoryData.length; i += chunkSize) {
            final end = (i + chunkSize < inventoryData.length) ? i + chunkSize : inventoryData.length;
            final chunk = inventoryData.sublist(i, end);
            await _dbHelper.insertMonInventoryItemsBatch(chunk, db: txn);
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

        // Use batch insert for service points
        if (servicePointsData.isNotEmpty) {
          debugPrint("ApiService: Batch inserting ${servicePointsData.length} service points");
          await _dbHelper.insertMonServicePointsBatch(servicePointsData, db: txn);
        } else {
          debugPrint("ApiService: No service points data available, skipping insertion");
        }

        // Use chunked batch insert for sales to reduce memory pressure
        if (salesData.isNotEmpty) {
          debugPrint("ApiService: Batch inserting ${salesData.length} sales records in chunks");
          const chunkSize = 500;
          for (var i = 0; i < salesData.length; i += chunkSize) {
            final end = (i + chunkSize < salesData.length) ? i + chunkSize : salesData.length;
            final chunk = salesData.sublist(i, end);
            await _dbHelper.insertMonSalesBatch(chunk, db: txn);
            debugPrint("ApiService: Inserted sales chunk ${(i ~/ chunkSize) + 1}/${(salesData.length / chunkSize).ceil()} (${chunk.length} records)");
          }
        }
      });

      // TRANSACTION 2: Update sales with salesperson/payment info (uses salesId index)
      if (salesDetailsData.isNotEmpty) {
        debugPrint("ApiService: Starting update transaction for ${salesDetailsData.length} sales details");
        await db.transaction((txn) async {
          // Reduced chunk size for updates (200 instead of 500) to reduce lock contention
          const chunkSize = 200;
          for (var i = 0; i < salesDetailsData.length; i += chunkSize) {
            final end = (i + chunkSize < salesDetailsData.length) ? i + chunkSize : salesDetailsData.length;
            final chunk = salesDetailsData.sublist(i, end);
            final updateBatch = txn.batch();
            for (final detail in chunk) {
              if (detail['id'] != null) {
                updateBatch.update(
                  'mon_sales',
                  {
                    'salesperson': detail['salesperson'],
                    'paymentmode': detail['paymentmode'],
                  },
                  where: 'salesId = ?',
                  whereArgs: [detail['id']],
                );
              }
            }
            await updateBatch.commit(noResult: true);
          }
          debugPrint("ApiService: Completed sales details update");
        });
      }

      // TRANSACTION 3: Map sales to service points
      if (hasDataToInsert) {
        await db.transaction((txn) async {
          await _dbHelper.mapMonSalesToServicePoints(db: txn);
          debugPrint("ApiService: Completed mapping sales to service points");
        });
      }

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

      // Early return if no sales data - skip all database operations
      if (salesData.isEmpty) {
        debugPrint("ApiService: No new sales to sync, skipping database operations.");
        await storeLastSyncTimestamp(now.millisecondsSinceEpoch);
        return;
      }

      // Only fetch sales details if we have sales data to process
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

      final db = _dbHelper.database;

      final startOfDayToClear = DateTime(
        lastSyncDate.year,
        lastSyncDate.month,
        lastSyncDate.day,
      );
      final startOfDayMillis = startOfDayToClear.millisecondsSinceEpoch;

      debugPrint(
        "ApiService: Deleting local sales from ${startOfDayToClear.toIso8601String()} onwards before inserting ${salesData.length} new records.",
      );

      // TRANSACTION 1: Delete old and insert new sales
      await db.transaction((txn) async {
        await txn.delete(
          'mon_sales',
          where: 'transactiondate >= ?',
          whereArgs: [startOfDayMillis],
        );

        // Use batch insert for better performance
        await _dbHelper.insertMonSalesBatch(salesData, db: txn);
      });

      // TRANSACTION 2: Update with salesperson and payment info (uses salesId index)
      if (salesDetailsData.isNotEmpty) {
        await db.transaction((txn) async {
          // Reduced chunk size for updates (200 instead of all at once)
          const chunkSize = 200;
          for (var i = 0; i < salesDetailsData.length; i += chunkSize) {
            final end = (i + chunkSize < salesDetailsData.length) ? i + chunkSize : salesDetailsData.length;
            final chunk = salesDetailsData.sublist(i, end);
            final updateBatch = txn.batch();
            for (final detail in chunk) {
              if (detail['id'] != null) {
                updateBatch.update(
                  'mon_sales',
                  {
                    'salesperson': detail['salesperson'],
                    'paymentmode': detail['paymentmode'],
                  },
                  where: 'salesId = ?',
                  whereArgs: [detail['id']],
                );
              }
            }
            await updateBatch.commit(noResult: true);
          }
        });
      }

      // TRANSACTION 3: Map sales to service points
      await db.transaction((txn) async {
        await _dbHelper.mapMonSalesToServicePoints(db: txn);
      });

      debugPrint(
        "ApiService: Successfully synced and replaced ${salesData.length} sales records for the specified period.",
      );

      await storeLastSyncTimestamp(now.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("ApiService: Error during recent sales sync: $e");
    }
  }

  Future<http.Response> getWithAuth(String endpoint, {Duration? timeout}) async {
    final token = await getStoredToken();

    if (token == null) {
      print('ERROR: MonitorApiService.getWithAuth() - Authentication token not found for GET request.');
      throw Exception('Authentication token not found for GET request.');
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse('$_baseUrl$endpoint'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      final streamedResponse = await client.send(request).timeout(
        timeout ?? const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Request timeout for $endpoint');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint("ApiService: Successfully fetched data from $endpoint");
        return response;
      } else {
        _handleResponse(response);
        throw Exception(
          'Failed to load data from $endpoint: ${response.statusCode}',
        );
      }
    } finally {
      client.close();
    }
  }

  Future<void> setInitialSyncCompleted() async {
    await secureStorage.write(key: 'initial_sync_completed', value: 'true');
  }

  Future<bool> isInitialSyncCompleted() async {
    final value = await secureStorage.read(key: 'initial_sync_completed');
    return value == 'true';
  }

  Future<void> clearInitialSyncFlag() async {
    await secureStorage.delete(key: 'initial_sync_completed');
  }

  // ==================== BATCHED MONTHLY SYNC METHODS ====================

  /// Track the oldest month that has been synced
  Future<void> storeOldestSyncedMonth(String yearMonth) async {
    await secureStorage.write(key: 'oldest_synced_month', value: yearMonth);
  }

  Future<String?> getOldestSyncedMonth() async {
    return await secureStorage.read(key: 'oldest_synced_month');
  }

  /// Track if background sync is complete (all historical data fetched)
  Future<void> setFullHistorySyncCompleted() async {
    await secureStorage.write(key: 'full_history_sync_completed', value: 'true');
  }

  Future<bool> isFullHistorySyncCompleted() async {
    final value = await secureStorage.read(key: 'full_history_sync_completed');
    return value == 'true';
  }

  Future<void> clearFullHistorySyncFlag() async {
    await secureStorage.delete(key: 'full_history_sync_completed');
    await secureStorage.delete(key: 'oldest_synced_month');
  }

  /// Generate weekly date ranges within a month
  List<Map<String, DateTime>> _generateWeeklyRanges(DateTime monthStart, DateTime monthEnd) {
    final ranges = <Map<String, DateTime>>[];
    var current = monthStart;

    while (current.isBefore(monthEnd) || current.isAtSameMomentAs(monthEnd)) {
      final weekEnd = current.add(const Duration(days: 6));
      ranges.add({
        'start': current,
        'end': weekEnd.isAfter(monthEnd) ? monthEnd : weekEnd,
      });
      current = weekEnd.add(const Duration(days: 1));
    }

    return ranges;
  }

  /// Fetch and insert sales for a specific date range (internal helper)
  /// Returns the number of records fetched, or throws on failure
  Future<int> _fetchAndInsertSalesForRange(DateTime rangeStart, DateTime rangeEnd) async {
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final startDate = dateFormatter.format(rangeStart);
    final endDate = dateFormatter.format(rangeEnd);

    debugPrint("ApiService: Fetching sales for $startDate to $endDate");

    final response = await getWithAuth(
      '/sales/reports/transaction/detail?startDate=$startDate&endDate=$endDate',
      timeout: const Duration(minutes: 3),
    );

    final List<dynamic> salesData = json.decode(response.body);

    if (salesData.isEmpty) {
      debugPrint("ApiService: No sales found for $startDate to $endDate");
      return 0;
    }

    // Also fetch sales details for salesperson info
    List<dynamic> salesDetailsData = [];
    try {
      final salesDetailsRes = await getWithAuth(
        '/sales/?pagecount=0&pagesize=5000&startdate=$startDate&enddate=$endDate',
        timeout: const Duration(minutes: 2),
      );
      salesDetailsData = json.decode(salesDetailsRes.body);
    } catch (e) {
      debugPrint("ApiService: Failed to fetch sales details for $startDate to $endDate -> $e");
    }

    final db = _dbHelper.database;

    // TRANSACTION 1: Insert sales data
    await db.transaction((txn) async {
      // Use batch insert for better performance
      await _dbHelper.insertMonSalesBatch(salesData, db: txn);
    });

    // TRANSACTION 2: Update with salesperson and payment info (uses salesId index)
    if (salesDetailsData.isNotEmpty) {
      await db.transaction((txn) async {
        // Reduced chunk size for updates
        const chunkSize = 200;
        for (var i = 0; i < salesDetailsData.length; i += chunkSize) {
          final end = (i + chunkSize < salesDetailsData.length) ? i + chunkSize : salesDetailsData.length;
          final chunk = salesDetailsData.sublist(i, end);
          final updateBatch = txn.batch();
          for (final detail in chunk) {
            if (detail['id'] != null) {
              updateBatch.update(
                'mon_sales',
                {
                  'salesperson': detail['salesperson'],
                  'paymentmode': detail['paymentmode'],
                },
                where: 'salesId = ?',
                whereArgs: [detail['id']],
              );
            }
          }
          await updateBatch.commit(noResult: true);
        }
      });
    }

    // TRANSACTION 3: Map sales to service points
    await db.transaction((txn) async {
      await _dbHelper.mapMonSalesToServicePoints(db: txn);
    });

    debugPrint("ApiService: Inserted ${salesData.length} sales for $startDate to $endDate");
    return salesData.length;
  }

  /// Fetch sales for a specific month and insert into database
  /// Returns the number of records fetched, or -1 if failed
  /// Automatically falls back to weekly fetches if monthly fetch fails
  Future<int> _fetchAndInsertSalesForMonth(DateTime monthStart, DateTime monthEnd, {bool clearExisting = false}) async {
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final startDate = dateFormatter.format(monthStart);
    final endDate = dateFormatter.format(monthEnd);

    // Clear existing data for this month if requested
    if (clearExisting) {
      final db = _dbHelper.database;
      final startMillis = monthStart.millisecondsSinceEpoch;
      final endMillis = monthEnd.add(const Duration(days: 1)).millisecondsSinceEpoch;
      await db.delete(
        'mon_sales',
        where: 'transactiondate >= ? AND transactiondate < ?',
        whereArgs: [startMillis, endMillis],
      );
    }

    // First, try to fetch the entire month at once
    try {
      debugPrint("ApiService: Attempting monthly fetch for $startDate to $endDate");
      return await _fetchAndInsertSalesForRange(monthStart, monthEnd);
    } catch (e) {
      // Check if it's a connection/timeout error that warrants retry with smaller batches
      final errorStr = e.toString().toLowerCase();
      final isConnectionError = errorStr.contains('connection closed') ||
          errorStr.contains('timeout') ||
          errorStr.contains('failed to parse http') ||
          errorStr.contains('clientexception');

      if (!isConnectionError) {
        debugPrint("ApiService: Non-recoverable error for $startDate to $endDate -> $e");
        return -1;
      }

      debugPrint("ApiService: Monthly fetch failed for $startDate to $endDate, falling back to weekly batches -> $e");
    }

    // Fall back to weekly batches
    final weeklyRanges = _generateWeeklyRanges(monthStart, monthEnd);
    debugPrint("ApiService: Fetching ${weeklyRanges.length} weeks for $startDate to $endDate");

    int totalRecords = 0;
    int failedWeeks = 0;

    for (final range in weeklyRanges) {
      try {
        final records = await _fetchAndInsertSalesForRange(range['start']!, range['end']!);
        totalRecords += records;
        // Small delay between weekly requests
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        failedWeeks++;
        debugPrint("ApiService: Failed to fetch week ${dateFormatter.format(range['start']!)} to ${dateFormatter.format(range['end']!)} -> $e");
      }
    }

    if (failedWeeks == weeklyRanges.length) {
      debugPrint("ApiService: All weekly batches failed for $startDate to $endDate");
      return -1;
    }

    debugPrint("ApiService: Completed weekly fetch for $startDate to $endDate - $totalRecords records, $failedWeeks failed weeks");
    return totalRecords;
  }

  /// Fetch essential data (company details, service points, inventory) without sales
  Future<void> _fetchEssentialData() async {
    try {
      debugPrint("ApiService: Fetching essential data (company, service points, inventory)...");

      http.Response? servicePointsRes;
      http.Response? companyDetailsRes;
      http.Response? inventoryRes;

      // Fetch company details
      try {
        companyDetailsRes = await getWithAuth('/company/details');
        debugPrint("ApiService: Successfully fetched company details");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch company details -> $e");
      }

      // Fetch service points
      try {
        servicePointsRes = await getWithAuth('/servicepoints');
        debugPrint("ApiService: Successfully fetched service points");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch service points -> $e");
      }

      // Fetch inventory
      try {
        inventoryRes = await getWithAuth('/inventory/');
        debugPrint("ApiService: Successfully fetched inventory");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch inventory -> $e");
      }

      // Parse responses
      Map<String, dynamic> companyDetailsData = {};
      if (companyDetailsRes != null && companyDetailsRes.body.isNotEmpty) {
        try {
          companyDetailsData = json.decode(companyDetailsRes.body);
        } catch (e) {
          debugPrint("ApiService: Failed to parse company details -> $e");
        }
      }

      List<dynamic> servicePointsData = [];
      if (servicePointsRes != null && servicePointsRes.body.isNotEmpty) {
        try {
          servicePointsData = json.decode(servicePointsRes.body);
        } catch (e) {
          debugPrint("ApiService: Failed to parse service points -> $e");
        }
      }

      List<dynamic> inventoryData = [];
      if (inventoryRes != null && inventoryRes.body.isNotEmpty) {
        try {
          inventoryData = json.decode(inventoryRes.body);
        } catch (e) {
          debugPrint("ApiService: Failed to parse inventory -> $e");
        }
      }

      // Insert into database
      final db = _dbHelper.database;
      await db.transaction((txn) async {
        if (companyDetailsData.isNotEmpty) {
          await txn.delete('company_details');
          await _dbHelper.insertCompanyDetails(companyDetailsData, db: txn);
        }

        if (servicePointsData.isNotEmpty) {
          await txn.delete('mon_service_points');
          for (final sp in servicePointsData) {
            await _dbHelper.insertMonServicePoint(sp, db: txn);
          }
        }

        if (inventoryData.isNotEmpty) {
          for (final item in inventoryData) {
            await _dbHelper.insertMonInventoryItem(item, db: txn);
          }
        }
      });

      if (Get.isRegistered<MonOperatorController>()) {
        await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();
      }

      debugPrint("ApiService: Essential data fetched and stored successfully");
    } catch (e) {
      debugPrint("ApiService: Failed to fetch essential data -> $e");
      rethrow;
    }
  }

  /// Generate list of month ranges from start date to end date
  List<Map<String, DateTime>> _generateMonthRanges(DateTime startDate, DateTime endDate) {
    final ranges = <Map<String, DateTime>>[];
    var current = DateTime(endDate.year, endDate.month, 1);
    final earliest = DateTime(startDate.year, startDate.month, 1);

    while (current.isAfter(earliest) || current.isAtSameMomentAs(earliest)) {
      final monthStart = current;
      final monthEnd = DateTime(current.year, current.month + 1, 0); // Last day of month

      ranges.add({
        'start': monthStart,
        'end': monthEnd.isAfter(endDate) ? endDate : monthEnd,
      });

      // Move to previous month
      current = DateTime(current.year, current.month - 1, 1);
    }

    return ranges;
  }

  /// Initial sync: Fetch essential data + last 12 months of sales
  /// Returns true if successful, false otherwise
  /// Calls onProgress callback with (currentMonth, totalMonths, recordsFetched)
  Future<bool> fetchInitialDataWithProgress({
    Function(int currentMonth, int totalMonths, int recordsFetched)? onProgress,
  }) async {
    try {
      debugPrint("ApiService: Starting initial data fetch (last 12 months)...");

      // First, fetch essential data
      await _fetchEssentialData();

      // Clear existing sales before initial sync
      final db = _dbHelper.database;
      await db.delete('mon_sales');

      // Generate month ranges for last 12 months
      final now = DateTime.now();
      final twelveMonthsAgo = DateTime(now.year - 1, now.month, 1);
      final monthRanges = _generateMonthRanges(twelveMonthsAgo, now);

      debugPrint("ApiService: Will fetch ${monthRanges.length} months of data");

      int totalRecords = 0;
      String? oldestMonth;

      for (var i = 0; i < monthRanges.length; i++) {
        final range = monthRanges[i];
        final recordsFetched = await _fetchAndInsertSalesForMonth(
          range['start']!,
          range['end']!,
        );

        if (recordsFetched >= 0) {
          totalRecords += recordsFetched;
          oldestMonth = DateFormat('yyyy-MM').format(range['start']!);
        }

        onProgress?.call(i + 1, monthRanges.length, totalRecords);

        // Small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Store the oldest synced month
      if (oldestMonth != null) {
        await storeOldestSyncedMonth(oldestMonth);
      }

      await storeLastSyncTimestamp(now.millisecondsSinceEpoch);
      await setInitialSyncCompleted();

      debugPrint("ApiService: Initial sync completed. Total records: $totalRecords");
      return true;
    } catch (e) {
      debugPrint("ApiService: Initial data fetch failed -> $e");
      return false;
    }
  }

  /// Background sync: Continue fetching older data month by month
  /// Starts from the oldest synced month and goes back to 2023-09-01
  /// Calls onProgress callback with (monthsCompleted, totalMonths, recordsFetched)
  Future<void> fetchOlderSalesInBackground({
    Function(int monthsCompleted, int totalMonths, int recordsFetched)? onProgress,
    Function()? onComplete,
  }) async {
    try {
      // Check if full history is already synced
      if (await isFullHistorySyncCompleted()) {
        debugPrint("ApiService: Full history already synced, skipping background fetch");
        onComplete?.call();
        return;
      }

      // Get the oldest synced month
      final oldestSyncedStr = await getOldestSyncedMonth();
      if (oldestSyncedStr == null) {
        debugPrint("ApiService: No oldest synced month found, skipping background fetch");
        onComplete?.call();
        return;
      }

      final parts = oldestSyncedStr.split('-');
      final oldestSynced = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);

      // Define the earliest date to sync (2023-09-01)
      final earliestDate = DateTime(2023, 9, 1);

      // If we've already synced back to the earliest date, mark as complete
      if (oldestSynced.isBefore(earliestDate) || oldestSynced.isAtSameMomentAs(earliestDate)) {
        await setFullHistorySyncCompleted();
        debugPrint("ApiService: Full history sync already complete");
        onComplete?.call();
        return;
      }

      // Generate month ranges from oldest synced to earliest date (going backwards)
      final previousMonth = DateTime(oldestSynced.year, oldestSynced.month - 1, 1);
      final monthRanges = _generateMonthRanges(earliestDate, previousMonth);

      debugPrint("ApiService: Background sync will fetch ${monthRanges.length} months of older data");

      int totalRecords = 0;
      String? newOldestMonth;

      for (var i = 0; i < monthRanges.length; i++) {
        final range = monthRanges[i];
        final recordsFetched = await _fetchAndInsertSalesForMonth(
          range['start']!,
          range['end']!,
        );

        if (recordsFetched >= 0) {
          totalRecords += recordsFetched;
          newOldestMonth = DateFormat('yyyy-MM').format(range['start']!);
          // Update oldest synced month as we go
          await storeOldestSyncedMonth(newOldestMonth);
        }

        onProgress?.call(i + 1, monthRanges.length, totalRecords);

        // Delay to avoid overwhelming the server and keep UI responsive
        await Future.delayed(const Duration(milliseconds: 200));
      }

      await setFullHistorySyncCompleted();
      debugPrint("ApiService: Background sync completed. Total records: $totalRecords");
      onComplete?.call();
    } catch (e) {
      debugPrint("ApiService: Background sync failed -> $e");
    }
  }

  /// Reload all data from 2023-09-01 to now in monthly batches
  /// This clears existing sales and re-fetches everything
  /// Calls onProgress callback with (monthsCompleted, totalMonths, recordsFetched)
  Future<bool> reloadAllDataInBatches({
    Function(int monthsCompleted, int totalMonths, int recordsFetched)? onProgress,
  }) async {
    try {
      debugPrint("ApiService: Starting full data reload from 2023-09-01...");

      // First, fetch essential data
      await _fetchEssentialData();

      // Clear all existing sales
      final db = _dbHelper.database;
      await db.delete('mon_sales');

      // Clear sync tracking
      await clearFullHistorySyncFlag();

      // Generate month ranges from 2023-09-01 to now
      final now = DateTime.now();
      final earliestDate = DateTime(2023, 9, 1);
      final monthRanges = _generateMonthRanges(earliestDate, now);

      debugPrint("ApiService: Will reload ${monthRanges.length} months of data");

      int totalRecords = 0;
      int failedMonths = 0;
      String? oldestMonth;

      for (var i = 0; i < monthRanges.length; i++) {
        final range = monthRanges[i];
        final recordsFetched = await _fetchAndInsertSalesForMonth(
          range['start']!,
          range['end']!,
        );

        if (recordsFetched >= 0) {
          totalRecords += recordsFetched;
          oldestMonth = DateFormat('yyyy-MM').format(range['start']!);
        } else {
          failedMonths++;
        }

        onProgress?.call(i + 1, monthRanges.length, totalRecords);

        // Small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Store sync state
      if (oldestMonth != null) {
        await storeOldestSyncedMonth(oldestMonth);
      }
      await storeLastSyncTimestamp(now.millisecondsSinceEpoch);
      await setInitialSyncCompleted();
      await setFullHistorySyncCompleted();

      debugPrint("ApiService: Full reload completed. Total records: $totalRecords, Failed months: $failedMonths");
      return failedMonths == 0;
    } catch (e) {
      debugPrint("ApiService: Full data reload failed -> $e");
      return false;
    }
  }

}