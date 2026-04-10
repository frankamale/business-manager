import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

// Package imports for external dependencies
import 'package:bac_pos/bac_monitor/lib/services/api_services.dart';
import 'package:bac_pos/bac_monitor/lib/services/kpi_sync_service.dart';
import 'bac_monitor/lib/repositories/kpi_repository.dart';
import 'bac_monitor/lib/additions/colors.dart';
import 'bac_monitor/lib/controllers/mon_data_sync_controller.dart';
import 'flavors/flavor_colors.dart';
import 'flavors/flavor_config.dart';

// POS Module imports
import 'bac_monitor/lib/controllers/profile_controller.dart';
import 'bac_monitor/lib/services/account_manager.dart';
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
import 'initialise/splashscreen.dart';
import 'shared/services/customer_auth_service.dart';
import 'shared/widgets/offline_banner.dart';

import 'package:bac_pos/bac_monitor/lib/controllers/mon_store_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/mon_store_kpi_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/mon_sync_controller.dart';
import 'package:bac_pos/bac_monitor/lib/controllers/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();


  print('FlavorConfig.flavorName: ${FlavorConfig.flavorName}');
  print('FlavorColors.current.primary: ${FlavorColors.current.primary}');

  // Initialize bot credentials from dart-define to secure storage
  final customerAuthService = CustomerAuthService();
  await customerAuthService.initBotCredentials();

  // Fetch and store bot's company info for flavor validation
  try {
    if (await customerAuthService.hasBotCredentials()) {
      await customerAuthService.fetchAndStoreBotCompanyInfo();
    }
  } catch (e) {
    print('Warning: Could not fetch bot company info: $e');
  }

  // POS Services
  Get.put(PosApiService());
  Get.lazyPut<SalesSyncService>(() => SalesSyncService());

  // Monitor Services
  Get.put(MonitorApiService());
  Get.put(AccountManager());
  Get.put(KpiSyncService());

  Get.put(AuthController());
  Get.put(CustomerController());
  Get.put(InventoryController());
  Get.put(KpiRepository());
  Get.put(PaymentController());
  Get.put(SalesController());
  Get.put(UserController());
  Get.put(SettingsController());
  Get.put(ServicePointController());


  Get.lazyPut<MonStoresController>(() => MonStoresController());
  Get.lazyPut<MonStoreKpiTrendController>(() => MonStoreKpiTrendController());
  Get.lazyPut<MonSyncController>(() => MonSyncController());
  Get.lazyPut<MonDataSyncController>(() => MonDataSyncController());
  Get.put(ProfileController());
  Get.put(ThemeController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = Get.find<ThemeController>();
      return GetMaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: true,

        // Light theme configuration
        theme: ThemeData(
          fontFamily: 'JosefinSans',
          colorScheme: ColorScheme.fromSeed(
            seedColor: FlavorColors.current.primary,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: LightColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: LightColors.background,
            foregroundColor: LightColors.textPrimary,
          ),
          cardTheme: CardThemeData(
            color: LightColors.card,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: LightColors.border),
            ),
          ),
          textTheme: TextTheme(
            bodyLarge: TextStyle(color: LightColors.textPrimary),
            bodyMedium: TextStyle(color: LightColors.textSecondary),
          ),
          useMaterial3: true,
        ),

        // Dark theme configuration
        darkTheme: ThemeData(
          fontFamily: 'JosefinSans',

          colorScheme: ColorScheme.fromSeed(
            seedColor: FlavorColors.current.primary,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: DarkColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: DarkColors.background,
            foregroundColor: DarkColors.textPrimary,
          ),
          cardTheme: CardThemeData(
            color: DarkColors.card,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: DarkColors.border),
            ),
          ),
          textTheme: TextTheme(
            bodyLarge: TextStyle(color: DarkColors.textPrimary),
            bodyMedium: TextStyle(color: DarkColors.textSecondary),
          ),
          useMaterial3: true,
        ),

        // Follow device's system theme or manual setting
        themeMode: controller.themeMode.value,

         fallbackLocale: const Locale('en', 'US_store'),
         builder: (context, child) {
           return OfflineBanner(child: child ?? const SplashScreen());
         },
         home: const SplashScreen(),
      );
    });
  }
}
