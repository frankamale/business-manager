
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../additions/colors.dart';
import '../../components/store/storeOverview.dart';
import '../../controllers/mon_store_controller.dart';
import '../../models/store.dart';
import '../../widgets/finance/date_range.dart';

class Stores extends StatefulWidget {
  const Stores({super.key});

  @override
  State<Stores> createState() => _StoresState();
}

class _StoresState extends State<Stores> {
  late final MonStoresController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(MonStoresController());
    // Ensure stores are fetched when page loads
    _loadStores();
  }

  Future<void> _loadStores() async {
    if (!controller.isInitialized.value) {
      await controller.fetchAllStores();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimaryColors.darkBlue,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: PrimaryColors.brightYellow),
          );
        }

        if (controller.storeList.isEmpty) {
          return const Center(
            child: Text(
              "No stores were found.",
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: PrimaryColors.darkBlue,
              elevation: 0,
              pinned: true,
              title: _buildStoreSelector(controller),
              actions: [
                Tooltip(
                  message: "View store location",
                  child: IconButton(
                    padding: EdgeInsetsGeometry.only(right: 16),
                    icon: const Icon(
                      Icons.quick_contacts_dialer_outlined,
                      size: 28,
                    ),
                    color: Colors.white,
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

  Widget _buildStoreSelector(MonStoresController ctrl) {
    return Obx(
      () => DropdownButtonHideUnderline(
        child: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: DropdownButton<Store>(
            value: ctrl.selectedStore.value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 20.0,
            ),
            dropdownColor: PrimaryColors.lightBlue,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
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
