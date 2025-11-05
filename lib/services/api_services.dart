import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../models/users.dart';

class ApiService extends GetxService {
  final String baseurl = "http://52.30.142.12:8080/rest";

  Future<List<User>> fetchUsers() async {
    final response = await http.get(Uri.parse("$baseurl/users"));

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => User.fromMap(json)).toList();
    } else {
      throw Exception("Failed to load user");
    }
  }
}
