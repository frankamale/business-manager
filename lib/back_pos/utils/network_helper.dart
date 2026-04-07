import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class NetworkHelper {
  static final Connectivity _connectivity = Connectivity();
  static DateTime? _lastCheck;
  static bool? _cachedResult;
  static const Duration _cacheDuration = Duration(seconds: 10);

  static Future<bool> hasConnection() async {
    final now = DateTime.now();
    if (_lastCheck != null && 
        _cachedResult != null &&
        now.difference(_lastCheck!) < _cacheDuration) {
      return _cachedResult!;
    }

    try {
      final result = await _connectivity.checkConnectivity();
      final isConnected = !result.contains(ConnectivityResult.none);
      
      _cachedResult = isConnected;
      _lastCheck = now;
      
      return isConnected;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> hasInternetAccess() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/auth/ping'),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  static Stream<List<ConnectivityResult>> get connectivityStream => 
      _connectivity.onConnectivityChanged;
}
