import 'package:bac_pos/bac_monitor/lib/services/api_services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:bac_pos/back_pos/controllers/auth_controller.dart';
import 'package:bac_pos/back_pos/controllers/customer_controller.dart';
import 'package:bac_pos/back_pos/controllers/inventory_controller.dart';
import 'package:bac_pos/back_pos/controllers/payment_controller.dart';
import 'package:bac_pos/back_pos/controllers/sales_controller.dart';
import 'package:bac_pos/back_pos/controllers/service_point_controller.dart';
import 'package:bac_pos/back_pos/controllers/settings_controller.dart';
import 'package:bac_pos/back_pos/controllers/user_controller.dart';
import 'package:bac_pos/back_pos/services/api_services.dart';
import 'package:bac_pos/back_pos/services/sales_sync_service.dart';
import 'package:bac_pos/back_pos/config.dart';
import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'controllers/dashboard_controller.dart';
import 'controllers/gross_profit_controller.dart';
import 'controllers/kpi_overview_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/operator_controller.dart';
import 'controllers/outstanding_payments_controller.dart';
import 'controllers/salestrends_controller.dart';
import 'controllers/store_controller.dart';
import 'controllers/store_kpi_controller.dart';
import 'controllers/sync_controller.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  
  // Initialize services
  Get.put(ApiServiceMonitor());
  Get.put(SalesSyncService());
  
  // Initialize POS controllers
  Get.put(AuthController());
  Get.put(CustomerController());
  Get.put(InventoryController());
  Get.put(PaymentController());
  Get.put(SalesController());
  Get.put(UserController());
  Get.put(SettingsController());
  Get.put(ServicePointController());
  
  // Initialize Monitor controllers
  Get.put(DashboardController());
  Get.put(GrossProfitController());
  Get.put(KpiOverviewController());
  Get.put(MainNavigationController());
  Get.put(OperatorController());
  Get.put(OutstandingPaymentsController());
  Get.put(SalesTrendsController());
  Get.put(StoresController());
  Get.put(StoreKpiTrendController());
  Get.put(SyncController());

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

      fallbackLocale: const Locale('en', 'US_store'),
      home: const UnifiedLoginScreen(),
    );
  }
}