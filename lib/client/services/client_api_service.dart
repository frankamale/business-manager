import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../back_pos/config.dart';

class ClientApiService {
  final String baseUrl = AppConfig.baseUrl;

  /// Send challenge code to user's email
  /// Returns true if successful
  Future<Map<String, dynamic>> sendChallengeCode({
    required String email,
    required String fullName,
    required String code,
    required String userId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/getchallengecode/'
      '?e=${Uri.encodeComponent(email)}'
      '&f=${Uri.encodeComponent(fullName)}'
      '&p=${Uri.encodeComponent(code)}'
      '&s=Account verification'
      '&id=$userId',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to send challenge code: ${response.statusCode}');
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
    String gender = 'Male',
    String status = 'Active/In Use',
    String statusId = '11111111-1111-1111-1111-111111111111',
  }) async {
    final uri = Uri.parse('$baseUrl/bp/postcustomer');

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
      'mode': 1,
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create customer: ${response.statusCode}');
    }
  }
}
