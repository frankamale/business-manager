import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../../back_pos/services/api_services.dart';
import '../controllers/mon_operator_controller.dart';
import '../controllers/mon_sync_controller.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../../../shared/services/token_refresh_interceptor.dart';
import '../../../initialise/splashscreen.dart';

/// Top-level function for isolate-based JSON decoding
/// Must be top-level or static for compute() to work
List<dynamic> _decodeJsonList(String jsonString) {
  return json.decode(jsonString) as List<dynamic>;
}

Map<String, dynamic> _decodeJsonMap(String jsonString) {
  return json.decode(jsonString) as Map<String, dynamic>;
}

/// Parse double from various formats (int, double, String)
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

/// Extract date part from datetime string (e.g., "2026-04-02T00:00:00" -> "2026-04-02")
String _extractDate(String dateTimeStr) {
  if (dateTimeStr.isEmpty) return dateTimeStr;
  return dateTimeStr.split('T')[0].split(' ')[0];
}

class MonitorApiService extends GetxService {
  static const String _baseUrl = 'http://52.30.142.12:8080/rest';
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final _dbHelper = UnifiedDatabaseHelper.instance;
  String? _cachedToken;
  String? cachedCompanyId;
  bool _isInitialized = false;

  Future<void>? _initializationFuture;

  // Token refresh interceptor for automatic token refresh on 401 errors
  late final TokenRefreshInterceptor _tokenRefreshInterceptor;

  @override
  void onInit() {
    super.onInit();
    _tokenRefreshInterceptor = TokenRefreshInterceptor(
      baseUrl: _baseUrl,
      secureStorage: secureStorage,
    );
  }

  @override
  void onClose() {
    _tokenRefreshInterceptor.close();
    super.onClose();
  }

  Future<String?> getStoredToken() async {
    if (_cachedToken != null) {
      return _cachedToken;
    }

    _cachedToken = await secureStorage.read(key: "access_token");
    // print('DEBUG: MonitorApiService.getStoredToken() retrieved and cached token');
    return _cachedToken;
  }

  Future<void> storeToken(String token) async {
    await secureStorage.write(key: 'access_token', value: token);
    _cachedToken = token;
    // print('DEBUG: MonitorApiService.storeToken() stored token');
  }

  Future<String?> getStoredCode() async {
    return await secureStorage.read(key: 'persistent_code');
  }

  Future<void> storeCode(String code) async {
    // print('DEBUG: MonitorApiService.storeCode() called with code: $code');
    await secureStorage.write(key: 'persistent_code', value: code);
    final savedCode = await secureStorage.read(key: 'persistent_code');
    // print('DEBUG: MonitorApiService.storeCode() verified saved code: $savedCode');
  }

