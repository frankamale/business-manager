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

  /// Check if we already have sales data in the database
  Future<bool> _hasSalesInDb() async {
    try {
      final db = _dbHelper.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM mon_sales');
      final count = result.first['count'] as int? ?? 0;
      debugPrint("ApiService: Found $count sales records in database");
      return count > 0;
    } catch (e) {
      debugPrint("ApiService: Error checking sales count -> $e");
      return false;
    }
  }

  Future<void> fetchAndCacheAllData() async {
    final now = DateTime.now();
    final dateFormatter = DateFormat('yyyy-MM-dd');

    try {
      debugPrint("ApiService: Starting to fetch all data...");

      // Check if we already have sales in the database
      final hasSales = await _hasSalesInDb();
      if (hasSales) {
        debugPrint("ApiService: Sales already exist in database, skipping fetch");
        await setInitialSyncCompleted();

        if (Get.isRegistered<MonOperatorController>()) {
          await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();
        }
        return;
      }

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
        servicePointsRes = null;
      }

      try {
        companyDetailsRes = await getWithAuth('/company/details');
        debugPrint("ApiService: Successfully fetched company details");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /company/details -> $e");
        companyDetailsRes = null;
      }

      try {
        final endDate = dateFormatter.format(now);
        debugPrint("ApiService: Fetching sales from 2023-09-01 to $endDate");
        salesRes = await getWithAuth(
          '/sales/reports/transaction/detail?startDate=2023-09-01&endDate=$endDate',
        );
        debugPrint("ApiService: Successfully fetched sales reports");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch sales -> $e");
        salesRes = null;
      }

      try {
        salesDetailsRes = await getWithAuth('/sales/?pagecount=0&pagesize=5000');
        debugPrint("ApiService: Successfully fetched sales details");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /sales/ -> $e");
        salesDetailsRes = null;
      }

      try {
        inventoryRes = await getWithAuth('/inventory/');
        debugPrint("ApiService: Successfully fetched inventory");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /inventory -> $e");
        inventoryRes = null;
      }

      // Parse responses
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
        } catch (e) {
          debugPrint("ApiService: Failed to parse company details JSON -> $e");
        }
      }

      List<dynamic> salesData = [];
      if (salesRes != null && salesRes.body.isNotEmpty) {
        try {
          salesData = json.decode(salesRes.body);
          debugPrint("ApiService: Parsed ${salesData.length} sales records");
        } catch (e) {
          debugPrint("ApiService: Failed to parse sales JSON -> $e");
        }
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
          debugPrint("ApiService: Parsed ${inventoryData.length} inventory items");
        } catch (e) {
          debugPrint("ApiService: Failed to parse inventory JSON -> $e");
        }
      }

      final db = _dbHelper.database;

      // Clear and insert data
      if (servicePointsData.isNotEmpty) {
        await _dbHelper.deleteAllMonServicePoints();
        debugPrint("ApiService: Inserting ${servicePointsData.length} service points");
        for (final sp in servicePointsData) {
          await _dbHelper.insertMonServicePoint(sp);
        }
      }

      if (companyDetailsData.isNotEmpty) {
        await _dbHelper.deleteAllCompanyDetails();
        await _dbHelper.insertCompanyDetails(companyDetailsData);
      }

      if (inventoryData.isNotEmpty) {
        debugPrint("ApiService: Inserting ${inventoryData.length} inventory items");
        for (final item in inventoryData) {
          await _dbHelper.insertMonInventoryItem(item);
        }
      }

      if (salesData.isNotEmpty) {
        await _dbHelper.deleteAllMonSales();
        debugPrint("ApiService: Inserting ${salesData.length} sales records");
        for (final sale in salesData) {
          await _dbHelper.insertMonSale(sale);
        }
      }

      // Update sales with salesperson/payment info
      if (salesDetailsData.isNotEmpty) {
        debugPrint("ApiService: Updating sales with salesperson details");
        for (final detail in salesDetailsData) {
          if (detail['id'] != null) {
            await db.update(
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
      }

      // Map sales to service points
      if (salesData.isNotEmpty) {
        await _dbHelper.mapMonSalesToServicePoints();
        debugPrint("ApiService: Completed mapping sales to service points");
      }

      await storeLastSyncTimestamp(now.millisecondsSinceEpoch);
      await setInitialSyncCompleted();
      debugPrint("ApiService: All data fetched and cached successfully");

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

      // Delete old sales
      await db.delete(
        'mon_sales',
        where: 'transactiondate >= ?',
        whereArgs: [startOfDayMillis],
      );

      // Insert new sales
      for (final sale in salesData) {
        await _dbHelper.insertMonSale(sale);
      }

      // Update with salesperson and payment info
      if (salesDetailsData.isNotEmpty) {
        for (final detail in salesDetailsData) {
          if (detail['id'] != null) {
            await db.update(
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
      }

      // Map sales to service points
      await _dbHelper.mapMonSalesToServicePoints();

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

}