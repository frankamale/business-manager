
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../additions/colors.dart';
import '../../components/store/storeOverview.dart';
import '../../controllers/mon_kpi_controller.dart';
import '../../controllers/mon_store_controller.dart';
import '../../controllers/mon_store_kpi_controller.dart';
import '../../models/kpi_sales_data.dart';
import '../../models/store.dart';
import '../../widgets/finance/date_range.dart';

class Stores extends StatefulWidget {
  const Stores({super.key});

  @override
  State<Stores> createState() => _StoresState();
}

class _StoresState extends State<Stores> {
  late final MonStoresController controller;
  late final MonStoreKpiTrendController kpiController;
  late final MonKpiController monKpiController;

  @override
  void initState() {
    super.initState();
    // Use existing controllers if registered, otherwise register new ones
    controller = Get.isRegistered<MonStoresController>()
        ? Get.find<MonStoresController>()
        : Get.put(MonStoresController());
    kpiController = Get.isRegistered<MonStoreKpiTrendController>()
        ? Get.find<MonStoreKpiTrendController>()
        : Get.put(MonStoreKpiTrendController());
    monKpiController = Get.isRegistered<MonKpiController>()
        ? Get.find<MonKpiController>()
        : Get.put(MonKpiController());
    // Ensure stores are fetched when page loads
    _loadStores();
  }

  Future<void> _loadStores() async {
    if (!controller.isInitialized.value) {
      await controller.fetchAllStores();
      // FIX: Now fetch all data for the default selection (All stores, last 7 days)
      debugPrint('StoresPage: Fetching all data for initial selection...');
      await controller.fetchAllDataForSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: Obx(() {
        // Check if stores are initialized before showing content
        if (!controller.isInitialized.value) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.getAccentColor(context)),
          );
        }

        if (controller.isLoading.value && controller.storeList.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.getAccentColor(context)),
          );
        }
        if (controller.storeList.isEmpty) {
          return Center(
            child: Text(
              "No stores were found.",
              style: TextStyle(color: AppColors.getTextSecondaryColor(context)),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.getCardColor(context),
              elevation: 0,
              pinned: true,
              title: _buildStoreSelector(context, controller),
              actions: [
                Tooltip(
                  message: "View store location",
                  child: IconButton(
                    padding: EdgeInsetsGeometry.only(right: 16),
                    icon: Icon(
                      Icons.quick_contacts_dialer_outlined,
                      size: 28,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                    onPressed:
                        controller.selectedStore.value?.id == Store.all.id
                        ? null
                        : () {
                            if (kDebugMode) {
                              print(
                                "Showing location for ${controller.selectedStore.value?.name}",
                              );
                            }
                            // contact store
                          },
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(65.0),
                child: DateRangePicker(
                  onDateRangeSelected: controller.onDateRangeChanged,
                ),
              ),
            ),
            SliverToBoxAdapter(child: StoreOverview()),

          ],
        );
      }),
    );
  }

  Widget _buildStoreSelector(BuildContext context, MonStoresController ctrl) {
    return Obx(
      () => DropdownButtonHideUnderline(
        child: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: DropdownButton<Store>(
            value: ctrl.selectedStore.value,
            style: TextStyle(
              color: AppColors.getTextPrimaryColor(context),
              fontWeight: FontWeight.w500,
              fontSize: 20.0,
            ),
            dropdownColor: AppColors.getCardColor(context),
            icon: Icon(Icons.arrow_drop_down, color: AppColors.getTextPrimaryColor(context)),
            items: ctrl.storeList.map<DropdownMenuItem<Store>>((Store store) {
              return DropdownMenuItem<Store>(
                value: store,
                child: Text(store.name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (Store? newValue) {
              ctrl.onStoreChanged(newValue);
            },
          ),
        ),
      ),
    );
  }
}
