import 'package:bac_pos/back_pos/controllers/auth_controller.dart';
import 'package:bac_pos/back_pos/controllers/service_point_controller.dart';
import 'package:bac_pos/back_pos/controllers/settings_controller.dart';
import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/back_pos/services/sales_sync_service.dart';
import 'package:bac_pos/back_pos/config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'back_pos/auth/splash_screen.dart';
import 'back_pos/controllers/customer_controller.dart';
import 'back_pos/controllers/inventory_controller.dart';
import 'back_pos/controllers/payment_controller.dart';
import 'back_pos/controllers/sales_controller.dart';
import 'back_pos/controllers/user_controller.dart';
import 'unified_login_screen.dart';
import 'app_roots.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init(); 
  Get.put(ApiService());
  Get.put(SalesSyncService());
  Get.put(AuthController());
  Get.put(CustomerController());
  Get.put(InventoryController());
  Get.put(PaymentController());
  Get.put(SalesController());
  Get.put(UserController());
  Get.put(SettingsController());
  Get.put(ServicePointController());

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: true,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,

      ),
      home: const PosAppRoot(),
    );
  }
}
