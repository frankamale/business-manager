import 'package:http/http.dart' as http;
import '../config.dart';

class NetworkHelper {
  /// Check if the device has an active internet connection by pinging the API server
  static Future<bool> hasConnection() async {
    try {
      // Try to connect to the API server with a timeout
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/auth/ping'),
      ).timeout(const Duration(seconds: 5));

      // If we get any response (even if not 200), we have connectivity
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      // If there's any error (timeout, no connection, etc.), we're offline
      print(' No network connection: $e');
      return false;
    }
  }

  /// Check connectivity with custom timeout
  static Future<bool> hasConnectionWithTimeout(Duration timeout) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/auth/ping'),
      ).timeout(timeout);

      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      print(' No network connection: $e');
      return false;
    }
  }
}