  Future<void> storeUserData(Map<String, dynamic> data) async {
    await secureStorage.write(key: 'user_data', value: jsonEncode(data));

    // Also store user role separately for easier access
    if (data.containsKey('roles') &&
        data['roles'] is List &&
        data['roles'].isNotEmpty) {
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
    await secureStorage.write(
      key: 'last_sync_timestamp',
      value: timestamp.toString(),
    );
  }

  Future<int?> getStoredLastSyncTimestamp() async {
    final timestampString = await secureStorage.read(
      key: 'last_sync_timestamp',
    );
    return timestampString != null ? int.parse(timestampString) : null;
  }

  Future<void> storeCompanyId(String companyId) async {
    await secureStorage.write(key: 'company_id', value: companyId);
    cachedCompanyId = companyId; // Update cache
    
    // Also store in GetStorage for offline access (survives app restarts)
    try {
      final box = GetStorage();
      await box.write(kLastCompanyIdKey, companyId);
      debugPrint('MonitorApiService: Company ID stored in GetStorage: $companyId');
    } catch (e) {
      debugPrint('MonitorApiService: Error storing company ID in GetStorage: $e');
    }
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
    return {'username': username, 'password': password};
  }

  /// Initialize company ID during app startup
  /// This should be called ONCE early in the app initialization process
  /// Uses a singleton pattern to prevent multiple simultaneous calls
  Future<void> initializeCompanyId() async {
    // If already initialized, return immediately
    if (_isInitialized && cachedCompanyId != null) {
      // print('DEBUG: MonitorApiService.initializeCompanyId() - Already initialized, skipping');
      return;
    }

    // If initialization is in progress, wait for it
    if (_initializationFuture != null) {
      // print('DEBUG: MonitorApiService.initializeCompanyId() - Initialization in progress, waiting...');
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
      // print('DEBUG: MonitorApiService._performInitialization() - Starting company ID initialization');

      // Try to get from cache/storage first
      final cachedId = await getStoredCompanyId();
      if (cachedId != null &&
          cachedId.isNotEmpty &&
          cachedId != 'default_offline_company') {
        // print('DEBUG: MonitorApiService._performInitialization() - Using cached company ID: $cachedId');

        // Check if database is already open for this company
        if (_dbHelper.isDatabaseOpen &&
            _dbHelper.currentCompanyId == cachedId) {
          // print('DEBUG: MonitorApiService._performInitialization() - Database already open for company: $cachedId');
          cachedCompanyId = cachedId;
          _isInitialized = true;
          return;
        }

        // Switch to company database (without fetching data - caller will handle that)
        await switchCompany(cachedId, fetchData: false);
        return;
      }

      // If not cached, fetch from API
      // print('DEBUG: MonitorApiService._performInitialization() - No cached company ID, fetching from API');
      final companyId = await _fetchCompanyIdOnce();
      // print('DEBUG: MonitorApiService._performInitialization() - Company ID fetched: $companyId');

      // Switch to the company's database if we have a valid company ID
      if (companyId.isNotEmpty && companyId != 'default_offline_company') {
        await switchCompany(companyId, fetchData: false);
      }
    } catch (e) {
      // print('ERROR: MonitorApiService._performInitialization() - Failed to initialize company ID: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Fetch company ID from API (internal method, only called once)
  Future<String> _fetchCompanyIdOnce() async {
    try {
      // print('DEBUG: MonitorApiService._fetchCompanyIdOnce() - Starting company ID fetch');
      final response = await getWithAuth('/company/details');
      final companyDetails = json.decode(response.body);
      // print('DEBUG: MonitorApiService._fetchCompanyIdOnce() - Company details response received');

      if (companyDetails.containsKey('company')) {
        final companyId = companyDetails['company'];
        // print('DEBUG: MonitorApiService._fetchCompanyIdOnce() - Found company ID: $companyId');
        await storeCompanyId(companyId.toString());
        return companyId.toString();
      } else {
        // print('ERROR: MonitorApiService._fetchCompanyIdOnce() - Company ID not found in company details');
        throw Exception('Company ID not found in company details');
      }
    } catch (e) {
      // print('ERROR: MonitorApiService._fetchCompanyIdOnce() - Failed to fetch company ID: $e');
      // debugPrint("ApiService: Failed to fetch company ID -> $e");
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
    // print('ERROR: MonitorApiService.ensureCompanyIdAvailable() - Company ID not initialized!');
    throw Exception(
      'Company ID not initialized. Call initializeCompanyId() first.',
    );
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool useToken = true,
  }) async {
    try {
      // print('DEBUG: MonitorApiService.post() called for endpoint: $endpoint');
      final headers = {'Content-Type': 'application/json'};
      if (useToken) {
        final token = await getStoredToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        } else {
          // print('ERROR: MonitorApiService.post() - Authentication token not found.');
          throw Exception('Authentication token not found.');
        }
      }
      // print('DEBUG: MonitorApiService.post() - Making POST request to $_baseUrl$endpoint');
      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );
      // print('DEBUG: MonitorApiService.post() - Received response with status: ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      // print('ERROR: MonitorApiService.post() - Network error: $e');
      throw Exception('Network error: $e');
    }
  }
 Future<http.Response> getWithAuth(
    String endpoint, {
    Duration? timeout,
  }) async {
    final request = http.Request('GET', Uri.parse('$_baseUrl$endpoint'));
    request.headers['Content-Type'] = 'application/json';

    final streamedResponse = await _tokenRefreshInterceptor
        .send(request)
        .timeout(
          timeout ?? const Duration(minutes: 5),
          onTimeout: () {
            throw Exception('Request timeout for $endpoint');
          },
        );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // debugPrint("ApiService: Successfully fetched data from $endpoint");
      return response;
    } else {
      _handleResponse(response);
      throw Exception(
        'Failed to load data from $endpoint: ${response.statusCode}',
      );
    }
  }

