import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../back_pos/config.dart';
import '../../shared/services/customer_auth_service.dart';

class ClientApiService {
  final String baseUrl = AppConfig.baseUrl;
  final CustomerAuthService _customerAuthService = CustomerAuthService();

  /// Get authorization headers with bot token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _customerAuthService.getBotToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Send challenge code to user's email
  /// Returns true if successful
  Future<Map<String, dynamic>> sendChallengeCode({
    required String email,
    required String fullName,
    required String code,
    required String userId,
    String subject = 'Account verification',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/getchallengecode/'
      '?e=${Uri.encodeComponent(email)}'
      '&f=${Uri.encodeComponent(fullName)}'
      '&p=${Uri.encodeComponent(code)}'
      '&s=${Uri.encodeComponent(subject)}'
      '&id=$userId',
    );

    final headers = await _getAuthHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      await _customerAuthService.clearBotToken();
      throw Exception('An error occurred');
    } else {
      throw Exception('Failed to send challenge code: ${response.statusCode}');
    }
  }

  /// Reset customer password
  Future<Map<String, dynamic>> resetPassword({
    required String userId,
    required String newPassword,
    String subject = 'password reset',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/password/'
      '?t=$userId'
      '&p=${Uri.encodeComponent(newPassword)}'
      '&s=${Uri.encodeComponent(subject)}',
    );

    final headers = await _getAuthHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      await _customerAuthService.clearBotToken();
      throw Exception('An error occurred');
    } else {
      throw Exception('Failed to reset password: ${response.statusCode}');
    }
  }

  /// Create a new customer account
  Future<Map<String, dynamic>> createCustomer({
    required String id,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String address,
    required String password,
    required int service,
    required int activationrequired,
    String category = "Retail Customer(Bulk Purchase)",
    String gender = 'Male',
    String status = 'Active/In Use',
    String statusId = "99999999-9999-9999-9999-999999999999",
  }) async {
    String endpoint;

    if (service == 2) {
      endpoint = "bp/vendor";
    } else if (service == 3) {
      endpoint = "bp/staff";
    } else {
      endpoint = "bp/postcustomer";
    }

    final uri = Uri.parse('$baseUrl/$endpoint');

    final body = {
      'id': id,
      'firstname': firstName,
      'lastname': lastName,
      'status': status,
      'gender': gender,
      'fullnames': '$firstName $lastName',
      'tracker1': '',
      'tracker2': '',
      'tracker3': '',
      'email': email,
      'phone1': phone,
      'address': address,
      'pospassword': password,
      'statusid': statusId,
      // "category" : "Retail Customer(Bulk Purchase)",
      "activationrequired": activationrequired,
      'mode': 1,
    };

    print('=== CREATE CUSTOMER REQUEST ===');
    print('URL: $uri');
    print('Body: ${json.encode(body)}');

    final headers = await _getAuthHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: json.encode(body),
    );

    print('=== CREATE CUSTOMER RESPONSE ===');
    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      await _customerAuthService.clearBotToken();
      throw Exception('An error occurred');
    } else {
      throw Exception('Failed to create customer: ${response.statusCode}');
    }
  }
}
