import 'dart:async';
import 'package:bac_pos/bac_monitor/lib/controllers/salestrends_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/api_services.dart';
import 'kpi_overview_controller.dart';

class SyncController extends GetxController {
  final ApiServiceMonitor _apiService = Get.find();
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

      if (Get.isRegistered<KpiOverviewController>()) {
        await Get.find<KpiOverviewController>().fetchKpiData();
      }
      if (Get.isRegistered<SalesTrendsController>()) {
        await Get.find<SalesTrendsController>().fetchAllData();
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