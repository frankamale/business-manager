import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class TranslationService extends Translations {
  static Map<String, Map<String, String>>? _translations;

  Future<void> loadTranslations() async {
    final String jsonContent = await rootBundle.loadString(
      'assets/labels.json',
    );
    final Map<String, dynamic> jsonMap = json.decode(jsonContent);

    _translations = jsonMap.map((key, value) {
      return MapEntry(key, Map<String, String>.from(value));
    });
  }

  @override
  Map<String, Map<String, String>> get keys => _translations ?? {};
}
