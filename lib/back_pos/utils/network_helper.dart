import 'dart:async';
import 'package:internet_connection_checker/internet_connection_checker.dart';

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
    return await hasConnection();
  }

  static Stream<InternetConnectionStatus> get connectivityStream =>
      _checker.onStatusChange;
}
