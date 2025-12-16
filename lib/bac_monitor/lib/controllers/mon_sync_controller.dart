import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/api_services.dart';
import 'mon_kpi_overview_controller.dart';
import 'mon_salestrends_controller.dart';

class MonSyncController extends GetxController {
  final MonitorApiService _apiService = Get.find<MonitorApiService>();
  Timer? _syncTimer;

  @override
  void onInit() {
    super.onInit();
    startPeriodicSync();
  }

  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      debugPrint("Sync triggered by timer.");
      await _apiService.syncRecentSales();

      if (Get.isRegistered<MonKpiOverviewController>()) {
        await Get.find<MonKpiOverviewController>().fetchKpiData();
      }
      if (Get.isRegistered<MonSalesTrendsController>()) {
        await Get.find<MonSalesTrendsController>().fetchAllData();
      }
      debugPrint("UI controllers refreshed after sync.");
    });
  }

  @override
  void onClose() {
    _syncTimer?.cancel();
    super.onClose();
  }
}