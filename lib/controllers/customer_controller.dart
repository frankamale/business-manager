import 'package:get/get.dart';
import '../services/api_services.dart';
import '../models/customer.dart';

class CustomerController extends GetxController {
  final _apiService = ApiService();

  // Reactive list of customers
  var customers = <Customer>[].obs;

  // Loading state
  var isLoadingCustomers = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadCustomers();
  }

  // Load customers from API
  Future<void> loadCustomers() async {
    try {
      print('👥 Loading customers from API...');
      isLoadingCustomers.value = true;

      final fetchedCustomers = await _apiService.fetchCustomers();
      customers.value = fetchedCustomers;

      isLoadingCustomers.value = false;

      print('✅ Successfully loaded ${fetchedCustomers.length} customers from API');
    } catch (e) {
      isLoadingCustomers.value = false;
      print('❌ Error loading customers from API: $e');
    }
  }

  // Get customer by ID
  Customer? getCustomerById(String id) {
    try {
      return customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get customer by fullnames
  Customer? getCustomerByFullnames(String fullnames) {
    try {
      return customers.firstWhere((customer) => customer.fullnames == fullnames);
    } catch (e) {
      return null;
    }
  }
}