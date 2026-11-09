import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

import '../models/inventory_item.dart';
import '../widgets/barcode_scanner.dart';
import '../../shared/database/unified_db_helper.dart';

/// Scan or search an item to see its current price for every packaging.
/// Mirrors the web Price Checker and works offline from the cached inventory.
class PriceChecker extends StatefulWidget {
  final Color color;

  const PriceChecker({super.key, required this.color});

  @override
  State<PriceChecker> createState() => _PriceCheckerState();
}

class _PriceCheckerState extends State<PriceChecker> {
  static const _recentKey = 'price_checker_recent';
  static const _recentLimit = 5;

  final _db = UnifiedDatabaseHelper.instance;
  final _storage = GetStorage();
  final _money = NumberFormat('#,###', 'en_US');
  final _searchController = TextEditingController();

  List<InventoryItem> _packagings = [];
  String? _notFoundCode;
  List<InventoryItem> _matches = [];
  List<InventoryItem> _recentItems = [];
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    // Open the camera straight away, like the web price checker
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Only item ids are kept, so recent items always show the current price.
  List<String> _recentIds() {
    try {
      final stored = _storage.read(_recentKey);
      return stored is List ? stored.map((e) => e.toString()).toList() : [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadRecent() async {
    final items = <InventoryItem>[];
    for (final id in _recentIds()) {
      try {
        final rows = await _db.getInventoryPackagings(id);
        if (rows.isNotEmpty) items.add(rows.first);
      } catch (_) {}
    }
    if (mounted) setState(() => _recentItems = items);
  }

  Future<void> _rememberRecent(String id) async {
    final next = [id, ..._recentIds().where((r) => r != id)]
        .take(_recentLimit)
        .toList();
    await _storage.write(_recentKey, next);
    await _loadRecent();
  }

  Future<void> _scan() async {
    final result = await Get.to<InventoryItem?>(() => const BarcodeScannerPage());
    if (result != null) {
      HapticFeedback.mediumImpact();
      await _showItem(result);
    }
  }

  Future<void> _showItem(InventoryItem item) async {
    List<InventoryItem> rows = [];
    try {
      rows = await _db.getInventoryPackagings(item.id);
    } catch (e) {
      debugPrint('PriceChecker: failed to load packagings: $e');
    }
    // Each packaging is its own row; keep one per packaging
    final byPackaging = <String, InventoryItem>{};
    for (final r in rows.isEmpty ? [item] : rows) {
      byPackaging.putIfAbsent(r.ipdid, () => r);
    }
    if (!mounted) return;
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _packagings = byPackaging.values.toList();
      _notFoundCode = null;
      _matches = [];
    });
    await _rememberRecent(item.id);
  }

  Future<void> _onSearchChanged(String value) async {
    final query = value.trim();
    final token = ++_searchToken;
    if (query.isEmpty) {
      setState(() => _matches = []);
      return;
    }
    List<InventoryItem> results = [];
    try {
      results = await _db.searchInventoryItems(query, limit: 100);
    } catch (e) {
      debugPrint('PriceChecker: search failed: $e');
    }
    if (!mounted || token != _searchToken) return;
    // List each item once, even though every packaging is its own row
    final unique = <String, InventoryItem>{};
    for (final r in results) {
      unique.putIfAbsent(r.id, () => r);
    }
    setState(() => _matches = unique.values.take(20).toList());
  }

  // Submit only opens an item when the match is certain; otherwise the list stays up.
  Future<void> _onSearchSubmitted(String value) async {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return;
    await _onSearchChanged(value);
    final exact = _matches.firstWhereOrNull(
      (i) => i.code.trim().toLowerCase() == query,
    );
    final match = exact ?? (_matches.length == 1 ? _matches.first : null);
    if (match != null) {
      await _showItem(match);
    } else if (_matches.isEmpty) {
      final byBarcode = await _db.getInventoryByBarcode(value.trim());
      if (byBarcode != null) {
        await _showItem(byBarcode);
      } else {
        setState(() {
          _packagings = [];
          _notFoundCode = value.trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Checker'),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (_packagings.isNotEmpty) _buildResultCard(),
            if (_notFoundCode != null) _buildNotFoundCard(),
            if (_packagings.isNotEmpty || _notFoundCode != null)
              const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(
                _packagings.isEmpty && _notFoundCode == null
                    ? 'Scan barcode'
                    : 'Scan again',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Or type item name or code',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
            ),
            const SizedBox(height: 12),
            if (hasQuery && _matches.isNotEmpty)
              _buildItemList(_matches)
            else if (hasQuery)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No matching items',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else if (_recentItems.isNotEmpty) ...[
              const Text(
                'Recent items',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildItemList(_recentItems),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final item = _packagings.first;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Code: ${item.code}',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          ..._packagings.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'UGX ${_money.format(p.price.round())} ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
                    TextSpan(
                      text:
                          '(${p.packaging}${p.packsize > 1 ? ' of ${_money.format(p.packsize)}' : ''})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Item not found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'No match for "$_notFoundCode"',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(List<InventoryItem> items) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              dense: true,
              title: Text(
                items[i].name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(items[i].code),
              onTap: () => _showItem(items[i]),
            ),
          ],
        ],
      ),
    );
  }
}