  Future<void> login(String email, String password) async {
    final response = await post('/auth/signin', {
      'username': email.trim().toLowerCase(),
      'password': password.trim(),
    }, useToken: false);

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

      // print("login success ----- authentication completed");

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
    // print('DEBUG: MonitorApiService.logout() - Starting logout');

    // Stop sync controller if registered
    try {
      if (Get.isRegistered<MonSyncController>()) {
        Get.find<MonSyncController>().onClose();
        await Get.delete<MonSyncController>(force: true);
      }
    } catch (e) {
      // print('DEBUG: MonitorApiService.logout() - Error stopping sync controller: $e');
    }

    // Close database instance on logout
    await _dbHelper.close();
    // print('DEBUG: MonitorApiService.logout() - Database closed');

    // Clear all secure storage keys
    await secureStorage.delete(key: 'access_token');
    await secureStorage.delete(key: 'user_data');
    await secureStorage.delete(key: 'user_role');
    await secureStorage.delete(key: 'persistent_code');
    await secureStorage.delete(key: 'last_sync_timestamp');
    await secureStorage.delete(key: 'company_id');
    await secureStorage.delete(key: 'initial_sync_completed');

    // Also clear company ID from GetStorage
    try {
      final box = GetStorage();
      await box.remove(kLastCompanyIdKey);
      debugPrint('MonitorApiService: Company ID cleared from GetStorage');
    } catch (e) {
      debugPrint('MonitorApiService: Error clearing company ID from GetStorage: $e');
    }

    // Clear all cached values - IMPORTANT: must be done AFTER storage is cleared
    _cachedToken = null;
    cachedCompanyId = null;
    _isInitialized = false;
    _initializationFuture = null;

    // print('DEBUG: MonitorApiService.logout() - Logout completed, all state cleared');
  }

  /// Switch to a different company
  /// This will update the stored company ID and switch the database
  /// Set fetchData to false to skip data fetching (useful when you'll fetch separately)
  Future<void> switchCompany(
    String newCompanyId, {
    bool fetchData = true,
  }) async {
    try {
      // print('DEBUG: MonitorApiService.switchCompany() - Switching to company: $newCompanyId (current: $cachedCompanyId)');

      // Check if we're already on this company
      if (cachedCompanyId == newCompanyId &&
          _dbHelper.isDatabaseOpen &&
          _dbHelper.currentCompanyId == newCompanyId) {
        // print('DEBUG: MonitorApiService.switchCompany() - Already on company $newCompanyId, skipping');
        return;
      }

      // Store the new company ID and update cache
      await storeCompanyId(newCompanyId);
      cachedCompanyId = newCompanyId;

      // Switch to the new company's database
      await _dbHelper.switchCompany(newCompanyId);

      // Mark as initialized since we now have a valid company
      _isInitialized = true;

      // print('DEBUG: MonitorApiService.switchCompany() - Successfully switched to company: $newCompanyId');

      if (fetchData) {
        await clearInitialSyncFlag();
        await fetchAndCacheAllData();
      }
    } catch (e) {
      // print('ERROR: MonitorApiService.switchCompany() - Failed to switch company: $e');
      rethrow;
    }
  }

  /// Check if we already have sales data in the database
  Future<bool> _hasSalesInDb() async {
    try {
      final db = _dbHelper.database;
      final result = await db.rawQuery(
'SELECT COUNT(*) as count FROM mon_sales',
      );
      final count = result.first['count'] as int? ?? 0;
      // debugPrint("ApiService: Found $count sales records in database");
      return count > 0;
    } catch (e) {
      // debugPrint("ApiService: Error checking sales count -> $e");
      return false;
    }
  }

