import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../controllers/sales_controller.dart';
import '../services/print_service.dart';

class DailySummary extends StatefulWidget {
  const DailySummary({super.key});

  @override
  State<DailySummary> createState() => _DailySummaryState();
}

class _DailySummaryState extends State<DailySummary> {
  final SalesController _salesController = Get.find<SalesController>();
  DateTime selectedDate = DateTime.now();
  Map<String, dynamic>? summaryData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      isLoading = true;
    });

    try {
      final summary = await _salesController.getDailySummary(selectedDate);
      setState(() {
        summaryData = summary;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading summary: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _loadSummary();
    }
  }

  Widget _buildSummaryTable({
    required String title,
    required List<Map<String, dynamic>> data,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              headingRowHeight: 48,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 52,
              columnSpacing: 20,
              horizontalMargin: 16,
              headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black12, width: 1),
                ),
              ),
              columns: const [
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Item',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  numeric: true,
                ),
              ],
              rows: data.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                final isTotal = row['isTotal'] as bool? ?? false;

                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      if (isTotal) {
                        return Colors.blue[50];
                      }
                      if (index.isEven) {
                        return Colors.grey[50];
                      }
                      return null;
                    },
                  ),
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (row['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              row['icon'] as IconData,
                              color: row['color'] as Color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              row['label'] as String,
                              style: TextStyle(
                                fontSize: isTotal ? 15 : 14,
                                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        alignment: Alignment.centerRight,
                        child: Text(
                          row['amount'] as String,
                          style: TextStyle(
                            fontSize: isTotal ? 16 : 15,
                            fontWeight: FontWeight.bold,
                            color: isTotal ? Colors.blue.shade900 : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(selectedDate);
    final currencyFormat = NumberFormat('#,###', 'en_US');

    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text(
            "Daily Summary",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final overallTotal = summaryData?['overallTotal'] as Map<String, dynamic>? ?? {};
    final totalSales = (overallTotal['totalSales'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (overallTotal['totalPaid'] as num?)?.toDouble() ?? 0.0;
    // totalBalance is the actual amount not yet received by cashiers
    final pendingAmount = ((overallTotal['totalBalance'] as num?)?.toDouble() ?? 0.0) > 0 ? ((overallTotal['totalBalance'] as num?)?.toDouble() ?? 0.0) : 0.0 ;
    final totalTransactions = overallTotal['totalTransactions'] as int? ?? 0;

    final paymentSummary = summaryData?['paymentSummary'] as List<Map<String, dynamic>>? ?? [];
    final categorySummary = summaryData?['categorySummary'] as List<Map<String, dynamic>>? ?? [];
    final complementaryTotal = (summaryData?['complementaryTotal'] as num?)?.toDouble() ?? 0.0;

    // Build payment method list
    final paymentData = <Map<String, dynamic>>[];
    double totalPaidAmount = 0.0;

    for (var payment in paymentSummary) {
      final type = payment['paymenttype'] as String? ?? 'Unknown';
      if (type.toLowerCase() == 'pending') continue;

      double amount = (overallTotal['totalSales'] as num?)?.toDouble() ?? 0.0;
      totalPaidAmount += amount;

      IconData icon;
      Color color;
      String label;

      switch (type.toLowerCase()) {
        case 'cash':
          icon = Icons.payments_outlined;
          color = Colors.green;
          label = 'Cash';
          break;
        case 'card':
          icon = Icons.credit_card;
          color = Colors.blue;
          label = 'Card';
          break;
        case 'mobile':
          icon = Icons.phone_android;
          color = Colors.orange;
          label = 'Mobile Money';
          break;
        default:
          icon = Icons.account_balance_wallet;
          color = Colors.purple;
          label = type;
      }

      paymentData.add({
        'icon': icon,
        'label': label,
        'amount': 'UGX ${currencyFormat.format(amount)}',
        'color': color,
      });
    }


    // Add Pending row
    paymentData.add({
      'icon': Icons.pending_actions,
      'label': 'Pending',
      'amount': 'UGX ${currencyFormat.format(pendingAmount)}',
      'color': Colors.red,
    });

    // Add Total row
    paymentData.add({
      'icon': Icons.account_balance,
      'label': 'TOTAL',
      'amount': 'UGX ${currencyFormat.format(totalSales)}',
      'color': Colors.blue.shade700,
      'isTotal': true,
    });

    // Build category data
    final categoryData = <Map<String, dynamic>>[];
    for (var category in categorySummary) {
      final catName = category['category'] as String? ?? 'Unknown';
      final amount = (category['totalAmount'] as num?)?.toDouble() ?? 0.0;

      IconData icon;
      Color color;

      switch (catName.toLowerCase()) {
        case 'drinks':
        case 'beverage':
          icon = Icons.local_drink;
          color = Colors.cyan;
          break;
        case 'food':
        case 'menu':
          icon = Icons.restaurant_menu;
          color = Colors.red;
          break;
        default:
          icon = Icons.shopping_bag;
          color = Colors.blue;
      }

      categoryData.add({
        'icon': icon,
        'label': '$catName Amount',
        'amount': 'UGX ${currencyFormat.format(amount)}',
        'color': color,
      });
    }

    // Add complementary if exists
    if (complementaryTotal > 0) {
      categoryData.add({
        'icon': Icons.card_giftcard,
        'label': 'Complementary Items',
        'amount': 'UGX ${currencyFormat.format(complementaryTotal)}',
        'color': Colors.teal,
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Daily Summary",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Header Card
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[700]!, Colors.blue[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "REVIEW DATE (Tap to change)",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.white30),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Transactions',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '$totalTransactions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total Sales',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'UGX ${currencyFormat.format(totalSales)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable Summary Tables
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Methods Table
                    if (paymentData.isNotEmpty)
                      _buildSummaryTable(
                        title: "Payment Methods",
                        data: paymentData,
                      ),
                    const SizedBox(height: 16),

                    // Sales Summary Table
                    if (categoryData.isNotEmpty)
                      _buildSummaryTable(
                        title: "Sales Summary by Category",
                        data: categoryData,
                      ),
                    const SizedBox(height: 16),

                    // Show message if no data
                    if (paymentData.isEmpty && categoryData.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No sales data for selected date',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showPrintOptions(),
                      icon: const Icon(Icons.print),
                      label: const Text("Print"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.blue[700]!),
                        foregroundColor: Colors.blue[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Commit"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text("Cancel"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    String title,
    double amount,
    int transactions,
    Color color,
    IconData icon,
  ) {
    final currencyFormat = NumberFormat('#,###', 'en_US');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$transactions',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'UGX ${currencyFormat.format(amount)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPrintOptions() async {
    if (summaryData == null) {
      Get.snackbar(
        'Error',
        'No data available to print',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    await Get.dialog(
      AlertDialog(
        title: Text('Print Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.print, color: Colors.blue),
              title: Text('Print Summary'),
              subtitle: Text('Print daily summary report'),
              onTap: () async {
                Get.back();
                try {
                  await PrintService.printDailySummary(
                    date: selectedDate,
                    summaryData: summaryData!,
                  );
                } catch (e) {
                  Get.snackbar(
                    'Print Error',
                    'Failed to print',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.shade700,
                    colorText: Colors.white,
                  );
                }
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.share, color: Colors.green),
              title: Text('Share PDF'),
              subtitle: Text('Share summary as PDF file'),
              onTap: () async {
                Get.back();
                try {
                  await PrintService.shareDailySummary(
                    date: selectedDate,
                    summaryData: summaryData!,
                  );
                } catch (e) {
                  Get.snackbar(
                    'Share Error',
                    'Failed to share PDF',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.shade700,
                    colorText: Colors.white,
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
