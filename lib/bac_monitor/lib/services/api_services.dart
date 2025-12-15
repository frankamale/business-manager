import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../controllers/mon_operator_controller.dart';
import '../controllers/mon_sync_controller.dart';
import '../db/db_helper.dart';
import '../pages/auth/Login.dart';
import '../pages/bottom_nav.dart';

class ApiServiceMonitor extends GetxService {
  static const String _baseUrl = 'http://52.30.142.12:8080/rest';
  final _storage = GetStorage();
  final _dbHelper = DatabaseHelper();

  String? getStoredToken() {
    return _storage.read('auth_token');
  }

  String? getStoredCode() {
    return _storage.read('persistent_code');
  }

  Future<void> storeCode(String code) async {
    await _storage.write('persistent_code', code);
  }

  Future<void> storeUserData(Map<String, dynamic> data) async {
    await _storage.write('user_data', data);
  }

  Map<String, dynamic>? getStoredUserData() {
    return _storage.read('user_data');
  }

  Future<void> storeLastSyncTimestamp(int timestamp) async {
    await _storage.write('last_sync_timestamp', timestamp);
  }

  int? getStoredLastSyncTimestamp() {
    return _storage.read('last_sync_timestamp');
  }

  Future<void> storeCompanyId(String companyId) async {
    await _storage.write('company_id', companyId);
  }

  String? getStoredCompanyId() {
    return _storage.read('company_id');
  }

  Future<String> fetchCompanyId() async {
    try {
      final response = await _getWithAuth('/company/details');
      final companyDetails = json.decode(response.body);
      
      if (companyDetails.containsKey('company')) {
        final companyId = companyDetails['company'];
        await storeCompanyId(companyId);
        return companyId;
      } else {
        throw Exception('Company ID not found in company details');
      }
    } catch (e) {
      debugPrint("ApiService: Failed to fetch company ID -> $e");
      throw Exception('Failed to fetch company ID: $e');
    }
  }

  Future<String> ensureCompanyIdAvailable() async {
    // Check if company ID is already stored
    final storedCompanyId = getStoredCompanyId();
    if (storedCompanyId != null && storedCompanyId.isNotEmpty) {
      return storedCompanyId;
    }
    
    // If not stored, try to fetch it
    try {
      return await fetchCompanyId();
    } catch (e) {
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
      final headers = {'Content-Type': 'application/json'};
      if (useToken) {
        final token = getStoredToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        } else {
          throw Exception('Authentication token not found.');
        }
      }
      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
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
    print (response);
    if (response.containsKey('accessToken')) {
      await _storage.write('auth_token', response['accessToken']);

      final userData = {
        'id': response['id'],
        'username': response['username'],
        'email': response['email'],
        'roles': response['roles'],
      };
      await _storage.write("userData", userData);

      print("login success ----- proceeding to fetch data");

      await storeCode(DateTime.now().millisecondsSinceEpoch.toString());
      
      // Fetch and store company ID before fetching all data
      try {
        final companyId = await fetchCompanyId();
        print("login success ----- company ID fetched: $companyId");
        
        // Switch to the new company's database
        await _dbHelper.switchCompany(companyId);
        print("login success ----- switched to company database: $companyId");
      } catch (e) {
        print("login warning ----- failed to fetch company ID: $e");
        // Continue with login even if company ID fetch fails
      }
      
      await fetchAndCacheAllData();

      if (!Get.isRegistered<MonSyncController>()) {
        Get.put(MonSyncController());
      }

      Get.offAll(() => const BottomNav());
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
      Future.delayed(Duration.zero, () {
        logout();
        Get.offAll(() => const LoginPage());
      });
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
    
    await _storage.remove('auth_token');
    await _storage.remove('user_data');
    await _storage.remove('persistent_code');
    await _storage.remove('last_sync_timestamp');
    await _storage.remove('company_id');
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
        servicePointsRes = await _getWithAuth('/servicepoints');
        debugPrint("ApiService: Successfully fetched service points");
      } catch (e) {
        debugPrint(
          "ApiService: Service points endpoint failed (will continue without it) -> $e",
        );
        servicePointsRes = null; // Explicitly set to null to continue
      }

      try {
        companyDetailsRes = await _getWithAuth('/company/details');
        debugPrint("ApiService: Successfully fetched company details");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /company/details -> $e");
      }

      try {
        final endDate = dateFormatter.format(now);
        salesRes = await _getWithAuth(
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
        salesDetailsRes = await _getWithAuth(
          '/sales/?pagecount=0&pagesize=5000',
        );
        debugPrint("ApiService: Successfully fetched sales details");
      } catch (e) {
        debugPrint("ApiService: Failed to fetch /sales/ -> $e");
      }

      try {
        inventoryRes = await _getWithAuth('/inventory/');
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
            await _dbHelper.insertInventoryItem(item,  db: txn);
          }
        } else {
          debugPrint(
            "ApiService: No inventory data available, skipping insertion",
          );
        }

        await _dbHelper.insertCompanyDetails(
          companyDetailsData,
          db: txn,
        );

        // Only insert service points if data is available
        if (servicePointsData.isNotEmpty) {
          debugPrint(
            "ApiService: Inserting ${servicePointsData.length} service points",
          );
          for (final item in servicePointsData) {
            await _dbHelper.insertServicePoint(item,  db: txn);
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
          getStoredLastSyncTimestamp() ??
          now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(
        lastSyncTimestamp,
      );

      final dateFormatter = DateFormat('yyyy-MM-dd');
      final startDate = dateFormatter.format(lastSyncDate);
      final endDate = dateFormatter.format(now);

      debugPrint("ApiService: Syncing from $startDate to $endDate.");

      final response = await _getWithAuth(
        '/sales/reports/transaction/detail?startDate=$startDate&endDate=$endDate',
      );

      final List<dynamic> salesData = json.decode(response.body);

      // Also fetch sales details for salesperson info
      http.Response? salesDetailsRes;
      try {
        salesDetailsRes = await _getWithAuth(
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

  Future<http.Response> _getWithAuth(String endpoint) async {
    final token = getStoredToken();
    if (token == null) {
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
