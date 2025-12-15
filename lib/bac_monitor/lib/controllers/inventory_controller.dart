import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../db/db_helper.dart';
import '../models/inventory_data.dart';

class InventoryController extends GetxController {
  final _dbHelper = DatabaseHelper();
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
      final items = await _dbHelper.getAllInventoryItems();
      inventoryItems.assignAll(
        items.map((e) => InventoryItem.fromJson(e)).toList(),
      );
    } catch (e) {
      print('Error loading inventory: $e');
    } finally {
      isLoading.value = false;
    }
  }
}