import 'package:flutter/material.dart';

import '../../additions/colors.dart';

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
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (!widget.focusNode.hasFocus && _searchController.text.isNotEmpty) {
        _searchController.clear();
        widget.onSearchChanged('');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: TextField(
        focusNode: widget.focusNode,
        controller: _searchController,
        onChanged: widget.onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: PrimaryColors.brightYellow,
        decoration: InputDecoration(
          filled: true,
          fillColor: PrimaryColors.lightBlue,
          hintText: 'Search for products...',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(
            Icons.search,
            color: PrimaryColors.brightYellow,
            size: 24,
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