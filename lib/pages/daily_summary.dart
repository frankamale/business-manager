import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailySummary extends StatelessWidget {
  const DailySummary({super.key});

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
                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
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
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
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
    final selectedDate = DateTime(2025, 1, 1);
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(selectedDate);

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
      body: SafeArea(
        child: Column(
          children: [
            // Date Header Card
            Container(
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
                    "REVIEW DATE",
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
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
                    _buildSummaryTable(
                      title: "Payment Methods",
                      data: [
                        {
                          'icon': Icons.payments_outlined,
                          'label': 'Total Cash Amount',
                          'amount': 'UGX 0',
                          'color': Colors.green,
                        },
                        {
                          'icon': Icons.credit_card,
                          'label': 'Card Amount',
                          'amount': 'UGX 0',
                          'color': Colors.blue,
                        },
                        {
                          'icon': Icons.phone_android,
                          'label': 'Mobile Money',
                          'amount': 'UGX 0',
                          'color': Colors.orange,
                        },
                        {
                          'icon': Icons.account_balance_wallet,
                          'label': 'Credit Amount',
                          'amount': 'UGX 0',
                          'color': Colors.purple,
                        },
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sales Summary Table
                    _buildSummaryTable(
                      title: "Sales Summary",
                      data: [
                        {
                          'icon': Icons.local_drink,
                          'label': 'Total Drinks Amount',
                          'amount': 'UGX 0',
                          'color': Colors.cyan,
                        },
                        {
                          'icon': Icons.restaurant_menu,
                          'label': 'Total Menu Amount',
                          'amount': 'UGX 0',
                          'color': Colors.red,
                        },
                        {
                          'icon': Icons.card_giftcard,
                          'label': 'Complementary Items',
                          'amount': 'UGX 0',
                          'color': Colors.teal,
                        },
                      ],
                    ),
                    const SizedBox(height: 16),
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
                      onPressed: () {},
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
}
