import 'dart:async';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class NetworkHelper {
  static DateTime? _lastCheck;
  static bool? _cachedResult;
  static const Duration _cacheDuration = Duration(seconds: 10);

  static InternetConnectionChecker get _checker => InternetConnectionChecker.instance;

  static Future<bool> hasConnection() async {
    final now = DateTime.now();
    if (_lastCheck != null &&
        _cachedResult != null &&
        now.difference(_lastCheck!) < _cacheDuration) {
      return _cachedResult!;
    }

    try {
      final isConnected = await _checker.hasConnection;

      _cachedResult = isConnected;
      _lastCheck = now;

      return isConnected;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> hasInternetAccess() async {
    // Use the same reliable method as hasConnection for consistency
    return await hasConnection();
  }

  static Stream<InternetConnectionStatus> get connectivityStream =>
      _checker.onStatusChange;
}
