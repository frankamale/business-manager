
class KpiSalesData {
  final int? id;
  final int kpiId;
  final String processingDate;
  final String? sellingPoint;
  final String? currency;
  final String kpi;
  final int quantity;
  final double amount1; // Used for profit
  final double amount2; // Used for transaction value
  final int? createdAt;

  KpiSalesData({
    this.id,
    required this.kpiId,
    required this.processingDate,
    this.sellingPoint,
    this.currency,
    required this.kpi,
    this.quantity = 0,
    this.amount1 = 0.0,
    this.amount2 = 0.0,
    this.createdAt,
  });

  /// Create KpiSalesData from API response JSON
  factory KpiSalesData.fromJson(Map<String, dynamic> json, int kpiId) {
    return KpiSalesData(
      kpiId: kpiId,
      processingDate: json['processingdate'] as String? ?? '',
      sellingPoint: json['sellingpoint'] as String?,
      currency: json['currency'] as String?,
      kpi: json['kpi'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      amount1: _parseDouble(json['amount1']),
      amount2: _parseDouble(json['amount2']),
    );
  }

  /// Create KpiSalesData from database map
  factory KpiSalesData.fromMap(Map<String, dynamic> map) {
    return KpiSalesData(
      id: map['id'] as int?,
      kpiId: map['kpi_id'] as int? ?? 0,
      processingDate: map['processing_date'] as String? ?? '',
      sellingPoint: map['selling_point'] as String?,
      currency: map['currency'] as String?,
      kpi: map['kpi'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      amount1: (map['amount1'] as num?)?.toDouble() ?? 0.0,
      amount2: (map['amount2'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] as int?,
    );
  }

  /// Convert to database map for insertion
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'kpi_id': kpiId,
      'processing_date': processingDate,
      'selling_point': sellingPoint,
      'currency': currency,
      'kpi': kpi,
      'quantity': quantity,
      'amount1': amount1,
      'amount2': amount2,
    };
  }

  /// Parse double from various formats (int, double, String)
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  @override
  String toString() {
    return 'KpiSalesData(kpiId: $kpiId, processingDate: $processingDate, kpi: $kpi, quantity: $quantity, amount1: $amount1, amount2: $amount2)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KpiSalesData &&
        other.kpiId == kpiId &&
        other.processingDate == processingDate &&
        other.sellingPoint == sellingPoint &&
        other.kpi == kpi;
  }

  @override
  int get hashCode => Object.hash(kpiId, processingDate, sellingPoint, kpi);
}

/// KPI mode constants
class KpiMode {
  /// All transactions
  static const int allTransactions = 0;
  
  /// Cash transactions
  static const int cash = 1;
  
  /// Pending payment transactions
  static const int pendingPayment = 2;
  
  /// Payment modes
  static const int paymentModes = 3;
  
  /// Salesperson data
  static const int salesperson = 4;
  
  /// Profit data (amount1=profit, amount2=transaction value)
  static const int profit = 5;
  
  /// EFRIS status (1-pending, 2-uploaded, 3-failed)
  static const int efrisStatus = 6;
  
  /// By stock category
  static const int stockCategory = 7;
  
  /// By item
  static const int byItem = 8;

  /// Get all KPI modes as list
  static List<int> get all => [
    allTransactions,
    cash,
    pendingPayment,
    paymentModes,
    salesperson,
    profit,
    efrisStatus,
    stockCategory,
    byItem,
  ];

  /// Get name for KPI mode
  static String getName(int mode) {
    switch (mode) {
      case allTransactions:
        return 'All Transactions';
      case cash:
        return 'Cash';
      case pendingPayment:
        return 'Pending Payment';
      case paymentModes:
        return 'Payment Modes';
      case salesperson:
        return 'Salesperson';
      case profit:
        return 'Profit';
      case efrisStatus:
        return 'EFRIS Status';
      case stockCategory:
        return 'Stock Category';
      case byItem:
        return 'By Item';
      default:
        return 'Unknown';
    }
  }
}

/// Timeframe constants
class KpiTimeframe {
  /// Normal date
  static const int normal = 1;
  
  /// Week
  static const int week = 2;
  
  /// Month
  static const int month = 3;
  
  /// Quarter
  static const int quarter = 4;
  
  /// Year
  static const int year = 5;

  /// Get name for timeframe
  static String getName(int timeframe) {
    switch (timeframe) {
      case normal:
        return 'Daily';
      case week:
        return 'Weekly';
      case month:
        return 'Monthly';
      case quarter:
        return 'Quarterly';
      case year:
        return 'Yearly';
      default:
        return 'Unknown';
    }
  }
}