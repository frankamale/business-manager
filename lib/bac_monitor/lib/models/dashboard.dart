class SalesDataPoint {
  final DateTime date;
  final double amount;

  SalesDataPoint(this.date, this.amount);
}

class StockAlert {
  final String productName;
  final int quantityLeft;

  StockAlert(this.productName, this.quantityLeft);
}

class StorePerformance {
  final String storeName;
  final double performanceValue;

  StorePerformance(this.storeName, this.performanceValue);
}

enum StockLevel { critical, low }

class CategorizedStockAlert {
  final String name;
  final int quantity;
  final StockLevel level;

  CategorizedStockAlert(this.name, this.quantity, this.level);
}

class PaymentData {
  final String paymentMode;
  final double totalAmount;

  PaymentData({required this.paymentMode, required this.totalAmount});
}

class CashierData {
  final String cashierName;
  final double totalAmount;

  CashierData({required this.cashierName, required this.totalAmount});
}
