import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../../../shared/database/unified_db_helper.dart';
import '../models/inventory_data.dart';

class MonInventoryController extends GetxController {
  final _dbHelper = UnifiedDatabaseHelper.instance;
  var inventoryItems = [].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadInventoryFromDb();
  }

  Future<void> loadInventoryFromDb() async {
       try {
      isLoading.value = true;
      final items = await _dbHelper.getMonInventoryItems();
      inventoryItems.assignAll(
        items.map((e) => MonitorInventoryItem.fromJson(e)).toList(),
      );
    } catch (e) {
      print('Error loading inventory: $e');
    } finally {
      isLoading.value = false;
    }
  }
}