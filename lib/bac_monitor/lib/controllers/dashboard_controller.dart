import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../widgets/finance/date_range.dart';

class DashboardController extends GetxController {

  var tabIndex = 0.obs;
  var selectedRange = DateRange.last7Days.obs;
  var customRange = Rxn<DateTimeRange>();

  void changeTabIndex(int index) {
    tabIndex.value = index;
  }
  void updateDateRange(DateRange range, DateTimeRange? customRange) {
    selectedRange.value = range;
    customRange != null ? this.customRange.value = customRange : this.customRange.value = null;
  }

}