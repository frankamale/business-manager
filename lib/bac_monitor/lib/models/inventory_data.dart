class MonitorInventoryItem {
  final String id;
  final String name;
  final String sku;
  final String category;
  final int quantityOnHand;
  final int reorderLevel;
  final double costPrice;
  final double sellingPrice;
  final String? imageUrl;
  final DateTime lastUpdated;
  final String servicePoint;
  final String? expiryDate;
  final String packaging;

  MonitorInventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.quantityOnHand,
    required this.reorderLevel,
    required this.costPrice,
    required this.sellingPrice,
    this.imageUrl,
    required this.lastUpdated,
    required this.servicePoint,
    required this.packaging,
    this.expiryDate,
  });

  /// Factory constructor to create from JSON (useful for API response)
  factory MonitorInventoryItem.fromJson(Map<String, dynamic> json) {
    final quantityOnHand = (json['quantityOnHand'] ?? 0).toInt();
    return MonitorInventoryItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      sku: json['code'] ?? '',
      category: json['category'] ?? 'Uncategorized',
      packaging: json['packaging'] ?? 'Uncategorized',
      quantityOnHand: quantityOnHand,
      reorderLevel: 0, // Not provided in API response
      costPrice: 0.0, // Not provided in API response
      sellingPrice: (json['price'] ?? 0).toDouble(),
      imageUrl: json['downloadlink'],
      lastUpdated: DateTime.now(), // Not provided in API response
      servicePoint: json['soldfrom'] ?? "",
      expiryDate: null, // Not provided in API response
    );
  }

  /// Convert to JSON (useful for sending to backend)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'category': category,
      'quantityOnHand': quantityOnHand,
      'reorderLevel': reorderLevel,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'imageUrl': imageUrl,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Helper getter for profit margin
  double get profitMargin => sellingPrice - costPrice;

  /// Helper to check if item is low in stock
  bool get isLowStock => quantityOnHand <= reorderLevel;
}
