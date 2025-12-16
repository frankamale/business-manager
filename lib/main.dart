import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

// Package imports for external dependencies
import 'package:bac_pos/bac_monitor/lib/services/api_services.dart';

// POS Module imports
import 'back_pos/controllers/auth_controller.dart';
import 'back_pos/controllers/customer_controller.dart';
import 'back_pos/controllers/inventory_controller.dart';
import 'back_pos/controllers/payment_controller.dart';
import 'back_pos/controllers/sales_controller.dart';
import 'back_pos/controllers/service_point_controller.dart';
import 'back_pos/controllers/settings_controller.dart';
import 'back_pos/controllers/user_controller.dart';
import 'back_pos/services/api_services.dart';
import 'back_pos/services/sales_sync_service.dart';
import 'back_pos/config.dart';
import 'initialise/unified_login_screen.dart';
// Monitor Module imports
import 'package:bac_pos/bac_monitor/lib/controllers/mon_dashboard_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/mon_gross_profit_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/mon_kpi_overview_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/mon_main_navigation_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/mon_operator_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/mon_outstanding_payments_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/mon_salestrends_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/mon_store_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/mon_store_kpi_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/mon_sync_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  // ============================================
  // Initialize Services
  // ============================================

  // POS Services
  Get.put(PosApiService());
  Get.put(SalesSyncService());

  // Monitor Services
  Get.put(MonitorApiService());

  // ============================================
  // Initialize POS Controllers
  // ============================================

  Get.put(AuthController());
  Get.put(CustomerController());
  Get.put(InventoryController());
  Get.put(PaymentController());
  Get.put(SalesController());
  Get.put(UserController());
  Get.put(SettingsController());
  Get.put(ServicePointController());

  // ============================================
  // Initialize Monitor Controllers (with Mon prefix)
  // ============================================

  Get.put(MonDashboardController());
  Get.put(MonGrossProfitController());
  Get.put(MonKpiOverviewController());
  Get.put(MonMainNavigationController());
  Get.put(MonOperatorController());
  Get.put(MonOutstandingPaymentsController());
  Get.put(MonSalesTrendsController());
  Get.put(MonStoresController());
  Get.put(MonStoreKpiTrendController());
  Get.put(MonSyncController());

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
