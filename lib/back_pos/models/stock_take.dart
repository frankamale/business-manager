class StockTake {
  final String id;
  final String inventoryId;
  final String itemName;
  final String code;
  final String packaging;
  final double quantity;
  final double costPrice;
  final double amount;
  final double markup;
  final double sellingPrice;
  final String batchNumber;
  final DateTime? expiryDate;
  final String? servicePointId;
  final DateTime createdAt;
  final String uploadStatus;

  StockTake({
    required this.id,
    required this.inventoryId,
    required this.itemName,
    required this.code,
    required this.packaging,
    required this.quantity,
    required this.costPrice,
    required this.amount,
    required this.markup,
    required this.sellingPrice,
    required this.batchNumber,
    required this.expiryDate,
    required this.servicePointId,
    required this.createdAt,
    this.uploadStatus = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inventoryid': inventoryId,
      'itemname': itemName,
      'code': code,
      'packaging': packaging,
      'quantity': quantity,
      'costprice': costPrice,
      'amount': amount,
      'markup': markup,
      'sellingprice': sellingPrice,
      'batchnumber': batchNumber,
      'expirydate': expiryDate?.millisecondsSinceEpoch,
      'servicepointid': servicePointId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'upload_status': uploadStatus,
    };
  }

  factory StockTake.fromMap(Map<String, dynamic> map) {
    return StockTake(
      id: map['id']?.toString() ?? '',
      inventoryId: map['inventoryid']?.toString() ?? '',
      itemName: map['itemname']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      packaging: map['packaging']?.toString() ?? '',
      quantity: _toDouble(map['quantity']),
      costPrice: _toDouble(map['costprice']),
      amount: _toDouble(map['amount']),
      markup: _toDouble(map['markup']),
      sellingPrice: _toDouble(map['sellingprice']),
      batchNumber: map['batchnumber']?.toString() ?? '',
      expiryDate: map['expirydate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expirydate'] as int)
          : null,
      servicePointId: map['servicepointid']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.now(),
      uploadStatus: map['upload_status']?.toString() ?? 'pending',
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
