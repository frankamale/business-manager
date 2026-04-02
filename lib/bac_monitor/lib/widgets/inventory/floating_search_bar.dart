import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../additions/colors.dart';
import '../../controllers/mon_inventory_controller.dart';

class FloatingSearchBar extends StatefulWidget {
  final Function(String) onSearchChanged;
  final FocusNode focusNode;

  const FloatingSearchBar({super.key, required this.onSearchChanged, required this.focusNode});

  @override
  State<FloatingSearchBar> createState() => _FloatingSearchBarState();
}

class _FloatingSearchBarState extends State<FloatingSearchBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    if (Get.isRegistered<MonInventoryController>()) {
      Get.find<MonInventoryController>().clearSearch();
    }
    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: TextField(
        focusNode: widget.focusNode,
        controller: _searchController,
        onChanged: widget.onSearchChanged,
        style: TextStyle(color: AppColors.getTextPrimaryColor(context), fontSize: 16),
        cursorColor: AppColors.getAccentColor(context),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.getSurfaceColor(context),
          hintText: 'Search for products...',
          hintStyle: TextStyle(color: AppColors.getTextHintColor(context)),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.getAccentColor(context),
            size: 24,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, child) {
              return value.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                    )
                  : const SizedBox.shrink();
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
      ),
    );
  }
}