  Future<void> fetchAndCacheAllData({bool force = false}) async {
    final now = DateTime.now();
    final dateFormatter = DateFormat('yyyy-MM-dd');

    try {
      debugPrint("ApiService: Starting to fetch all data...");

      // Check if we already have sales in the database
      if (!force) {
        final hasSales = await _hasSalesInDb();
        if (hasSales) {
          debugPrint(
            "ApiService: Sales already exist in database, skipping fetch",
          );
          await setInitialSyncCompleted();

          if (Get.isRegistered<MonOperatorController>()) {
            await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();
          }
          return;
        }
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
        debugPrint("ApiService: Starting to fetch customers from /bp/customers endpoint");
        final posApiService = Get.find<PosApiService>();
        final customers = await posApiService.fetchCustomers();
        debugPrint(
          "ApiService: Successfully fetched ${customers.length} customers from API",
        );

        // Save to database
        debugPrint("ApiService: Deleting existing customers from database...");
        await _dbHelper.deleteAllCustomers();
        debugPrint("ApiService: Inserting ${customers.length} customers into database...");
        await _dbHelper.insertCustomers(customers);
        
        // Verify the save
        final savedCount = await _dbHelper.getCustomerCount();
        debugPrint("ApiService: Verified $savedCount customers saved to database successfully");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch customers -> $e");
      }

      try {
        companyDetailsRes = await getWithAuth('/company/details');
        debugPrint("ApiService: Successfully fetched company details");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /company/details -> $e");
        companyDetailsRes = null;
      }

      try {
        // Fetch all KPI data types using syncAllKpiData
        // This ensures all kpi_ids (0-8) are available in the database
        final startDate = DateTime(2023, 9, 1); // Start from historical date
        debugPrint("ApiService: Fetching all KPI data types from 2023-09-01 to ${dateFormatter.format(now)}");
        
        await syncAllKpiData(startDate, now);
        debugPrint("ApiService: Successfully fetched all KPI data types");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch all KPI data -> $e");
        salesRes = null;
      }

      // Sales details now fetched via individual KPI endpoints when needed
      // instead of the previous /sales/?pagecount=0&pagesize=5000 endpoint
      salesDetailsRes = null;

      try {
        inventoryRes = await getWithAuth('/inventory/');
        debugPrint("ApiService: Successfully fetched inventory");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /inventory -> $e");
        inventoryRes = null;
      }

      // Parse responses - use compute() for large datasets to avoid main thread blocking
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

      // Parse large datasets on isolate to prevent GC pressure on main thread
      List<dynamic> salesData = [];
      if (salesRes != null && salesRes.body.isNotEmpty) {
        try {
          salesData = await compute(_decodeJsonList, salesRes.body);
          debugPrint(
            "ApiService: Parsed ${salesData.length} sales records (isolate)",
          );
        } catch (e) {
          debugPrint("ApiService: Failed to parse sales JSON -> $e");
        }
      }

      List<dynamic> salesDetailsData = [];
      if (salesDetailsRes != null && salesDetailsRes.body.isNotEmpty) {
        try {
          salesDetailsData = await compute(
            _decodeJsonList,
            salesDetailsRes.body,
          );
        } catch (e) {
          debugPrint("ApiService: Failed to parse sales details JSON -> $e");
        }
      }

      List<dynamic> inventoryData = [];
      if (inventoryRes != null && inventoryRes.body.isNotEmpty) {
        try {
          inventoryData = await compute(_decodeJsonList, inventoryRes.body);
          debugPrint(
            "ApiService: Parsed ${inventoryData.length} inventory items (isolate)",
          );
        } catch (e) {
          debugPrint("ApiService: Failed to parse inventory JSON -> $e");
        }
      }

      final db = _dbHelper.database;

      // Use transaction with batch for optimal performance
      // Batch reduces Dart-to-Native FFI overhead by executing all inserts in one go
      await db.transaction((txn) async {
        // Clear old data
        await txn.delete('mon_service_points');
        await txn.delete('company_details');
        await txn.delete('mon_sales');

        // Insert inventory using batch
        if (inventoryData.isNotEmpty) {
          // debugPrint("ApiService: Batch inserting ${inventoryData.length} inventory items");
          final inventoryBatch = txn.batch();
          for (final item in inventoryData) {
            inventoryBatch.insert('mon_inventory', {
              'id': item['id'],
              'ipdid': item['ipdid'],
              'code': item['code'],
              'externalserial': item['externalserial'],
              'name': item['name'],
              'category': item['category'],
              'price': item['price'],
              'packsize': item['packsize'],
              'packaging': item['packaging'],
              'packagingid': item['packagingid'],
              'soldfrom': item['soldfrom'],
              'shortform': item['shortform'],
              'packagingcode': item['packagingcode'],
              'efris': item['efris'] == true ? 1 : 0,
              'efrisid': item['efrisid'],
              'measurmentunitidefris': item['measurmentunitidefris'],
              'measurmentunit': item['measurmentunit'],
              'measurmentunitid': item['measurmentunitid'],
              'vatcategoryid': item['vatcategoryid'],
              'branchid': item['branchid'],
              'companyid': item['companyid'],
              'downloadlink': item['downloadlink'],
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await inventoryBatch.commit(noResult: true);
        }

        // Insert company details (single record, no batch needed)
        if (companyDetailsData.isNotEmpty) {
          await txn.insert('company_details', {
            'branch': companyDetailsData['branch'],
            'company': companyDetailsData['company'],
            'userCode': companyDetailsData['userCode'],
            'currentBranchName': companyDetailsData['currentBranchName'],
            'currentBranchCode': companyDetailsData['currentBranchCode'],
            'activeBranchName': companyDetailsData['activeBranch']?['name'],
            'activeBranchAddress':
                companyDetailsData['activeBranch']?['address'],
            'activeBranchPrimaryEmail':
                companyDetailsData['activeBranch']?['primaryEmail'],
            'activeBranchCode': companyDetailsData['activeBranch']?['code'],
            'efrisEnabled': companyDetailsData['efrisEnabled'] == true ? 1 : 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Insert service points using batch
        if (servicePointsData.isNotEmpty) {
          // debugPrint("ApiService: Batch inserting ${servicePointsData.length} service points");
          final spBatch = txn.batch();
          for (final sp in servicePointsData) {
            spBatch.insert('mon_service_points', {
              'id': sp['id'],
              'name': sp['name'],
              'code': sp['code'],
              'branch': sp['branch'],
              'company': sp['company'],
              'mainServicePoint': sp['mainServicePoint'] == true ? 1 : 0,
              'stores': sp['stores'] == true ? 1 : 0,
              'sales': sp['sales'] == true ? 1 : 0,
              'production': sp['production'] == true ? 1 : 0,
              'booking': sp['booking'] == true ? 1 : 0,
              'servicePointTypeId': sp['servicePointTypeId'],
              'departmentid': sp['departmentid'],
              'facilityName': sp['name'],
              'facilityCode': sp['facility']?['code'],
              'fullName': sp['fullName'],
              'servicepointtype': sp['servicepointtype'],
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await spBatch.commit(noResult: true);
        }

        // Insert KPI aggregated sales using batch
        if (salesData.isNotEmpty) {
          debugPrint("ApiService: Batch inserting ${salesData.length} KPI sales records into mon_kpi_sales");
          final kpiBatch = txn.batch();
          for (final sale in salesData) {
            // Map the KPI response data to the new table schema
            // kpiId is passed separately, default to 0 (all transactions)
            kpiBatch.insert('mon_kpi_sales', {
              'kpi_id': 0, // Default to all transactions
              'processing_date': _extractDate(sale['processingdate'] ?? ''),
              'selling_point': sale['sellingpoint'] ?? '',
              'currency': sale['currency'] ?? '',
              'kpi': sale['kpi'] ?? '',
              'quantity': sale['quantity'] ?? 0,
              'amount1': _parseDouble(sale['amount1']),
              'amount2': _parseDouble(sale['amount2']),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await kpiBatch.commit(noResult: true);
          debugPrint("ApiService: Successfully inserted KPI sales records");
        }

        // Clear old mon_sales since we now use KPI aggregated data
        // Note: Keeping the table for backward compatibility, but it's no longer populated
        // await txn.delete('mon_sales');

        // Update sales with salesperson/payment info using batch
        if (salesDetailsData.isNotEmpty) {
          // debugPrint("ApiService: Batch updating ${salesDetailsData.length} sales with details");
          final updateBatch = txn.batch();
          for (final detail in salesDetailsData) {
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

      await storeLastSyncTimestamp(now.millisecondsSinceEpoch);
      await setInitialSyncCompleted();
      // debugPrint("ApiService: All data fetched and cached successfully");

      if (Get.isRegistered<MonOperatorController>()) {
        await Get.find<MonOperatorController>().loadCompanyDetailsFromDb();
      }
    } catch (e) {
      // debugPrint("ApiService: fetchAndCacheAllData() failed -> $e");
      rethrow;
    }
  }

  Future<void> syncRecentSales() async {
    try {
      // debugPrint("ApiService: Starting recent sales sync...");
      final now = DateTime.now();

      final lastSyncTimestamp =
          (await getStoredLastSyncTimestamp()) ??
          now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(
        lastSyncTimestamp,
      );

      // Sync all KPI data types for the recent period
      await syncAllKpiData(lastSyncDate, now);

      await storeLastSyncTimestamp(now.millisecondsSinceEpoch);
      debugPrint("ApiService: Recent sales sync completed.");
    } catch (e) {
      debugPrint("ApiService: syncRecentSales failed -> $e");
      rethrow;
    }
  }

  /// Legacy method - redirects to syncAllKpiData
  Future<void> _syncRecentSalesLegacy() async {
    // This method is kept for backward compatibility but now uses syncAllKpiData
    await syncRecentSales();
  }

  /// KPI ID definitions for aggregated sales reports
  /// 0 - all transactions
  /// 1 - cash
  /// 2 - pending payment
  /// 3 - payment modes
  /// 4 - salesperson
  /// 5 - profit
  /// 6 - efris status (1- pending, 2 - uploaded, 3- failed)
  /// 7 - by stick category
  /// 8 - by item
  static const int kpiAllTransactions = 0;
  static const int kpiCash = 1;
  static const int kpiPendingPayment = 2;
  static const int kpiPaymentModes = 3;
  static const int kpiSalesperson = 4;
  static const int kpiProfit = 5;
  static const int kpiEfrisStatus = 6;
  // static const int kpiStockCategory = 7;
  static const int kpiByItem = 8;

  /// Timeframe definitions
  /// 1 - normal date
  /// 2 - week
  /// 3 - month
  /// 4 - quarter
  /// 5 - year
  static const int timeframeNormal = 1;
  static const int timeframeWeek = 2;
  static const int timeframeMonth = 3;
  static const int timeframeQuarter = 4;
  static const int timeframeYear = 5;

  /// Fetch KPI aggregated sales data
  ///
  /// [startDate] - Start date in yyyy-MM-dd format
  /// [endDate] - End date in yyyy-MM-dd format
  /// [kpiId] - KPI mode (0-8, see constants above)
  /// [timeframe] - Timeframe (1-5, see constants above)
  ///
  /// Returns the HTTP response with aggregated KPI data
  Future<http.Response> getKpiSalesData({
    required String startDate,
    required String endDate,
    int kpiId = kpiAllTransactions,
    int timeframe = timeframeNormal,
  }) async {
    final endpoint =
        '/sales/reports/kpi?startDate=$startDate&endDate=$endDate&kpiId=$kpiId&timeframe=$timeframe';
    debugPrint("ApiService: Fetching KPI data with kpiId=$kpiId, timeframe=$timeframe");
    return await getWithAuth(endpoint);
  }

  /// Fetch all transactions KPI (kpiId=0)
  Future<http.Response> getAllTransactions({
    required String startDate,
    required String endDate,
    int timeframe = timeframeNormal,
  }) async {
    return await getKpiSalesData(
      startDate: startDate,
      endDate: endDate,
      kpiId: kpiAllTransactions,
      timeframe: timeframe,
    );
  }

  /// Fetch cash transactions KPI (kpiId=1)
  Future<http.Response> getCashTransactions({
    required String startDate,
    required String endDate,
    int timeframe = timeframeNormal,
  }) async {
    return await getKpiSalesData(
      startDate: startDate,
      endDate: endDate,
      kpiId: kpiCash,
      timeframe: timeframe,
    );
  }

  /// Fetch pending payment transactions KPI (kpiId=2)
  Future<http.Response> getPendingPaymentTransactions({
    required String startDate,
    required String endDate,
    int timeframe = timeframeNormal,
  }) async {
    return await getKpiSalesData(
      startDate: startDate,
      endDate: endDate,
      kpiId: kpiPendingPayment,
      timeframe: timeframe,
    );
  }

  /// Fetch payment modes KPI (kpiId=3)
  Future<http.Response> getPaymentModes({
    required String startDate,
    required String endDate,
    int timeframe = timeframeNormal,
  }) async {
    return await getKpiSalesData(
      startDate: startDate,
      endDate: endDate,
      kpiId: kpiPaymentModes,
      timeframe: timeframe,
    );
  }

  /// Fetch salesperson KPI (kpiId=4)
  Future<http.Response> getSalespersonData({
    required String startDate,
    required String endDate,
    int timeframe = timeframeNormal,
  }) async {
    return await getKpiSalesData(
      startDate: startDate,
      endDate: endDate,
      kpiId: kpiSalesperson,
      timeframe: timeframe,
    );
  }

  /// Fetch profit KPI (kpiId=5)
  Future<http.Response> getProfitData({
    required String startDate,
    required String endDate,
    int timeframe = timeframeNormal,
  }) async {
    return await getKpiSalesData(
      startDate: startDate,
      endDate: endDate,
      kpiId: kpiProfit,
      timeframe: timeframe,
    );
  }

  /// Fetch EFRIS status KPI (kpiId=6)
  /// [efrisStatus] - 1 for pending, 2 for uploaded, 3 for failed
  // Future<http.Response> getEfrisStatusData({
  //   required String startDate,
  //   required String endDate,
  //   int efrisStatus = 1,
  //   int timeframe = timeframeNormal,
  // }) async {
  //   // For EFRIS status, the status is passed as part of the query
  //   final endpoint =
  //       '/sales/reports/kpi?startDate=$startDate&endDate=$endDate&kpiId=$kpiEfrisStatus&efrisStatus=$efrisStatus&timeframe=$timeframe';
  //   debugPrint("ApiService: Fetching EFRIS status data with status=$efrisStatus");
  //   return await getWithAuth(endpoint);
  // }

  /// Fetch stock category KPI (kpiId=7)
  // Future<http.Response> getStockCategoryData({
  //   required String startDate,
  //   required String endDate,
  //   int timeframe = timeframeNormal,
  // }) async {
  //   return await getKpiSalesData(
  //     startDate: startDate,
  //     endDate: endDate,
  //     kpiId: kpiStockCategory,
  //     timeframe: timeframe,
  //   );
  // }

  /// Fetch by item KPI (kpiId=8)
  Future<http.Response> getByItemData({
    required String startDate,
    required String endDate,
    int timeframe = timeframeNormal,
  }) async {
    return await getKpiSalesData(
      startDate: startDate,
      endDate: endDate,
      kpiId: kpiByItem,
      timeframe: timeframe,
    );
  }

  Future<void> setInitialSyncCompleted() async {
    await secureStorage.write(key: 'initial_sync_completed', value: 'true');
  }

  Future<bool> isInitialSyncCompleted() async {
    final value = await secureStorage.read(key: 'initial_sync_completed');
    return value == 'true';
  }

  /// Check if data sync is needed based on 30-minute cache window
  /// Returns true if sync is needed, false if recent sync exists
  Future<bool> isSyncNeeded({int cacheMinutes = 30}) async {
    final lastSyncTimestamp = await getStoredLastSyncTimestamp();
    if (lastSyncTimestamp == null) {
      return true; // No previous sync, need to sync
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheWindowMs = cacheMinutes * 60 * 1000;
    final timeSinceLastSync = now - lastSyncTimestamp;

    return timeSinceLastSync > cacheWindowMs;
  }

  Future<void> clearInitialSyncFlag() async {
    await secureStorage.delete(key: 'initial_sync_completed');
  }

  /// Sync all KPI data types (0-8) from the API and store in database
  /// This ensures all data is available for queries including top selling products
  Future<void> syncAllKpiData(DateTime startDate, DateTime endDate) async {
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final startDateStr = dateFormatter.format(startDate);
    final endDateStr = dateFormatter.format(endDate);

    debugPrint("ApiService: Syncing all KPI data from $startDateStr to $endDateStr");

    // List of all KPI types to fetch
    final kpiTypes = [
      {'id': kpiAllTransactions, 'name': 'all_transactions'},
      {'id': kpiCash, 'name': 'cash'},
      {'id': kpiPendingPayment, 'name': 'pending_payment'},
      {'id': kpiPaymentModes, 'name': 'payment_modes'},
      {'id': kpiSalesperson, 'name': 'salesperson'},
      {'id': kpiProfit, 'name': 'profit'},
      {'id': kpiEfrisStatus, 'name': 'efris_status'},
      // {'id': kpiStockCategory, 'name': 'stock_category'},
      {'id': kpiByItem, 'name': 'by_item'},
    ];

    final db = _dbHelper.database;

    // DO NOT DELETE - use ConflictAlgorithm.replace to update existing records
    // This preserves all existing data and only inserts/updates new records
    // Only delete when user explicitly triggers "Reload All Data" from More page
    debugPrint("ApiService: Syncing KPI data (upsert mode - no deletions)");

    // Fetch and insert each KPI type
    for (final kpiType in kpiTypes) {
      try {
        debugPrint("ApiService: Fetching KPI data for ${kpiType['name']} (kpiId=${kpiType['id']})");
        final response = await getWithAuth(
          '/sales/reports/kpi?startDate=$startDateStr&endDate=$endDateStr&kpiId=${kpiType['id']}&timeframe=$timeframeNormal',
        );

        final List<dynamic> salesData = await compute(
          _decodeJsonList,
          response.body,
        );

        if (salesData.isEmpty) {
          debugPrint("ApiService: No data for ${kpiType['name']}");
          continue;
        }

        // Batch insert KPI sales
        final kpiBatch = db.batch();
        for (final sale in salesData) {
          kpiBatch.insert('mon_kpi_sales', {
            'kpi_id': kpiType['id'],
            'processing_date': _extractDate(sale['processingdate'] ?? ''),
            'selling_point': sale['sellingpoint'] ?? '',
            'currency': sale['currency'] ?? '',
            'kpi': sale['kpi'] ?? '',
            'quantity': sale['quantity'] ?? 0,
            'amount1': _parseDouble(sale['amount1']),
            'amount2': _parseDouble(sale['amount2']),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await kpiBatch.commit(noResult: true);
        debugPrint("ApiService: Inserted ${salesData.length} records for ${kpiType['name']}");
      } catch (e) {
        debugPrint("ApiService: Error fetching ${kpiType['name']}: $e");
      }
    }

    debugPrint("ApiService: Completed syncing all KPI data");
  }

  /// Fetches KPI metrics for the current day only.
  /// This is the first data fetch operation during splash screen.
  /// 
  /// Returns: Map of kpiId to list of records for quick access
  Future<Map<int, List<Map<String, dynamic>>>> fetchTodayKpiMetrics() async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    
    final kpiTypes = [
      {'id': kpiAllTransactions, 'name': 'all_transactions'},
      {'id': kpiCash, 'name': 'cash'},
      {'id': kpiPendingPayment, 'name': 'pending_payment'},
      {'id': kpiPaymentModes, 'name': 'payment_modes'},
      {'id': kpiSalesperson, 'name': 'salesperson'},
      {'id': kpiProfit, 'name': 'profit'},
      {'id': kpiEfrisStatus, 'name': 'efris_status'},
      // {'id': kpiStockCategory, 'name': 'stock_category'},
      {'id': kpiByItem, 'name': 'by_item'},
    ];
    
    final results = <int, List<Map<String, dynamic>>>{};
    
    for (final kpiType in kpiTypes) {
      try {
        debugPrint("ApiService: Fetching today's KPI ${kpiType['name']} (kpiId=${kpiType['id']})");
        final response = await getWithAuth(
          '/sales/reports/kpi?startDate=$today&endDate=$today&kpiId=${kpiType['id']}&timeframe=$timeframeNormal',
        );
        
        final data = await compute(_decodeJsonList, response.body);
        final records = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        
        results[kpiType['id'] as int] = records;
        debugPrint("ApiService: Fetched ${records.length} records for ${kpiType['name']}");
      } catch (e) {
        debugPrint('ApiService: Error fetching KPI ${kpiType['name']}: $e');
        results[kpiType['id'] as int] = [];
      }
    }
    
    // Store to database
    if (results.values.expand((e) => e).isNotEmpty) {
      await syncAllKpiData(now, now);
    }
    
    return results;
  }

  /// Fetches historical KPI data for the past N months.
  /// Partitions data into monthly intervals to minimize server load.
  /// 
  /// [monthsBack] - Number of months to fetch (default: 12)
  /// [onProgress] - Callback for progress updates (0.0 to 1.0)
  Future<void> fetchHistoricalData({
    int monthsBack = 12,
    void Function(double progress)? onProgress,
  }) async {
    final now = DateTime.now();
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final totalMonths = monthsBack;
    int completedMonths = 0;
    
    debugPrint("ApiService: Starting historical data fetch for $totalMonths months");
    
    for (int i = 0; i < totalMonths; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);
      
      final startDateStr = dateFormatter.format(monthStart);
      final endDateStr = dateFormatter.format(monthEnd);
      
      // Check if this month's data already exists
      final hasData = await _dbHelper.hasKpiDataForDateRange(startDateStr, endDateStr);
      if (hasData) {
        debugPrint("ApiService: Month $startDateStr already has data, skipping");
        completedMonths++;
        onProgress?.call(completedMonths / totalMonths);
        continue;
      }
      
      // Fetch all KPI types for this month
      debugPrint("ApiService: Fetching data for month: $startDateStr to $endDateStr");
      await syncAllKpiData(monthStart, monthEnd);
      
      completedMonths++;
      onProgress?.call(completedMonths / totalMonths);
      
      // Small delay between months to prevent server overload
      if (i < totalMonths - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    debugPrint("ApiService: Historical data fetch complete for $totalMonths months");
  }
}
