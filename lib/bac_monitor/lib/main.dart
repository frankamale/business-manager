
import 'package:bac_pos/bac_monitor/lib/pages/auth/splash_page.dart';
import 'package:bac_pos/bac_monitor/lib/services/api_services.dart';
import 'package:bac_pos/bac_monitor/lib/services/translations_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'controllers/operator_controller.dart';
import 'controllers/store_controller.dart';
import 'controllers/store_kpi_controller.dart';
import 'controllers/sync_controller.dart';
import 'db/db_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  Get.put(ApiService());
  Get.put(OperatorController());
  Get.put(SyncController());
  final translationService = TranslationService();
  await translationService.loadTranslations();
  Get.put(translationService);

  Get.put(StoresController());
  Get.put(StoreKpiTrendController());
  final box = GetStorage();
  final String labelPreference = box.read('label_preference') ?? 'store';
  final initialLocale = Locale('en', 'US_$labelPreference');

  // Test the sales mapping
  final dbHelper = DatabaseHelper();
  await dbHelper.testSalesMapping();
  await dbHelper.getSalesTableSchema().then((schema) {
    print('Sales table schema:');
    for (var column in schema) {
      print('${column['name']}: ${column['type']}');
    }
  });

  runApp(
    MyApp(translationService: translationService, initialLocale: initialLocale),
  );
}

class MyApp extends StatelessWidget {
  final TranslationService translationService;
  final Locale initialLocale;

  const MyApp({
    super.key,
    required this.translationService,
    required this.initialLocale,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'BAC Monitor',
      theme: ThemeData(primarySwatch: Colors.blue),
      translations: translationService,
      locale: initialLocale,
      fallbackLocale: const Locale('en', 'US_store'),
      home: const SplashPage(),
    );
  }
}