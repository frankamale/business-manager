import 'package:get/get.dart';

class MonMainNavigationController extends GetxController {
  var selectedIndex = 0.obs;
  void changeTab(int index) {
    selectedIndex.value = index;
  }
}