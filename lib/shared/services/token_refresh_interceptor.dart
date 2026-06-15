import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A custom HTTP client that automatically handles 401 errors by re-authenticating
/// with stored credentials and retrying the original request.
///
/// This interceptor wraps the standard http.Client and provides automatic token
/// refresh functionality. It handles concurrent requests properly by queuing them
/// while the token is being refreshed.
///
/// The [baseUrl] parameter is required to specify the API base URL for authentication.
/// The [secureStorage] parameter allows injecting a custom secure storage instance
/// for testing purposes.
class TokenRefreshInterceptor extends http.BaseClient {
  final http.Client _inner;
  final FlutterSecureStorage _secureStorage;
  final String _baseUrl;

  // Mutex/lock mechanism for handling concurrent refresh attempts
  Completer<http.Response>? _refreshCompleter;
  bool _isRefreshing = false;

  /// Storage keys for tokens and credentials
  static const String tokenKey = 'access_token';
  static const String serverUsernameKey = 'server_username';
  static const String serverPasswordKey = 'server_password';

  /// Creates a new TokenRefreshInterceptor.
  ///
  /// [baseUrl] - The base URL for the API (e.g., 'http://52.30.142.12:8080/rest')
  /// [inner] - The underlying HTTP client to use for making requests
  /// [secureStorage] - The secure storage instance for reading/writing tokens and credentials
  TokenRefreshInterceptor({
    required String baseUrl,
    http.Client? inner,
    FlutterSecureStorage? secureStorage,
  })  : _inner = inner ?? http.Client(),
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _baseUrl = baseUrl;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Add authorization header if token exists
    final token = await _getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Send the request
    final streamedResponse = await _inner.send(request);

    // Check if we got a 401 Unauthorized response
    if (streamedResponse.statusCode == 401) {
      // Convert StreamedResponse to Response for easier handling
      final response = await http.Response.fromStream(streamedResponse);

      // Try to refresh the token and retry the request
      return await _handleUnauthorized(request, response);
    }

    return streamedResponse;
  }

  /// Handles 401 Unauthorized responses by refreshing the token and retrying the request.
  Future<http.StreamedResponse> _handleUnauthorized(
    http.BaseRequest originalRequest,
    http.Response unauthorizedResponse,
  ) async {
    // If a refresh is already in progress, wait for it to complete
    if (_isRefreshing) {
      // Wait for the refresh to complete
      await _refreshCompleter!.future;
      // Retry the original request with the new token
      return await _retryRequest(originalRequest);
    }

    // Start a new refresh process
    _isRefreshing = true;
    _refreshCompleter = Completer<http.Response>();

    try {
      // Attempt to refresh the token
      await _refreshToken();

      // Complete the refresh completer to notify waiting requests
      _refreshCompleter!.complete(unauthorizedResponse);

      // Retry the original request with the new token
      return await _retryRequest(originalRequest);
    } catch (e) {
      // If refresh fails, complete with error and rethrow
      _refreshCompleter!.completeError(e);
      rethrow;
    } finally {
      // Reset the refresh state
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Refreshes the authentication token using stored credentials.
  Future<void> _refreshToken() async {
    // Get stored credentials
    final credentials = await _getServerCredentials();

    // Log credentials for debugging (mask password)
    print('TokenRefreshInterceptor: Refreshing token for user: ${credentials['username'] ?? 'null'}');

    if (credentials['username'] == null || credentials['password'] == null) {
      throw Exception(
        'Token refresh failed: No stored credentials found. Please log in again.',
      );
    }

    // Make a login request to get a new token
    final loginUrl = Uri.parse('$_baseUrl/auth/signin');
    final loginResponse = await _inner.post(
      loginUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': credentials['username'],
        'password': credentials['password'],
      }),
    );

    if (loginResponse.statusCode == 200) {
      final responseData = jsonDecode(loginResponse.body);

      if (responseData.containsKey('accessToken')) {
        // Store the new token
        await _storeToken(responseData['accessToken']);
      } else {
        throw Exception(
          'Token refresh failed: No access token in response.',
        );
      }
    } else {
      throw Exception(
        'Token refresh failed: Login returned status ${loginResponse.statusCode}',
      );
    }
  }

  /// Retries the original request with the new token.
  Future<http.StreamedResponse> _retryRequest(http.BaseRequest originalRequest) async {
    // Get the new token
    final newToken = await _getToken();

    if (newToken == null) {
      throw Exception('Token refresh failed: Unable to retrieve new token.');
    }

    // Clone the original request with the new token
    final retryRequest = _cloneRequest(originalRequest);
    retryRequest.headers['Authorization'] = 'Bearer $newToken';

    // Send the retry request
    return await _inner.send(retryRequest);
  }

  /// Clones an HTTP request to allow retrying.
  http.BaseRequest _cloneRequest(http.BaseRequest original) {
    if (original is http.Request) {
      final cloned = http.Request(original.method, original.url);
      cloned.headers.addAll(original.headers);
      cloned.bodyBytes = original.bodyBytes;
      cloned.encoding = original.encoding;
      return cloned;
    } else if (original is http.MultipartRequest) {
      final cloned = http.MultipartRequest(original.method, original.url);
      cloned.headers.addAll(original.headers);
      cloned.fields.addAll(original.fields);
      cloned.files.addAll(original.files);
      return cloned;
    } else {
      // For other request types, create a basic request
      final cloned = http.Request(original.method, original.url);
      cloned.headers.addAll(original.headers);
      return cloned;
    }
  }

  /// Gets the current access token from secure storage.
  Future<String?> _getToken() async {
    return await _secureStorage.read(key: tokenKey);
  }

  /// Stores the new access token in secure storage.
  Future<void> _storeToken(String token) async {
    await _secureStorage.write(key: tokenKey, value: token);
  }

  /// Gets the stored server credentials from secure storage.
  Future<Map<String, String?>> _getServerCredentials() async {
    final username = await _secureStorage.read(key: serverUsernameKey);
    final password = await _secureStorage.read(key: serverPasswordKey);
    return {'username': username, 'password': password};
  }

  /// Closes the underlying HTTP client.
  @override
  void close() {
    _inner.close();
  }
}

/// Extension to provide convenient access to create TokenRefreshInterceptor
extension TokenRefreshInterceptorExtension on http.Client {
  /// Creates a TokenRefreshInterceptor instance.
  static TokenRefreshInterceptor create({
    required String baseUrl,
  }) {
    return TokenRefreshInterceptor(baseUrl: baseUrl);
  }
}
